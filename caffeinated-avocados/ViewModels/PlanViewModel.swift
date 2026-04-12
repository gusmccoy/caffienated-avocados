// ViewModels/PlanViewModel.swift
// Drives the weekly training plan view and add-workout sheet.

import Foundation
import Observation
import SwiftData

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
    var editingWorkout: PlannedWorkout? = nil
    var sheetTargetDate: Date = .now
    var formType: WorkoutType = .running
    var formTitle: String = ""
    var formDistanceMiles: Double = 0
    var formHours: Int = 0
    var formMinutes: Int = 0
    var formSeconds: Int = 0
    var formNotes: String = ""
    var formIntensity: IntensityLevel = .moderate
    var formStrengthType: StrengthType = .unspecified
    var formCrossTrainingActivityType: CrossTrainingActivityType = .other
    var formRunCategory: RunCategory = .none
    var formRunSegments: [PlannedRunSegment] = []
    var formPostRunStrides: Bool = false
    var formRouteWaypoints: [RouteWaypoint] = []
    var formRoutePolyline: [RouteCoordinate] = []
    var formRouteDistanceMiles: Double = 0
    var calendarAuthorizationDenied: Bool = false

    var formDurationSeconds: Int { formHours * 3600 + formMinutes * 60 + formSeconds }

    var isEditing: Bool { editingWorkout != nil }

    var formShowsDistance: Bool {
        formType == .running || formType == .crossTraining
    }

    /// True when the user has typed a distance manually, overriding the segment calculation.
    var formIsDistanceManuallySet: Bool = false

    /// Distance calculated from the current run segments (0 when none have distances set).
    var formCalculatedDistanceMiles: Double {
        guard formType == .running else { return 0 }
        return formRunSegments.reduce(0.0) { total, seg in
            switch seg.segmentType {
            case .repeats, .fartlek:
                return total + seg.distanceMiles * Double(max(1, seg.intervalCount))
            case .ladder:
                return total + seg.ladderDistances.reduce(0.0, +)
            default:
                return total + seg.distanceMiles
            }
        }
    }

    /// The distance that will actually be saved — manual value if overridden, segment total otherwise.
    var formEffectiveDistanceMiles: Double {
        if formIsDistanceManuallySet && formDistanceMiles > 0 { return formDistanceMiles }
        let calc = formCalculatedDistanceMiles
        return calc > 0 ? calc : formDistanceMiles
    }

    func openAddSheet(for day: Date) {
        editingWorkout = nil
        sheetTargetDate = day.startOfDay
        formType = .running
        formTitle = ""
        formDistanceMiles = 0
        formHours = 0
        formMinutes = 0
        formSeconds = 0
        formNotes = ""
        formIntensity = .moderate
        formCrossTrainingActivityType = .other
        formRunCategory = .none
        formStrengthType = .unspecified
        formRunSegments = []
        formPostRunStrides = false
        formRouteWaypoints = []
        formRoutePolyline = []
        formRouteDistanceMiles = 0
        formIsDistanceManuallySet = false
        calendarAuthorizationDenied = false
        isShowingAddSheet = true
    }

    func openEditSheet(for workout: PlannedWorkout) {
        editingWorkout = workout
        sheetTargetDate = workout.date
        formType = workout.workoutType
        formTitle = workout.title
        formDistanceMiles = workout.plannedDistanceMiles
        let d = workout.plannedDurationSeconds
        formHours   = d / 3600
        formMinutes = (d % 3600) / 60
        formSeconds = d % 60
        formNotes = workout.notes
        formIntensity = workout.intensityLevel
        formCrossTrainingActivityType = workout.crossTrainingActivityType
        formRunCategory = workout.runCategory
        formStrengthType = workout.strengthType
        formRunSegments = workout.runSegments
        formPostRunStrides = workout.postRunStrides
        formRouteWaypoints = workout.routeWaypoints
        formRoutePolyline = workout.routePolyline
        formRouteDistanceMiles = workout.routeDistanceMiles
        // If stored distance differs from segment total, the user overrode it manually
        formIsDistanceManuallySet = workout.plannedDistanceMiles > 0 && !workout.distanceIsFromSegments
        calendarAuthorizationDenied = false
        isShowingAddSheet = true
    }

    func resetForm() {
        isShowingAddSheet = false
        editingWorkout = nil
        formTitle = ""
        formDistanceMiles = 0
        formHours = 0
        formMinutes = 0
        formSeconds = 0
        formNotes = ""
        formIntensity = .moderate
        formCrossTrainingActivityType = .other
        formRunCategory = .none
        formStrengthType = .unspecified
        formRunSegments = []
        formPostRunStrides = false
        formRouteWaypoints = []
        formRoutePolyline = []
        formRouteDistanceMiles = 0
        formIsDistanceManuallySet = false
        calendarAuthorizationDenied = false
    }

    // MARK: - Plan Completion

    /// Creates a stub WorkoutSession and marks the plan as completed manually.
    func markPlanComplete(_ workout: PlannedWorkout, modelContext: ModelContext) {
        let session = WorkoutSession(
            date: workout.date,
            type: workout.workoutType,
            title: workout.title,
            notes: workout.notes,
            durationSeconds: workout.plannedDurationSeconds,
            intensityLevel: workout.intensityLevel
        )
        session.isManualPlanCompletion = true

        switch workout.workoutType {
        case .running:
            let run = RunningWorkout(
                distanceMiles: workout.plannedDistanceMiles,
                runType: .other,
                averagePaceSecondsPerMile: 0
            )
            run.session = session
            session.runningWorkout = run
            modelContext.insert(run)
        case .crossTraining:
            let ct = CrossTrainingWorkout(
                activityType: workout.crossTrainingActivityType,
                distanceMiles: workout.plannedDistanceMiles > 0 ? workout.plannedDistanceMiles : nil
            )
            ct.session = session
            session.crossTrainingWorkout = ct
            modelContext.insert(ct)
        case .strength:
            let strength = StrengthWorkout()
            strength.session = session
            session.strengthWorkout = strength
            modelContext.insert(strength)
        }

        modelContext.insert(session)
        workout.isCompleted = true
        workout.completedByStravaActivityId = "manual_\(session.id.uuidString)"
    }

    /// Deletes the stub session and unmarks the plan as complete (only for manual completions).
    func unmarkPlanComplete(_ workout: PlannedWorkout, modelContext: ModelContext) {
        if let ref = workout.completedByStravaActivityId, ref.hasPrefix("manual_") {
            let uuidString = String(ref.dropFirst("manual_".count))
            if let uuid = UUID(uuidString: uuidString) {
                let descriptor = FetchDescriptor<WorkoutSession>(
                    predicate: #Predicate { $0.id == uuid }
                )
                if let stub = try? modelContext.fetch(descriptor).first {
                    modelContext.delete(stub)
                }
            }
        }
        workout.isCompleted = false
        workout.completedByStravaActivityId = nil
    }

    /// Re-runs planned vs actual matching against all existing WorkoutSessions.
    /// Useful when plans were added after activities were already synced.
    func rematchAllPlannedWorkouts(modelContext: ModelContext) {
        let threshold = max(0.01, UserDefaults.standard.double(forKey: "planCompletionThreshold") == 0
            ? 0.05
            : UserDefaults.standard.double(forKey: "planCompletionThreshold") / 100.0)

        let planDescriptor = FetchDescriptor<PlannedWorkout>(
            predicate: #Predicate { $0.isCompleted == false }
        )
        let plans = (try? modelContext.fetch(planDescriptor)) ?? []
        guard !plans.isEmpty else { return }

        let sessions = (try? modelContext.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        let calendar = Calendar.current

        for plan in plans {
            let dayStart = calendar.startOfDay(for: plan.date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

            let candidates = sessions.filter {
                $0.type == plan.workoutType && $0.date >= dayStart && $0.date < dayEnd
            }

            for session in candidates {
                var matched = false

                let importedMiles: Double
                switch session.type {
                case .running:       importedMiles = session.runningWorkout?.distanceMiles ?? 0
                case .crossTraining: importedMiles = session.crossTrainingWorkout?.distanceMiles ?? 0
                case .strength:      importedMiles = 0
                }

                if plan.plannedDistanceMiles > 0 && importedMiles > 0 {
                    if importedMiles >= plan.plannedDistanceMiles {
                        matched = true  // met or exceeded planned distance
                    } else {
                        let shortfall = (plan.plannedDistanceMiles - importedMiles) / plan.plannedDistanceMiles
                        if shortfall <= threshold { matched = true }
                    }
                }

                if !matched && plan.plannedDurationSeconds > 0 && session.durationSeconds > 0 {
                    if session.durationSeconds >= plan.plannedDurationSeconds {
                        matched = true  // met or exceeded planned duration
                    } else {
                        let shortfall = (Double(plan.plannedDurationSeconds) - Double(session.durationSeconds))
                            / Double(plan.plannedDurationSeconds)
                        if shortfall <= threshold { matched = true }
                    }
                }

                if matched {
                    plan.isCompleted = true
                    plan.completedByStravaActivityId = session.stravaActivityId ?? "manual_\(session.id.uuidString)"
                    break
                }
            }
        }
    }

    // MARK: - Copy Previous Week

    /// Returns true if the currently displayed week already has any planned workouts.
    func currentWeekHasWorkouts(from all: [PlannedWorkout]) -> Bool {
        !workoutsInCurrentWeek(from: all).isEmpty
    }

    /// Copies all planned workouts from the previous week into the current week.
    /// Shifts each date forward by 7 days. Resets completion state and calendar event ID.
    func copyPreviousWeek(from all: [PlannedWorkout], modelContext: ModelContext) {
        let prevStart = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: weekStart.startOfDay) ?? weekStart
        let prevEnd = weekStart.startOfDay

        let previousWeekWorkouts = all.filter { $0.date >= prevStart && $0.date < prevEnd }

        for source in previousWeekWorkouts {
            let newDate = Calendar.current.date(byAdding: .day, value: 7, to: source.date) ?? source.date
            let copy = PlannedWorkout(
                date: newDate,
                workoutType: source.workoutType,
                title: source.title,
                plannedDistanceMiles: source.plannedDistanceMiles,
                plannedDurationSeconds: source.plannedDurationSeconds,
                notes: source.notes,
                intensityLevel: source.intensityLevel
            )
            modelContext.insert(copy)
        }
    }

    // MARK: - Private

    static func currentWeekMonday() -> Date {
        var calendar = Calendar(identifier: .iso8601)
        calendar.locale = Locale.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
        return (calendar.date(from: components) ?? .now).startOfDay
    }
}
