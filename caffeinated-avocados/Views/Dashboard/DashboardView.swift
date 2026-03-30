// Views/Dashboard/DashboardView.swift
// Main home screen — weekly summary, recent workouts, and quick-add button.

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @State private var listVM = WorkoutListViewModel()
    @State private var showingAddWorkout = false

    // Grab just the 5 most recent workouts for the "Recent" section
    private var recentSessions: [WorkoutSession] {
        Array(sessions.prefix(5))
    }

    private var weeklySummary: WorkoutListViewModel.WeeklySummary {
        listVM.weeklySummary(from: sessions)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    WeeklySummaryCard(summary: weeklySummary)
                    QuickAddRow(showingAddWorkout: $showingAddWorkout)
                    RecentWorkoutsSection(sessions: recentSessions)
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddWorkout = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddWorkout) {
                AddWorkoutView()
            }
        }
    }
}

// MARK: - Weekly Summary Card

private struct WeeklySummaryCard: View {
    let summary: WorkoutListViewModel.WeeklySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.title3).bold()

            HStack(spacing: 0) {
                StatCell(value: "\(summary.totalWorkouts)", label: "Workouts", icon: "flame.fill", color: .orange)
                Divider().frame(height: 50)
                StatCell(value: summary.formattedDuration, label: "Time", icon: "clock.fill", color: .blue)
                Divider().frame(height: 50)
                StatCell(value: String(format: "%.1f", summary.runningMiles), label: "Miles", icon: "figure.run", color: .green)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

private struct StatCell: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.title2).bold()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Quick Add Row

private struct QuickAddRow: View {
    @Binding var showingAddWorkout: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Add")
                .font(.title3).bold()

            HStack(spacing: 12) {
                QuickAddButton(type: .running, showingAdd: $showingAddWorkout)
                QuickAddButton(type: .strength, showingAdd: $showingAddWorkout)
                QuickAddButton(type: .crossTraining, showingAdd: $showingAddWorkout)
            }
        }
    }
}

private struct QuickAddButton: View {
    let type: WorkoutType
    @Binding var showingAdd: Bool

    var body: some View {
        Button {
            showingAdd = true
        } label: {
            VStack(spacing: 6) {
                Image(systemName: type.systemImage)
                    .font(.title2)
                Text(type.rawValue)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
        .foregroundStyle(.primary)
    }
}

// MARK: - Recent Workouts Section

private struct RecentWorkoutsSection: View {
    let sessions: [WorkoutSession]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Workouts")
                    .font(.title3).bold()
                Spacer()
                NavigationLink("See All") {
                    RunningListView()  // Could link to a unified "All Workouts" list
                }
                .font(.subheadline)
            }

            if sessions.isEmpty {
                ContentUnavailableView(
                    "No Workouts Yet",
                    systemImage: "figure.run.circle",
                    description: Text("Log your first workout to get started.")
                )
                .padding(.vertical)
            } else {
                ForEach(sessions) { session in
                    WorkoutRowView(session: session)
                }
            }
        }
    }
}

// MARK: - Shared Workout Row

struct WorkoutRowView: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(typeColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: session.type.systemImage)
                    .foregroundStyle(typeColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(session.title.isEmpty ? session.type.rawValue : session.title)
                    .font(.subheadline).bold()
                Text(session.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(session.formattedDuration)
                    .font(.subheadline).bold()
                if let run = session.runningWorkout {
                    Text(run.formattedDistance)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var typeColor: Color {
        switch session.type {
        case .running:       return .green
        case .strength:      return .orange
        case .crossTraining: return .blue
        }
    }
}

// MARK: - Add Workout Sheet (type picker)

struct AddWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: WorkoutType = .running

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout Type") {
                    ForEach(WorkoutType.allCases, id: \.self) { type in
                        Button {
                            selectedType = type
                        } label: {
                            HStack {
                                Label(type.rawValue, systemImage: type.systemImage)
                                Spacer()
                                if selectedType == type {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }

                Section {
                    NavigationLink("Continue") {
                        destinationView
                    }
                    .foregroundStyle(.orange)
                }
            }
            .navigationTitle("New Workout")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch selectedType {
        case .running:       LogRunningView()
        case .strength:      LogStrengthView()
        case .crossTraining: LogCrossTrainingView()
        }
    }
}

#Preview {
    DashboardView()
}
