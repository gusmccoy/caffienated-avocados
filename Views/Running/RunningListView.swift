// Views/Running/RunningListView.swift
// List of all logged running workouts with filter + sort controls.

import SwiftUI
import SwiftData

struct RunningListView: View {
    @Query(
        filter: #Predicate<WorkoutSession> { $0.type == .running },
        sort: \WorkoutSession.date,
        order: .reverse
    ) private var sessions: [WorkoutSession]

    @State private var listVM = WorkoutListViewModel()
    @State private var showingLog = false
    @State private var showingFilters = false

    private var filteredSessions: [WorkoutSession] {
        listVM.filter(sessions, typesOverride: [.running])
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredSessions.isEmpty {
                    ContentUnavailableView(
                        "No Runs Yet",
                        systemImage: "figure.run.circle",
                        description: Text("Tap + to log your first run.")
                    )
                } else {
                    List {
                        RunningStatsHeader(sessions: sessions)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)

                        ForEach(filteredSessions) { session in
                            NavigationLink {
                                RunningDetailView(session: session)
                            } label: {
                                RunningRowView(session: session)
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                        .onDelete(perform: deleteSessions)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Running")
            .searchable(text: $listVM.searchText, prompt: "Search runs")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingFilters = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingLog = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingLog) {
                LogRunningView()
            }
            .sheet(isPresented: $showingFilters) {
                WorkoutFilterSheet(listVM: listVM, workoutType: .running)
            }
        }
    }

    @Environment(\.modelContext) private var modelContext

    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredSessions[index])
        }
    }
}

// MARK: - Stats Header

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
        .background(Color(.systemGroupedBackground))
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

// MARK: - Row

private struct RunningRowView: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 12) {
            // Date badge
            VStack(spacing: 0) {
                Text(session.date.formatted(.dateTime.month().day()))
                    .font(.caption2).bold()
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.green, in: RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(session.title.isEmpty ? (session.runningWorkout?.runType.rawValue ?? "Run") : session.title)
                    .font(.subheadline).bold()

                HStack(spacing: 8) {
                    if let run = session.runningWorkout {
                        Label(run.formattedDistance, systemImage: "arrow.triangle.swap")
                            .font(.caption)
                        Label(run.formattedPace, systemImage: "timer")
                            .font(.caption)
                    }
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(session.formattedDuration)
                .font(.subheadline).bold()
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    RunningListView()
}
