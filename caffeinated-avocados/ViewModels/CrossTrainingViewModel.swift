// ViewModels/CrossTrainingViewModel.swift
// Manages state for logging cross-training workout sessions.

import Foundation
import SwiftData
import Observation

@Observable
final class CrossTrainingViewModel {

    // MARK: - Form State
    var date: Date = .now
    var title: String = ""
    var activityType: CrossTrainingActivityType = .cycling
    var hours: Int = 0
    var minutes: Int = 0
    var seconds: Int = 0
    var intensityLevel: IntensityLevel = .moderate
    var distanceMiles: String = ""
    var avgPowerWatts: String = ""
    var avgCadenceRPM: String = ""
    var strokesPerMinute: String = ""
    var poolLengthYards: String = ""
    var lapsCompleted: String = ""
    var elevationGainFeet: String = ""
    var heartRateAvg: String = ""
    var heartRateMax: String = ""
    var caloriesBurned: String = ""
    var notes: String = ""

    // MARK: - Computed

    var durationSeconds: Int {
        hours * 3600 + minutes * 60 + seconds
    }

    var isFormValid: Bool {
        durationSeconds > 0
    }

    /// Whether to show distance field for this activity.
    var showsDistance: Bool {
        switch activityType {
        case .cycling, .hiking, .rowing, .elliptical: return true
        default: return false
        }
    }

    /// Whether to show power field.
    var showsPower: Bool {
        activityType == .cycling || activityType == .rowing
    }

    /// Whether to show pool/lap fields.
    var showsPool: Bool {
        activityType == .swimming
    }

    // MARK: - Reset

    func reset() {
        date = .now
        title = ""
        activityType = .cycling
        hours = 0; minutes = 0; seconds = 0
        intensityLevel = .moderate
        distanceMiles = ""; avgPowerWatts = ""; avgCadenceRPM = ""
        strokesPerMinute = ""; poolLengthYards = ""; lapsCompleted = ""
        elevationGainFeet = ""; heartRateAvg = ""; heartRateMax = ""
        caloriesBurned = ""; notes = ""
    }

    // MARK: - Build model objects

    func buildWorkoutSession(modelContext: ModelContext) -> WorkoutSession {
        let session = WorkoutSession(
            date: date,
            type: .crossTraining,
            title: title.isEmpty ? activityType.rawValue : title,
            notes: notes,
            durationSeconds: durationSeconds,
            intensityLevel: intensityLevel,
            caloriesBurned: Int(caloriesBurned),
            heartRateAvg: Int(heartRateAvg),
            heartRateMax: Int(heartRateMax)
        )

        let ct = CrossTrainingWorkout(
            activityType: activityType,
            distanceMiles: Double(distanceMiles),
            avgPowerWatts: Int(avgPowerWatts),
            avgCadenceRPM: Int(avgCadenceRPM),
            strokesPerMinute: Int(strokesPerMinute),
            poolLengthYards: Int(poolLengthYards),
            lapsCompleted: Int(lapsCompleted),
            elevationGainFeet: Double(elevationGainFeet)
        )

        ct.session = session
        session.crossTrainingWorkout = ct

        modelContext.insert(session)
        modelContext.insert(ct)
        return session
    }
}
