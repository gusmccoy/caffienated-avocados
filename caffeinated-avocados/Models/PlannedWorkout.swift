// Models/PlannedWorkout.swift
// Represents a single planned workout entry in the weekly training plan.

import Foundation
import SwiftData

// MARK: - Run Planning Enums

enum RunCategory: String, Codable, CaseIterable {
    case none        = "None"
    case baseMileage = "Base Mileage"
    case recovery    = "Recovery"
    case workout     = "Workout"
    case longRun     = "Long Run"
}

enum RunSegmentType: String, Codable, CaseIterable {
    case warmup   = "Warm Up"
    case easy     = "Easy"
    case tempo    = "Tempo"
    case repeats  = "Repeats"
    case fartlek  = "Fartlek"
    case ladder   = "Ladder"
    case cooldown = "Cool Down"

    var systemImage: String {
        switch self {
        case .warmup:   return "thermometer.sun"
        case .easy:     return "figure.walk"
        case .tempo:    return "speedometer"
        case .repeats:  return "repeat"
        case .fartlek:  return "shuffle"
        case .ladder:   return "stairs"
        case .cooldown: return "snowflake"
        }
    }

    var hasIntervals: Bool { self == .repeats || self == .fartlek }
    var isLadder: Bool { self == .ladder }
}

enum PaceReference: String, Codable, CaseIterable {
    case exact        = "Exact"
    case milePace     = "Mile Pace"
    case fiveKPace    = "5K Pace"
    case tenKPace     = "10K Pace"
    case halfPace     = "Half Marathon Pace"
    case marathonPace = "Marathon Pace"
}

// MARK: - Planned Run Segment

struct PlannedRunSegment: Codable, Identifiable {
    var id: UUID = UUID()
    var segmentType: RunSegmentType = .easy

    // Pace
    var paceReference: PaceReference = .exact
    var paceMinutes: Int = 0
    var paceSeconds: Int = 0

    // Volume — distance or duration (one or both may be set)
    var distanceMiles: Double = 0
    var durationMinutes: Int = 0

    // Intervals (repeats / fartlek)
    var intervalCount: Int = 4
    var recoveryDurationSeconds: Int = 90

    // Ladder: ordered list of per-step distances in miles
    var ladderDistances: [Double] = []

    var notes: String = ""

    // MARK: - Display

    var paceLabel: String {
        if paceReference == .exact {
            guard paceMinutes > 0 || paceSeconds > 0 else { return "" }
            return String(format: "%d:%02d /mi", paceMinutes, paceSeconds)
        }
        return paceReference.rawValue
    }

    /// Short summary shown in the plan row (e.g. "4× 800m @ 5K Pace")
    var summaryLabel: String {
        var parts: [String] = []

        if segmentType.isLadder {
            let steps = ladderDistances.map { Self.formatDistance($0) }.joined(separator: "–")
            if !steps.isEmpty { parts.append(steps) }
        } else if segmentType.hasIntervals {
            let distStr = distanceMiles > 0 ? Self.formatDistance(distanceMiles) : ""
            parts.append("\(intervalCount)×\(distStr.isEmpty ? "" : " \(distStr)")")
        } else {
            if distanceMiles > 0 { parts.append(Self.formatDistance(distanceMiles)) }
            else if durationMinutes > 0 { parts.append("\(durationMinutes) min") }
        }

        let pace = paceLabel
        if !pace.isEmpty { parts.append("@ \(pace)") }

        return parts.joined(separator: " ")
    }

    static func formatDistance(_ miles: Double) -> String {
        let meters = miles * 1609.34
        if meters < 1400 {
            return String(format: "%.0fm", meters.rounded(.toNearestOrAwayFromZero))
        }
        return String(format: "%.2g mi", miles)
    }
}

// MARK: - PlannedWorkout Model

@Model
final class PlannedWorkout {
    var id: UUID
    /// Stored as startOfDay so grouping by day is a simple equality check.
    var date: Date
    var workoutType: WorkoutType
    var title: String
    /// Always stored in miles (0 for strength workouts or when not set).
    var plannedDistanceMiles: Double
    /// Optional planned duration in seconds (0 = not set).
    var plannedDurationSeconds: Int = 0
    /// Activity type for cross-training workouts; ignored for other types.
    var crossTrainingActivityType: CrossTrainingActivityType = CrossTrainingActivityType.other
    /// Run category (Base Mileage / Recovery / Workout / Long Run); ignored for non-running types.
    var runCategory: RunCategory = RunCategory.none
    /// Structured run segments (warm-up, tempo, repeats, etc.); ignored for non-running types.
    var runSegments: [PlannedRunSegment] = []
    var notes: String
    var intensityLevel: IntensityLevel
    /// EKEvent.eventIdentifier — nil if calendar access was not granted or event not created.
    var calendarEventIdentifier: String?
    /// True when an imported activity matched this planned workout within the configured threshold.
    var isCompleted: Bool = false
    /// The stravaActivityId of the session that completed this planned workout, if applicable.
    var completedByStravaActivityId: String?
    var createdAt: Date

    init(
        date: Date,
        workoutType: WorkoutType,
        title: String = "",
        plannedDistanceMiles: Double = 0,
        plannedDurationSeconds: Int = 0,
        crossTrainingActivityType: CrossTrainingActivityType = .other,
        runCategory: RunCategory = .none,
        runSegments: [PlannedRunSegment] = [],
        notes: String = "",
        intensityLevel: IntensityLevel = .moderate,
        calendarEventIdentifier: String? = nil,
        isCompleted: Bool = false,
        completedByStravaActivityId: String? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.workoutType = workoutType
        self.title = title
        self.plannedDistanceMiles = plannedDistanceMiles
        self.plannedDurationSeconds = plannedDurationSeconds
        self.crossTrainingActivityType = crossTrainingActivityType
        self.runCategory = runCategory
        self.runSegments = runSegments
        self.notes = notes
        self.intensityLevel = intensityLevel
        self.calendarEventIdentifier = calendarEventIdentifier
        self.isCompleted = isCompleted
        self.completedByStravaActivityId = completedByStravaActivityId
        self.createdAt = .now
    }
}
