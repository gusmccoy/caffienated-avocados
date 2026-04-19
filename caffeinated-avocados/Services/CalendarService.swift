// Services/CalendarService.swift
// EventKit wrapper for creating and removing calendar events for planned workouts.

import CoreLocation
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

        // If the planned workout has a mapped route, set the starting waypoint as the
        // calendar event's location so it shows a tappable map pin in the Calendar app.
        if let startWaypoint = workout.routeWaypoints.first {
            await applyStartLocation(to: event, waypoint: startWaypoint)
        }

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

    // MARK: - Route Location

    /// Writes the start waypoint of a planned route as the calendar event's structured
    /// location, giving the Calendar app a tappable map pin.
    /// Reverse-geocodes for a human-readable address; falls back to a coordinate string
    /// if geocoding is unavailable or fails.
    private func applyStartLocation(to event: EKEvent, waypoint: RouteWaypoint) async {
        let clLocation = CLLocation(latitude: waypoint.latitude, longitude: waypoint.longitude)
        let title = await reverseGeocodeTitle(for: clLocation)
            ?? String(format: "%.5f°, %.5f°", waypoint.latitude, waypoint.longitude)

        let structured = EKStructuredLocation(title: title)
        structured.geoLocation = clLocation
        event.structuredLocation = structured
    }

    /// Returns a short human-readable address for `location` via reverse geocoding,
    /// or `nil` if the geocoder is unavailable or returns no results.
    private func reverseGeocodeTitle(for location: CLLocation) async -> String? {
        return try? await withCheckedThrowingContinuation { continuation in
            CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let placemark = placemarks?.first else {
                    continuation.resume(returning: nil)
                    return
                }
                var parts: [String] = []
                // `name` is populated for named places (parks, gyms, etc.) and street
                // addresses — prefer it; otherwise build from sub-components.
                if let name = placemark.name, !name.isEmpty {
                    parts.append(name)
                } else {
                    if let number = placemark.subThoroughfare { parts.append(number) }
                    if let street = placemark.thoroughfare    { parts.append(street) }
                }
                if let city = placemark.locality { parts.append(city) }
                continuation.resume(returning: parts.isEmpty ? nil : parts.joined(separator: ", "))
            }
        }
    }
}
