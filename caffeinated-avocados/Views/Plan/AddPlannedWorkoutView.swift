// Views/Plan/AddPlannedWorkoutView.swift
// Sheet for adding a new planned workout to a specific day.

import SwiftUI
import SwiftData

struct AddPlannedWorkoutView: View {
    @Bindable var vm: PlanViewModel
    let calendarService: CalendarService
    @Environment(\.modelContext) private var modelContext

    @State private var addingSegment = false
    @State private var editingSegmentIndex: Int? = nil
    @State private var showingFuelPlan = false
    @State private var localFuelPlan: FuelPlan? = nil
    @State private var showingRoutePlanner = false
    @State private var showingTemplatePicker = false
    @State private var showingSaveAsTemplate = false
    @State private var newTemplateName = ""

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Workout Type
                Section("Workout Type") {
                    Picker("Type", selection: $vm.formType) {
                        ForEach(WorkoutType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.systemImage).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                // MARK: Strength Type
                if vm.formType == .strength {
                    Section("Strength Type") {
                        Picker("Type", selection: $vm.formStrengthType) {
                            ForEach(StrengthType.allCases, id: \.self) { type in
                                Text(type == .unspecified ? "Unspecified" : type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                // MARK: Cross-Training Activity Type
                if vm.formType == .crossTraining {
                    Section("Activity Type") {
                        Picker("Activity", selection: $vm.formCrossTrainingActivityType) {
                            ForEach(CrossTrainingActivityType.allCases, id: \.self) { type in
                                Label(type.rawValue, systemImage: type.systemImage).tag(type)
                            }
                        }
                    }
                }

                // MARK: Run Category + Segments
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
                            Button {
                                editingSegmentIndex = i
                            } label: {
                                SegmentRow(segment: vm.formRunSegments[i])
                            }
                            .foregroundStyle(.primary)
                        }
                        .onDelete { vm.formRunSegments.remove(atOffsets: $0) }
                        .onMove { vm.formRunSegments.move(fromOffsets: $0, toOffset: $1) }

                        Button {
                            addingSegment = true
                        } label: {
                            Label("Add Segment", systemImage: "plus.circle")
                        }

                        Toggle("Post Run Strides", isOn: $vm.formPostRunStrides)
                    } header: {
                        HStack {
                            Text("Segments")
                            Spacer()
                            #if !os(macOS)
                            if !vm.formRunSegments.isEmpty {
                                EditButton().font(.caption)
                            }
                            #endif
                        }
                    } footer: {
                        if vm.formRunSegments.isEmpty {
                            Text("Break this run into structured parts — warm-up, tempo, repeats, cooldown, etc.")
                        }
                    }
                }

                // MARK: Route
                if vm.formType == .running {
                    Section {
                        if vm.formRouteWaypoints.count >= 2 {
                            RoutePreviewMap(polyline: vm.formRoutePolyline, height: 160)
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                            HStack {
                                Label(
                                    String(format: "%.2f mi route", vm.formRouteDistanceMiles),
                                    systemImage: "map"
                                )
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                                Spacer()

                                Button("Edit") {
                                    showingRoutePlanner = true
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)

                                Button("Remove", role: .destructive) {
                                    vm.formRouteWaypoints = []
                                    vm.formRoutePolyline = []
                                    vm.formRouteDistanceMiles = 0
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
                            }
                        } else {
                            Button {
                                showingRoutePlanner = true
                            } label: {
                                Label("Plan Route on Map", systemImage: "map")
                            }
                        }
                    } header: {
                        Text("Route")
                    } footer: {
                        if vm.formRouteWaypoints.isEmpty {
                            Text("Tap to draw a running route on Apple Maps. Distance will be calculated automatically.")
                        }
                    }
                }

                // MARK: Details
                Section("Details") {
                    TextField("Title (optional)", text: $vm.formTitle)
                    Picker("Intensity", selection: $vm.formIntensity) {
                        ForEach(IntensityLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // MARK: Planned Time
                Section {
                    Toggle("Set a planned time", isOn: $vm.formPlannedTimeEnabled)
                    if vm.formPlannedTimeEnabled {
                        DatePicker(
                            "Time",
                            selection: plannedTimeBinding,
                            displayedComponents: .hourAndMinute
                        )
                    }
                } footer: {
                    if !vm.formPlannedTimeEnabled {
                        Text("Optionally set a specific time this workout is planned for. Defaults to your configured time in Settings.")
                    }
                }

                // MARK: Distance
                if vm.formShowsDistance {
                    let calc = vm.formCalculatedDistanceMiles
                    Section {
                        if vm.formType == .running && calc > 0 && !vm.formIsDistanceManuallySet {
                            // Auto-calculated from segments — show read-only with override affordance
                            HStack {
                                Text("Miles")
                                Spacer()
                                Text(String(format: "%.2f", calc))
                                    .foregroundStyle(.secondary)
                                Button("Override") {
                                    vm.formDistanceMiles = calc
                                    vm.formIsDistanceManuallySet = true
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
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
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    } header: {
                        Text("Total Distance (optional)")
                    } footer: {
                        if vm.formType == .running {
                            if calc > 0 && !vm.formIsDistanceManuallySet {
                                Text("Calculated from segments.")
                            } else if calc > 0 && vm.formIsDistanceManuallySet {
                                Text(String(format: "Manually set — segments total %.2f mi.", calc))
                            }
                        }
                    }
                }

                // MARK: Duration
                Section("Total Duration (optional)") {
                    HStack {
                        DurationPicker(label: "h", value: $vm.formHours, range: 0...23)
                        DurationPicker(label: "m", value: $vm.formMinutes, range: 0...59)
                        DurationPicker(label: "s", value: $vm.formSeconds, range: 0...59)
                    }
                }

                // MARK: Notes
                Section("Notes") {
                    TextEditor(text: $vm.formNotes)
                        .frame(minHeight: 80)
                }

                // MARK: Fuel Plan
                Section {
                    Button {
                        showingFuelPlan = true
                    } label: {
                        HStack {
                            Label("Fuel Plan", systemImage: "fork.knife")
                            Spacer()
                            if localFuelPlan?.hasContent == true {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Text("Set Up")
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                            }
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    .foregroundStyle(.primary)
                } footer: {
                    Text("Plan pre-, mid-, and post-workout nutrition and hydration.")
                }

                // MARK: Calendar Warning
                if vm.calendarAuthorizationDenied {
                    Section {
                        Label {
                            Text("Calendar access denied. Enable it in Settings to create events.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }
                    }
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
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        showingTemplatePicker = true
                    } label: {
                        Label("Load Template", systemImage: "doc.text")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        newTemplateName = vm.formTitle.isEmpty ? vm.formType.rawValue : vm.formTitle
                        showingSaveAsTemplate = true
                    } label: {
                        Label("Save as Template", systemImage: "square.and.arrow.down")
                    }
                }
            }
            // Add new segment
            .sheet(isPresented: $addingSegment) {
                AddRunSegmentView { newSegment in
                    vm.formRunSegments.append(newSegment)
                }
            }
            // Edit existing segment
            .sheet(item: $editingSegmentIndex) { idx in
                AddRunSegmentView(
                    existingSegment: vm.formRunSegments[idx],
                    onSave: { vm.formRunSegments[idx] = $0 },
                    onDelete: { vm.formRunSegments.remove(at: idx) }
                )
            }
            // Route planner
            #if os(macOS)
            .sheet(isPresented: $showingRoutePlanner) {
                RoutePlannerView(
                    existingWaypoints: vm.formRouteWaypoints,
                    existingPolyline: vm.formRoutePolyline,
                    existingDistanceMiles: vm.formRouteDistanceMiles,
                    onSave: { waypoints, polyline, miles in
                        vm.formRouteWaypoints = waypoints
                        vm.formRoutePolyline = polyline
                        vm.formRouteDistanceMiles = miles
                        // Auto-populate distance from route if not manually set and no segments
                        if !vm.formIsDistanceManuallySet && vm.formRunSegments.isEmpty && miles > 0 {
                            vm.formDistanceMiles = miles
                        }
                    },
                    onClear: {
                        vm.formRouteWaypoints = []
                        vm.formRoutePolyline = []
                        vm.formRouteDistanceMiles = 0
                    }
                )
            }
            #else
            .fullScreenCover(isPresented: $showingRoutePlanner) {
                RoutePlannerView(
                    existingWaypoints: vm.formRouteWaypoints,
                    existingPolyline: vm.formRoutePolyline,
                    existingDistanceMiles: vm.formRouteDistanceMiles,
                    onSave: { waypoints, polyline, miles in
                        vm.formRouteWaypoints = waypoints
                        vm.formRoutePolyline = polyline
                        vm.formRouteDistanceMiles = miles
                        // Auto-populate distance from route if not manually set and no segments
                        if !vm.formIsDistanceManuallySet && vm.formRunSegments.isEmpty && miles > 0 {
                            vm.formDistanceMiles = miles
                        }
                    },
                    onClear: {
                        vm.formRouteWaypoints = []
                        vm.formRoutePolyline = []
                        vm.formRouteDistanceMiles = 0
                    }
                )
            }
            #endif
            // Fuel plan editor
            .sheet(isPresented: $showingFuelPlan) {
                FuelPlanView(fuelPlan: localFuelPlan) { plan in
                    if localFuelPlan == nil {
                        modelContext.insert(plan)
                    }
                    localFuelPlan = plan
                }
            }
            .onAppear {
                localFuelPlan = vm.editingWorkout?.fuelPlan
            }
            // Template picker
            .sheet(isPresented: $showingTemplatePicker) {
                TemplateLibraryView { template in
                    vm.applyTemplate(template)
                }
            }
            // Save as template
            .alert("Save as Template", isPresented: $showingSaveAsTemplate) {
                TextField("Template name", text: $newTemplateName)
                Button("Save") {
                    vm.saveFormAsTemplate(name: newTemplateName, modelContext: modelContext)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Give this workout a name so you can reuse it later.")
            }
        }
    }

    // MARK: - Helpers

    /// Converts vm.formPlannedTimeMinutes ↔ a full Date (time component only) for DatePicker.
    private var plannedTimeBinding: Binding<Date> {
        Binding(
            get: {
                let mins = vm.formPlannedTimeMinutes
                return Calendar.current.date(
                    bySettingHour: mins / 60,
                    minute: mins % 60,
                    second: 0,
                    of: .now
                ) ?? .now
            },
            set: { date in
                let h = Calendar.current.component(.hour, from: date)
                let m = Calendar.current.component(.minute, from: date)
                vm.formPlannedTimeMinutes = h * 60 + m
            }
        )
    }

    private var dateTitle: String {
        vm.sheetTargetDate.formatted(date: .complete, time: .omitted)
    }

    private var defaultTitle: String {
        if vm.formType == .crossTraining {
            return vm.formCrossTrainingActivityType.rawValue
        }
        if vm.formType == .running && vm.formRunCategory != .none {
            return vm.formRunCategory.rawValue
        }
        return vm.formType.rawValue
    }

    private func save() {
        if let existing = vm.editingWorkout {
            update(existing)
        } else {
            create()
        }
        vm.resetForm()
    }

    private func create() {
        // Calculate displayOrder as the count of existing workouts on this day
        let dayStart = vm.sheetTargetDate.startOfDay
        let descriptor = FetchDescriptor<PlannedWorkout>(
            predicate: #Predicate { $0.date == dayStart }
        )
        let existingCount = (try? modelContext.fetchCount(descriptor)) ?? 0

        let workout = PlannedWorkout(
            date: vm.sheetTargetDate,
            workoutType: vm.formType,
            title: vm.formTitle.isEmpty ? defaultTitle : vm.formTitle,
            plannedDistanceMiles: vm.formShowsDistance ? vm.formEffectiveDistanceMiles : 0,
            plannedDurationSeconds: vm.formDurationSeconds,
            strengthType: vm.formStrengthType,
            crossTrainingActivityType: vm.formCrossTrainingActivityType,
            runCategory: vm.formRunCategory,
            runSegments: vm.formRunSegments,
            notes: vm.formNotes,
            postRunStrides: vm.formPostRunStrides,
            intensityLevel: vm.formIntensity,
            displayOrder: existingCount,
            plannedTimeMinutesSinceMidnight: vm.formPlannedTimeEnabled ? vm.formPlannedTimeMinutes : 0
        )
        modelContext.insert(workout)
        workout.routeWaypoints = vm.formRouteWaypoints
        workout.routePolyline = vm.formRoutePolyline
        workout.routeDistanceMiles = vm.formRouteDistanceMiles
        workout.fuelPlan = localFuelPlan

        Task { @MainActor in
            let granted = await calendarService.requestAccessIfNeeded()
            if granted {
                if let eventId = try? await calendarService.createEvent(for: workout) {
                    workout.calendarEventIdentifier = eventId
                }
            } else {
                vm.calendarAuthorizationDenied = true
            }
        }
    }

    private func update(_ workout: PlannedWorkout) {
        let oldEventId = workout.calendarEventIdentifier
        workout.workoutType = vm.formType
        workout.title = vm.formTitle.isEmpty ? defaultTitle : vm.formTitle
        workout.plannedDistanceMiles = vm.formShowsDistance ? vm.formEffectiveDistanceMiles : 0
        workout.plannedDurationSeconds = vm.formDurationSeconds
        workout.crossTrainingActivityType = vm.formCrossTrainingActivityType
        workout.runCategory = vm.formRunCategory
        workout.strengthType = vm.formStrengthType
        workout.runSegments = vm.formRunSegments
        workout.routeWaypoints = vm.formRouteWaypoints
        workout.routePolyline = vm.formRoutePolyline
        workout.routeDistanceMiles = vm.formRouteDistanceMiles
        workout.notes = vm.formNotes
        workout.postRunStrides = vm.formPostRunStrides
        workout.intensityLevel = vm.formIntensity
        workout.plannedTimeMinutesSinceMidnight = vm.formPlannedTimeEnabled ? vm.formPlannedTimeMinutes : 0
        if let plan = localFuelPlan {
            workout.fuelPlan = plan
        }

        Task { @MainActor in
            if let id = oldEventId {
                try? await calendarService.deleteEvent(identifier: id)
            }
            let granted = await calendarService.requestAccessIfNeeded()
            if granted {
                if let eventId = try? await calendarService.createEvent(for: workout) {
                    workout.calendarEventIdentifier = eventId
                }
            }
        }
    }
}

// MARK: - Segment Row

private struct SegmentRow: View {
    let segment: PlannedRunSegment

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: segment.segmentType.systemImage)
                .font(.caption)
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Color.green.opacity(0.8), in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 1) {
                Text(segment.segmentType.rawValue)
                    .font(.subheadline.weight(.medium))
                let summary = segment.summaryLabel
                if !summary.isEmpty {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Int: Identifiable for sheet(item:)
extension Int: @retroactive Identifiable {
    public var id: Int { self }
}
