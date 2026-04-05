// Services/WeeklyPlanningReminderService.swift
// Schedules a repeating Sunday notification reminding the user to plan the next week.

import UserNotifications

struct WeeklyPlanningReminderService {
    static let notificationIdentifier = "weekly-planning-reminder"

    /// Requests .alert and .sound notification permissions.
    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    /// Replaces any existing reminder with one firing every Sunday at the given hour/minute.
    static func scheduleReminder(hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Plan Your Week"
        content.body = "Have you mapped out your workouts for next week?"
        content.sound = .default

        var components = DateComponents()
        components.weekday = 1 // 1 = Sunday in Gregorian calendar
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    /// Removes the pending reminder.
    static func cancelReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
    }
}
