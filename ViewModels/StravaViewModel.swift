// ViewModels/StravaViewModel.swift
// Drives the Strava connection flow and activity import.

import Foundation
import SwiftData
import Observation
import AuthenticationServices

@Observable
final class StravaViewModel {

    // MARK: - State
    var isConnected: Bool = false
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var recentActivities: [StravaActivity] = []
    var connectedAthlete: StravaAthlete? = nil
    var lastSyncDate: Date? = nil
    var importProgress: Double = 0          // 0..1 for progress indicator

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

        do {
            let activities = try await stravaService.fetchRecentActivities()
            recentActivities = activities
            importProgress = 0.5

            // Import activities that don't already exist locally
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

    // MARK: - Private import logic

    @MainActor
    private func importActivity(_ activity: StravaActivity, modelContext: ModelContext) async {
        // Check if this Strava activity is already saved
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.stravaActivityId == String(activity.id) }
        )
        guard let existing = try? modelContext.fetch(descriptor), existing.isEmpty else { return }

        // Map Strava sport type → our WorkoutType
        let workoutType = mapStravaType(activity.sportType)

        let session = WorkoutSession(
            date: activity.startDate,
            type: workoutType,
            title: activity.name,
            durationSeconds: activity.movingTime,
            heartRateAvg: activity.averageHeartrate.map(Int.init),
            heartRateMax: activity.maxHeartrate.map(Int.init),
            stravaActivityId: String(activity.id)
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
