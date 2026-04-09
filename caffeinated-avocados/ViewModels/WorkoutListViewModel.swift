// ViewModels/WorkoutListViewModel.swift
// Manages filtering, sorting, and summary stats across all workout types.

import Foundation
import SwiftData
import SwiftUI
import Observation

@Observable
final class WorkoutListViewModel {

    // MARK: - Filter / Sort State
    var selectedTypes: Set<WorkoutType> = Set(WorkoutType.allCases)
    var sortOrder: SortOrder = .dateDescending
    var searchText: String = ""
    var selectedDateRange: DateRange = .allTime

    enum SortOrder: String, CaseIterable {
        case dateDescending  = "Newest First"
        case dateAscending   = "Oldest First"
        case durationLongest = "Longest Duration"
    }

    enum DateRange: String, CaseIterable {
        case allTime    = "All Time"
        case thisWeek   = "This Week"
        case thisMonth  = "This Month"
        case thisYear   = "This Year"

        var startDate: Date? {
            let now = Date.now
            switch self {
            case .allTime:   return nil
            case .thisWeek:  return Calendar.mondayFirst.dateInterval(of: .weekOfYear, for: now)?.start
            case .thisMonth: return Calendar.current.dateInterval(of: .month, for: now)?.start
            case .thisYear:  return Calendar.current.dateInterval(of: .year, for: now)?.start
            }
        }
    }

    // MARK: - Filtering

    /// - Parameter typesOverride: When provided, overrides `selectedTypes` for this call only.
    ///   Use this from type-specific list views so they don't mutate the shared VM state.
    func filter(_ sessions: [WorkoutSession], typesOverride: Set<WorkoutType>? = nil) -> [WorkoutSession] {
        var result = sessions
        let types = typesOverride ?? selectedTypes

        // Type filter
        result = result.filter { types.contains($0.type) }

        // Date range filter
        if let start = selectedDateRange.startDate {
            result = result.filter { $0.date >= start }
        }

        // Search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                $0.type.rawValue.lowercased().contains(query) ||
                $0.notes.lowercased().contains(query)
            }
        }

        // Sort
        switch sortOrder {
        case .dateDescending:
            result.sort { $0.date > $1.date }
        case .dateAscending:
            result.sort { $0.date < $1.date }
        case .durationLongest:
            result.sort { $0.durationSeconds > $1.durationSeconds }
        }

        return result
    }

    // MARK: - Summary Stats

    struct WeeklySummary {
        var totalWorkouts: Int
        var totalDurationSeconds: Int
        var runningMiles: Double
        var strengthSessions: Int
        var crossTrainingSessions: Int

        var formattedDuration: String {
            let hours   = totalDurationSeconds / 3600
            let minutes = (totalDurationSeconds % 3600) / 60
            return "\(hours)h \(minutes)m"
        }
    }

    /// Absolute and percentage deltas vs. the same elapsed window last week.
    struct WeekOverWeekDelta {
        var workouts: Int
        var workoutsPct: Double
        var durationSeconds: Int
        var durationPct: Double
        var miles: Double
        var milesPct: Double

        /// Returns the appropriate color for a percentage delta, per spec:
        /// > +5 % → green | ±5 % → nil (default) | −5 to −10 % → yellow | < −10 % → red
        static func color(for pct: Double) -> Color? {
            if pct > 5   { return .green }
            if pct >= -5 { return nil }
            if pct >= -10 { return .yellow }
            return .red
        }

        var workoutsColor:  Color? { Self.color(for: workoutsPct) }
        var durationColor:  Color? { Self.color(for: durationPct) }
        var milesColor:     Color? { Self.color(for: milesPct) }

        /// "+3", "−1", or "=" style label for workouts.
        var workoutsLabel: String { formatInt(workouts) }

        /// "+12m", "−3m" style label for duration.
        var durationLabel: String {
            let abs = Swift.abs(durationSeconds)
            let h = abs / 3600
            let m = (abs % 3600) / 60
            let formatted = h > 0 ? "\(h)h \(m)m" : "\(m)m"
            return durationSeconds >= 0 ? "+\(formatted)" : "−\(formatted)"
        }

        /// "+2.3", "−0.5" style label for miles.
        var milesLabel: String {
            miles >= 0
                ? String(format: "+%.1f", miles)
                : String(format: "−%.1f", Swift.abs(miles))
        }

        private func formatInt(_ n: Int) -> String {
            if n > 0 { return "+\(n)" }
            if n < 0 { return "−\(Swift.abs(n))" }
            return "="
        }
    }

    func weeklySummary(from sessions: [WorkoutSession]) -> WeeklySummary {
        let calendar = Calendar.mondayFirst
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let thisWeek = sessions.filter { $0.date >= weekStart }

        let runningMiles = thisWeek
            .compactMap { $0.runningWorkout }
            .reduce(0) { $0 + $1.distanceMiles }

        return WeeklySummary(
            totalWorkouts: thisWeek.count,
            totalDurationSeconds: thisWeek.reduce(0) { $0 + $1.durationSeconds },
            runningMiles: runningMiles,
            strengthSessions: thisWeek.filter { $0.type == .strength }.count,
            crossTrainingSessions: thisWeek.filter { $0.type == .crossTraining }.count
        )
    }

    /// Compares the current week (up to now) against the same elapsed window in the previous week.
    func weekOverWeekDelta(from sessions: [WorkoutSession]) -> WeekOverWeekDelta {
        let calendar = Calendar.mondayFirst
        let now = Date.now
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now

        // Elapsed seconds since the start of this week — used to slice last week identically.
        let elapsed = now.timeIntervalSince(weekStart)
        let prevWeekStart   = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) ?? weekStart
        let prevWeekCutoff  = prevWeekStart.addingTimeInterval(elapsed)

        let current = sessions.filter { $0.date >= weekStart && $0.date <= now }
        let prev    = sessions.filter { $0.date >= prevWeekStart && $0.date < prevWeekCutoff }

        let curWorkouts = current.count
        let curDuration = current.reduce(0) { $0 + $1.durationSeconds }
        let curMiles    = current.compactMap(\.runningWorkout).reduce(0.0) { $0 + $1.distanceMiles }

        let prevWorkouts = prev.count
        let prevDuration = prev.reduce(0) { $0 + $1.durationSeconds }
        let prevMiles    = prev.compactMap(\.runningWorkout).reduce(0.0) { $0 + $1.distanceMiles }

        func pct(_ cur: Double, _ prv: Double) -> Double {
            guard prv > 0 else { return cur > 0 ? 100 : 0 }
            return (cur - prv) / prv * 100
        }

        return WeekOverWeekDelta(
            workouts:     curWorkouts - prevWorkouts,
            workoutsPct:  pct(Double(curWorkouts), Double(prevWorkouts)),
            durationSeconds: curDuration - prevDuration,
            durationPct:  pct(Double(curDuration), Double(prevDuration)),
            miles:        curMiles - prevMiles,
            milesPct:     pct(curMiles, prevMiles)
        )
    }
}
