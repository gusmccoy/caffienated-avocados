// Services/CalendarService.swift
// EventKit wrapper for creating and removing calendar events for planned workouts.

import EventKit
import Foundation

enum CalendarError: LocalizedError {
    case notAuthorized
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Calendar access is required to create events. Enable it in Settings."
        case .saveFailed(let error):
            return "Could not save calendar event: \(error.localizedDescription)"
        }
    }
}

final class CalendarService {

    private let store = EKEventStore()

    // MARK: - Authorization

    var isAuthorized: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    /// Requests full calendar access if not already granted. Returns true if authorized.
    func requestAccessIfNeeded() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .fullAccess:
            return true
        case .notDetermined:
            do {
                return try await store.requestFullAccessToEvents()
            } catch {
                return false
            }
        default:
            return false
        }
    }

    // MARK: - Create

    /// Creates a calendar event for a planned workout and returns the eventIdentifier.
    func createEvent(for workout: PlannedWorkout) async throws -> String {
        guard await requestAccessIfNeeded() else { throw CalendarError.notAuthorized }

        let event = EKEvent(eventStore: store)
        event.title = workout.title.isEmpty ? workout.workoutType.rawValue : workout.title
        event.startDate = workout.date
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: workout.date) ?? workout.date
        event.notes = buildNotes(for: workout)
        event.calendar = store.defaultCalendarForNewEvents

        do {
            try store.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            throw CalendarError.saveFailed(error)
        }
    }

    /// Creates an all-day calendar event for a race and returns the eventIdentifier.
    func createEvent(for race: Race) async throws -> String {
        guard await requestAccessIfNeeded() else { throw CalendarError.notAuthorized }

        let event = EKEvent(eventStore: store)
        event.title = race.name
        event.isAllDay = true
        event.startDate = race.date
        event.endDate = race.date
        event.notes = buildNotes(for: race)
        event.calendar = store.defaultCalendarForNewEvents

        do {
            try store.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            throw CalendarError.saveFailed(error)
        }
    }

    // MARK: - Delete

    /// Deletes a calendar event by its stored identifier. Treats a missing event as success.
    func deleteEvent(identifier: String) async throws {
        guard await requestAccessIfNeeded() else { throw CalendarError.notAuthorized }
        guard let event = store.event(withIdentifier: identifier) else { return }
        do {
            try store.remove(event, span: .thisEvent)
        } catch {
            throw CalendarError.saveFailed(error)
        }
    }

    // MARK: - Helpers

    private func buildNotes(for race: Race) -> String {
        var parts: [String] = ["Distance: \(race.raceDistance.rawValue)"]
        if !race.location.isEmpty { parts.append("Location: \(race.location)") }
        if let secs = race.goalTimeSeconds {
            let h = secs / 3600
            let m = (secs % 3600) / 60
            let s = secs % 60
            parts.append(String(format: "Goal Time: %d:%02d:%02d", h, m, s))
        }
        if !race.notes.isEmpty { parts.append(race.notes) }
        return parts.joined(separator: "\n")
    }

    private func buildNotes(for workout: PlannedWorkout) -> String {
        var parts: [String] = []
        if workout.plannedDistanceMiles > 0 {
            parts.append(String(format: "Distance: %.2f mi", workout.plannedDistanceMiles))
        }
        parts.append("Intensity: \(workout.intensityLevel.rawValue)")
        if !workout.notes.isEmpty {
            parts.append(workout.notes)
        }
        return parts.joined(separator: "\n")
    }
}
