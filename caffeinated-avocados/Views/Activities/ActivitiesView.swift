// Views/Activities/ActivitiesView.swift
// Unified activity list — Running, Strength, and Cross Training in one tab.

import SwiftUI
import SwiftData

struct ActivitiesView: View {
    @Query(sort: \WorkoutSession.date, order: .reverse)
    private var sessions: [WorkoutSession]

    @State private var selectedType: WorkoutType = .running
    @State private var listVM = WorkoutListViewModel()
    @State private var showingLog = false
    @State private var showingFilters = false

    @Environment(\.modelContext) private var modelContext

    private var filteredSessions: [WorkoutSession] {
        listVM.filter(sessions, typesOverride: [selectedType])
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Type picker
                Picker("Activity Type", selection: $selectedType) {
                    Label("Run", systemImage: "figure.run").tag(WorkoutType.running)
                    Label("Strength", systemImage: "dumbbell.fill").tag(WorkoutType.strength)
                    Label("Cross Train", systemImage: "figure.cross.training").tag(WorkoutType.crossTraining)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Group {
                    if filteredSessions.isEmpty {
                        emptyState
                    } else {
                        List {
                            // Stats header for running only
                            if selectedType == .running {
                                RunningStatsHeader(sessions: filteredSessions)
                                    .listRowInsets(EdgeInsets())
                                    .listRowBackground(Color.clear)
                            }

                            ForEach(filteredSessions) { session in
                                NavigationLink {
                                    destinationView(for: session)
                                } label: {
                                    ActivityRowView(session: session)
                                }
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            }
                            .onDelete(perform: deleteSessions)
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("Activities")
            .searchable(text: $listVM.searchText, prompt: searchPrompt)
            .toolbar {
                if selectedType == .running {
                    ToolbarItem(placement: .navigation) {
                        Button { showingFilters = true } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingLog = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingLog) {
                logView
            }
            .sheet(isPresented: $showingFilters) {
                WorkoutFilterSheet(listVM: listVM, workoutType: .running)
            }
        }
    }

    // MARK: - Helpers

    private var searchPrompt: String {
        switch selectedType {
        case .running:      return "Search runs"
        case .strength:     return "Search workouts"
        case .crossTraining: return "Search sessions"
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        switch selectedType {
        case .running:
            ContentUnavailableView(
                "No Runs Yet",
                systemImage: "figure.run.circle",
                description: Text("Tap + to log your first run.")
            )
        case .strength:
            ContentUnavailableView(
                "No Strength Sessions Yet",
                systemImage: "dumbbell.fill",
                description: Text("Tap + to log your first workout.")
            )
        case .crossTraining:
            ContentUnavailableView(
                "No Cross-Training Yet",
                systemImage: "figure.cross.training",
                description: Text("Tap + to log your first session.")
            )
        }
    }

    @ViewBuilder
    private var logView: some View {
        switch selectedType {
        case .running:      LogRunningView()
        case .strength:     LogStrengthView()
        case .crossTraining: LogCrossTrainingView()
        }
    }

    @ViewBuilder
    private func destinationView(for session: WorkoutSession) -> some View {
        switch session.type {
        case .running:      RunningDetailView(session: session)
        case .strength:     StrengthDetailView(session: session)
        case .crossTraining: CrossTrainingDetailView(session: session)
        }
    }

    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredSessions[index])
        }
    }
}

// MARK: - Activity Row (dispatches to type-specific row)

private struct ActivityRowView: View {
    let session: WorkoutSession

    var body: some View {
        switch session.type {
        case .running:      RunningRow(session: session)
        case .strength:     StrengthRow(session: session)
        case .crossTraining: CrossTrainingRow(session: session)
        }
    }
}

// MARK: - Running Row

private struct RunningRow: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(session.date.formatted(.dateTime.month().day()))
                    .font(.caption2).bold()
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.green, in: RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(session.title.isEmpty ? (session.runningWorkout?.runType.rawValue ?? "Run") : session.title)
                        .font(.subheadline).bold()
                    if session.stravaActivityId != nil {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 8) {
                    if let run = session.runningWorkout {
                        Label(run.formattedDistance, systemImage: "arrow.triangle.swap").font(.caption)
                        Label(run.formattedPace, systemImage: "timer").font(.caption)
                    }
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(session.formattedDuration).font(.subheadline).bold()
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Strength Row

private struct StrengthRow: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "dumbbell.fill").foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(session.title.isEmpty ? "Strength" : session.title)
                        .font(.subheadline).bold()
                    if session.stravaActivityId != nil {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 8) {
                    Text(session.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption).foregroundStyle(.secondary)
                    if let strength = session.strengthWorkout {
                        Text("·")
                        Text("\(strength.exercises.count) exercises")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(session.formattedDuration).font(.subheadline).bold()
                if let strength = session.strengthWorkout, strength.totalVolumeLbs > 0 {
                    Text(String(format: "%.0f lbs", strength.totalVolumeLbs))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Cross Training Row

private struct CrossTrainingRow: View {
    let session: WorkoutSession

    private var activityType: CrossTrainingActivityType {
        session.crossTrainingWorkout?.activityType ?? .other
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: activityType.systemImage).foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(session.title.isEmpty ? activityType.rawValue : session.title)
                        .font(.subheadline).bold()
                    if session.stravaActivityId != nil {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 6) {
                    Text(session.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption).foregroundStyle(.secondary)
                    if let ct = session.crossTrainingWorkout {
                        Text("·")
                        Text(ct.summaryLine)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Text(session.formattedDuration).font(.subheadline).bold()
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Running Stats Header

private struct RunningStatsHeader: View {
    let sessions: [WorkoutSession]

    private var totalMiles: Double {
        sessions.compactMap(\.runningWorkout).reduce(0) { $0 + $1.distanceMiles }
    }

    private var avgPace: Int {
        let paces = sessions.compactMap(\.runningWorkout).map(\.averagePaceSecondsPerMile).filter { $0 > 0 }
        guard !paces.isEmpty else { return 0 }
        return paces.reduce(0, +) / paces.count
    }

    var body: some View {
        HStack(spacing: 0) {
            MiniStat(value: "\(sessions.count)", label: "Runs")
            Divider().frame(height: 40)
            MiniStat(value: String(format: "%.1f", totalMiles), label: "Total Mi")
            Divider().frame(height: 40)
            MiniStat(
                value: avgPace > 0 ? String(format: "%d:%02d", avgPace / 60, avgPace % 60) : "--",
                label: "Avg Pace"
            )
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        #if canImport(UIKit)
        .background(Color(.systemGroupedBackground))
        #else
        .background(Color(nsColor: .controlBackgroundColor))
        #endif
    }
}

private struct MiniStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.headline)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ActivitiesView()
}
