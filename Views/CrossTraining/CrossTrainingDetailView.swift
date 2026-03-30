// Views/CrossTraining/CrossTrainingDetailView.swift
// Detail view for a single cross-training session.

import SwiftUI

struct CrossTrainingDetailView: View {
    let session: WorkoutSession
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingEdit = false
    @State private var showingDeleteAlert = false

    private var ct: CrossTrainingWorkout? { session.crossTrainingWorkout }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DetailHeaderView(session: session, accentColor: .blue)

                // Stats
                SectionCard(title: "Stats") {
                    StatGrid {
                        StatItem(icon: "clock.fill", label: "Duration", value: session.formattedDuration)

                        if let dist = ct?.distanceMiles {
                            StatItem(icon: "arrow.triangle.swap", label: "Distance", value: String(format: "%.2f mi", dist))
                        }
                        if let power = ct?.avgPowerWatts {
                            StatItem(icon: "bolt.fill", label: "Avg Power", value: "\(power)W")
                        }
                        if let laps = ct?.lapsCompleted {
                            StatItem(icon: "repeat", label: "Laps", value: "\(laps)")
                        }
                        if let hr = session.heartRateAvg {
                            StatItem(icon: "heart.fill", label: "Avg HR", value: "\(hr) bpm")
                        }
                        if let cals = session.caloriesBurned {
                            StatItem(icon: "flame.fill", label: "Calories", value: "\(cals) cal")
                        }
                    }
                }

                // Activity Details
                if let ct = ct {
                    SectionCard(title: "Activity Details") {
                        LabeledContent("Type", value: ct.activityType.rawValue)
                        LabeledContent("Intensity", value: session.intensityLevel.rawValue)
                        if let cadence = ct.avgCadenceRPM {
                            LabeledContent("Cadence", value: "\(cadence) RPM")
                        }
                        if let spm = ct.strokesPerMinute {
                            LabeledContent("Strokes/min", value: "\(spm)")
                        }
                        if let pool = ct.poolLengthYards {
                            LabeledContent("Pool Length", value: "\(pool) yds")
                        }
                        if let elev = ct.elevationGainFeet {
                            LabeledContent("Elevation", value: String(format: "%.0f ft", elev))
                        }
                    }
                }

                // Notes
                if !session.notes.isEmpty {
                    SectionCard(title: "Notes") {
                        Text(session.notes)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Cross Training")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit") { showingEdit = true }
                    Button("Delete", role: .destructive) { showingDeleteAlert = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            LogCrossTrainingView(editingSession: session)
        }
        .alert("Delete Session?", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                modelContext.delete(session)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cross-training session will be permanently removed.")
        }
    }
}
