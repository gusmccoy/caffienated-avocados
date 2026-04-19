// Services/RacePrepSuggestionService.swift
// Generates race prep checklist suggestions based on race distance and weather.

import Foundation
import WeatherKit
import CoreLocation

struct RacePrepSuggestionService {

    // MARK: - Public API

    /// Generates a full set of prep suggestions for the given race.
    /// Fetches weather for `race.location` when available; falls back to
    /// distance-based suggestions when weather lookup fails.
    static func generateSuggestions(for race: Race) async throws -> [PrepItem] {
        // Snapshot the values we need off the main-actor-bound model first,
        // so we don't touch SwiftData on another actor later.
        let distance = race.distanceMiles
        let location = race.location
        let raceDate = race.date
        let daysUntil = race.daysUntil

        var items: [PrepItem] = []

        items.append(contentsOf: gearSuggestions(distance: distance))

        if !location.isEmpty {
            if let weather = try? await weatherForLocation(location) {
                items.append(contentsOf: weatherBasedSuggestions(weather: weather))
            }
        }

        items.append(contentsOf: lodgingSuggestions(daysUntil: daysUntil, raceDate: raceDate, location: location))
        items.append(contentsOf: travelSuggestions())
        items.append(contentsOf: fuelSuggestions(distance: distance, raceDate: raceDate))

        return items
    }

    // MARK: - Gear

    private static func gearSuggestions(distance: Double) -> [PrepItem] {
        var items: [PrepItem] = []

        items.append(PrepItem(name: "Running shoes (race-day pair)", category: .gear, notes: "Broken in and tested"))
        items.append(PrepItem(name: "Socks (moisture-wicking)", category: .gear))
        items.append(PrepItem(name: "Race bib & timing chip", category: .gear))
        items.append(PrepItem(name: "Race uniform/shirt", category: .gear))

        if distance >= 10 {
            items.append(PrepItem(name: "Hat or visor", category: .gear))
            items.append(PrepItem(name: "Sunglasses", category: .gear))
        }

        if distance >= 13 {
            items.append(PrepItem(name: "Anti-chafe balm", category: .gear))
            items.append(PrepItem(name: "Shorts with pockets", category: .gear))
        }

        if distance >= 26 {
            items.append(PrepItem(name: "Backup shoes", category: .gear, notes: "Optional: prevents blisters on long races"))
            items.append(PrepItem(name: "Moisture-wicking long-sleeve", category: .gear, notes: "If early morning start"))
        }

        if distance >= 50 {
            items.append(PrepItem(name: "Headlamp or light", category: .gear, notes: "If early or night sections"))
            items.append(PrepItem(name: "Backup socks", category: .gear))
            items.append(PrepItem(name: "Trekking poles (optional)", category: .gear, notes: "For downhill protection"))
        }

        return items
    }

    // MARK: - Weather-based

    private static func weatherBasedSuggestions(weather: Weather) -> [PrepItem] {
        var items: [PrepItem] = []

        let dayWeather = weather.dailyForecast.first
        let temp = dayWeather?.highTemperature ?? weather.currentWeather.temperature
        let precipChance = dayWeather?.precipitationChance ?? 0.0

        // Hot (> 24°C / 75°F)
        if temp.value > 24 {
            items.append(PrepItem(name: "Cooling towel or bandana", category: .gear, notes: "Wet before race"))
            items.append(PrepItem(name: "Extra water bottles", category: .gear, notes: "Plan for more hydration"))
            items.append(PrepItem(name: "Sunscreen (high SPF)", category: .gear, notes: "Reapply if race > 2 hours"))
        }

        // Cold (< 10°C / 50°F)
        if temp.value < 10 {
            items.append(PrepItem(name: "Thermal base layer", category: .gear))
            items.append(PrepItem(name: "Running gloves", category: .gear))
            items.append(PrepItem(name: "Beanie or headband", category: .gear))
            items.append(PrepItem(name: "Windbreaker jacket", category: .gear, notes: "Start with, discard if warm"))
        }

        // High precipitation chance (> 50%)
        if precipChance > 0.5 {
            items.append(PrepItem(name: "Rain jacket or poncho", category: .gear))
            items.append(PrepItem(name: "Waterproof bag for phone", category: .gear, notes: "If carrying electronics"))
        }

        return items
    }

    // MARK: - Lodging

    private static func lodgingSuggestions(daysUntil: Int, raceDate: Date, location: String) -> [PrepItem] {
        var items: [PrepItem] = []
        let cal = Calendar.current

        if daysUntil > 14 {
            items.append(PrepItem(name: "Research accommodations", category: .lodging,
                                  notes: "Book early for popular races",
                                  dueDate: cal.date(byAdding: .day, value: -10, to: raceDate)))
        }

        if daysUntil > 7 {
            items.append(PrepItem(name: "Confirm lodging reservation", category: .lodging,
                                  dueDate: cal.date(byAdding: .day, value: -7, to: raceDate)))
        }

        items.append(PrepItem(name: "Plan arrival timing (day before)", category: .lodging,
                              notes: "Allow time for check-in, exploration"))
        items.append(PrepItem(name: "Scout race course or venue", category: .lodging,
                              notes: "Walk/drive the route if possible"))

        if !location.isEmpty {
            items.append(PrepItem(name: "Download offline maps", category: .lodging,
                                  notes: "For \(location)"))
        }

        items.append(PrepItem(name: "Arrange parking or transportation", category: .lodging,
                              notes: "Race morning logistics"))

        return items
    }

    // MARK: - Travel

    private static func travelSuggestions() -> [PrepItem] {
        [
            PrepItem(name: "Check travel requirements (passport, ID)", category: .travel),
            PrepItem(name: "Book transportation (flights/train)", category: .travel, notes: "If traveling far"),
            PrepItem(name: "Plan race day route & timing", category: .travel, notes: "Leave early for parking/check-in"),
            PrepItem(name: "Confirm race start time & location", category: .travel),
            PrepItem(name: "Attend packet pickup", category: .travel, notes: "Get bib, timing chip, shirt"),
            PrepItem(name: "Scout bathroom locations", category: .travel, notes: "At race venue")
        ]
    }

    // MARK: - Fuel

    private static func fuelSuggestions(distance: Double, raceDate: Date) -> [PrepItem] {
        var items: [PrepItem] = []

        items.append(PrepItem(name: "Pre-race breakfast plan", category: .fuel,
                              notes: "Eat 2–3 hours before; test in training", dueDate: raceDate))
        items.append(PrepItem(name: "Race morning fuel", category: .fuel,
                              notes: "Familiar carbs + protein", dueDate: raceDate))

        if distance > 10 {
            items.append(PrepItem(name: "Plan hydration strategy", category: .fuel, notes: "Drink every 15–20 min"))
        }

        if distance >= 13 {
            items.append(PrepItem(name: "Plan fueling schedule", category: .fuel, notes: "Carbs every 30–45 min"))
            items.append(PrepItem(name: "Test race-day fuel in training", category: .fuel, notes: "No surprises on race day"))
        }

        if distance >= 26 {
            items.append(PrepItem(name: "Electrolyte plan", category: .fuel, notes: "Replace sodium losses"))
            items.append(PrepItem(name: "Pack fuel (gels, sports drink, etc.)", category: .fuel, notes: "Test brand in long runs"))
        }

        if distance >= 50 {
            items.append(PrepItem(name: "Plan aid station nutrition", category: .fuel, notes: "Solid foods if longer efforts"))
            items.append(PrepItem(name: "Prepare backup fuel", category: .fuel, notes: "In case aid stations run out"))
        }

        items.append(PrepItem(name: "Recovery meal plan", category: .fuel, notes: "Carbs + protein within 30 min after"))

        return items
    }

    // MARK: - Weather fetching

    private static func weatherForLocation(_ location: String) async throws -> Weather {
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.geocodeAddressString(location)

        guard let coordinate = placemarks.first?.location?.coordinate else {
            throw NSError(domain: "RacePrepSuggestion", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Could not geocode location"])
        }

        let clLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return try await WeatherService.shared.weather(for: clLocation)
    }
}
