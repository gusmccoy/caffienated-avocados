// Models/CrossTrainingWorkout.swift
// Cross-training workout data (cycling, swimming, yoga, rowing, etc.)

import Foundation
import SwiftData

/// Supported cross-training activity types.
enum CrossTrainingActivityType: String, Codable, CaseIterable {
    case cycling      = "Cycling"
    case swimming     = "Swimming"
    case rowing       = "Rowing"
    case yoga         = "Yoga"
    case pilates      = "Pilates"
    case hiit         = "HIIT"
    case elliptical   = "Elliptical"
    case hiking       = "Hiking"
    case jumpRope     = "Jump Rope"
    case rockClimbing = "Rock Climbing"
    case kayaking     = "Kayaking"
    case other        = "Other"

    var systemImage: String {
        switch self {
        case .cycling:      return "bicycle"
        case .swimming:     return "figure.pool.swim"
        case .rowing:       return "figure.rowing"
        case .yoga:         return "figure.mind.and.body"
        case .pilates:      return "figure.pilates"
        case .hiit:         return "flame.fill"
        case .elliptical:   return "figure.elliptical"
        case .hiking:       return "figure.hiking"
        case .jumpRope:     return "figure.jumprope"
        case .rockClimbing: return "figure.climbing"
        case .kayaking:     return "figure.open.water.swim"
        case .other:        return "figure.mixed.cardio"
        }
    }
}

@Model
final class CrossTrainingWorkout {
    var id: UUID
    var activityType: CrossTrainingActivityType
    var distanceMiles: Double?        // nil for non-distance activities (yoga, etc.)
    var avgPowerWatts: Int?           // Useful for cycling / rowing
    var avgCadenceRPM: Int?           // Cycling cadence
    var strokesPerMinute: Int?        // Rowing / swimming
    var poolLengthYards: Int?         // For lap swimming
    var lapsCompleted: Int?
    var elevationGainFeet: Double?    // For cycling / hiking

    var session: WorkoutSession?

    init(
        activityType: CrossTrainingActivityType = .other,
        distanceMiles: Double? = nil,
        avgPowerWatts: Int? = nil,
        avgCadenceRPM: Int? = nil,
        strokesPerMinute: Int? = nil,
        poolLengthYards: Int? = nil,
        lapsCompleted: Int? = nil,
        elevationGainFeet: Double? = nil
    ) {
        self.id = UUID()
        self.activityType = activityType
        self.distanceMiles = distanceMiles
        self.avgPowerWatts = avgPowerWatts
        self.avgCadenceRPM = avgCadenceRPM
        self.strokesPerMinute = strokesPerMinute
        self.poolLengthYards = poolLengthYards
        self.lapsCompleted = lapsCompleted
        self.elevationGainFeet = elevationGainFeet
    }

    /// Summary string for display in list cells.
    var summaryLine: String {
        var parts: [String] = []
        if let dist = distanceMiles {
            parts.append(String(format: "%.2f mi", dist))
        }
        if let power = avgPowerWatts {
            parts.append("\(power)W avg")
        }
        if let laps = lapsCompleted {
            parts.append("\(laps) laps")
        }
        return parts.isEmpty ? activityType.rawValue : parts.joined(separator: " · ")
    }
}
