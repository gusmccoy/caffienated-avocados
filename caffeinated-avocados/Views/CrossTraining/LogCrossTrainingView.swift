// Views/CrossTraining/LogCrossTrainingView.swift
// Form for logging (or editing) a cross-training session.

import SwiftUI
import SwiftData

struct LogCrossTrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var vm = CrossTrainingViewModel()
    var editingSession: WorkoutSession? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Session Info") {
                    DatePicker("Date", selection: $vm.date, displayedComponents: .date)
                    TextField("Title (optional)", text: $vm.title)

                    Picker("Activity", selection: $vm.activityType) {
                        ForEach(CrossTrainingActivityType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.systemImage).tag(type)
                        }
                    }
                }

                Section("Duration") {
                    HStack {
                        DurationPicker(label: "h", value: $vm.hours, range: 0...10)
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

                if vm.showsDistance {
                    Section("Distance") {
                        HStack {
                            Text("Miles")
                            Spacer()
                            TextField("0.00", text: $vm.distanceMiles)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        if vm.activityType == .cycling || vm.activityType == .hiking {
                            HStack {
                                Text("Elevation Gain (ft)")
                                Spacer()
                                TextField("0", text: $vm.elevationGainFeet)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                }

                if vm.showsPower {
                    Section("Performance") {
                        HStack {
                            Text("Avg Power (watts)")
                            Spacer()
                            TextField("0", text: $vm.avgPowerWatts)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        HStack {
                            Text("Cadence (RPM)")
                            Spacer()
                            TextField("0", text: $vm.avgCadenceRPM)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                if vm.showsPool {
                    Section("Swimming") {
                        HStack {
                            Text("Pool Length (yards)")
                            Spacer()
                            TextField("25", text: $vm.poolLengthYards)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        HStack {
                            Text("Laps Completed")
                            Spacer()
                            TextField("0", text: $vm.lapsCompleted)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        HStack {
                            Text("Strokes/min")
                            Spacer()
                            TextField("0", text: $vm.strokesPerMinute)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                Section("Heart Rate & Calories") {
                    HStack {
                        Text("Avg HR (bpm)")
                        Spacer()
                        TextField("0", text: $vm.heartRateAvg)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Max HR (bpm)")
                        Spacer()
                        TextField("0", text: $vm.heartRateMax)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Calories Burned")
                        Spacer()
                        TextField("0", text: $vm.caloriesBurned)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Notes") {
                    TextEditor(text: $vm.notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle(editingSession == nil ? "Log Cross Training" : "Edit Session")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!vm.isFormValid)
                }
            }
        }
    }

    private func save() {
        _ = vm.buildWorkoutSession(modelContext: modelContext)
        dismiss()
    }
}
