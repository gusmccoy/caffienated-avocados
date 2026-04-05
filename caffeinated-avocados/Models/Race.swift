// Models/Race.swift
// Represents a goal race on the training plan.

import Foundation
import SwiftData

/// Common race distances with preset mileage. Choose .custom to enter a manual distance.
enum RaceDistance: String, Codable, CaseIterable {
    case fiveK        = "5K"
    case eightK       = "8K"
    case tenK         = "10K"
    case fifteenK     = "15K"
    case tenMile      = "10 Mile"
    case halfMarathon = "Half Marathon"
    case marathon     = "Marathon"
    case fiftyK       = "50K"
    case fiftyMile    = "50 Mile"
    case hundredK     = "100K"
    case hundredMile  = "100 Mile"
    case custom       = "Custom"

    /// Preset distance in miles. Nil for `.custom`.
    var presetMiles: Double? {
        switch self {
        case .fiveK:        return 3.107
        case .eightK:       return 4.971
        case .tenK:         return 6.214
        case .fifteenK:     return 9.321
        case .tenMile:      return 10.0
        case .halfMarathon: return 13.109
        case .marathon:     return 26.219
        case .fiftyK:       return 31.069
        case .fiftyMile:    return 50.0
        case .hundredK:     return 62.137
        case .hundredMile:  return 100.0
        case .custom:       return nil
        }
    }
}

@Model
final class Race {
    var id: UUID
    var name: String
    var date: Date
    var raceDistance: RaceDistance
    /// Effective distance in miles. Matches `raceDistance.presetMiles` unless `.custom`.
    var distanceMiles: Double
    var location: String
    var goalTimeSeconds: Int?           // nil = no goal time set
    var notes: String
    var isCompleted: Bool = false
    var createdAt: Date

    init(
        name: String = "",
        date: Date = .now,
        raceDistance: RaceDistance = .marathon,
        distanceMiles: Double = 26.219,
        location: String = "",
        goalTimeSeconds: Int? = nil,
        notes: String = "",
        isCompleted: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.date = date
        self.raceDistance = raceDistance
        self.distanceMiles = distanceMiles
        self.location = location
        self.goalTimeSeconds = goalTimeSeconds
        self.notes = notes
        self.isCompleted = isCompleted
        self.createdAt = .now
    }

    // MARK: - Computed

    /// Days from today until the race (negative if in the past).
    var daysUntil: Int {
        Calendar.current.dateComponents([.day], from: Date.now.startOfDay, to: date.startOfDay).day ?? 0
    }

    /// e.g. "In 42 days", "Today!", "3 days ago"
    var countdownLabel: String {
        let d = daysUntil
        if d == 0 { return "Today!" }
        if d > 0  { return "In \(d) day\(d == 1 ? "" : "s")" }
        return "\(abs(d)) day\(abs(d) == 1 ? "" : "s") ago"
    }

    var isPast: Bool { daysUntil < 0 }
}
