// Models/WorkoutSession.swift
// Base workout session model — parent of all specific workout types.
// Uses SwiftData for local persistence.

import Foundation
import SwiftData

/// The category of a workout.
enum WorkoutType: String, Codable, CaseIterable {
    case running      = "Running"
    case strength     = "Strength"
    case crossTraining = "Cross Training"

    var systemImage: String {
        switch self {
        case .running:       return "figure.run"
        case .strength:      return "dumbbell.fill"
        case .crossTraining: return "figure.cross.training"
        }
    }
}

/// Workout intensity / perceived effort (RPE 1-10 collapsed into zones).
enum IntensityLevel: String, Codable, CaseIterable {
    case easy     = "Easy"
    case moderate = "Moderate"
    case hard     = "Hard"
    case max      = "Max Effort"

    var color: String {
        switch self {
        case .easy:     return "green"
        case .moderate: return "yellow"
        case .hard:     return "orange"
        case .max:      return "red"
        }
    }
}

/// Base model shared by all workout types.
@Model
final class WorkoutSession {
    var id: UUID = UUID()
    var date: Date = Date()
    var type: WorkoutType = WorkoutType.running
    var title: String = ""
    var notes: String = ""
    var durationSeconds: Int = 0      // Total workout duration
    var intensityLevel: IntensityLevel = IntensityLevel.moderate
    var caloriesBurned: Int?
    var heartRateAvg: Int?
    var heartRateMax: Int?
    var stravaActivityId: String?     // nil if not synced from Strava
    /// True when this session was created as a stub by manually marking a planned workout complete.
    var isManualPlanCompletion: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Relationships (one-to-one — only one will be non-nil depending on `type`)
    @Relationship(deleteRule: .cascade) var runningWorkout: RunningWorkout?
    @Relationship(deleteRule: .cascade) var strengthWorkout: StrengthWorkout?
    @Relationship(deleteRule: .cascade) var crossTrainingWorkout: CrossTrainingWorkout?

    init(
        date: Date = .now,
        type: WorkoutType,
        title: String = "",
        notes: String = "",
        durationSeconds: Int = 0,
        intensityLevel: IntensityLevel = .moderate,
        caloriesBurned: Int? = nil,
        heartRateAvg: Int? = nil,
        heartRateMax: Int? = nil,
        stravaActivityId: String? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.type = type
        self.title = title
        self.notes = notes
        self.durationSeconds = durationSeconds
        self.intensityLevel = intensityLevel
        self.caloriesBurned = caloriesBurned
        self.heartRateAvg = heartRateAvg
        self.heartRateMax = heartRateMax
        self.stravaActivityId = stravaActivityId
        self.createdAt = .now
        self.updatedAt = .now
    }

    // MARK: - Computed

    /// Human-readable duration string, e.g. "1h 23m".
    var formattedDuration: String {
        let hours   = durationSeconds / 3600
        let minutes = (durationSeconds % 3600) / 60
        let seconds = durationSeconds % 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %02ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}
