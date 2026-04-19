// Utilities/Extensions.swift
// Handy extensions used throughout the app.

import SwiftUI
import Foundation

// MARK: - Bundle

extension Bundle {
    /// App version string, e.g. "1.0.0 (42)"
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build   = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Calendar

extension Calendar {
    /// ISO 8601 calendar — week always starts on Monday, regardless of device locale.
    static let mondayFirst: Calendar = {
        var cal = Calendar(identifier: .iso8601)
        cal.locale = .current
        return cal
    }()
}

// MARK: - Date

extension Date {
    /// Returns the start of the day for this date.
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// Returns a friendly relative string: "Today", "Yesterday", or the abbreviated date.
    var friendlyRelative: String {
        if Calendar.current.isDateInToday(self) { return "Today" }
        if Calendar.current.isDateInYesterday(self) { return "Yesterday" }
        return formatted(date: .abbreviated, time: .omitted)
    }

    /// Number of days between self and another date.
    func daysBetween(_ other: Date) -> Int {
        abs(Calendar.current.dateComponents([.day], from: startOfDay, to: other.startOfDay).day ?? 0)
    }
}

// MARK: - Double

extension Double {
    /// Converts miles to kilometers.
    var milesToKm: Double { self * 1.60934 }

    /// Converts kilometers to miles.
    var kmToMiles: Double { self / 1.60934 }

    /// Converts meters to feet.
    var metersToFeet: Double { self * 3.28084 }

    /// Converts feet to meters.
    var feetToMeters: Double { self / 3.28084 }

    /// Converts lbs to kg.
    var lbsToKg: Double { self * 0.453592 }

    /// Converts kg to lbs.
    var kgToLbs: Double { self / 0.453592 }

    /// Rounds to a given number of decimal places.
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

// MARK: - Int (seconds → formatted time)

extension Int {
    /// Formats seconds as "H:MM:SS" or "M:SS".
    var formattedAsTime: String {
        let h = self / 3600
        let m = (self % 3600) / 60
        let s = self % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    /// Formats seconds as a pace string "M:SS /unit".
    func formattedAsPace(unit: String = "mi") -> String {
        let m = self / 60
        let s = self % 60
        return String(format: "%d:%02d /\(unit)", m, s)
    }
}

// MARK: - Color

extension Color {
    /// Intensity-level accent color.
    static func intensityColor(_ level: IntensityLevel) -> Color {
        switch level {
        case .easy:     return .green
        case .moderate: return .yellow
        case .hard:     return .orange
        case .max:      return .red
        }
    }
}

// MARK: - macOS Compatibility

#if os(macOS)
enum UIKeyboardType: Int {
    case `default`, asciiCapable, numbersAndPunctuation, URL, numberPad, phonePad, namePhonePad, emailAddress, decimalPad, twitter, webSearch, asciiCapableNumberPad
}

extension View {
    func keyboardType(_ type: UIKeyboardType) -> some View { self }
}
#endif

// MARK: - Platform Interaction Vocabulary

/// "Click" on macOS, "Tap" on iOS — for use in help text and empty state descriptions.
let activateVerb: String = {
    #if os(macOS)
    return "Click"
    #else
    return "Tap"
    #endif
}()

/// "Right-click" on macOS, "Swipe left" on iOS — for swipe-action hints.
let swipeDeleteHint: String = {
    #if os(macOS)
    return "Right-click to delete."
    #else
    return "Swipe left to delete."
    #endif
}()

// MARK: - View Modifiers

extension View {
    /// Applies a card-style background with rounded corners.
    func cardStyle() -> some View {
        self
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    /// Hides the view (but still takes up space).
    func hidden(_ isHidden: Bool) -> some View {
        opacity(isHidden ? 0 : 1)
    }
}
