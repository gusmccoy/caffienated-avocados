// Models/RunningWorkout.swift
// Running-specific data attached to a WorkoutSession.

import Foundation
import SwiftData

/// Unit preference for distance display.
enum DistanceUnit: String, Codable, CaseIterable {
    case miles      = "mi"
    case kilometers = "km"
}

/// Type of running workout.
enum RunType: String, Codable, CaseIterable {
    case easy        = "Easy Run"
    case tempo       = "Tempo"
    case intervals   = "Intervals"
    case longRun     = "Long Run"
    case race        = "Race"
    case trail       = "Trail"
    case recovery    = "Recovery"
    case other       = "Other"
}

@Model
final class RunningWorkout {
    var id: UUID = UUID()
    var distanceMiles: Double = 0        // Always stored in miles; UI converts if needed
    var runType: RunType = RunType.easy
    var averagePaceSecondsPerMile: Int = 0  // Stored as seconds/mile
    var elevationGainFeet: Double?
    var elevationLossFeet: Double?
    var cadenceAvg: Int?              // Steps per minute
    var strideLength: Double?         // In meters
    var route: String?                // e.g. "Griffith Park Loop"
    var splits: [RunningSplit] = []   // Per-mile/km split data

    // Back-reference to parent session
    var session: WorkoutSession?

    init(
        distanceMiles: Double = 0,
        runType: RunType = .easy,
        averagePaceSecondsPerMile: Int = 0,
        elevationGainFeet: Double? = nil,
        elevationLossFeet: Double? = nil,
        cadenceAvg: Int? = nil,
        route: String? = nil
    ) {
        self.id = UUID()
        self.distanceMiles = distanceMiles
        self.runType = runType
        self.averagePaceSecondsPerMile = averagePaceSecondsPerMile
        self.elevationGainFeet = elevationGainFeet
        self.elevationLossFeet = elevationLossFeet
        self.cadenceAvg = cadenceAvg
        self.route = route
        self.splits = []
    }

    // MARK: - Computed

    /// Pace formatted as "M:SS /mi".
    var formattedPace: String {
        guard averagePaceSecondsPerMile > 0 else { return "--:--" }
        let minutes = averagePaceSecondsPerMile / 60
        let seconds = averagePaceSecondsPerMile % 60
        return String(format: "%d:%02d /mi", minutes, seconds)
    }

    /// Distance formatted with 2 decimal places.
    var formattedDistance: String {
        String(format: "%.2f mi", distanceMiles)
    }
}

// MARK: - Split

/// Per-mile (or per-km) split data for a run.
struct RunningSplit: Codable, Identifiable {
    var id: UUID = UUID()
    var splitNumber: Int             // 1-indexed
    var distanceUnit: DistanceUnit
    var paceSecondsPerUnit: Int      // Pace for this split
    var heartRateAvg: Int?

    var formattedPace: String {
        let minutes = paceSecondsPerUnit / 60
        let seconds = paceSecondsPerUnit % 60
        return String(format: "%d:%02d /\(distanceUnit.rawValue)", minutes, seconds)
    }
}
