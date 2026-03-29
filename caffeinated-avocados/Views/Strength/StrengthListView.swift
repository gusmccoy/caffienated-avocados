// Views/Strength/StrengthListView.swift
// List of all logged strength training sessions.

import SwiftUI
import SwiftData

struct StrengthListView: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]

    @State private var listVM = WorkoutListViewModel()
    @State private var showingLog = false

    private var filteredSessions: [WorkoutSession] {
        listVM.filter(sessions, typesOverride: [.strength])
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredSessions.isEmpty {
                    ContentUnavailableView(
                        "No Strength Sessions Yet",
                        systemImage: "dumbbell.fill",
                        description: Text("Tap + to log your first workout.")
                    )
                } else {
                    List {
                        ForEach(filteredSessions) { session in
                            NavigationLink {
                                StrengthDetailView(session: session)
                            } label: {
                                StrengthRowView(session: session)
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                        .onDelete(perform: deleteSessions)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Strength")
            .searchable(text: $listVM.searchText, prompt: "Search workouts")
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
                LogStrengthView()
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

private struct StrengthRowView: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(session.title.isEmpty ? "Strength" : session.title)
                    .font(.subheadline).bold()
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
                Text(session.formattedDuration)
                    .font(.subheadline).bold()
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

#Preview {
    StrengthListView()
}
