// Views/CrossTraining/CrossTrainingListView.swift
// List of all cross-training sessions grouped by activity type.

import SwiftUI
import SwiftData

struct CrossTrainingListView: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]

    @State private var listVM = WorkoutListViewModel()
    @State private var showingLog = false

    private var filteredSessions: [WorkoutSession] {
        listVM.filter(sessions, typesOverride: [.crossTraining])
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredSessions.isEmpty {
                    ContentUnavailableView(
                        "No Cross-Training Yet",
                        systemImage: "figure.cross.training",
                        description: Text("Tap + to log your first session.")
                    )
                } else {
                    List {
                        ForEach(filteredSessions) { session in
                            NavigationLink {
                                CrossTrainingDetailView(session: session)
                            } label: {
                                CrossTrainingRowView(session: session)
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                        .onDelete(perform: deleteSessions)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Cross Training")
            .searchable(text: $listVM.searchText, prompt: "Search sessions")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingLog = true
                    } label: {
                        Image(systemName: "plus.circle.fill").font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingLog) {
                LogCrossTrainingView()
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

// MARK: - Row

private struct CrossTrainingRowView: View {
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
                Image(systemName: activityType.systemImage)
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(session.title.isEmpty ? activityType.rawValue : session.title)
                    .font(.subheadline).bold()
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

            Text(session.formattedDuration)
                .font(.subheadline).bold()
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    CrossTrainingListView()
}
