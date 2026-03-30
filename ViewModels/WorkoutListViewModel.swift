// ViewModels/WorkoutListViewModel.swift
// Manages filtering, sorting, and summary stats across all workout types.

import Foundation
import SwiftData
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
            let calendar = Calendar.current
            let now = Date.now
            switch self {
            case .allTime:   return nil
            case .thisWeek:  return calendar.dateInterval(of: .weekOfYear, for: now)?.start
            case .thisMonth: return calendar.dateInterval(of: .month, for: now)?.start
            case .thisYear:  return calendar.dateInterval(of: .year, for: now)?.start
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

    func weeklySummary(from sessions: [WorkoutSession]) -> WeeklySummary {
        let calendar = Calendar.current
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
}
