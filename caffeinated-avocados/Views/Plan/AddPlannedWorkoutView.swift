// Views/Plan/AddPlannedWorkoutView.swift
// Sheet for adding a new planned workout to a specific day.

import SwiftUI
import SwiftData

struct AddPlannedWorkoutView: View {
    @Bindable var vm: PlanViewModel
    let calendarService: CalendarService
    @Environment(\.modelContext) private var modelContext

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

                Section("Details") {
                    TextField("Title (optional)", text: $vm.formTitle)
                    Picker("Intensity", selection: $vm.formIntensity) {
                        ForEach(IntensityLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if vm.formShowsDistance {
                    Section("Distance (optional)") {
                        HStack {
                            Text("Miles")
                            Spacer()
                            TextField("0.00", value: $vm.formDistanceMiles, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                Section("Duration (optional)") {
                    HStack {
                        DurationPicker(label: "h", value: $vm.formHours, range: 0...23)
                        DurationPicker(label: "m", value: $vm.formMinutes, range: 0...59)
                        DurationPicker(label: "s", value: $vm.formSeconds, range: 0...59)
                    }
                }

                Section("Notes") {
                    TextEditor(text: $vm.formNotes)
                        .frame(minHeight: 80)
                }

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
        }
    }

    private var dateTitle: String {
        vm.sheetTargetDate.formatted(date: .complete, time: .omitted)
    }

    /// Default title when the user leaves the title field blank.
    private var defaultTitle: String {
        if vm.formType == .crossTraining {
            return vm.formCrossTrainingActivityType.rawValue
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
            plannedDistanceMiles: vm.formShowsDistance ? vm.formDistanceMiles : 0,
            plannedDurationSeconds: vm.formDurationSeconds,
            crossTrainingActivityType: vm.formCrossTrainingActivityType,
            notes: vm.formNotes,
            intensityLevel: vm.formIntensity
        )
        modelContext.insert(workout)

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
        workout.plannedDistanceMiles = vm.formShowsDistance ? vm.formDistanceMiles : 0
        workout.plannedDurationSeconds = vm.formDurationSeconds
        workout.crossTrainingActivityType = vm.formCrossTrainingActivityType
        workout.notes = vm.formNotes
        workout.intensityLevel = vm.formIntensity

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
