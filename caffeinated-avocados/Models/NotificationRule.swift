// Models/NotificationRule.swift
// User-configurable rules that drive enhanced workout notifications.

import Foundation
import SwiftData

// MARK: - Rule Type

enum NotificationRuleType: String, Codable, CaseIterable {
    case preWorkoutMeal   = "Pre-Workout Meal Reminder"
    case hydration        = "Hydration Reminder"
    case fuelPlan         = "Fuel Plan Reminder"
    case upcomingRace     = "Upcoming Race Reminder"
    case longRunFuel      = "Long Run Gel Timing"

    var description: String {
        switch self {
        case .preWorkoutMeal:
            return "Reminds you to eat before a planned workout."
        case .hydration:
            return "Reminds you to hydrate on workout days."
        case .fuelPlan:
            return "Reminds you of your fuel plan before workouts that have one."
        case .upcomingRace:
            return "Sends a reminder a set number of days before a race."
        case .longRunFuel:
            return "Sends periodic gel/fuel reminders during long runs."
        }
    }

    var systemImage: String {
        switch self {
        case .preWorkoutMeal:  return "fork.knife"
        case .hydration:       return "waterbottle.fill"
        case .fuelPlan:        return "bolt.fill"
        case .upcomingRace:    return "flag.checkered"
        case .longRunFuel:     return "drop.fill"
        }
    }

    var defaultLeadMinutes: Int {
        switch self {
        case .preWorkoutMeal: return 90
        case .hydration:      return 60
        case .fuelPlan:       return 30
        case .upcomingRace:   return 2880   // 2 days = 2880 min
        case .longRunFuel:    return 45     // every 45 min
        }
    }
}

// MARK: - Workout Filter

/// Which workout types a rule applies to.
enum NotificationWorkoutFilter: String, Codable, CaseIterable {
    case allWorkouts   = "All Workouts"
    case runningOnly   = "Running Only"
    case longRunsOnly  = "Long Runs Only"
    case strengthOnly  = "Strength Only"
}

// MARK: - NotificationRule (@Model)

@Model
final class NotificationRule {
    var id: UUID
    /// Raw storage for `NotificationRuleType`.
    var typeRaw: String = NotificationRuleType.preWorkoutMeal.rawValue
    var isEnabled: Bool = true
    /// For pre-event rules: minutes before the workout to fire.
    /// For race rules: minutes before the race date.
    /// For longRunFuel: interval in minutes.
    var leadMinutes: Int = 90
    /// Override the default message (empty = use default).
    var customMessage: String = ""
    /// Whether to play a sound with this notification.
    var soundEnabled: Bool = true
    /// Raw storage for `NotificationWorkoutFilter`.
    var workoutFilterRaw: String = NotificationWorkoutFilter.allWorkouts.rawValue
    var createdAt: Date

    var type: NotificationRuleType {
        get { NotificationRuleType(rawValue: typeRaw) ?? .preWorkoutMeal }
        set { typeRaw = newValue.rawValue }
    }

    var workoutFilter: NotificationWorkoutFilter {
        get { NotificationWorkoutFilter(rawValue: workoutFilterRaw) ?? .allWorkouts }
        set { workoutFilterRaw = newValue.rawValue }
    }

    init(
        type: NotificationRuleType,
        isEnabled: Bool = true,
        leadMinutes: Int? = nil,
        customMessage: String = "",
        soundEnabled: Bool = true,
        workoutFilter: NotificationWorkoutFilter = .allWorkouts
    ) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.isEnabled = isEnabled
        self.leadMinutes = leadMinutes ?? type.defaultLeadMinutes
        self.customMessage = customMessage
        self.soundEnabled = soundEnabled
        self.workoutFilterRaw = workoutFilter.rawValue
        self.createdAt = .now
    }
}
