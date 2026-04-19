// ViewModels/PlannerViewModel.swift
// Manages coach/athlete planner relationships and the athlete-switching context for planners.

import Foundation
import Observation
import SwiftData
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Errors

enum PlannerError: LocalizedError {
    case emptyCode
    case alreadyHasPlanner

    var errorDescription: String? {
        switch self {
        case .emptyCode:         return "Please enter an invite code."
        case .alreadyHasPlanner: return "You already have an active planner. Revoke the existing one first."
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

    // MARK: - CloudKit publish state (athlete side)

    /// True while publishing the invite to CloudKit's public database.
    var isPublishingInvite: Bool = false
    /// Set if the CloudKit publish fails — shown in InviteCodeSheet.
    var publishError: String? = nil

    // MARK: - CloudKit accept state (coach side)

    /// True while the coach's invite acceptance is in flight.
    var isAcceptingInvite: Bool = false

    // MARK: - Planner Context
    //
    // When a planner taps into an athlete's row, `activeAthleteRelationship` is set.
    // PlanView reads this to show the correct header and restrict add/edit access.

    var activeAthleteRelationship: PlannerRelationship? = nil

    // MARK: - Invite Generation (athlete side)

    /// Generates a new 8-char uppercase invite code, inserts a pendingOutgoing record locally,
    /// and fires a background task to publish it to CloudKit's public database so coaches on
    /// other iCloud accounts can look it up.
    @discardableResult
    func generateInvite(athleteDisplayName: String, modelContext: ModelContext) -> String {
        let code = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)).uppercased()
        generatedInviteCode = code

        let displayName = athleteDisplayName.isEmpty ? "Athlete" : athleteDisplayName
        let rel = PlannerRelationship(
            inviteCode: code,
            status: .pendingOutgoing,
            currentUserIsAthlete: true,
            athleteDisplayName: displayName,
            plannerDisplayName: ""
        )
        modelContext.insert(rel)

        Task { await publishToCloudKit(code: code, athleteDisplayName: displayName) }
        return code
    }

    @MainActor
    func publishToCloudKit(code: String, athleteDisplayName: String) async {
        isPublishingInvite = true
        publishError = nil
        do {
            try await InviteService.shared.publish(code: code, athleteDisplayName: athleteDisplayName)
        } catch {
            publishError = "Couldn't publish invite: \(error.localizedDescription)"
        }
        isPublishingInvite = false
    }

    /// Cancels a pending outgoing invite, removes its local record, and deletes it from CloudKit.
    func cancelInvite(_ relationship: PlannerRelationship, modelContext: ModelContext) {
        let code = relationship.inviteCode
        modelContext.delete(relationship)
        if generatedInviteCode == code { generatedInviteCode = "" }
        Task { await InviteService.shared.deletePending(code: code) }
    }

    // MARK: - Invite Acceptance (coach side)

    /// Called when a coach enters an invite code.
    /// Looks up the code in CloudKit's public database (works across iCloud accounts),
    /// marks it accepted, then creates the local planner-side record.
    @MainActor
    func acceptInvite(
        code: String,
        plannerDisplayName: String,
        modelContext: ModelContext
    ) async {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else {
            acceptError = PlannerError.emptyCode.errorDescription
            return
        }

        isAcceptingInvite = true
        acceptError = nil

        do {
            let plannerName = plannerDisplayName.isEmpty ? "Coach" : plannerDisplayName
            let athleteDisplayName = try await InviteService.shared.accept(
                code: trimmed,
                plannerDisplayName: plannerName
            )

            let plannerRecord = PlannerRelationship(
                inviteCode: trimmed,
                status: .accepted,
                currentUserIsAthlete: false,
                athleteDisplayName: athleteDisplayName,
                plannerDisplayName: plannerName
            )
            modelContext.insert(plannerRecord)

            acceptCodeInput = ""
            acceptError = nil
            isShowingAcceptSheet = false
        } catch {
            acceptError = error.localizedDescription
        }

        isAcceptingInvite = false
    }

    // MARK: - Acceptance Polling (athlete side)

    /// Checks whether a pending invite has been accepted by a coach.
    /// If so, activates the local record and cleans up the CloudKit invite.
    /// Safe to call frequently — returns immediately if the invite is already accepted.
    @MainActor
    func checkPendingInviteAcceptance(invite: PlannerRelationship, modelContext: ModelContext) async {
        guard invite.status == .pendingOutgoing else { return }
        guard let plannerName = await InviteService.shared.checkAcceptance(code: invite.inviteCode),
              !plannerName.isEmpty else { return }

        invite.status = .accepted
        invite.plannerDisplayName = plannerName

        // Clean up the public CK record now that both sides are linked
        await InviteService.shared.deletePending(code: invite.inviteCode)
        generatedInviteCode = ""
    }

    // MARK: - Revocation (either side)

    /// Revokes the relationship. Removes both sides' records from the local store
    /// and cleans up any corresponding CloudKit public invite.
    func revoke(_ relationship: PlannerRelationship, modelContext: ModelContext) {
        let code = relationship.inviteCode
        let descriptor = FetchDescriptor<PlannerRelationship>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        for rel in all where rel.inviteCode == code {
            modelContext.delete(rel)
        }
        if activeAthleteRelationship?.inviteCode == code {
            activeAthleteRelationship = nil
        }
        // Best-effort CK cleanup (no-op if the record was already deleted)
        Task { await InviteService.shared.deletePending(code: code) }
    }

    // MARK: - Planner: Add Workout for Athlete

    /// Creates a coach-attributed PlannedWorkout on behalf of the athlete,
    /// then publishes it to CloudKit's public database so the athlete's device can sync it.
    func addWorkout(
        for relationship: PlannerRelationship,
        date: Date,
        workoutType: WorkoutType,
        title: String,
        plannedDistanceMiles: Double = 0,
        plannedDurationSeconds: Int = 0,
        crossTrainingActivityType: CrossTrainingActivityType = .other,
        runCategory: RunCategory = .none,
        runSegments: [PlannedRunSegment] = [],
        notes: String = "",
        intensityLevel: IntensityLevel = .moderate,
        modelContext: ModelContext
    ) {
        let workout = PlannedWorkout(
            date: date,
            workoutType: workoutType,
            title: title,
            plannedDistanceMiles: plannedDistanceMiles,
            plannedDurationSeconds: plannedDurationSeconds,
            crossTrainingActivityType: crossTrainingActivityType,
            runCategory: runCategory,
            runSegments: runSegments,
            notes: notes,
            intensityLevel: intensityLevel,
            createdByPlannerRelationshipId: relationship.id.uuidString,
            plannerDisplayName: relationship.plannerDisplayName
        )
        workout.coachAssignmentId = "coachassign-\(workout.id.uuidString)"
        modelContext.insert(workout)

        let payload = CoachAssignmentPayload(
            id: workout.id.uuidString,
            date: date,
            workoutTypeRaw: workoutType.rawValue,
            title: title,
            plannedDistanceMiles: plannedDistanceMiles,
            plannedDurationSeconds: plannedDurationSeconds,
            strengthTypeRaw: StrengthType.unspecified.rawValue,
            crossTrainingActivityTypeRaw: crossTrainingActivityType.rawValue,
            runCategoryRaw: runCategory.rawValue,
            runSegmentsData: workout.runSegmentsData,
            notes: notes,
            postRunStrides: false,
            intensityLevelRaw: intensityLevel.rawValue,
            plannerDisplayName: relationship.plannerDisplayName
        )
        Task { try? await CoachAssignmentService.shared.publish(payload: payload, inviteCode: relationship.inviteCode) }
    }

    // MARK: - Athlete: Sync coach workouts

    /// Pulls coach-assigned workouts from CloudKit into local SwiftData.
    /// Safe to call on every Plan tab appear — deduplicates by coachAssignmentId.
    @MainActor
    func syncCoachWorkouts(
        forRelationship invite: PlannerRelationship,
        modelContext: ModelContext
    ) async {
        let allPlanned = (try? modelContext.fetch(FetchDescriptor<PlannedWorkout>())) ?? []
        guard let records = try? await CoachAssignmentService.shared.fetchAll(inviteCode: invite.inviteCode) else { return }

        let existingIds = Set(allPlanned.compactMap(\.coachAssignmentId))
        let dismissed   = Set(UserDefaults.standard.stringArray(forKey: "dismissedCoachAssignments") ?? [])

        for item in records {
            let ckId = "coachassign-\(item.workoutId)"

            if item.isDeleted {
                if let local = allPlanned.first(where: { $0.coachAssignmentId == ckId }) {
                    modelContext.delete(local)
                }
            } else if !dismissed.contains(ckId), !existingIds.contains(ckId), let p = item.payload {
                let w = PlannedWorkout(
                    date: p.date,
                    workoutType: WorkoutType(rawValue: p.workoutTypeRaw) ?? .running,
                    title: p.title,
                    plannedDistanceMiles: p.plannedDistanceMiles,
                    plannedDurationSeconds: p.plannedDurationSeconds,
                    strengthType: StrengthType(rawValue: p.strengthTypeRaw) ?? .unspecified,
                    crossTrainingActivityType: CrossTrainingActivityType(rawValue: p.crossTrainingActivityTypeRaw) ?? .other,
                    runCategory: RunCategory(rawValue: p.runCategoryRaw) ?? .none,
                    notes: p.notes,
                    postRunStrides: p.postRunStrides,
                    intensityLevel: IntensityLevel(rawValue: p.intensityLevelRaw) ?? .moderate,
                    plannerDisplayName: p.plannerDisplayName
                )
                w.runSegmentsData   = p.runSegmentsData
                w.coachAssignmentId = ckId
                // createdByPlannerRelationshipId stays nil so the athlete's plan filter shows it
                modelContext.insert(w)
            }
        }
    }

    // MARK: - Helpers

    func copyToClipboard(_ string: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = string
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
        isCopied = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            isCopied = false
        }
    }
}
