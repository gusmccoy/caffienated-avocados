// Models/WorkoutTemplate.swift
// A reusable planned-workout blueprint — date-free snapshot of a workout's structure.

import Foundation
import SwiftData

@Model
final class WorkoutTemplate {
    var id: UUID = UUID()
    /// User-visible name for this template (e.g. "Tuesday Tempo", "Saturday Long Run").
    var templateName: String = ""
    var workoutType: WorkoutType = WorkoutType.running
    var title: String = ""
    var plannedDistanceMiles: Double = 0
    var plannedDurationSeconds: Int = 0
    var notes: String = ""
    var postRunStrides: Bool = false

    // String-backed enums for CloudKit/migration safety
    var strengthTypeRaw: String = StrengthType.unspecified.rawValue
    var crossTrainingActivityTypeRaw: String = CrossTrainingActivityType.other.rawValue
    var runCategoryRaw: String = RunCategory.none.rawValue
    var intensityLevelRaw: String = IntensityLevel.moderate.rawValue

    var strengthType: StrengthType {
        get { StrengthType(rawValue: strengthTypeRaw) ?? .unspecified }
        set { strengthTypeRaw = newValue.rawValue }
    }
    var crossTrainingActivityType: CrossTrainingActivityType {
        get { CrossTrainingActivityType(rawValue: crossTrainingActivityTypeRaw) ?? .other }
        set { crossTrainingActivityTypeRaw = newValue.rawValue }
    }
    var runCategory: RunCategory {
        get { RunCategory(rawValue: runCategoryRaw) ?? .none }
        set { runCategoryRaw = newValue.rawValue }
    }
    var intensityLevel: IntensityLevel {
        get { IntensityLevel(rawValue: intensityLevelRaw) ?? .moderate }
        set { intensityLevelRaw = newValue.rawValue }
    }

    /// JSON-encoded [PlannedRunSegment].
    var runSegmentsData: Data = Data()
    var runSegments: [PlannedRunSegment] {
        get {
            guard !runSegmentsData.isEmpty else { return [] }
            return (try? JSONDecoder().decode([PlannedRunSegment].self, from: runSegmentsData)) ?? []
        }
        set {
            runSegmentsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    /// JSON-encoded [RouteWaypoint].
    var routeWaypointsData: Data = Data()
    var routeWaypoints: [RouteWaypoint] {
        get {
            guard !routeWaypointsData.isEmpty else { return [] }
            return (try? JSONDecoder().decode([RouteWaypoint].self, from: routeWaypointsData)) ?? []
        }
        set { routeWaypointsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    /// JSON-encoded [RouteCoordinate].
    var routePolylineData: Data = Data()
    var routePolyline: [RouteCoordinate] {
        get {
            guard !routePolylineData.isEmpty else { return [] }
            return (try? JSONDecoder().decode([RouteCoordinate].self, from: routePolylineData)) ?? []
        }
        set { routePolylineData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var routeDistanceMiles: Double = 0

    var createdAt: Date = Date()
    /// Number of times this template has been applied to a plan day.
    var usageCount: Int = 0

    init(
        templateName: String,
        workoutType: WorkoutType = .running,
        title: String = "",
        plannedDistanceMiles: Double = 0,
        plannedDurationSeconds: Int = 0,
        strengthType: StrengthType = .unspecified,
        crossTrainingActivityType: CrossTrainingActivityType = .other,
        runCategory: RunCategory = .none,
        intensityLevel: IntensityLevel = .moderate,
        runSegments: [PlannedRunSegment] = [],
        notes: String = "",
        postRunStrides: Bool = false,
        routeWaypoints: [RouteWaypoint] = [],
        routePolyline: [RouteCoordinate] = [],
        routeDistanceMiles: Double = 0
    ) {
        self.id = UUID()
        self.templateName = templateName
        self.workoutType = workoutType
        self.title = title
        self.plannedDistanceMiles = plannedDistanceMiles
        self.plannedDurationSeconds = plannedDurationSeconds
        self.strengthTypeRaw = strengthType.rawValue
        self.crossTrainingActivityTypeRaw = crossTrainingActivityType.rawValue
        self.runCategoryRaw = runCategory.rawValue
        self.intensityLevelRaw = intensityLevel.rawValue
        self.runSegmentsData = (try? JSONEncoder().encode(runSegments)) ?? Data()
        self.notes = notes
        self.postRunStrides = postRunStrides
        self.routeWaypointsData = (try? JSONEncoder().encode(routeWaypoints)) ?? Data()
        self.routePolylineData = (try? JSONEncoder().encode(routePolyline)) ?? Data()
        self.routeDistanceMiles = routeDistanceMiles
        self.usageCount = 0
        self.createdAt = .now
    }

    /// Short summary line shown in the library (e.g. "Running · 8.0 mi · Long Run").
    var summaryLabel: String {
        var parts: [String] = [workoutType.rawValue]
        if plannedDistanceMiles > 0 {
            parts.append(String(format: "%.2g mi", plannedDistanceMiles))
        } else if routeDistanceMiles > 0 {
            parts.append(String(format: "%.2g mi route", routeDistanceMiles))
        }
        if workoutType == WorkoutType.running && runCategory != RunCategory.none {
            parts.append(runCategory.rawValue)
        }
        if workoutType == WorkoutType.strength && strengthType != StrengthType.unspecified {
            parts.append(strengthType.rawValue)
        }
        if workoutType == WorkoutType.crossTraining {
            parts.append(crossTrainingActivityType.rawValue)
        }
        if plannedDurationSeconds > 0 {
            parts.append(plannedDurationSeconds.formattedAsTime)
        }
        return parts.joined(separator: " · ")
    }
}
