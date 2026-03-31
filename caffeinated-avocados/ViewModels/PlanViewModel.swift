// ViewModels/PlanViewModel.swift
// Drives the weekly training plan view and add-workout sheet.

import Foundation
import Observation

@Observable
final class PlanViewModel {

    // MARK: - Week Navigation

    /// The Monday of the currently displayed week.
    var weekStart: Date = PlanViewModel.currentWeekMonday()

    var weekEnd: Date {
        Calendar.current.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
    }

    var weekDays: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: weekStart) }
    }

    var weekLabel: String {
        let startFmt = DateFormatter()
        startFmt.dateFormat = "MMM d"
        let endFmt = DateFormatter()
        endFmt.dateFormat = "MMM d, yyyy"
        return "\(startFmt.string(from: weekStart)) – \(endFmt.string(from: weekEnd))"
    }

    var isCurrentWeek: Bool {
        weekStart == PlanViewModel.currentWeekMonday()
    }

    func goToPreviousWeek() {
        weekStart = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: weekStart) ?? weekStart
    }

    func goToNextWeek() {
        weekStart = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? weekStart
    }

    func goToCurrentWeek() {
        weekStart = PlanViewModel.currentWeekMonday()
    }

    // MARK: - Data Helpers

    /// Filters planned workouts to a specific day (matched by startOfDay).
    func workouts(for day: Date, from all: [PlannedWorkout]) -> [PlannedWorkout] {
        let target = day.startOfDay
        return all.filter { $0.date == target }
    }

    /// Sum of planned miles for running and cross-training workouts in the provided list.
    func totalPlannedMiles(from workouts: [PlannedWorkout]) -> Double {
        workouts
            .filter { $0.workoutType == .running || $0.workoutType == .crossTraining }
            .reduce(0) { $0 + $1.plannedDistanceMiles }
    }

    /// Workouts whose date falls within the current displayed week.
    func workoutsInCurrentWeek(from all: [PlannedWorkout]) -> [PlannedWorkout] {
        let start = weekStart.startOfDay
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? start
        return all.filter { $0.date >= start && $0.date < end }
    }

    // MARK: - Add-Sheet Form State

    var isShowingAddSheet: Bool = false
    var sheetTargetDate: Date = .now
    var formType: WorkoutType = .running
    var formTitle: String = ""
    var formDistanceMiles: Double = 0
    var formNotes: String = ""
    var formIntensity: IntensityLevel = .moderate
    var calendarAuthorizationDenied: Bool = false

    var formShowsDistance: Bool {
        formType == .running || formType == .crossTraining
    }

    func openAddSheet(for day: Date) {
        sheetTargetDate = day.startOfDay
        formType = .running
        formTitle = ""
        formDistanceMiles = 0
        formNotes = ""
        formIntensity = .moderate
        calendarAuthorizationDenied = false
        isShowingAddSheet = true
    }

    func resetForm() {
        isShowingAddSheet = false
        formTitle = ""
        formDistanceMiles = 0
        formNotes = ""
        formIntensity = .moderate
        calendarAuthorizationDenied = false
    }

    // MARK: - Private

    static func currentWeekMonday() -> Date {
        var calendar = Calendar(identifier: .iso8601)
        calendar.locale = Locale.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
        return (calendar.date(from: components) ?? .now).startOfDay
    }
}
