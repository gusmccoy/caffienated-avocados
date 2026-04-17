// Views/Plan/PlanView.swift
// Weekly training plan tab — Mon through Sun with Apple Calendar integration.

import SwiftUI
import SwiftData

struct PlanView: View {
    @State private var vm = PlanViewModel()
    @State private var plannerVM = PlannerViewModel()
    private let calendarService = CalendarService()

    @Query(sort: [
        SortDescriptor(\PlannedWorkout.date, order: .forward),
        SortDescriptor(\PlannedWorkout.displayOrder, order: .forward)
    ])
    private var allPlannedRaw: [PlannedWorkout]

    /// Personal plan: excludes workouts the coach created for athletes (those have
    /// createdByPlannerRelationshipId set). Synced coach workouts on the athlete's
    /// device intentionally leave that field nil, so they pass through.
    private var allPlanned: [PlannedWorkout] {
        allPlannedRaw.filter { $0.createdByPlannerRelationshipId == nil }
    }

    @Query(sort: \Race.date, order: .forward)
    private var allRaces: [Race]

    @Query(sort: \PlannerRelationship.createdAt, order: .forward)
    private var allRelationships: [PlannerRelationship]

    /// Accepted relationships where the current user is the athlete (used for sync).
    private var acceptedCoachRelationships: [PlannerRelationship] {
        allRelationships.filter { $0.currentUserIsAthlete && $0.status == .accepted }
    }

    @State private var showingAddRace = false
    @State private var editingRace: Race? = nil
    @State private var showingCopyConfirmation = false
    @State private var showingRouteLibrary = false
    @State private var showingTemplateLibrary = false

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
                    WeekMileageCard(miles: vm.totalPlannedMiles(from: weekWorkouts) + weekRaceMiles)

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
                    Button { showingTemplateLibrary = true } label: {
                        Label("Workout Templates", systemImage: "doc.text")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button { showingRouteLibrary = true } label: {
                        Label("Route Library", systemImage: "map")
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
                AddRaceView(calendarService: calendarService)
            }
            .sheet(item: $editingRace) { race in
                AddRaceView(editingRace: race, calendarService: calendarService)
            }
            .sheet(isPresented: $showingRouteLibrary) {
                RoutesView()
            }
            .sheet(isPresented: $showingTemplateLibrary) {
                TemplateLibraryView()
            }
            .task {
                for relationship in acceptedCoachRelationships {
                    await plannerVM.syncCoachWorkouts(forRelationship: relationship, modelContext: modelContext)
                }
            }
        }
    }

    private var weekWorkouts: [PlannedWorkout] {
        vm.workoutsInCurrentWeek(from: allPlanned)
    }

    private var weekRaceMiles: Double {
        let start = vm.weekStart.startOfDay
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? start
        return allRaces
            .filter { $0.date >= start && $0.date < end }
            .reduce(0) { $0 + $1.distanceMiles }
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
        if let id = race.calendarEventIdentifier {
            Task { try? await calendarService.deleteEvent(identifier: id) }
        }
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

struct WeekNavigationHeader: View {
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

struct WeekMileageCard: View {
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
                ForEach(Array(workouts.enumerated()), id: \.element.id) { index, workout in
                    InteractivePlannedWorkoutRow(
                        workout: workout,
                        index: index,
                        allWorkouts: workouts,
                        vm: vm,
                        onDelete: { deleteWorkout($0) },
                        onReorder: { moved, target, workouts in
                            reorderWorkouts(movedWorkout: moved, targetIndex: target, from: workouts)
                        }
                    )
                }
            }
        }
        .cardStyle()
    }

    private func deleteWorkout(_ workout: PlannedWorkout) {
        // Prevent re-sync of coach-assigned workouts the athlete explicitly removed
        if let ckId = workout.coachAssignmentId {
            var dismissed = UserDefaults.standard.stringArray(forKey: "dismissedCoachAssignments") ?? []
            dismissed.append(ckId)
            UserDefaults.standard.set(dismissed, forKey: "dismissedCoachAssignments")
        }
        let identifier = workout.calendarEventIdentifier
        modelContext.delete(workout)
        if let id = identifier {
            Task {
                try? await calendarService.deleteEvent(identifier: id)
            }
        }
    }

    private func reorderWorkouts(movedWorkout: PlannedWorkout, targetIndex: Int, from workouts: [PlannedWorkout]) {
        var updatedWorkouts = workouts

        // Remove the moved workout from its current position
        if let currentIndex = updatedWorkouts.firstIndex(where: { $0.id == movedWorkout.id }) {
            updatedWorkouts.remove(at: currentIndex)
        }

        // Insert at the target position
        let insertIndex = min(targetIndex, updatedWorkouts.count)
        updatedWorkouts.insert(movedWorkout, at: insertIndex)

        // Update displayOrder for all workouts
        for (index, workout) in updatedWorkouts.enumerated() {
            workout.displayOrder = index
        }
    }
}

// MARK: - Interactive Planned Workout Row

private struct InteractivePlannedWorkoutRow: View {
    let workout: PlannedWorkout
    let index: Int
    let allWorkouts: [PlannedWorkout]
    var vm: PlanViewModel
    let onDelete: (PlannedWorkout) -> Void
    let onReorder: (PlannedWorkout, Int, [PlannedWorkout]) -> Void
    
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        PlannedWorkoutRow(workout: workout)
            .draggable(workout)
            .dropDestination(for: PlannedWorkout.self) { droppedWorkouts, _ in
                handleDrop(droppedWorkouts: droppedWorkouts)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                trailingSwipeActions
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                leadingSwipeActions
            }
            .contextMenu {
                contextMenuContent
            }
    }
    
    private func handleDrop(droppedWorkouts: [PlannedWorkout]) -> Bool {
        guard let droppedWorkout = droppedWorkouts.first else { return false }
        
        onReorder(droppedWorkout, index, allWorkouts)
        return true
    }
    
    @ViewBuilder
    private var trailingSwipeActions: some View {
        // Delete: athletes cannot delete coach-created workouts
        if !workout.isCoachCreated {
            Button(role: .destructive) {
                onDelete(workout)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    @ViewBuilder
    private var leadingSwipeActions: some View {
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
        
        // Edit: athletes cannot edit coach-created workouts
        if !workout.isCompleted && !workout.isCoachCreated {
            Button {
                vm.openEditSheet(for: workout)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }
    
    @ViewBuilder
    private var contextMenuContent: some View {
        if !workout.isCompleted {
            // Edit blocked for coach-created workouts
            if !workout.isCoachCreated {
                Button {
                    vm.openEditSheet(for: workout)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
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
        
        // Delete blocked for coach-created workouts
        if !workout.isCoachCreated {
            Button(role: .destructive) {
                onDelete(workout)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Planned Workout Row

struct PlannedWorkoutRow: View {
    let workout: PlannedWorkout
    @AppStorage("distanceUnit") private var distanceUnit: String = DistanceUnit.miles.rawValue
    @AppStorage("defaultPaceSecondsPerMile") private var defaultPaceSecondsPerMile: Int = 0

    /// Estimated distance from default pace when no distance is set but duration is.
    private var estimatedDistanceMiles: Double? {
        guard workout.workoutType == .running,
              workout.plannedDistanceMiles == 0,
              workout.plannedDurationSeconds > 0,
              defaultPaceSecondsPerMile > 0 else { return nil }
        return Double(workout.plannedDurationSeconds) / Double(defaultPaceSecondsPerMile)
    }

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
                    // Coach badge — uses plannerDisplayName (set on both coach's device
                    // and athlete's device via CK sync) instead of isCoachCreated which
                    // is false for synced workouts on the athlete's device.
                    if workout.plannerDisplayName != nil {
                        HStack(spacing: 3) {
                            Image(systemName: "person.badge.shield.checkmark.fill")
                                .font(.system(size: 8))
                            Text(workout.plannerDisplayName ?? "Coach")
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(.purple)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.purple.opacity(0.10), in: Capsule())
                    }
                    // Post-run strides badge (runs only)
                    if workout.workoutType == .running && workout.postRunStrides && !workout.isCompleted {
                        Text("w/ strides")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15), in: Capsule())
                            .foregroundStyle(.orange)
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

                    if workout.workoutType == .running && workout.runCategory != .none {
                        Text(workout.runCategory.rawValue)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.12), in: Capsule())
                            .foregroundStyle(Color.green)
                    }

                    if workout.plannedDistanceMiles > 0 {
                        HStack(spacing: 2) {
                            if workout.workoutType == .running && workout.distanceIsFromSegments {
                                Image(systemName: "sum")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.tertiary)
                            }
                            Text(distanceText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if let est = estimatedDistanceMiles {
                        Text("~\(formattedEstimate(est))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .italic()
                    }

                    if workout.plannedDurationSeconds > 0 {
                        Text(formattedDuration)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Run segments summary
                if workout.workoutType == .running && !workout.runSegments.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(workout.runSegments) { seg in
                            HStack(spacing: 5) {
                                Image(systemName: seg.segmentType.systemImage)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                Text(seg.segmentType.rawValue)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                let summary = seg.summaryLabel
                                if !summary.isEmpty {
                                    Text("· \(summary)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                    .padding(.top, 2)
                }

                // Route preview
                if workout.workoutType == .running && workout.hasRoute {
                    RoutePreviewMap(polyline: workout.routePolyline, height: 100)
                        .padding(.top, 4)
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

    private func formattedEstimate(_ miles: Double) -> String {
        if distanceUnit == DistanceUnit.kilometers.rawValue {
            return String(format: "%.2f km", miles.milesToKm)
        }
        return String(format: "%.2f mi", miles)
    }
}
