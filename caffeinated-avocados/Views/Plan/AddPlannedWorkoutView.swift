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
                    Section("Distance") {
                        HStack {
                            Text("Miles")
                            Spacer()
                            TextField("0.00", value: $vm.formDistanceMiles, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
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
            title: vm.formTitle.isEmpty ? vm.formType.rawValue : vm.formTitle,
            plannedDistanceMiles: vm.formShowsDistance ? vm.formDistanceMiles : 0,
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
        workout.title = vm.formTitle.isEmpty ? vm.formType.rawValue : vm.formTitle
        workout.plannedDistanceMiles = vm.formShowsDistance ? vm.formDistanceMiles : 0
        workout.notes = vm.formNotes
        workout.intensityLevel = vm.formIntensity

        Task { @MainActor in
            // Delete the old calendar event and create a fresh one with updated details
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
