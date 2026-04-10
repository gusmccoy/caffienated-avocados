// Views/Athletes/AthletesView.swift
// Shown as the "Athletes" tab for users who are acting as a planner/coach for someone.
// Lists each athlete they have access to; tapping one opens that athlete's training plan
// where the planner can add, edit, and remove planned workouts on the athlete's behalf.

import SwiftUI
import SwiftData

// MARK: - Athletes Tab Root

struct AthletesView: View {
    @Query private var allRelationships: [PlannerRelationship]

    private var coachingRelationships: [PlannerRelationship] {
        allRelationships.filter { !$0.currentUserIsAthlete && $0.status == .accepted }
    }

    var body: some View {
        NavigationStack {
            Group {
                if coachingRelationships.isEmpty {
                    emptyState
                } else {
                    List(coachingRelationships) { relationship in
                        NavigationLink {
                            AthletePlanView(relationship: relationship)
                        } label: {
                            AthleteRow(relationship: relationship)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Athletes")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Athletes Yet")
                .font(.title3.weight(.semibold))
            Text("Ask an athlete to invite you from their Settings tab, then enter their code in your Settings to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Athlete Row

private struct AthleteRow: View {
    let relationship: PlannerRelationship

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "person.crop.circle.fill")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 3) {
                Text(relationship.athleteDisplayName)
                    .font(.subheadline.weight(.semibold))
                Text("Coaching since \(relationship.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Athlete Plan View (planner's view of one athlete's plan)

struct AthletePlanView: View {
    let relationship: PlannerRelationship

    @State private var vm = PlanViewModel()
    private let calendarService = CalendarService()

    @Query(sort: \PlannedWorkout.date, order: .forward)
    private var allPlanned: [PlannedWorkout]

    @Query(sort: \Race.date, order: .forward)
    private var allRaces: [Race]

    @State private var showingAddRace = false
    @State private var editingRace: Race? = nil

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                coachBanner

                WeekNavigationHeader(vm: vm)
                WeekMileageCard(miles: vm.totalPlannedMiles(from: weekWorkouts))

                ForEach(vm.weekDays, id: \.self) { day in
                    AthleteDaySection(
                        day: day,
                        workouts: vm.workouts(for: day, from: allPlanned),
                        races: racesOnDay(day),
                        vm: vm,
                        relationship: relationship,
                        calendarService: calendarService
                    )
                }
            }
            .padding()
        }
        .navigationTitle("\(relationship.athleteDisplayName)'s Plan")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddRace = true } label: {
                    Label("Add Race", systemImage: "flag.checkered")
                }
            }
        }
        .sheet(isPresented: $vm.isShowingAddSheet) {
            // Wrap the standard add-sheet but tag new workouts with the planner relationship
            CoachAddPlannedWorkoutView(vm: vm, relationship: relationship, calendarService: calendarService)
        }
        .sheet(isPresented: $showingAddRace) {
            AddRaceView()
        }
        .sheet(item: $editingRace) { race in
            AddRaceView(editingRace: race)
        }
    }

    private var weekWorkouts: [PlannedWorkout] {
        vm.workoutsInCurrentWeek(from: allPlanned)
    }

    private func racesOnDay(_ day: Date) -> [Race] {
        let target = day.startOfDay
        return allRaces.filter { Calendar.current.startOfDay(for: $0.date) == target }
    }

    private var coachBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.badge.shield.checkmark.fill")
                .font(.title3)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Editing as Coach")
                    .font(.subheadline.weight(.semibold))
                Text("Activities you add are marked as coach-created and cannot be edited or deleted by the athlete.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Athlete Day Section (planner has full edit/delete access)

private struct AthleteDaySection: View {
    let day: Date
    let workouts: [PlannedWorkout]
    let races: [Race]
    var vm: PlanViewModel
    let relationship: PlannerRelationship
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

            ForEach(races) { race in
                HStack(spacing: 8) {
                    Image(systemName: "flag.checkered").foregroundStyle(.orange).font(.caption)
                    Text(race.name).font(.caption.weight(.semibold)).foregroundStyle(.orange)
                    Text("·").foregroundStyle(.secondary)
                    Text(race.raceDistance.rawValue).font(.caption).foregroundStyle(.secondary)
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
                        // Planner can delete any workout in this athlete's plan
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) { deleteWorkout(workout) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        // Planner can edit any non-completed workout
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if !workout.isCompleted {
                                Button { vm.openEditSheet(for: workout) } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                        .contextMenu {
                            if !workout.isCompleted {
                                Button { vm.openEditSheet(for: workout) } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                            }
                            Button(role: .destructive) { deleteWorkout(workout) } label: {
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
            Task { try? await calendarService.deleteEvent(identifier: id) }
        }
    }
}

// MARK: - Coach Add/Edit Planned Workout Sheet
//
// Mirrors AddPlannedWorkoutView but tags newly created workouts with the planner relationship.
// For edits it preserves the existing attribution.

struct CoachAddPlannedWorkoutView: View {
    @Bindable var vm: PlanViewModel
    let relationship: PlannerRelationship
    let calendarService: CalendarService

    @Environment(\.modelContext) private var modelContext

    @State private var addingSegment = false
    @State private var editingSegmentIndex: Int? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout Type") {
                    Picker("Type", selection: $vm.formType) {
                        ForEach(WorkoutType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.systemImage).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                if vm.formType == .crossTraining {
                    Section("Activity Type") {
                        Picker("Activity", selection: $vm.formCrossTrainingActivityType) {
                            ForEach(CrossTrainingActivityType.allCases, id: \.self) { type in
                                Label(type.rawValue, systemImage: type.systemImage).tag(type)
                            }
                        }
                    }
                }

                if vm.formType == .running {
                    Section("Run Type") {
                        Picker("Category", selection: $vm.formRunCategory) {
                            ForEach(RunCategory.allCases, id: \.self) { cat in
                                Text(cat == .none ? "Unspecified" : cat.rawValue).tag(cat)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Section {
                        ForEach(vm.formRunSegments.indices, id: \.self) { i in
                            Button { editingSegmentIndex = i } label: {
                                CoachSegmentRow(segment: vm.formRunSegments[i])
                            }
                            .foregroundStyle(.primary)
                        }
                        .onDelete { vm.formRunSegments.remove(atOffsets: $0) }
                        .onMove { vm.formRunSegments.move(fromOffsets: $0, toOffset: $1) }
                        Button { addingSegment = true } label: {
                            Label("Add Segment", systemImage: "plus.circle")
                        }
                    } header: {
                        HStack {
                            Text("Segments")
                            Spacer()
                            #if !os(macOS)
                            if !vm.formRunSegments.isEmpty { EditButton().font(.caption) }
                            #endif
                        }
                    }
                }

                Section("Details") {
                    TextField("Title (optional)", text: $vm.formTitle)
                    Picker("Intensity", selection: $vm.formIntensity) {
                        ForEach(IntensityLevel.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                if vm.formShowsDistance {
                    let calc = vm.formCalculatedDistanceMiles
                    Section {
                        if vm.formType == .running && calc > 0 && !vm.formIsDistanceManuallySet {
                            HStack {
                                Text("Miles")
                                Spacer()
                                Text(String(format: "%.2f", calc)).foregroundStyle(.secondary)
                                Button("Override") {
                                    vm.formDistanceMiles = calc
                                    vm.formIsDistanceManuallySet = true
                                }
                                .font(.caption).buttonStyle(.bordered)
                            }
                        } else {
                            HStack {
                                Text("Miles")
                                Spacer()
                                TextField("0.00", value: $vm.formDistanceMiles, format: .number)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .onChange(of: vm.formDistanceMiles) { _, _ in
                                        if vm.formType == .running { vm.formIsDistanceManuallySet = true }
                                    }
                                if vm.formType == .running && calc > 0 && vm.formIsDistanceManuallySet {
                                    Button("Reset") {
                                        vm.formIsDistanceManuallySet = false
                                        vm.formDistanceMiles = 0
                                    }
                                    .font(.caption).buttonStyle(.bordered)
                                }
                            }
                        }
                    } header: {
                        Text("Total Distance (optional)")
                    }
                }

                Section("Total Duration (optional)") {
                    HStack {
                        DurationPicker(label: "h", value: $vm.formHours, range: 0...23)
                        DurationPicker(label: "m", value: $vm.formMinutes, range: 0...59)
                        DurationPicker(label: "s", value: $vm.formSeconds, range: 0...59)
                    }
                }

                Section("Notes") {
                    TextEditor(text: $vm.formNotes).frame(minHeight: 80)
                }
            }
            .navigationTitle(vm.isEditing ? "Edit Workout" : dateTitle)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { vm.resetForm() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(vm.isEditing ? "Update" : "Save") { save() }
                }
            }
            .sheet(isPresented: $addingSegment) {
                AddRunSegmentView { vm.formRunSegments.append($0) }
            }
            .sheet(item: $editingSegmentIndex) { idx in
                AddRunSegmentView(
                    existingSegment: vm.formRunSegments[idx],
                    onSave: { vm.formRunSegments[idx] = $0 },
                    onDelete: { vm.formRunSegments.remove(at: idx) }
                )
            }
        }
    }

    private var dateTitle: String {
        vm.sheetTargetDate.formatted(date: .complete, time: .omitted)
    }

    private var defaultTitle: String {
        if vm.formType == .crossTraining { return vm.formCrossTrainingActivityType.rawValue }
        if vm.formType == .running && vm.formRunCategory != .none { return vm.formRunCategory.rawValue }
        return vm.formType.rawValue
    }

    private func save() {
        if let existing = vm.editingWorkout {
            updateExisting(existing)
        } else {
            createNew()
        }
        vm.resetForm()
    }

    private func createNew() {
        let workout = PlannedWorkout(
            date: vm.sheetTargetDate,
            workoutType: vm.formType,
            title: vm.formTitle.isEmpty ? defaultTitle : vm.formTitle,
            plannedDistanceMiles: vm.formShowsDistance ? vm.formEffectiveDistanceMiles : 0,
            plannedDurationSeconds: vm.formDurationSeconds,
            crossTrainingActivityType: vm.formCrossTrainingActivityType,
            runCategory: vm.formRunCategory,
            runSegments: vm.formRunSegments,
            notes: vm.formNotes,
            intensityLevel: vm.formIntensity,
            createdByPlannerRelationshipId: relationship.id.uuidString,
            plannerDisplayName: relationship.plannerDisplayName
        )
        modelContext.insert(workout)
    }

    private func updateExisting(_ workout: PlannedWorkout) {
        let oldEventId = workout.calendarEventIdentifier
        workout.workoutType = vm.formType
        workout.title = vm.formTitle.isEmpty ? defaultTitle : vm.formTitle
        workout.plannedDistanceMiles = vm.formShowsDistance ? vm.formEffectiveDistanceMiles : 0
        workout.plannedDurationSeconds = vm.formDurationSeconds
        workout.crossTrainingActivityType = vm.formCrossTrainingActivityType
        workout.runCategory = vm.formRunCategory
        workout.runSegments = vm.formRunSegments
        workout.notes = vm.formNotes
        workout.intensityLevel = vm.formIntensity
        // Preserve coach attribution — do not strip it on edit
        if workout.createdByPlannerRelationshipId == nil {
            workout.createdByPlannerRelationshipId = relationship.id.uuidString
            workout.plannerDisplayName = relationship.plannerDisplayName
        }
        Task { @MainActor in
            if let id = oldEventId { try? await calendarService.deleteEvent(identifier: id) }
        }
    }
}

// MARK: - Segment Row (local to this file)

private struct CoachSegmentRow: View {
    let segment: PlannedRunSegment
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: segment.segmentType.systemImage)
                .font(.caption)
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Color.green.opacity(0.8), in: RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 1) {
                Text(segment.segmentType.rawValue).font(.subheadline.weight(.medium))
                let summary = segment.summaryLabel
                if !summary.isEmpty { Text(summary).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
        }
    }
}
