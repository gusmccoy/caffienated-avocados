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
    /// Always stored in miles (0 for strength workouts).
    var plannedDistanceMiles: Double
    var notes: String
    var intensityLevel: IntensityLevel
    /// EKEvent.eventIdentifier — nil if calendar access was not granted or event not created.
    var calendarEventIdentifier: String?
    var createdAt: Date

    init(
        date: Date,
        workoutType: WorkoutType,
        title: String = "",
        plannedDistanceMiles: Double = 0,
        notes: String = "",
        intensityLevel: IntensityLevel = .moderate,
        calendarEventIdentifier: String? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.workoutType = workoutType
        self.title = title
        self.plannedDistanceMiles = plannedDistanceMiles
        self.notes = notes
        self.intensityLevel = intensityLevel
        self.calendarEventIdentifier = calendarEventIdentifier
        self.createdAt = .now
    }
}
