// Models/PersonalRecord.swift
// Personal records and milestone eras for the Profile tab.

import Foundation
import SwiftData

// MARK: - PR Distance

/// Standard racing distances tracked as personal records.
enum PRDistance: String, Codable, CaseIterable {
    case mile         = "1 Mile"
    case twoMile      = "2 Mile"
    case fiveK        = "5K"
    case tenK         = "10K"
    case halfMarathon = "Half Marathon"
    case marathon     = "Marathon"

    /// Approximate distance in miles — used when comparing against logged run data.
    var distanceMiles: Double {
        switch self {
        case .mile:         return 1.0
        case .twoMile:      return 2.0
        case .fiveK:        return 3.10686
        case .tenK:         return 6.21371
        case .halfMarathon: return 13.1094
        case .marathon:     return 26.2188
        }
    }

    var systemImage: String {
        switch self {
        case .mile:         return "figure.run"
        case .twoMile:      return "figure.run"
        case .fiveK:        return "rosette"
        case .tenK:         return "rosette"
        case .halfMarathon: return "trophy"
        case .marathon:     return "trophy.fill"
        }
    }
}

// MARK: - PersonalRecord

/// A single personal-best effort for a standard distance.
@Model
final class PersonalRecord {
    var id: UUID
    /// Raw storage for PRDistance — do not access directly.
    var distanceRaw: String
    /// PR time in seconds.
    var timeSeconds: Int
    var dateAchieved: Date
    var notes: String
    /// UUID of the `PRMilestone` this PR belongs to. `nil` = all-time record.
    var milestoneIdString: String?
    /// True when this PR was automatically derived from Strava splits data.
    var isDerivedFromStrava: Bool = false
    /// The Strava activity ID that produced this derived PR.
    var sourceStravaActivityId: String? = nil
    /// Calendar year this PR counts for (used for YTD scoping). `nil` = no year restriction.
    var ytdYear: Int? = nil

    init(
        distance: PRDistance,
        timeSeconds: Int,
        dateAchieved: Date = .now,
        notes: String = "",
        milestoneId: UUID? = nil,
        isDerivedFromStrava: Bool = false,
        sourceStravaActivityId: String? = nil,
        ytdYear: Int? = nil
    ) {
        self.id = UUID()
        self.distanceRaw = distance.rawValue
        self.timeSeconds = timeSeconds
        self.dateAchieved = dateAchieved
        self.notes = notes
        self.milestoneIdString = milestoneId?.uuidString
        self.isDerivedFromStrava = isDerivedFromStrava
        self.sourceStravaActivityId = sourceStravaActivityId
        self.ytdYear = ytdYear
    }

    var distance: PRDistance {
        PRDistance(rawValue: distanceRaw) ?? .fiveK
    }

    var milestoneId: UUID? {
        get { milestoneIdString.flatMap { UUID(uuidString: $0) } }
        set { milestoneIdString = newValue?.uuidString }
    }

    /// Formatted as "H:MM:SS" or "M:SS".
    var formattedTime: String {
        timeSeconds.formattedAsTime
    }
}

// MARK: - PRMilestone

/// A named era used for milestone-scoped personal records (e.g. "Post College", "After Injury").
@Model
final class PRMilestone {
    var id: UUID
    var name: String
    var startDate: Date
    var orderIndex: Int

    init(name: String, startDate: Date, orderIndex: Int = 0) {
        self.id = UUID()
        self.name = name
        self.startDate = startDate
        self.orderIndex = orderIndex
    }
}
