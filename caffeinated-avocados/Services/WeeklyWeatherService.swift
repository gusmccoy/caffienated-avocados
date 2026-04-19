// Services/WeeklyWeatherService.swift
// Fetches daily weather forecasts for the current week's plan.
// Prefers race/run locations when set; falls back to the user's current location.

import Foundation
import Observation
import CoreLocation
import WeatherKit
import SwiftUI

/// Compact summary of a single day's weather suitable for UI rendering.
struct DayWeatherSummary: Equatable {
    let symbolName: String      // SF Symbol name (e.g., "sun.max.fill")
    let highTempCelsius: Double
    let precipitationChance: Double

    var formattedHigh: String {
        let measurement = Measurement(value: highTempCelsius, unit: UnitTemperature.celsius)
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .temperatureWithoutUnit
        formatter.numberFormatter.maximumFractionDigits = 0
        return formatter.string(from: measurement)
    }
}

/// Observable cache of per-day weather summaries keyed by day start.
/// Entries are fetched lazily and reused for 6 hours to avoid excess WeatherKit calls.
@Observable
final class WeeklyWeatherService {
    /// Map of day (startOfDay) → weather summary. View observes this.
    var summaries: [Date: DayWeatherSummary] = [:]

    /// Day → the last time we successfully fetched it (used for freshness).
    private var lastFetched: [Date: Date] = [:]

    /// TTL for a cached forecast. A fresh call beyond this re-fetches.
    private let cacheTTL: TimeInterval = 60 * 60 * 6  // 6 hours

    private let weatherService = WeatherService.shared

    /// Fetch weather for each day in `days` using the preferred coordinate for that day.
    /// - Parameter dayCoordinates: Pairs of (dayStart, coordinate). Pass `nil` to skip a day.
    func refresh(dayCoordinates: [(day: Date, coordinate: CLLocationCoordinate2D?)]) {
        Task { @MainActor in
            for entry in dayCoordinates {
                guard let coord = entry.coordinate else { continue }
                let dayKey = entry.day.startOfDay

                // Skip if cache is fresh
                if let last = lastFetched[dayKey], Date().timeIntervalSince(last) < cacheTTL,
                   summaries[dayKey] != nil {
                    continue
                }

                do {
                    let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                    let weather = try await weatherService.weather(for: location)

                    // Find the daily forecast matching this day (WeatherKit returns ~10 days).
                    let matching = weather.dailyForecast.forecast.first { day in
                        Calendar.current.isDate(day.date, inSameDayAs: dayKey)
                    }

                    if let dayForecast = matching {
                        summaries[dayKey] = DayWeatherSummary(
                            symbolName: dayForecast.symbolName,
                            highTempCelsius: dayForecast.highTemperature.converted(to: .celsius).value,
                            precipitationChance: dayForecast.precipitationChance
                        )
                        lastFetched[dayKey] = Date()
                    }
                } catch {
                    // Silently skip — UI just won't show an icon for this day.
                }
            }
        }
    }

    /// Retrieve a cached summary for a given day if available.
    func summary(for day: Date) -> DayWeatherSummary? {
        summaries[day.startOfDay]
    }
}
