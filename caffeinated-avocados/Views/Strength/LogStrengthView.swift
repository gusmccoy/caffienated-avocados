// Views/Strength/LogStrengthView.swift
// Form for logging (or editing) a strength training session.

import SwiftUI
import SwiftData

struct LogStrengthView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var vm = StrengthViewModel()
    var editingSession: WorkoutSession? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Session Info") {
                    DatePicker("Date", selection: $vm.date, displayedComponents: .date)
                    TextField("Title (optional)", text: $vm.title)
                    TextField("Template (e.g. Push Day A)", text: $vm.workoutTemplate)
                }

                Section("Duration") {
                    HStack {
                        DurationPicker(label: "h", value: $vm.hours, range: 0...5)
                        DurationPicker(label: "m", value: $vm.minutes, range: 0...59)
                        DurationPicker(label: "s", value: $vm.seconds, range: 0...59)
                    }
                }

                Section("Intensity") {
                    Picker("Level", selection: $vm.intensityLevel) {
                        ForEach(IntensityLevel.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                // Exercises
                Section {
                    ForEach($vm.exercises) { $exercise in
                        ExerciseEditorRow(entry: $exercise)
                    }
                    .onDelete { vm.removeExercise(at: $0) }
                    .onMove { vm.moveExercise(from: $0, to: $1) }

                    Button {
                        vm.isAddingExercise = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle.fill")
                    }
                } header: {
                    HStack {
                        Text("Exercises")
                        Spacer()
                        if !vm.exercises.isEmpty {
                            Text("Vol: \(String(format: "%.0f lbs", vm.totalVolumeLbs))")
                                .font(.caption)
                        }
                    }
                }

                Section("Optional") {
                    TextField("Avg Heart Rate (bpm)", text: $vm.heartRateAvg)
                        .keyboardType(.numberPad)
                    TextField("Calories Burned", text: $vm.caloriesBurned)
                        .keyboardType(.numberPad)
                }

                Section("Notes") {
                    TextEditor(text: $vm.notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle(editingSession == nil ? "Log Strength" : "Edit Strength")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!vm.isFormValid)
                }
            }
            .sheet(isPresented: $vm.isAddingExercise) {
                AddExerciseSheet(vm: vm)
            }
            .environment(\.editMode, .constant(.active))
        }
    }

    private func save() {
        _ = vm.buildWorkoutSession(modelContext: modelContext)
        dismiss()
    }
}

// MARK: - Exercise Editor Row

private struct ExerciseEditorRow: View {
    @Binding var entry: StrengthViewModel.ExerciseEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.name).font(.subheadline).bold()
                Spacer()
                Text(entry.muscleGroup.rawValue)
                    .font(.caption).foregroundStyle(.secondary)
            }

            ForEach(entry.sets.indices, id: \.self) { i in
                HStack(spacing: 8) {
                    Text("Set \(i + 1)")
                        .font(.caption).foregroundStyle(.secondary).frame(width: 40, alignment: .leading)

                    TextField("lbs", value: $entry.sets[i].weightLbs, format: .number)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 70)

                    Text("×")

                    TextField("reps", value: $entry.sets[i].reps, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 60)

                    Spacer()

                    Button {
                        entry.removeSet(at: i)
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(.red)
                    }
                }
            }

            Button {
                entry.addSet()
            } label: {
                Label("Add Set", systemImage: "plus")
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Exercise Sheet

private struct AddExerciseSheet: View {
    let vm: StrengthViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise Name") {
                    TextField("e.g. Bench Press", text: Bindable(vm).newExerciseName)
                }
                Section("Muscle Group") {
                    Picker("Group", selection: Bindable(vm).newExerciseMuscleGroup) {
                        ForEach(MuscleGroup.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        vm.addExercise()
                        dismiss()
                    }
                    .disabled(vm.newExerciseName.isEmpty)
                }
            }
        }
    }
}
