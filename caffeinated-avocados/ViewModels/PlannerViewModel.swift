// ViewModels/PlannerViewModel.swift
// Manages coach/athlete planner relationships and the athlete-switching context for planners.

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

    var errorDescription: String? {
        switch self {
        case .emptyCode:         return "Please enter an invite code."
        case .codeNotFound:      return "No pending invite found for that code. Make sure the athlete sent an invite and the code is correct."
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

    // MARK: - Planner Context
    //
    // When a planner taps into an athlete's row, `activeAthleteRelationship` is set.
    // PlanView reads this to show the correct header and restrict add/edit access.

    var activeAthleteRelationship: PlannerRelationship? = nil

    // MARK: - Invite Generation (athlete side)

    /// Generates a new 8-char uppercase invite code, inserts a pendingOutgoing record,
    /// and returns the code so the UI can display/copy it.
    @discardableResult
    func generateInvite(athleteDisplayName: String, modelContext: ModelContext) -> String {
        let code = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)).uppercased()
        generatedInviteCode = code

        let rel = PlannerRelationship(
            inviteCode: code,
            status: .pendingOutgoing,
            currentUserIsAthlete: true,
            athleteDisplayName: athleteDisplayName.isEmpty ? "Athlete" : athleteDisplayName,
            plannerDisplayName: ""
        )
        modelContext.insert(rel)
        return code
    }

    /// Cancels a pending outgoing invite and removes its record.
    func cancelInvite(_ relationship: PlannerRelationship, modelContext: ModelContext) {
        modelContext.delete(relationship)
        if generatedInviteCode == relationship.inviteCode {
            generatedInviteCode = ""
        }
    }

    // MARK: - Invite Acceptance (planner side)

    /// Called when a planner enters an invite code.
    /// Finds the matching pendingOutgoing record (athlete side) in the local store,
    /// activates both sides, and fills in the planner's display name.
    func acceptInvite(
        code: String,
        plannerDisplayName: String,
        allRelationships: [PlannerRelationship],
        modelContext: ModelContext
    ) throws {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { throw PlannerError.emptyCode }

        // Look for the athlete's pending invite in the local store
        guard let pending = allRelationships.first(where: {
            $0.inviteCode == trimmed &&
            $0.currentUserIsAthlete == true &&
            $0.status == .pendingOutgoing
        }) else {
            throw PlannerError.codeNotFound
        }

        let plannerName = plannerDisplayName.isEmpty ? "Coach" : plannerDisplayName

        // Activate the athlete-side record
        pending.status = .accepted
        pending.plannerDisplayName = plannerName

        // Insert a planner-side record (currentUserIsAthlete = false)
        let plannerRecord = PlannerRelationship(
            inviteCode: trimmed,
            status: .accepted,
            currentUserIsAthlete: false,
            athleteDisplayName: pending.athleteDisplayName,
            plannerDisplayName: plannerName
        )
        modelContext.insert(plannerRecord)

        acceptCodeInput = ""
        acceptError = nil
        isShowingAcceptSheet = false
    }

    // MARK: - Revocation (either side)

    /// Revokes the relationship. Removes both sides' records from the local store.
    func revoke(_ relationship: PlannerRelationship, modelContext: ModelContext) {
        // Remove the matching opposite-side record too (same inviteCode, opposite isAthlete flag)
        let descriptor = FetchDescriptor<PlannerRelationship>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        for rel in all where rel.inviteCode == relationship.inviteCode {
            modelContext.delete(rel)
        }
        if activeAthleteRelationship?.inviteCode == relationship.inviteCode {
            activeAthleteRelationship = nil
        }
    }

    // MARK: - Planner: Add Workout for Athlete

    /// Creates a coach-attributed PlannedWorkout on behalf of the athlete.
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
        modelContext.insert(workout)
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
}
