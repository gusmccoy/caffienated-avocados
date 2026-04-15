// ViewModels/ProfileViewModel.swift
// State and logic for the Profile tab.

import Foundation
import SwiftData
import Observation

@Observable
final class ProfileViewModel {

    // MARK: - Persistent Profile (UserDefaults)

    var firstName: String {
        get { UserDefaults.standard.string(forKey: "profileFirstName") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "profileFirstName") }
    }

    /// The date the user first opened the app. Written once on first access, never changes.
    var firstLaunchDate: Date {
        if let stored = UserDefaults.standard.object(forKey: "profileFirstLaunchDate") as? Date {
            return stored
        }
        let now = Date.now
        UserDefaults.standard.set(now, forKey: "profileFirstLaunchDate")
        return now
    }

    // MARK: - PR View Mode

    enum PRMode: String, CaseIterable {
        case allTime    = "All-Time"
        case ytd        = "This Year"
        case milestones = "Milestones"
    }
    var prMode: PRMode = .allTime

    // MARK: - YTD PR Derivation

    var isDerivedPRsLoading: Bool = false

    // MARK: - Sheet State

    var isShowingEditProfile = false
    var isShowingAddPR = false
    var isShowingAddMilestone = false
    var editingMilestone: PRMilestone? = nil

    // MARK: - Edit Profile Form

    var editFirstName: String = ""

    func openEditProfile() {
        editFirstName = firstName
        isShowingEditProfile = true
    }

    func saveProfile() {
        firstName = editFirstName
        isShowingEditProfile = false
    }

    // MARK: - Add PR Form

    var prFormDistance: PRDistance = .fiveK
    var prFormHours: Int = 0
    var prFormMinutes: Int = 25
    var prFormSeconds: Int = 0
    var prFormDate: Date = .now
    var prFormNotes: String = ""
    var prFormMilestoneId: UUID? = nil

    var prFormTimeSeconds: Int {
        prFormHours * 3600 + prFormMinutes * 60 + prFormSeconds
    }

    var isPRFormValid: Bool {
        prFormTimeSeconds > 0
    }

    func openAddPR(milestoneId: UUID? = nil) {
        prFormDistance = .fiveK
        prFormHours = 0
        prFormMinutes = 25
        prFormSeconds = 0
        prFormDate = .now
        prFormNotes = ""
        prFormMilestoneId = milestoneId
        isShowingAddPR = true
    }

    func savePR(modelContext: ModelContext) {
        let pr = PersonalRecord(
            distance: prFormDistance,
            timeSeconds: prFormTimeSeconds,
            dateAchieved: prFormDate,
            notes: prFormNotes,
            milestoneId: prFormMilestoneId
        )
        modelContext.insert(pr)
        isShowingAddPR = false
    }

    func deletePR(_ pr: PersonalRecord, modelContext: ModelContext) {
        modelContext.delete(pr)
    }

    // MARK: - Milestone Form

    var milestoneFormName: String = ""
    var milestoneFormStartDate: Date = .now
    var milestoneFormNotes: String = ""

    func openAddMilestone() {
        milestoneFormName = ""
        milestoneFormStartDate = .now
        milestoneFormNotes = ""
        editingMilestone = nil
        isShowingAddMilestone = true
    }

    func openEditMilestone(_ milestone: PRMilestone) {
        milestoneFormName = milestone.name
        milestoneFormStartDate = milestone.startDate
        milestoneFormNotes = milestone.notes
        editingMilestone = milestone
        isShowingAddMilestone = true
    }

    func saveMilestone(modelContext: ModelContext, existingCount: Int) {
        if let existing = editingMilestone {
            existing.name = milestoneFormName
            existing.startDate = milestoneFormStartDate
            existing.notes = milestoneFormNotes
        } else {
            let milestone = PRMilestone(
                name: milestoneFormName,
                startDate: milestoneFormStartDate,
                orderIndex: existingCount,
                notes: milestoneFormNotes
            )
            modelContext.insert(milestone)
        }
        isShowingAddMilestone = false
        editingMilestone = nil
    }

    func deleteMilestone(_ milestone: PRMilestone, allPRs: [PersonalRecord], modelContext: ModelContext) {
        for pr in allPRs where pr.milestoneId == milestone.id {
            modelContext.delete(pr)
        }
        modelContext.delete(milestone)
    }

    // MARK: - YTD PR Derivation from Strava Splits

    /// Scans all running sessions with splits data and creates/refreshes `PersonalRecord`
    /// entries tagged as Strava-derived for the current calendar year.
    @MainActor
    func deriveYTDPRs(from sessions: [WorkoutSession], modelContext: ModelContext) {
        isDerivedPRsLoading = true
        defer { isDerivedPRsLoading = false }

        let calendar = Calendar.current
        let year = calendar.component(.year, from: .now)
        guard let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else { return }

        // Runs this year that have splits data
        let ytdRuns = sessions.filter { session in
            guard session.type == .running, session.date >= yearStart else { return false }
            return !(session.runningWorkout?.splits.isEmpty ?? true)
        }

        // Find best effort time for each PR distance across all qualifying runs
        var bestEfforts: [PRDistance: (timeSeconds: Int, date: Date, stravaId: String)] = [:]

        for session in ytdRuns {
            guard let run = session.runningWorkout else { continue }
            for prDist in PRDistance.allCases {
                guard run.distanceMiles >= prDist.distanceMiles * 0.95 else { continue }
                let estimated = estimateTimeForDistance(prDist.distanceMiles, from: run.splits)
                guard estimated > 0 else { continue }
                if let existing = bestEfforts[prDist] {
                    if estimated < existing.timeSeconds {
                        bestEfforts[prDist] = (estimated, session.date, session.stravaActivityId ?? "")
                    }
                } else {
                    bestEfforts[prDist] = (estimated, session.date, session.stravaActivityId ?? "")
                }
            }
        }

        // Delete old derived PRs for this year
        for pr in (try? modelContext.fetch(FetchDescriptor<PersonalRecord>())) ?? [] {
            if pr.isDerivedFromStrava && pr.ytdYear == year {
                modelContext.delete(pr)
            }
        }

        // Insert new derived PRs
        for (distance, effort) in bestEfforts {
            let pr = PersonalRecord(
                distance: distance,
                timeSeconds: effort.timeSeconds,
                dateAchieved: effort.date,
                notes: "Derived from Strava splits",
                milestoneId: nil,
                isDerivedFromStrava: true,
                sourceStravaActivityId: effort.stravaId.isEmpty ? nil : effort.stravaId,
                ytdYear: year
            )
            modelContext.insert(pr)
        }
    }

    /// Estimates the time to cover `targetMiles` using cumulative mile-split data.
    private func estimateTimeForDistance(_ targetMiles: Double, from splits: [RunningSplit]) -> Int {
        let sortedSplits = splits.sorted { $0.splitNumber < $1.splitNumber }
        var cumulativeMiles = 0.0
        var cumulativeSeconds = 0

        for split in sortedSplits {
            let splitMiles = split.distanceUnit == .miles ? 1.0 : (1.0 / 1.60934)
            let splitTime  = split.paceSecondsPerUnit   // seconds to cover 1 unit at this pace

            let needed = targetMiles - cumulativeMiles
            if needed <= splitMiles {
                let fraction = needed / splitMiles
                cumulativeSeconds += Int((Double(splitTime) * fraction).rounded())
                return cumulativeSeconds
            }

            cumulativeMiles += splitMiles
            cumulativeSeconds += splitTime
        }

        return 0  // Not enough splits to reach targetMiles
    }

    // MARK: - Helpers

    /// Best PR for a given distance within a specific milestone (or all-time when `milestoneId` is nil).
    func bestPR(for distance: PRDistance, from prs: [PersonalRecord], milestoneId: UUID? = nil) -> PersonalRecord? {
        prs
            .filter { $0.distance == distance && $0.milestoneId == milestoneId }
            .min(by: { $0.timeSeconds < $1.timeSeconds })
    }

    /// All PRs for a given milestone (or all-time), sorted by distance order.
    func prs(for milestoneId: UUID?, from allPRs: [PersonalRecord]) -> [PersonalRecord] {
        let filtered = allPRs.filter { $0.milestoneId == milestoneId }
        return PRDistance.allCases.compactMap { dist in
            filtered
                .filter { $0.distance == dist }
                .min(by: { $0.timeSeconds < $1.timeSeconds })
        }
    }

    /// Membership label, e.g. "An avocado since 4/11/26".
    var avocadoMembershipLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yy"
        return "An avocado since \(formatter.string(from: firstLaunchDate))"
    }
}
