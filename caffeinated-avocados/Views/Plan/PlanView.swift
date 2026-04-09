// Views/Plan/PlanView.swift
// Weekly training plan tab — Mon through Sun with Apple Calendar integration.

import SwiftUI
import SwiftData

struct PlanView: View {
    @State private var vm = PlanViewModel()
    private let calendarService = CalendarService()

    @Query(sort: \PlannedWorkout.date, order: .forward)
    private var allPlanned: [PlannedWorkout]

    @Query(sort: \Race.date, order: .forward)
    private var allRaces: [Race]

    @State private var showingAddRace = false
    @State private var editingRace: Race? = nil
    @State private var showingCopyConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Sunday planning prompt (only when next week has no workouts)
                    if shouldShowPlanningBanner {
                        PlanningReminderBanner {
                            let nextMonday = Calendar.current.date(byAdding: .day, value: 1, to: Date.now.startOfDay)!
                            vm.weekStart = nextMonday
                        }
                    }

                    // Next upcoming race banner (if any)
                    if let next = nextUpcomingRace {
                        NextRaceBanner(race: next)
                    }

                    WeekNavigationHeader(vm: vm)
                    WeekMileageCard(miles: vm.totalPlannedMiles(from: weekWorkouts))

                    ForEach(vm.weekDays, id: \.self) { day in
                        DaySection(
                            day: day,
                            workouts: vm.workouts(for: day, from: allPlanned),
                            races: racesOnDay(day),
                            vm: vm,
                            calendarService: calendarService
                        )
                    }

                    // All races section
                    RacesSectionView(
                        races: allRaces,
                        onAdd: { showingAddRace = true },
                        onEdit: { editingRace = $0 },
                        onDelete: deleteRace
                    )
                }
                .padding()
            }
            .navigationTitle("Training Plan")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAddRace = true } label: {
                        Label("Add Race", systemImage: "flag.checkered")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        vm.rematchAllPlannedWorkouts(modelContext: modelContext)
                    } label: {
                        Label("Re-match Activities", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        if vm.currentWeekHasWorkouts(from: allPlanned) {
                            showingCopyConfirmation = true
                        } else {
                            vm.copyPreviousWeek(from: allPlanned, modelContext: modelContext)
                        }
                    } label: {
                        Label("Copy Last Week", systemImage: "doc.on.doc")
                    }
                }
            }
            .confirmationDialog(
                "This week already has workouts. Copy last week's plan anyway?",
                isPresented: $showingCopyConfirmation,
                titleVisibility: .visible
            ) {
                Button("Copy Last Week") {
                    vm.copyPreviousWeek(from: allPlanned, modelContext: modelContext)
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $vm.isShowingAddSheet) {
                AddPlannedWorkoutView(vm: vm, calendarService: calendarService)
            }
            .sheet(isPresented: $showingAddRace) {
                AddRaceView()
            }
            .sheet(item: $editingRace) { race in
                AddRaceView(editingRace: race)
            }
        }
    }

    private var weekWorkouts: [PlannedWorkout] {
        vm.workoutsInCurrentWeek(from: allPlanned)
    }

    private var shouldShowPlanningBanner: Bool {
        let weekday = Calendar.current.component(.weekday, from: .now)
        guard weekday == 1 else { return false } // 1 = Sunday
        let nextMonday = Calendar.current.date(byAdding: .day, value: 1, to: Date.now.startOfDay)!
        let weekAfter  = Calendar.current.date(byAdding: .day, value: 8, to: Date.now.startOfDay)!
        return !allPlanned.contains { $0.date >= nextMonday && $0.date < weekAfter }
    }

    private var nextUpcomingRace: Race? {
        allRaces.first { !$0.isPast }
    }

    private func racesOnDay(_ day: Date) -> [Race] {
        let target = day.startOfDay
        return allRaces.filter { Calendar.current.startOfDay(for: $0.date) == target }
    }

    @Environment(\.modelContext) private var modelContext

    private func deleteRace(_ race: Race) {
        modelContext.delete(race)
    }
}

// MARK: - Planning Reminder Banner

private struct PlanningReminderBanner: View {
    let onPlanNextWeek: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Plan Next Week")
                    .font(.subheadline.weight(.semibold))
                Text("No workouts scheduled yet for next week.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Plan", action: onPlanNextWeek)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.orange, in: Capsule())
                .foregroundStyle(.white)
        }
        .cardStyle()
    }
}

// MARK: - Next Race Banner

private struct NextRaceBanner: View {
    let race: Race

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "flag.checkered")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(race.name)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    Text(race.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(race.raceDistance.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(race.countdownLabel)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.orange)
                if let goal = race.goalTimeSeconds {
                    Text(formattedGoal(goal))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .cardStyle()
    }

    private func formattedGoal(_ secs: Int) -> String {
        let h = secs / 3600
        let m = (secs % 3600) / 60
        let s = secs % 60
        if h > 0 { return String(format: "Goal %d:%02d:%02d", h, m, s) }
        return String(format: "Goal %d:%02d", m, s)
    }
}

// MARK: - Races Section

private struct RacesSectionView: View {
    let races: [Race]
    let onAdd: () -> Void
    let onEdit: (Race) -> Void
    let onDelete: (Race) -> Void

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Label("Races", systemImage: "flag.checkered")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                if races.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "flag.checkered")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("No races added yet")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button("Add Your First Race", action: onAdd)
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                        }
                        .padding(.vertical, 8)
                        Spacer()
                    }
                } else {
                    ForEach(races) { race in
                        RaceRow(race: race)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { onDelete(race) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button { onEdit(race) } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                            .contextMenu {
                                Button { onEdit(race) } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button(role: .destructive) { onDelete(race) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }

                    Button(action: onAdd) {
                        Label("Add Race", systemImage: "plus.circle")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .cardStyle()
    }
}

private struct RaceRow: View {
    let race: Race
    @AppStorage("distanceUnit") private var distanceUnit: String = DistanceUnit.miles.rawValue

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: race.isPast ? "flag.checkered" : "flag.checkered.2.crossed")
                .foregroundStyle(race.isPast ? Color.secondary : Color.orange)
                .frame(width: 32, height: 32)
                .background(
                    (race.isPast ? Color.secondary : Color.orange).opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 8)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(race.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(race.isPast ? .secondary : .primary)

                HStack(spacing: 6) {
                    Text(race.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(distanceLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let loc = race.location.isEmpty ? nil : race.location {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(loc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(race.countdownLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(race.isPast ? Color.secondary : Color.orange)
                if let goal = race.goalTimeSeconds {
                    Text(formattedGoal(goal))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var distanceLabel: String {
        if race.raceDistance == .custom {
            if distanceUnit == DistanceUnit.kilometers.rawValue {
                return String(format: "%.1f km", race.distanceMiles.milesToKm)
            }
            return String(format: "%.1f mi", race.distanceMiles)
        }
        return race.raceDistance.rawValue
    }

    private func formattedGoal(_ secs: Int) -> String {
        let h = secs / 3600
        let m = (secs % 3600) / 60
        let s = secs % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Week Navigation Header

private struct WeekNavigationHeader: View {
    var vm: PlanViewModel

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Button {
                    vm.goToPreviousWeek()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.orange)
                }

                Spacer()

                Text(vm.weekLabel)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button {
                    vm.goToNextWeek()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }

            if !vm.isCurrentWeek {
                Button("Today") { vm.goToCurrentWeek() }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
            }
        }
    }
}

// MARK: - Week Mileage Card

private struct WeekMileageCard: View {
    let miles: Double
    @AppStorage("distanceUnit") private var distanceUnit: String = DistanceUnit.miles.rawValue

    private var displayValue: String {
        if distanceUnit == DistanceUnit.kilometers.rawValue {
            return String(format: "%.1f km planned", miles.milesToKm)
        }
        return String(format: "%.1f mi planned", miles)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.run")
                .font(.title2)
                .foregroundStyle(.orange)
            Text(displayValue)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.orange)
            Spacer()
        }
        .cardStyle()
    }
}

// MARK: - Day Section

private struct DaySection: View {
    let day: Date
    let workouts: [PlannedWorkout]
    let races: [Race]
    var vm: PlanViewModel
    let calendarService: CalendarService
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.formatted(.dateTime.weekday(.wide)))
                        .font(.headline)
                    Text(day.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    vm.openAddSheet(for: day)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                }
            }

            // Race indicator for this day
            ForEach(races) { race in
                HStack(spacing: 8) {
                    Image(systemName: "flag.checkered")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text(race.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(race.raceDistance.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            if workouts.isEmpty && races.isEmpty {
                Text("Rest day")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 2)
            } else {
                ForEach(workouts) { workout in
                    PlannedWorkoutRow(workout: workout)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteWorkout(workout)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if !workout.isCompleted {
                                Button {
                                    vm.markPlanComplete(workout, modelContext: modelContext)
                                } label: {
                                    Label("Mark Done", systemImage: "checkmark.circle.fill")
                                }
                                .tint(.green)
                            } else if workout.completedByStravaActivityId?.hasPrefix("manual_") == true {
                                Button {
                                    vm.unmarkPlanComplete(workout, modelContext: modelContext)
                                } label: {
                                    Label("Unmark", systemImage: "xmark.circle")
                                }
                                .tint(.orange)
                            }
                            if !workout.isCompleted {
                                Button {
                                    vm.openEditSheet(for: workout)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                        .contextMenu {
                            if !workout.isCompleted {
                                Button {
                                    vm.openEditSheet(for: workout)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button {
                                    vm.markPlanComplete(workout, modelContext: modelContext)
                                } label: {
                                    Label("Mark as Done", systemImage: "checkmark.circle.fill")
                                }
                            } else if workout.completedByStravaActivityId?.hasPrefix("manual_") == true {
                                Button {
                                    vm.unmarkPlanComplete(workout, modelContext: modelContext)
                                } label: {
                                    Label("Unmark as Done", systemImage: "xmark.circle")
                                }
                            }
                            Button(role: .destructive) {
                                deleteWorkout(workout)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .cardStyle()
    }

    private func deleteWorkout(_ workout: PlannedWorkout) {
        let identifier = workout.calendarEventIdentifier
        modelContext.delete(workout)
        if let id = identifier {
            Task {
                try? await calendarService.deleteEvent(identifier: id)
            }
        }
    }
}

// MARK: - Planned Workout Row

private struct PlannedWorkoutRow: View {
    let workout: PlannedWorkout
    @AppStorage("distanceUnit") private var distanceUnit: String = DistanceUnit.miles.rawValue

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: rowIcon)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(typeColor.opacity(workout.isCompleted ? 0.5 : 1), in: RoundedRectangle(cornerRadius: 8))

                if workout.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.green)
                        .background(Color.white, in: Circle())
                        .offset(x: 5, y: 5)
                }
            }
            .padding(.bottom, workout.isCompleted ? 4 : 0)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(workout.title)
                        .font(.subheadline.weight(.medium))
                        .strikethrough(workout.isCompleted, color: .secondary)
                    if workout.isCompleted {
                        let isManual = workout.completedByStravaActivityId?.hasPrefix("manual_") == true
                        Text(isManual ? "Done (manual)" : "Completed")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.12), in: Capsule())
                    }
                }

                HStack(spacing: 8) {
                    if !workout.isCompleted {
                        Text(workout.intensityLevel.rawValue)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.intensityColor(workout.intensityLevel).opacity(0.15),
                                        in: Capsule())
                            .foregroundStyle(Color.intensityColor(workout.intensityLevel))
                    }

                    if workout.workoutType == .crossTraining {
                        Text(workout.crossTrainingActivityType.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if workout.plannedDistanceMiles > 0 {
                        Text(distanceText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if workout.plannedDurationSeconds > 0 {
                        Text(formattedDuration)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if workout.calendarEventIdentifier != nil && !workout.isCompleted {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var rowIcon: String {
        if workout.workoutType == .crossTraining {
            return workout.crossTrainingActivityType.systemImage
        }
        return workout.workoutType.systemImage
    }

    private var typeColor: Color {
        switch workout.workoutType {
        case .running:       return .green
        case .strength:      return .orange
        case .crossTraining: return .blue
        }
    }

    private var distanceText: String {
        if distanceUnit == DistanceUnit.kilometers.rawValue {
            return String(format: "%.2f km", workout.plannedDistanceMiles.milesToKm)
        }
        return String(format: "%.2f mi", workout.plannedDistanceMiles)
    }

    private var formattedDuration: String {
        let s = workout.plannedDurationSeconds
        let h = s / 3600
        let m = (s % 3600) / 60
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        return String(format: "%dm", m)
    }
}
