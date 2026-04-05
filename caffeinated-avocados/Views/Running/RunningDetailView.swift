// Views/Running/RunningDetailView.swift
// Detailed view for a single running workout session.

import SwiftUI
import SwiftData

struct RunningDetailView: View {
    let session: WorkoutSession
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingEdit = false
    @State private var showingDeleteAlert = false

    private var run: RunningWorkout? { session.runningWorkout }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                DetailHeaderView(session: session, accentColor: .green)

                // Key Stats
                if let run = run {
                    SectionCard(title: "Stats") {
                        StatGrid {
                            StatItem(icon: "arrow.triangle.swap", label: "Distance", value: run.formattedDistance)
                            StatItem(icon: "timer", label: "Avg Pace", value: run.formattedPace)
                            StatItem(icon: "clock.fill", label: "Duration", value: session.formattedDuration)
                            if let cals = session.caloriesBurned {
                                StatItem(icon: "flame.fill", label: "Calories", value: "\(cals) cal")
                            }
                            if let hr = session.heartRateAvg {
                                StatItem(icon: "heart.fill", label: "Avg HR", value: "\(hr) bpm")
                            }
                            if let elev = run.elevationGainFeet {
                                StatItem(icon: "mountain.2.fill", label: "Elevation", value: String(format: "%.0f ft", elev))
                            }
                        }
                    }
                }

                // Run Details
                if let run = run {
                    SectionCard(title: "Details") {
                        LabeledContent("Type", value: run.runType.rawValue)
                        if let route = run.route, !route.isEmpty {
                            LabeledContent("Route", value: route)
                        }
                        if let cadence = run.cadenceAvg {
                            LabeledContent("Cadence", value: "\(cadence) spm")
                        }
                        LabeledContent("Intensity", value: session.intensityLevel.rawValue)
                    }
                }

                // Splits
                if let run = run, !run.splits.isEmpty {
                    SectionCard(title: "Splits") {
                        ForEach(run.splits) { split in
                            HStack {
                                Text("Mile \(split.splitNumber)")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(split.formattedPace)
                                    .bold()
                                if let hr = split.heartRateAvg {
                                    Text("\(hr) bpm")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                            }
                            .font(.subheadline)
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

                // Strava badge
                if let stravaId = session.stravaActivityId {
                    Label("Synced from Strava · ID \(stravaId)", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .navigationTitle("Run Details")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button("Edit") { showingEdit = true }
                    Button("Delete", role: .destructive) { showingDeleteAlert = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            LogRunningView(editingSession: session)
        }
        .alert("Delete Run?", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                modelContext.delete(session)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This run will be permanently removed.")
        }
    }
}

// MARK: - Shared Detail Components

struct DetailHeaderView: View {
    let session: WorkoutSession
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: session.type.systemImage)
                    .foregroundStyle(accentColor)
                Text(session.type.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if session.stravaActivityId != nil {
                    Label("Strava", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.regularMaterial, in: Capsule())
                }
                Spacer()
                Text(session.date.formatted(date: .long, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(session.title.isEmpty ? session.type.rawValue : session.title)
                .font(.title2).bold()
        }
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

struct StatGrid<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            content()
        }
    }
}

struct StatItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(.orange)
            Text(value)
                .font(.subheadline).bold()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
