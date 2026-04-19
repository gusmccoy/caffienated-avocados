// Views/Dashboard/DashboardView.swift
// Main home screen — weekly summary, recent workouts, and quick-add button.

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \PlannedWorkout.date, order: .forward) private var allPlannedWorkouts: [PlannedWorkout]
    @State private var listVM = WorkoutListViewModel()
    @State private var showingAddWorkout = false
    @State private var showingLogRunning = false
    @State private var showingLogStrength = false
    @State private var showingLogCrossTraining = false

    // Grab just the 5 most recent workouts for the "Recent" section
    private var recentSessions: [WorkoutSession] {
        Array(sessions.prefix(5))
    }

    /// Computed property that checks if all planned workouts for the current week are completed.
    private var shouldShowWeekCompletionBanner: Bool {
        let currentWeekStart = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
        let weekWorkouts = allPlannedWorkouts.filter { workout in
            let workoutWeekComponents = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: workout.date)
            return workoutWeekComponents.yearForWeekOfYear == currentWeekStart.yearForWeekOfYear &&
                   workoutWeekComponents.weekOfYear == currentWeekStart.weekOfYear
        }
        return !weekWorkouts.isEmpty && weekWorkouts.allSatisfy { $0.isCompleted }
    }

    private var weeklySummary: WorkoutListViewModel.WeeklySummary {
        listVM.weeklySummary(from: sessions)
    }

    private var weekDelta: WorkoutListViewModel.WeekOverWeekDelta {
        listVM.weekOverWeekDelta(from: sessions)
    }

    private var trainingSuggestions: [TrainingSuggestion] {
        SuggestionEngine.suggestions(from: Array(sessions))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    WeeklySummaryCard(summary: weeklySummary, delta: weekDelta)

                    if shouldShowWeekCompletionBanner {
                        WeekCompletionBanner()
                    }

                    if !trainingSuggestions.isEmpty {
                        SuggestionsCard(suggestions: trainingSuggestions)
                    }

                    QuickAddRow(
                        showingLogRunning: $showingLogRunning,
                        showingLogStrength: $showingLogStrength,
                        showingLogCrossTraining: $showingLogCrossTraining
                    )
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
                ToolbarItem(placement: .secondaryAction) {
                    NavigationLink {
                        TrendDashboardView()
                    } label: {
                        Label("Trends", systemImage: "chart.line.uptrend.xyaxis")
                    }
                }
            }
            .sheet(isPresented: $showingAddWorkout) {
                AddWorkoutView()
            }
            .sheet(isPresented: $showingLogRunning) {
                LogRunningView()
            }
            .sheet(isPresented: $showingLogStrength) {
                LogStrengthView()
            }
            .sheet(isPresented: $showingLogCrossTraining) {
                LogCrossTrainingView()
            }
        }
    }
}

// MARK: - Weekly Summary Card

private struct WeeklySummaryCard: View {
    let summary: WorkoutListViewModel.WeeklySummary
    let delta: WorkoutListViewModel.WeekOverWeekDelta

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("This Week")
                    .font(.title3).bold()
                Spacer()
                Text("vs. same point last week")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 0) {
                StatCell(
                    value: "\(summary.totalWorkouts)",
                    label: "Workouts",
                    icon: "flame.fill",
                    color: .orange,
                    deltaText: delta.workoutsLabel,
                    deltaColor: delta.workoutsColor
                )
                Divider().frame(height: 60)
                StatCell(
                    value: summary.formattedDuration,
                    label: "Time",
                    icon: "clock.fill",
                    color: .blue,
                    deltaText: delta.durationLabel,
                    deltaColor: delta.durationColor
                )
                Divider().frame(height: 60)
                StatCell(
                    value: String(format: "%.1f", summary.runningMiles),
                    label: "Miles",
                    icon: "figure.run",
                    color: .green,
                    deltaText: delta.milesLabel,
                    deltaColor: delta.milesColor
                )
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
    var deltaText: String? = nil
    var deltaColor: Color? = nil

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.title2).bold()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let text = deltaText {
                Text(text)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(deltaColor ?? .secondary)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Quick Add Row

private struct QuickAddRow: View {
    @Binding var showingLogRunning: Bool
    @Binding var showingLogStrength: Bool
    @Binding var showingLogCrossTraining: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Add")
                .font(.title3).bold()

            HStack(spacing: 12) {
                QuickAddButton(type: .running) { showingLogRunning = true }
                QuickAddButton(type: .strength) { showingLogStrength = true }
                QuickAddButton(type: .crossTraining) { showingLogCrossTraining = true }
            }
        }
    }
}

private struct QuickAddButton: View {
    let type: WorkoutType
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
                HStack(spacing: 4) {
                    Text(session.title.isEmpty ? session.type.rawValue : session.title)
                        .font(.subheadline).bold()
                    if session.stravaActivityId != nil {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
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
