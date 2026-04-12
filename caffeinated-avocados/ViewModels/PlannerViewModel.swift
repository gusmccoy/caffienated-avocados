// ViewModels/PlannerViewModel.swift
// Manages coach/athlete planner relationships and the athlete-switching context for planners.
// Invite handshake and workout sync are backed by CloudKit public database.

import Foundation
import Observation
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Errors

enum PlannerError: LocalizedError {
    case emptyCode
    case codeNotFound
    case alreadyHasPlanner
    case cloudKitError(String)

    var errorDescription: String? {
        switch self {
        case .emptyCode:         return "Please enter an invite code."
        case .codeNotFound:      return "No pending invite found for that code. Make sure the athlete sent an invite and the code is correct."
        case .alreadyHasPlanner: return "You already have an active planner. Revoke the existing one first."
        case .cloudKitError(let msg): return msg
        }
    }
}

// MARK: - ViewModel

@Observable
final class PlannerViewModel {

    // MARK: - User Identity (persisted in UserDefaults)

    /// The user's display name — shown to the other party in a planner relationship.
    var currentUserName: String {
        get { UserDefaults.standard.string(forKey: "userDisplayName") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "userDisplayName") }
    }

    // MARK: - Sheet / UI State

    var isShowingInviteSheet: Bool = false
    var isShowingAcceptSheet: Bool = false
    /// Input field in the "Accept Invite" sheet.
    var acceptCodeInput: String = ""
    /// Error shown in accept sheet.
    var acceptError: String? = nil
    /// Invite code generated for the outgoing invite — shown to the athlete for sharing.
    var generatedInviteCode: String = ""
    /// Transient "copied" feedback on the share button.
    var isCopied: Bool = false
    /// Loading indicator for async CloudKit operations.
    var isLoading: Bool = false

    // MARK: - Planner Context
    //
    // When a planner taps into an athlete's row, `activeAthleteRelationship` is set.
    // PlanView reads this to show the correct header and restrict add/edit access.

    var activeAthleteRelationship: PlannerRelationship? = nil

    // MARK: - Invite Generation (athlete side)

    /// Generates a new 8-char uppercase invite code, saves it to CloudKit public DB,
    /// and inserts a local pendingOutgoing record.
    @discardableResult
    func generateInvite(athleteDisplayName: String, modelContext: ModelContext) -> String {
        let code = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)).uppercased()
        generatedInviteCode = code

        let displayName = athleteDisplayName.isEmpty ? "Athlete" : athleteDisplayName

        // Insert local record immediately
        let rel = PlannerRelationship(
            inviteCode: code,
            status: .pendingOutgoing,
            currentUserIsAthlete: true,
            athleteDisplayName: displayName,
            plannerDisplayName: ""
        )
        modelContext.insert(rel)

        // Push to CloudKit in the background
        Task {
            do {
                try await CloudKitPlannerService.createInvite(code: code, athleteDisplayName: displayName)
            } catch {
                print("CloudKit invite creation failed: \(error.localizedDescription)")
            }
        }

        return code
    }

    /// Cancels a pending outgoing invite — removes it locally and from CloudKit.
    func cancelInvite(_ relationship: PlannerRelationship, modelContext: ModelContext) {
        let code = relationship.inviteCode
        modelContext.delete(relationship)
        if generatedInviteCode == code {
            generatedInviteCode = ""
        }
        Task {
            try? await CloudKitPlannerService.cancelInvite(code: code)
        }
    }

    // MARK: - Invite Acceptance (planner/coach side)

    /// Called when a planner enters an invite code.
    /// Queries CloudKit public DB for the matching pending invite, accepts it,
    /// and creates a local planner-side PlannerRelationship.
    func acceptInvite(
        code: String,
        plannerDisplayName: String,
        modelContext: ModelContext
    ) async throws {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { throw PlannerError.emptyCode }

        let plannerName = plannerDisplayName.isEmpty ? "Coach" : plannerDisplayName

        do {
            let result = try await CloudKitPlannerService.acceptInvite(
                code: trimmed,
                plannerDisplayName: plannerName
            )

            // Insert a planner-side record locally (currentUserIsAthlete = false)
            let plannerRecord = PlannerRelationship(
                inviteCode: trimmed,
                status: .accepted,
                currentUserIsAthlete: false,
                athleteDisplayName: result.athleteDisplayName,
                plannerDisplayName: plannerName
            )
            modelContext.insert(plannerRecord)

            acceptCodeInput = ""
            acceptError = nil
            isShowingAcceptSheet = false
        } catch let error as CloudKitPlannerError {
            throw PlannerError.cloudKitError(error.localizedDescription)
        }
    }

    // MARK: - Invite Polling (athlete side)

    /// Athlete polls CloudKit to check if their invite has been accepted.
    /// If accepted, updates the local relationship with the planner's name.
    func checkInviteAccepted(
        _ relationship: PlannerRelationship,
        modelContext: ModelContext
    ) async {
        guard relationship.status == .pendingOutgoing else { return }
        do {
            if let plannerName = try await CloudKitPlannerService.checkInviteStatus(code: relationship.inviteCode) {
                relationship.status = .accepted
                relationship.plannerDisplayName = plannerName
            }
        } catch {
            print("Invite status check failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Revocation (either side)

    /// Revokes the relationship. Removes both sides' records from the local store
    /// and cleans up CloudKit.
    func revoke(_ relationship: PlannerRelationship, modelContext: ModelContext) {
        let code = relationship.inviteCode

        // Remove all local records with the same invite code
        let descriptor = FetchDescriptor<PlannerRelationship>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        for rel in all where rel.inviteCode == code {
            modelContext.delete(rel)
        }
        if activeAthleteRelationship?.inviteCode == code {
            activeAthleteRelationship = nil
        }

        // Clean up CloudKit
        Task {
            try? await CloudKitPlannerService.revokeRelationship(code: code)
        }

        // Remove any locally synced coach workouts for this relationship
        let workoutDescriptor = FetchDescriptor<PlannedWorkout>()
        let allWorkouts = (try? modelContext.fetch(workoutDescriptor)) ?? []
        for workout in allWorkouts {
            if let relId = workout.createdByPlannerRelationshipId {
                let matchesCode = all.contains { $0.id.uuidString == relId && $0.inviteCode == code }
                if matchesCode {
                    modelContext.delete(workout)
                }
            }
        }
    }

    // MARK: - Workout Sync: Push (planner/coach side)

    /// Pushes a coach-created PlannedWorkout to CloudKit so the athlete can pull it.
    func pushWorkoutToCloud(_ workout: PlannedWorkout, inviteCode: String, plannerDisplayName: String) {
        let segmentsJSON: String
        if let data = try? JSONEncoder().encode(workout.runSegments),
           let str = String(data: data, encoding: .utf8) {
            segmentsJSON = str
        } else {
            segmentsJSON = "[]"
        }

        Task {
            do {
                try await CloudKitPlannerService.saveWorkout(
                    inviteCode: inviteCode,
                    workoutId: workout.id.uuidString,
                    date: workout.date,
                    workoutTypeRaw: workout.workoutType.rawValue,
                    title: workout.title,
                    plannedDistanceMiles: workout.plannedDistanceMiles,
                    plannedDurationSeconds: workout.plannedDurationSeconds,
                    crossTrainingActivityTypeRaw: workout.crossTrainingActivityTypeRaw,
                    runCategoryRaw: workout.runCategoryRaw,
                    runSegmentsJSON: segmentsJSON,
                    notes: workout.notes,
                    intensityLevelRaw: workout.intensityLevel.rawValue,
                    plannerDisplayName: plannerDisplayName
                )
            } catch {
                print("CloudKit workout push failed: \(error.localizedDescription)")
            }
        }
    }

    /// Soft-deletes a workout in CloudKit so the athlete removes it on next sync.
    func deleteWorkoutFromCloud(workoutId: String) {
        Task {
            try? await CloudKitPlannerService.softDeleteWorkout(workoutId: workoutId)
        }
    }

    // MARK: - Workout Sync: Pull (athlete side)

    /// Athlete pulls coach-created workouts from CloudKit and upserts them locally.
    func syncCoachWorkouts(
        forRelationship relationship: PlannerRelationship,
        modelContext: ModelContext
    ) async {
        guard relationship.currentUserIsAthlete && relationship.status == .accepted else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            // Pull active workouts
            let remoteWorkouts = try await CloudKitPlannerService.fetchWorkouts(
                forInviteCode: relationship.inviteCode
            )

            // Fetch existing local coach workouts for this relationship
            let descriptor = FetchDescriptor<PlannedWorkout>()
            let allLocal = (try? modelContext.fetch(descriptor)) ?? []
            let localCoachWorkouts = allLocal.filter { $0.createdByPlannerRelationshipId == relationship.id.uuidString }
            var localByWorkoutId: [String: PlannedWorkout] = [:]
            for w in localCoachWorkouts {
                localByWorkoutId[w.id.uuidString] = w
            }

            // Upsert remote workouts
            for dict in remoteWorkouts {
                let workoutId = dict["workoutId"] as? String ?? ""
                if let existing = localByWorkoutId[workoutId] {
                    // Update existing
                    updateLocalWorkout(existing, from: dict, relationship: relationship)
                    localByWorkoutId.removeValue(forKey: workoutId)
                } else {
                    // Insert new
                    if let workout = createLocalWorkout(from: dict, relationship: relationship) {
                        modelContext.insert(workout)
                    }
                }
            }

            // Handle soft-deleted workouts
            let deletedIds = try await CloudKitPlannerService.fetchDeletedWorkoutIds(
                forInviteCode: relationship.inviteCode
            )
            for deletedId in deletedIds {
                if let toRemove = localByWorkoutId[deletedId] {
                    modelContext.delete(toRemove)
                    localByWorkoutId.removeValue(forKey: deletedId)
                } else {
                    // Check all local workouts — might have a different relationship ID mapping
                    for w in allLocal where w.id.uuidString == deletedId {
                        modelContext.delete(w)
                    }
                }
            }
        } catch {
            print("Coach workout sync failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    #if canImport(UIKit)
    func copyToClipboard(_ string: String) {
        UIPasteboard.general.string = string
        isCopied = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            isCopied = false
        }
    }
    #endif

    // MARK: - Private: Workout Conversion

    private func createLocalWorkout(from dict: [String: Any], relationship: PlannerRelationship) -> PlannedWorkout? {
        guard let workoutId = dict["workoutId"] as? String,
              let uuid = UUID(uuidString: workoutId) else { return nil }

        let date = dict["date"] as? Date ?? Date()
        let typeRaw = dict["workoutTypeRaw"] as? String ?? "Running"
        let type = WorkoutType(rawValue: typeRaw) ?? .running
        let title = dict["title"] as? String ?? ""
        let distance = dict["plannedDistanceMiles"] as? Double ?? 0
        let duration = dict["plannedDurationSeconds"] as? Int ?? 0
        let ctRaw = dict["crossTrainingActivityTypeRaw"] as? String ?? CrossTrainingActivityType.other.rawValue
        let ct = CrossTrainingActivityType(rawValue: ctRaw) ?? .other
        let runCatRaw = dict["runCategoryRaw"] as? String ?? RunCategory.none.rawValue
        let runCat = RunCategory(rawValue: runCatRaw) ?? .none
        let segJSON = dict["runSegmentsJSON"] as? String ?? "[]"
        let segments = decodeSegments(segJSON)
        let notes = dict["notes"] as? String ?? ""
        let intensityRaw = dict["intensityLevelRaw"] as? String ?? IntensityLevel.moderate.rawValue
        let intensity = IntensityLevel(rawValue: intensityRaw) ?? .moderate
        let plannerName = dict["plannerDisplayName"] as? String ?? relationship.plannerDisplayName

        let workout = PlannedWorkout(
            date: date,
            workoutType: type,
            title: title,
            plannedDistanceMiles: distance,
            plannedDurationSeconds: duration,
            crossTrainingActivityType: ct,
            runCategory: runCat,
            runSegments: segments,
            notes: notes,
            intensityLevel: intensity,
            createdByPlannerRelationshipId: relationship.id.uuidString,
            plannerDisplayName: plannerName
        )
        // Overwrite the auto-generated ID so it matches the cloud workoutId
        workout.id = uuid
        return workout
    }

    private func updateLocalWorkout(_ workout: PlannedWorkout, from dict: [String: Any], relationship: PlannerRelationship) {
        workout.date = dict["date"] as? Date ?? workout.date
        if let raw = dict["workoutTypeRaw"] as? String, let t = WorkoutType(rawValue: raw) { workout.workoutType = t }
        workout.title = dict["title"] as? String ?? workout.title
        workout.plannedDistanceMiles = dict["plannedDistanceMiles"] as? Double ?? workout.plannedDistanceMiles
        workout.plannedDurationSeconds = dict["plannedDurationSeconds"] as? Int ?? workout.plannedDurationSeconds
        if let raw = dict["crossTrainingActivityTypeRaw"] as? String { workout.crossTrainingActivityTypeRaw = raw }
        if let raw = dict["runCategoryRaw"] as? String { workout.runCategoryRaw = raw }
        if let json = dict["runSegmentsJSON"] as? String { workout.runSegments = decodeSegments(json) }
        workout.notes = dict["notes"] as? String ?? workout.notes
        if let raw = dict["intensityLevelRaw"] as? String, let i = IntensityLevel(rawValue: raw) { workout.intensityLevel = i }
        workout.plannerDisplayName = dict["plannerDisplayName"] as? String ?? relationship.plannerDisplayName
    }

    private func decodeSegments(_ json: String) -> [PlannedRunSegment] {
        guard let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([PlannedRunSegment].self, from: data)) ?? []
    }
}
