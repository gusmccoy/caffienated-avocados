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
        }
    }

    // MARK: - Helpers

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
            intensityLevel: vm.formIntensity
        )
        modelContext.insert(workout)
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
        workout.notes = vm.formNotes
        workout.postRunStrides = vm.formPostRunStrides
        workout.intensityLevel = vm.formIntensity
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
