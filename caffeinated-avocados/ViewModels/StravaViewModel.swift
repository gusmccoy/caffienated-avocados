// ViewModels/StravaViewModel.swift
// Drives the Strava connection flow and activity import.

import Foundation
import SwiftData
import Observation
import AuthenticationServices

// MARK: - Override tracking types

/// Captures all data from a manually-entered session so it can be restored if the user undoes a Strava override.
struct OverriddenSessionSnapshot {
    let date: Date
    let type: WorkoutType
    let title: String
    let notes: String
    let durationSeconds: Int
    let intensityLevel: IntensityLevel
    let caloriesBurned: Int?
    let heartRateAvg: Int?
    let heartRateMax: Int?
    // Running-specific
    let distanceMiles: Double?
    let runType: RunType?
    let averagePaceSecondsPerMile: Int?
    let elevationGainFeet: Double?
    let cadenceAvg: Int?
    let route: String?
    // Cross-training-specific
    let crossTrainingType: CrossTrainingActivityType?
    let ctDistanceMiles: Double?
    let avgPowerWatts: Int?
    let ctElevationGainFeet: Double?

    init(from session: WorkoutSession) {
        date = session.date
        type = session.type
        title = session.title
        notes = session.notes
        durationSeconds = session.durationSeconds
        intensityLevel = session.intensityLevel
        caloriesBurned = session.caloriesBurned
        heartRateAvg = session.heartRateAvg
        heartRateMax = session.heartRateMax

        if let run = session.runningWorkout {
            distanceMiles = run.distanceMiles
            runType = run.runType
            averagePaceSecondsPerMile = run.averagePaceSecondsPerMile
            elevationGainFeet = run.elevationGainFeet
            cadenceAvg = run.cadenceAvg
            route = run.route
        } else {
            distanceMiles = nil
            runType = nil
            averagePaceSecondsPerMile = nil
            elevationGainFeet = nil
            cadenceAvg = nil
            route = nil
        }

        if let ct = session.crossTrainingWorkout {
            crossTrainingType = ct.activityType
            ctDistanceMiles = ct.distanceMiles
            avgPowerWatts = ct.avgPowerWatts
            ctElevationGainFeet = ct.elevationGainFeet
        } else {
            crossTrainingType = nil
            ctDistanceMiles = nil
            avgPowerWatts = nil
            ctElevationGainFeet = nil
        }
    }
}

/// Records that a manual session was replaced by a Strava import, enabling the user to undo.
struct OverrideResult: Identifiable {
    let id = UUID()
    let snapshot: OverriddenSessionSnapshot
    let stravaActivityTitle: String
    /// The Strava activity ID string stored on the WorkoutSession — used to find and delete the Strava session on undo.
    let stravaActivityId: String
}

// MARK: - ViewModel

@Observable
final class StravaViewModel {

    // MARK: - State
    var isConnected: Bool = false
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var recentActivities: [StravaActivity] = []
    var connectedAthlete: StravaAthlete? = nil
    var lastSyncDate: Date? = nil
    var importProgress: Double = 0

    /// Manual sessions replaced during the last sync. Shown to the user with an undo option.
    var overrideResults: [OverrideResult] = []

    private let stravaService = StravaService()

    // MARK: - Connection

    func connect(presentationAnchor: ASPresentationAnchor) async {
        isLoading = true
        errorMessage = nil
        do {
            let athlete = try await stravaService.authenticate(anchor: presentationAnchor)
            connectedAthlete = athlete
            isConnected = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func disconnect() {
        stravaService.clearTokens()
        isConnected = false
        connectedAthlete = nil
        recentActivities = []
        lastSyncDate = nil
    }

    // MARK: - Sync

    func syncActivities(modelContext: ModelContext) async {
        guard isConnected else { return }
        isLoading = true
        errorMessage = nil
        importProgress = 0
        overrideResults = []

        do {
            let activities = try await stravaService.fetchRecentActivities()
            recentActivities = activities
            importProgress = 0.5

            for (index, activity) in activities.enumerated() {
                await importActivity(activity, modelContext: modelContext)
                importProgress = 0.5 + (Double(index + 1) / Double(activities.count)) * 0.5
            }

            lastSyncDate = .now
        } catch {
            errorMessage = "Sync failed: \(error.localizedDescription)"
        }

        isLoading = false
        importProgress = 0
    }

    // MARK: - Undo override

    /// Deletes the Strava-imported session and restores the original manual entry.
    @MainActor
    func undoOverride(_ result: OverrideResult, modelContext: ModelContext) {
        // Find and delete the Strava session that replaced the manual one
        let stravaId = result.stravaActivityId
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.stravaActivityId == stravaId }
        )
        if let stravaSession = try? modelContext.fetch(descriptor).first {
            modelContext.delete(stravaSession)
        }

        // Recreate the manual session from the snapshot
        let snap = result.snapshot
        let session = WorkoutSession(
            date: snap.date,
            type: snap.type,
            title: snap.title,
            notes: snap.notes,
            durationSeconds: snap.durationSeconds,
            intensityLevel: snap.intensityLevel,
            caloriesBurned: snap.caloriesBurned,
            heartRateAvg: snap.heartRateAvg,
            heartRateMax: snap.heartRateMax
        )

        if snap.type == .running, let dist = snap.distanceMiles {
            let run = RunningWorkout(
                distanceMiles: dist,
                runType: snap.runType ?? .other,
                averagePaceSecondsPerMile: snap.averagePaceSecondsPerMile ?? 0,
                elevationGainFeet: snap.elevationGainFeet,
                cadenceAvg: snap.cadenceAvg,
                route: snap.route
            )
            run.session = session
            session.runningWorkout = run
            modelContext.insert(run)
        } else if snap.type == .crossTraining, let ctType = snap.crossTrainingType {
            let ct = CrossTrainingWorkout(
                activityType: ctType,
                distanceMiles: snap.ctDistanceMiles,
                avgPowerWatts: snap.avgPowerWatts,
                elevationGainFeet: snap.ctElevationGainFeet
            )
            ct.session = session
            session.crossTrainingWorkout = ct
            modelContext.insert(ct)
        }

        modelContext.insert(session)
        overrideResults.removeAll { $0.id == result.id }
    }

    // MARK: - Private import logic

    @MainActor
    private func importActivity(_ activity: StravaActivity, modelContext: ModelContext) async {
        // Check if this Strava activity is already saved
        let activityId = String(activity.id)
        let dupDescriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.stravaActivityId == activityId }
        )
        guard let existing = try? modelContext.fetch(dupDescriptor), existing.isEmpty else { return }

        // Map Strava sport type → our WorkoutType
        let workoutType = mapStravaType(activity.sportType)

        // Detect conflicting manual sessions on the same calendar day + same type.
        // Strava is the source of truth — manual entries are deleted and the user is notified.
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: activity.startDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let manualDescriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { session in
                session.date >= dayStart && session.date < dayEnd
            }
        )
        let allOnDay = (try? modelContext.fetch(manualDescriptor)) ?? []
        let conflicting = allOnDay.filter { $0.type == workoutType && $0.stravaActivityId == nil }

        // Capture snapshots before deletion so the user can undo
        var newOverrides: [(OverriddenSessionSnapshot, String)] = []
        for manual in conflicting {
            newOverrides.append((OverriddenSessionSnapshot(from: manual), activity.name))
            modelContext.delete(manual)
        }

        // Create and insert the Strava-sourced session
        let session = WorkoutSession(
            date: activity.startDate,
            type: workoutType,
            title: activity.name,
            durationSeconds: activity.movingTime,
            heartRateAvg: activity.averageHeartrate.map(Int.init),
            heartRateMax: activity.maxHeartrate.map(Int.init),
            stravaActivityId: activityId
        )

        if workoutType == .running {
            let run = RunningWorkout(
                distanceMiles: activity.distanceMiles,
                runType: .other,
                averagePaceSecondsPerMile: activity.distanceMiles > 0
                    ? Int(Double(activity.movingTime) / activity.distanceMiles)
                    : 0,
                elevationGainFeet: activity.totalElevationGain * 3.28084
            )
            run.session = session
            session.runningWorkout = run

            // Fetch per-mile splits and store them for later PR derivation.
            // Silently ignore errors — splits are optional enrichment data.
            if let detail = try? await stravaService.fetchActivityDetail(id: activity.id),
               let stravaSplits = detail.splitsStandard, !stravaSplits.isEmpty {
                run.splits = stravaSplits.map { split in
                    RunningSplit(
                        splitNumber: split.split,
                        distanceUnit: .miles,
                        paceSecondsPerUnit: split.paceSecondsPerMile,
                        heartRateAvg: split.averageHeartrate.map(Int.init)
                    )
                }
            }

            modelContext.insert(run)
        } else if workoutType == .crossTraining {
            let ct = CrossTrainingWorkout(
                activityType: mapStravaCrossType(activity.sportType),
                distanceMiles: activity.distance > 0 ? activity.distanceMiles : nil,
                avgPowerWatts: activity.averageWatts.map(Int.init),
                elevationGainFeet: activity.totalElevationGain * 3.28084
            )
            ct.session = session
            session.crossTrainingWorkout = ct
            modelContext.insert(ct)
        }

        modelContext.insert(session)

        // Match against planned workouts for this day and mark any close enough as completed
        let importedMiles: Double = {
            if workoutType == .running { return activity.distanceMiles }
            if workoutType == .crossTraining, activity.distance > 0 { return activity.distanceMiles }
            return 0
        }()
        matchPlannedWorkouts(
            on: activity.startDate,
            type: workoutType,
            importedMiles: importedMiles,
            importedDurationSeconds: activity.movingTime,
            stravaActivityId: activityId,
            modelContext: modelContext
        )

        // Record each override now that the Strava session's activityId is known
        for (snapshot, stravaTitle) in newOverrides {
            overrideResults.append(OverrideResult(
                snapshot: snapshot,
                stravaActivityTitle: stravaTitle,
                stravaActivityId: activityId
            ))
        }
    }

    private func matchPlannedWorkouts(
        on date: Date,
        type workoutType: WorkoutType,
        importedMiles: Double,
        importedDurationSeconds: Int,
        stravaActivityId: String,
        modelContext: ModelContext
    ) {
        let threshold = max(0.01, UserDefaults.standard.double(forKey: "planCompletionThreshold") == 0
            ? 0.05
            : UserDefaults.standard.double(forKey: "planCompletionThreshold") / 100.0)

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        let descriptor = FetchDescriptor<PlannedWorkout>(
            predicate: #Predicate { pw in
                pw.date >= dayStart && pw.date < dayEnd && pw.isCompleted == false
            }
        )
        let candidates = (try? modelContext.fetch(descriptor)) ?? []

        for pw in candidates where pw.workoutType == workoutType {
            var matched = false

            // Distance match
            if pw.plannedDistanceMiles > 0 && importedMiles > 0 {
                let delta = abs(importedMiles - pw.plannedDistanceMiles) / pw.plannedDistanceMiles
                if delta <= threshold { matched = true }
            }

            // Duration match
            if !matched && pw.plannedDurationSeconds > 0 && importedDurationSeconds > 0 {
                let delta = abs(Double(importedDurationSeconds) - Double(pw.plannedDurationSeconds))
                    / Double(pw.plannedDurationSeconds)
                if delta <= threshold { matched = true }
            }

            if matched {
                pw.isCompleted = true
                pw.completedByStravaActivityId = stravaActivityId
            }
        }
    }

    private func mapStravaType(_ sportType: String) -> WorkoutType {
        let runs: Set<String> = ["Run", "TrailRun", "VirtualRun", "Hike", "Walk"]
        let strength: Set<String> = ["WeightTraining", "Workout", "Crossfit", "RockClimbing"]
        if runs.contains(sportType) { return .running }
        if strength.contains(sportType) { return .strength }
        return .crossTraining
    }

    private func mapStravaCrossType(_ sportType: String) -> CrossTrainingActivityType {
        switch sportType {
        case "Ride", "VirtualRide", "EBikeRide": return .cycling
        case "Swim":                              return .swimming
        case "Rowing", "VirtualRow":              return .rowing
        case "Yoga":                              return .yoga
        case "Hike":                              return .hiking
        case "Elliptical":                        return .elliptical
        default:                                  return .other
        }
    }
}
