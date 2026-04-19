// Services/EnhancedNotificationService.swift
// Schedules rule-based workout notifications beyond the basic Sunday reminder.

import Foundation
import UserNotifications

struct EnhancedNotificationService {

    // MARK: - Permission

    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    // MARK: - Schedule

    /// Re-evaluates all enabled rules against this week's plan and replaces
    /// any previously-scheduled rule-based notifications.
    /// When `isInjured` is true, workout-day reminders (meal, hydration, fuel, long-run gel)
    /// are silenced — only race-countdown reminders continue.
    static func scheduleNotifications(
        rules: [NotificationRule],
        plannedWorkouts: [PlannedWorkout],
        races: [Race],
        isInjured: Bool = false
    ) {
        let center = UNUserNotificationCenter.current()

        // Remove all previously scheduled rule-based notifications
        center.getPendingNotificationRequests { pending in
            let ruleIds = pending
                .filter { $0.identifier.hasPrefix("rule-") || $0.identifier.hasPrefix("race-prep-") }
                .map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: ruleIds)

            let now = Date.now
            let calendar = Calendar.current
            let weekEnd = calendar.date(byAdding: .day, value: 14, to: now) ?? now

            for rule in rules where rule.isEnabled {
                // Skip workout-day reminders while the athlete is injured/on break.
                // Race countdowns still fire so they don't miss upcoming races.
                if isInjured && rule.type != .upcomingRace { continue }

                switch rule.type {

                case .preWorkoutMeal, .hydration, .fuelPlan:
                    // Fire N minutes before each qualifying planned workout
                    let qualifying = plannedWorkouts.filter { workout in
                        guard workout.date > now, workout.date <= weekEnd else { return false }
                        guard !workout.isCompleted else { return false }
                        switch rule.workoutFilter {
                        case .allWorkouts:   return true
                        case .runningOnly:   return workout.workoutType == .running
                        case .strengthOnly:  return workout.workoutType == .strength
                        case .longRunsOnly:
                            return workout.workoutType == .running &&
                                   (workout.runCategory == .longRun ||
                                    workout.plannedDistanceMiles >= 10)
                        }
                    }
                    for workout in qualifying {
                        // Skip fuelPlan rule if workout has no plan
                        if rule.type == .fuelPlan && workout.fuelPlan?.hasContent != true { continue }

                        guard let fireDate = calendar.date(
                            byAdding: .minute,
                            value: -rule.leadMinutes,
                            to: workout.date
                        ), fireDate > now else { continue }

                        let content = buildContent(rule: rule, workout: workout)
                        schedule(content: content, at: fireDate,
                                 identifier: "rule-\(rule.id)-\(workout.id)")
                    }

                case .longRunFuel:
                    // Schedule interval reminders for upcoming long runs
                    let longRuns = plannedWorkouts.filter { workout in
                        guard workout.date > now, workout.date <= weekEnd else { return false }
                        guard !workout.isCompleted else { return false }
                        return workout.workoutType == .running &&
                               (workout.runCategory == .longRun ||
                                workout.plannedDistanceMiles >= 10)
                    }
                    for run in longRuns {
                        // Fire at: start + 1×interval, start + 2×interval, etc.
                        let duration = run.plannedDurationSeconds > 0
                            ? run.plannedDurationSeconds
                            : estimatedDurationSeconds(for: run)
                        guard duration > 0 else { continue }

                        let intervalSecs = rule.leadMinutes * 60
                        var offset = intervalSecs
                        var index = 1
                        while offset < duration {
                            guard let fireDate = calendar.date(
                                byAdding: .second, value: offset, to: run.date
                            ), fireDate > now else {
                                offset += intervalSecs
                                index += 1
                                continue
                            }
                            let content = buildLongRunFuelContent(rule: rule, index: index)
                            schedule(content: content, at: fireDate,
                                     identifier: "rule-\(rule.id)-\(run.id)-\(index)")
                            offset += intervalSecs
                            index += 1
                        }
                    }

                case .upcomingRace:
                    // Fire N minutes (typically days) before each upcoming race
                    for race in races where !race.isPast {
                        guard let fireDate = calendar.date(
                            byAdding: .minute,
                            value: -rule.leadMinutes,
                            to: race.date
                        ), fireDate > now else { continue }

                        let content = buildRaceContent(rule: rule, race: race)
                        schedule(content: content, at: fireDate,
                                 identifier: "rule-\(rule.id)-race-\(race.id)")
                    }
                }
            }

            // Schedule race prep reminders for races with checklists
            schedulePrepReminders(races: races, now: now, calendar: calendar)
        }
    }

    /// Schedule race prep checklist reminders at 7 days, 3 days, and 1 day before race
    private static func schedulePrepReminders(races: [Race], now: Date, calendar: Calendar) {
        let daysBeforeRace = [7, 3, 1]

        for race in races where !race.isPast && race.racePrep != nil {
            let prep = race.racePrep!
            guard !prep.items.isEmpty else { continue }

            let completed = prep.items.filter { $0.isCompleted }.count
            let total = prep.items.count

            for days in daysBeforeRace {
                guard let fireDate = calendar.date(
                    byAdding: .day,
                    value: -days,
                    to: race.date
                ), fireDate > now else { continue }

                let content = buildPrepReminderContent(race: race, daysUntil: days, completed: completed, total: total)
                schedule(content: content, at: fireDate,
                         identifier: "race-prep-\(race.id)-\(days)d")
            }
        }
    }

    // MARK: - Cancel

    static func cancelAllRuleNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { pending in
            let ids = pending
                .filter { $0.identifier.hasPrefix("rule-") }
                .map(\.identifier)
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - Notification Content Builders

    private static func buildContent(
        rule: NotificationRule,
        workout: PlannedWorkout
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let workoutName = workout.title.isEmpty ? workout.workoutType.rawValue : workout.title

        if !rule.customMessage.isEmpty {
            content.title = rule.type.rawValue
            content.body  = rule.customMessage
        } else {
            switch rule.type {
            case .preWorkoutMeal:
                content.title = "Fuel Up Soon"
                content.body  = "\(workoutName) in \(minuteLabel(rule.leadMinutes)). Time to eat!"
            case .hydration:
                content.title = "Stay Hydrated"
                content.body  = "You have \(workoutName) in \(minuteLabel(rule.leadMinutes)). Drink water now."
            case .fuelPlan:
                let itemCount = workout.fuelPlan?.entries.filter { $0.phase == .pre }.count ?? 0
                content.title = "Review Your Fuel Plan"
                content.body  = "\(workoutName) in \(minuteLabel(rule.leadMinutes))."
                    + (itemCount > 0 ? " You have \(itemCount) pre-workout item\(itemCount == 1 ? "" : "s") scheduled." : "")
            default:
                content.title = rule.type.rawValue
                content.body  = "\(workoutName) in \(minuteLabel(rule.leadMinutes))."
            }
        }

        if rule.soundEnabled { content.sound = .default }
        return content
    }

    private static func buildLongRunFuelContent(
        rule: NotificationRule,
        index: Int
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        if !rule.customMessage.isEmpty {
            content.title = "Fuel Reminder"
            content.body  = rule.customMessage
        } else {
            content.title = "Time to Fuel"
            content.body  = "Take your gel/nutrition now. (\(index * rule.leadMinutes) min in)"
        }
        if rule.soundEnabled { content.sound = .default }
        return content
    }

    private static func buildRaceContent(
        rule: NotificationRule,
        race: Race
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        if !rule.customMessage.isEmpty {
            content.title = "Race Reminder"
            content.body  = rule.customMessage
        } else {
            let days = rule.leadMinutes / 1440
            let hours = (rule.leadMinutes % 1440) / 60
            let timeLabel = days > 0 ? "\(days) day\(days == 1 ? "" : "s")" : "\(hours)h"
            content.title = "Race Day Approaching"
            content.body  = "\(race.name) is in \(timeLabel)."
                + (race.goalTimeSeconds != nil ? " Goal: \(race.goalTimeSeconds!.formattedAsTime)." : "")
        }
        if rule.soundEnabled { content.sound = .default }
        return content
    }

    private static func buildPrepReminderContent(
        race: Race,
        daysUntil: Int,
        completed: Int,
        total: Int
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Race Prep Checklist"
        let dayLabel = daysUntil == 1 ? "tomorrow" : "in \(daysUntil) days"
        content.body = "\(race.name) is \(dayLabel). \(completed) of \(total) prep items done."
        content.sound = .default
        return content
    }

    // MARK: - Helpers

    private static func schedule(
        content: UNMutableNotificationContent,
        at date: Date,
        identifier: String
    ) {
        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private static func minuteLabel(_ minutes: Int) -> String {
        if minutes < 60  { return "\(minutes) min" }
        let h = minutes / 60
        let m = minutes % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    /// Rough duration estimate when plannedDurationSeconds is 0.
    private static func estimatedDurationSeconds(for workout: PlannedWorkout) -> Int {
        // Use a 10 min/mile estimate for running
        guard workout.workoutType == .running, workout.plannedDistanceMiles > 0 else { return 0 }
        return Int(workout.plannedDistanceMiles * 10 * 60)
    }
}
