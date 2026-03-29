// Views/Running/LogRunningView.swift
// Form for logging (or editing) a running workout.

import SwiftUI
import SwiftData

struct LogRunningView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var vm = RunningViewModel()
    var editingSession: WorkoutSession? = nil

    var body: some View {
        NavigationStack {
            Form {
                // Basic info
                Section("Workout Info") {
                    DatePicker("Date", selection: $vm.date, displayedComponents: .date)
                    TextField("Title (optional)", text: $vm.title)
                    Picker("Run Type", selection: $vm.runType) {
                        ForEach(RunType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                }

                // Distance
                Section("Distance") {
                    HStack {
                        Text("Miles")
                        Spacer()
                        TextField("0.00", value: $vm.distanceMiles, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                // Duration
                Section("Duration") {
                    HStack {
                        DurationPicker(label: "h", value: $vm.hours, range: 0...23)
                        DurationPicker(label: "m", value: $vm.minutes, range: 0...59)
                        DurationPicker(label: "s", value: $vm.seconds, range: 0...59)
                    }
                    if vm.durationSeconds > 0 && vm.distanceMiles > 0 {
                        Text("Avg Pace: \(vm.formattedPace)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Intensity
                Section("Intensity") {
                    Picker("Level", selection: $vm.intensityLevel) {
                        ForEach(IntensityLevel.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                // Optional details
                Section("Optional Details") {
                    TextField("Route / Location", text: $vm.route)
                    TextField("Elevation Gain (ft)", text: $vm.elevationGainFeet)
                        .keyboardType(.numberPad)
                    TextField("Cadence (spm)", text: $vm.cadenceAvg)
                        .keyboardType(.numberPad)
                    TextField("Avg Heart Rate (bpm)", text: $vm.heartRateAvg)
                        .keyboardType(.numberPad)
                    TextField("Max Heart Rate (bpm)", text: $vm.heartRateMax)
                        .keyboardType(.numberPad)
                    TextField("Calories Burned", text: $vm.caloriesBurned)
                        .keyboardType(.numberPad)
                }

                Section("Notes") {
                    TextEditor(text: $vm.notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle(editingSession == nil ? "Log Run" : "Edit Run")
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
            .onAppear {
                if let session = editingSession {
                    vm.populate(from: session)
                }
            }
        }
    }

    private func save() {
        if editingSession == nil {
            _ = vm.buildWorkoutSession(modelContext: modelContext)
        } else {
            updateSession()
        }
        dismiss()
    }

    private func updateSession() {
        guard let session = editingSession, let run = session.runningWorkout else { return }
        session.date = vm.date
        session.title = vm.title
        session.notes = vm.notes
        session.intensityLevel = vm.intensityLevel
        session.durationSeconds = vm.durationSeconds
        session.heartRateAvg = Int(vm.heartRateAvg)
        session.heartRateMax = Int(vm.heartRateMax)
        session.caloriesBurned = Int(vm.caloriesBurned)
        session.updatedAt = .now

        run.distanceMiles = vm.distanceMiles
        run.runType = vm.runType
        run.averagePaceSecondsPerMile = vm.averagePaceSecondsPerMile
        run.elevationGainFeet = Double(vm.elevationGainFeet)
        run.cadenceAvg = Int(vm.cadenceAvg)
        run.route = vm.route.isEmpty ? nil : vm.route
    }
}

// MARK: - Duration Picker

struct DurationPicker: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 2) {
            Picker("", selection: $value) {
                ForEach(Array(range), id: \.self) { i in
                    Text(String(format: "%02d", i)).tag(i)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 60)
            .clipped()

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
