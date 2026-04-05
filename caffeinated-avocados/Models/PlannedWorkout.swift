// Models/PlannedWorkout.swift
// Represents a single planned workout entry in the weekly training plan.

import Foundation
import SwiftData

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
        self.notes = notes
        self.intensityLevel = intensityLevel
        self.calendarEventIdentifier = calendarEventIdentifier
        self.isCompleted = isCompleted
        self.completedByStravaActivityId = completedByStravaActivityId
        self.createdAt = .now
    }
}
