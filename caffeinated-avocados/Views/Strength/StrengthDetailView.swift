// Views/Strength/StrengthDetailView.swift
// Detailed view for a single strength training session.

import SwiftUI
import SwiftData

struct StrengthDetailView: View {
    let session: WorkoutSession
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingEdit = false
    @State private var showingDeleteAlert = false

    private var strength: StrengthWorkout? { session.strengthWorkout }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DetailHeaderView(session: session, accentColor: .orange)

                // Key Stats
                SectionCard(title: "Summary") {
                    StatGrid {
                        StatItem(icon: "clock.fill", label: "Duration", value: session.formattedDuration)
                        if let str = strength {
                            StatItem(icon: "dumbbell.fill", label: "Volume", value: String(format: "%.0f lbs", str.totalVolumeLbs))
                            StatItem(icon: "list.number", label: "Exercises", value: "\(str.exercises.count)")
                        }
                        if let cals = session.caloriesBurned {
                            StatItem(icon: "flame.fill", label: "Calories", value: "\(cals) cal")
                        }
                        if let hr = session.heartRateAvg {
                            StatItem(icon: "heart.fill", label: "Avg HR", value: "\(hr) bpm")
                        }
                        StatItem(icon: "gauge.with.dots.needle.bottom.50percent", label: "Intensity", value: session.intensityLevel.rawValue)
                    }
                }

                // Exercise breakdown
                if let strength = strength, !strength.exercises.isEmpty {
                    SectionCard(title: "Exercises") {
                        ForEach(strength.exercises.sorted(by: { $0.orderIndex < $1.orderIndex })) { exercise in
                            ExerciseDetailRow(exercise: exercise)
                            if exercise.id != strength.exercises.last?.id {
                                Divider()
                            }
                        }
                    }
                }

                // Template
                if let template = strength?.workoutTemplate, !template.isEmpty {
                    SectionCard(title: "Template") {
                        Text(template)
                            .font(.subheadline)
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
        .navigationTitle("Strength Details")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Edit") { showingEdit = true }
                    Button("Delete", role: .destructive) { showingDeleteAlert = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            LogStrengthView(editingSession: session)
        }
        .alert("Delete Workout?", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                modelContext.delete(session)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This strength session will be permanently removed.")
        }
    }
}

// MARK: - Exercise Detail Row

private struct ExerciseDetailRow: View {
    let exercise: ExerciseSet

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exercise.name)
                    .font(.subheadline).bold()
                Spacer()
                Text(exercise.muscleGroup.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(exercise.sets) { set in
                HStack {
                    if set.isWarmup {
                        Text("W").foregroundStyle(.secondary).font(.caption).bold()
                    }
                    Text("Set \(set.setNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(set.formattedWeight) × \(set.reps ?? 0) reps")
                        .font(.subheadline)
                    if let rpe = set.rpe {
                        Text("@\(String(format: "%.1f", rpe))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
