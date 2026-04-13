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
    case twoMilePace  = "2 Mile Pace"
    case fiveKPace    = "5K Pace"
    case tenKPace     = "10K Pace"
    case halfPace     = "Half Marathon Pace"
    case marathonPace = "Marathon Pace"
}

// MARK: - Route Coordinate

/// A single latitude/longitude point used to store running routes on planned workouts.
struct RouteCoordinate: Codable, Equatable {
    var latitude: Double
    var longitude: Double
}

/// A user-placed waypoint that MKDirections routes through.
struct RouteWaypoint: Codable, Equatable {
    var latitude: Double
    var longitude: Double
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

    // Repeats modifier
    var isHills: Bool = false

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
    var id: UUID = UUID()
    /// Stored as startOfDay so grouping by day is a simple equality check.
    var date: Date = Date()
    // Property-level defaults ensure CloudKit-synced records can be reconstructed
    // by SwiftData without calling init() when schema evolves across app versions.
    var workoutType: WorkoutType = WorkoutType.running
    var title: String = ""
    /// Always stored in miles (0 for strength workouts or when not set).
    var plannedDistanceMiles: Double = 0
    /// Optional planned duration in seconds (0 = not set).
    var plannedDurationSeconds: Int = 0
    // MARK: - Enum-backed String storage
    // Stored as plain String so Core Data can apply the inline default during lightweight
    // migration (avoids "Could not cast Optional<Any> to EnumType" on existing records).

    /// Raw storage for strengthType — do not access directly.
    var strengthTypeRaw: String = StrengthType.unspecified.rawValue
    /// Strength session classification (Upper Body / Lower Body / Core / Full Body); ignored for non-strength types.
    var strengthType: StrengthType {
        get { StrengthType(rawValue: strengthTypeRaw) ?? .unspecified }
        set { strengthTypeRaw = newValue.rawValue }
    }

    /// Raw storage for crossTrainingActivityType — do not access directly.
    var crossTrainingActivityTypeRaw: String = CrossTrainingActivityType.other.rawValue
    /// Activity type for cross-training workouts; ignored for other types.
    var crossTrainingActivityType: CrossTrainingActivityType {
        get { CrossTrainingActivityType(rawValue: crossTrainingActivityTypeRaw) ?? .other }
        set { crossTrainingActivityTypeRaw = newValue.rawValue }
    }

    /// Raw storage for runCategory — do not access directly.
    var runCategoryRaw: String = RunCategory.none.rawValue
    /// Run category (Base Mileage / Recovery / Workout / Long Run); ignored for non-running types.
    var runCategory: RunCategory {
        get { RunCategory(rawValue: runCategoryRaw) ?? .none }
        set { runCategoryRaw = newValue.rawValue }
    }

    /// JSON-encoded [PlannedRunSegment]. Access via the `runSegments` computed property.
    /// Stored as Data to avoid SwiftData limitations with nested Codable arrays.
    var runSegmentsData: Data = Data()
    /// Decoded run segments. Encodes/decodes transparently through `runSegmentsData`.
    var runSegments: [PlannedRunSegment] {
        get {
            guard !runSegmentsData.isEmpty else { return [] }
            return (try? JSONDecoder().decode([PlannedRunSegment].self, from: runSegmentsData)) ?? []
        }
        set {
            runSegmentsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    /// Total distance derived from segments (repeats × count, ladder = sum of steps).
    var segmentTotalMiles: Double {
        runSegments.reduce(0.0) { total, seg in
            switch seg.segmentType {
            case .repeats, .fartlek:
                return total + seg.distanceMiles * Double(max(1, seg.intervalCount))
            case .ladder:
                return total + seg.ladderDistances.reduce(0.0, +)
            default:
                return total + seg.distanceMiles
            }
        }
    }

    /// True when the stored distance matches what segments calculate (i.e. not manually overridden).
    var distanceIsFromSegments: Bool {
        let calc = segmentTotalMiles
        return calc > 0 && abs(plannedDistanceMiles - calc) < 0.01
    }

    // MARK: - Route

    /// JSON-encoded [RouteCoordinate] — the full polyline for the planned route.
    var routePolylineData: Data = Data()
    /// Decoded route polyline. Encodes/decodes transparently through `routePolylineData`.
    var routePolyline: [RouteCoordinate] {
        get {
            guard !routePolylineData.isEmpty else { return [] }
            return (try? JSONDecoder().decode([RouteCoordinate].self, from: routePolylineData)) ?? []
        }
        set {
            routePolylineData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    /// JSON-encoded [RouteWaypoint] — user-placed pins that define the route path.
    var routeWaypointsData: Data = Data()
    /// Decoded route waypoints for re-editing the route later.
    var routeWaypoints: [RouteWaypoint] {
        get {
            guard !routeWaypointsData.isEmpty else { return [] }
            return (try? JSONDecoder().decode([RouteWaypoint].self, from: routeWaypointsData)) ?? []
        }
        set {
            routeWaypointsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    /// Distance of the planned route in miles, as calculated by MapKit directions.
    var routeDistanceMiles: Double = 0

    /// True when the workout has a planned route with at least two waypoints.
    var hasRoute: Bool { routeWaypoints.count >= 2 }

    var notes: String = ""
    var postRunStrides: Bool = false
    /// Optional fuel and nutrition plan for this workout.
    @Relationship(deleteRule: .cascade) var fuelPlan: FuelPlan? = nil
    var intensityLevel: IntensityLevel = IntensityLevel.moderate
    /// EKEvent.eventIdentifier — nil if calendar access was not granted or event not created.
    var calendarEventIdentifier: String?
    /// True when an imported activity matched this planned workout within the configured threshold.
    var isCompleted: Bool = false
    /// The stravaActivityId of the session that completed this planned workout, if applicable.
    var completedByStravaActivityId: String?
    var createdAt: Date = Date()

    // MARK: - Planner (coach) attribution

    /// The `PlannerRelationship.id.uuidString` of the coach who created this workout.
    /// Nil when the athlete created it themselves.
    var createdByPlannerRelationshipId: String?
    /// Cached display name of the planner — shown as a badge in the athlete's plan.
    var plannerDisplayName: String?

    /// True when this workout was created by a planner (coach) on the athlete's behalf.
    var isCoachCreated: Bool { createdByPlannerRelationshipId != nil }

    init(
        date: Date,
        workoutType: WorkoutType,
        title: String = "",
        plannedDistanceMiles: Double = 0,
        plannedDurationSeconds: Int = 0,
        strengthType: StrengthType = .unspecified,
        crossTrainingActivityType: CrossTrainingActivityType = .other,
        runCategory: RunCategory = .none,
        runSegments: [PlannedRunSegment] = [],   // encoded into runSegmentsData
        notes: String = "",
        postRunStrides: Bool = false,
        intensityLevel: IntensityLevel = .moderate,
        calendarEventIdentifier: String? = nil,
        isCompleted: Bool = false,
        completedByStravaActivityId: String? = nil,
        createdByPlannerRelationshipId: String? = nil,
        plannerDisplayName: String? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.workoutType = workoutType
        self.title = title
        self.plannedDistanceMiles = plannedDistanceMiles
        self.plannedDurationSeconds = plannedDurationSeconds
        self.strengthTypeRaw = strengthType.rawValue
        self.crossTrainingActivityTypeRaw = crossTrainingActivityType.rawValue
        self.runCategoryRaw = runCategory.rawValue
        self.runSegmentsData = (try? JSONEncoder().encode(runSegments)) ?? Data()
        self.notes = notes
        self.postRunStrides = postRunStrides
        self.intensityLevel = intensityLevel
        self.calendarEventIdentifier = calendarEventIdentifier
        self.isCompleted = isCompleted
        self.completedByStravaActivityId = completedByStravaActivityId
        self.createdByPlannerRelationshipId = createdByPlannerRelationshipId
        self.plannerDisplayName = plannerDisplayName
        self.createdAt = .now
    }
}
