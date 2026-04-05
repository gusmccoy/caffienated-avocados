// Views/Settings/SettingsView.swift
// App settings: Strava connection, preferences, and about info.

import SwiftUI
import SwiftData
import AuthenticationServices
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct SettingsView: View {
    @State private var stravaVM = StravaViewModel()
    @Query private var connections: [StravaConnection]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingOverrideSummary = false

    var body: some View {
        NavigationStack {
            Form {
                // Strava
                Section {
                    StravaConnectionRow(vm: stravaVM, modelContext: modelContext)
                } header: {
                    Text("Strava")
                } footer: {
                    Text("Connect Strava to automatically import your activities.")
                }

                // Sync
                if stravaVM.isConnected {
                    Section("Sync") {
                        Button {
                            Task { await stravaVM.syncActivities(modelContext: modelContext) }
                        } label: {
                            HStack {
                                Label("Sync Activities Now", systemImage: "arrow.triangle.2.circlepath")
                                Spacer()
                                if stravaVM.isLoading {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(stravaVM.isLoading)

                        if let lastSync = stravaVM.lastSyncDate {
                            LabeledContent("Last Synced") {
                                Text(lastSync.formatted(date: .abbreviated, time: .shortened))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Override notifications — shown after a sync that replaced manual entries
                    if !stravaVM.overrideResults.isEmpty {
                        Section {
                            ForEach(stravaVM.overrideResults) { result in
                                OverrideResultRow(result: result, vm: stravaVM, modelContext: modelContext)
                            }
                        } header: {
                            Label("Overridden by Strava", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        } footer: {
                            Text("These manual entries were replaced because a matching Strava activity was found on the same day. Tap Undo to restore them.")
                        }
                    }
                }

                // Preferences
                Section("Display") {
                    NavigationLink("Units & Measurements") {
                        UnitsPreferenceView()
                    }
                }

                // Data
                Section("Data") {
                    NavigationLink("Export Workouts") {
                        ExportView()
                    }
                }

                // About
                Section("About") {
                    LabeledContent("Version") {
                        Text(Bundle.main.appVersion)
                            .foregroundStyle(.secondary)
                    }
                    Link("Strava API Docs", destination: URL(string: "https://developers.strava.com")!)
                    Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Error", isPresented: .constant(stravaVM.errorMessage != nil)) {
                Button("OK") { stravaVM.errorMessage = nil }
            } message: {
                Text(stravaVM.errorMessage ?? "")
            }
        }
    }
}

// MARK: - Override Result Row

private struct OverrideResultRow: View {
    let result: OverrideResult
    let vm: StravaViewModel
    let modelContext: ModelContext

    private var manualTitle: String {
        let snap = result.snapshot
        return snap.title.isEmpty ? snap.type.rawValue : snap.title
    }

    private var dateString: String {
        result.snapshot.date.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.subheadline)

            VStack(alignment: .leading, spacing: 2) {
                Text("\"\(manualTitle)\" on \(dateString)")
                    .font(.subheadline)
                Text("Replaced by Strava: \"\(result.stravaActivityTitle)\"")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Undo") {
                vm.undoOverride(result, modelContext: modelContext)
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .tint(.orange)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Strava Connection Row

private struct StravaConnectionRow: View {
    let vm: StravaViewModel
    let modelContext: ModelContext

    var body: some View {
        if vm.isConnected {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                VStack(alignment: .leading) {
                    Text(vm.connectedAthlete?.fullName ?? "Connected")
                        .font(.subheadline).bold()
                    Text("@\(vm.connectedAthlete?.username ?? "")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Disconnect", role: .destructive) {
                    vm.disconnect()
                }
                .font(.caption)
            }
        } else {
            Button {
                Task {
                    #if canImport(UIKit)
                    guard let window = UIApplication.shared.connectedScenes
                        .compactMap({ $0 as? UIWindowScene })
                        .first?.windows.first(where: { $0.isKeyWindow })
                    else { return }
                    await vm.connect(presentationAnchor: window)
                    #elseif canImport(AppKit)
                    guard let window = NSApplication.shared.keyWindow
                        ?? NSApplication.shared.mainWindow
                        ?? NSApplication.shared.windows.first(where: { $0.isVisible })
                    else { return }
                    await vm.connect(presentationAnchor: window)
                    #endif
                }
            } label: {
                HStack {
                    Image(systemName: "link")
                    Text("Connect Strava")
                    Spacer()
                    if vm.isLoading {
                        ProgressView()
                    }
                }
            }
            .disabled(vm.isLoading)
        }
    }
}

// MARK: - Placeholder Sub-views

struct UnitsPreferenceView: View {
    @AppStorage("distanceUnit") private var distanceUnit: String = DistanceUnit.miles.rawValue
    @AppStorage("weightUnit")   private var weightUnit: String   = WeightUnit.lbs.rawValue

    var body: some View {
        Form {
            Section("Distance") {
                Picker("Unit", selection: $distanceUnit) {
                    ForEach(DistanceUnit.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
            }
            Section("Weight") {
                Picker("Unit", selection: $weightUnit) {
                    ForEach(WeightUnit.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
            }
        }
        .navigationTitle("Units")
    }
}

struct ExportView: View {
    @Query private var sessions: [WorkoutSession]

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.and.arrow.up.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Export \(sessions.count) Workouts")
                .font(.title3).bold()
            Text("Export coming soon — workouts will be available as CSV or JSON.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Export")
    }
}

// MARK: - Workout Filter Sheet (shared across list views)

struct WorkoutFilterSheet: View {
    let listVM: WorkoutListViewModel
    let workoutType: WorkoutType
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Date Range") {
                    Picker("Range", selection: Bindable(listVM).selectedDateRange) {
                        ForEach(WorkoutListViewModel.DateRange.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.inline)
                }
                Section("Sort By") {
                    Picker("Sort", selection: Bindable(listVM).sortOrder) {
                        ForEach(WorkoutListViewModel.SortOrder.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.inline)
                }
            }
            .navigationTitle("Filter & Sort")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
