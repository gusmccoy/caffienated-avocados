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
    @State private var plannerVM = PlannerViewModel()
    @Query private var connections: [StravaConnection]
    @Query private var allRelationships: [PlannerRelationship]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            settingsForm
                #if os(macOS)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity, alignment: .center)
                #endif
                .navigationTitle("Settings")
                .alert("Error", isPresented: .constant(stravaVM.errorMessage != nil)) {
                    Button("OK") { stravaVM.errorMessage = nil }
                } message: {
                    Text(stravaVM.errorMessage ?? "")
                }
        }
    }

    private var settingsForm: some View {
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
                        Text("These manual entries were replaced because a matching Strava activity was found on the same day. \(activateVerb) Undo to restore them.")
                    }
                }
            }

            // Reminders
            Section {
                PlanningReminderRow()
                NavigationLink("Workout Reminders") {
                    NotificationsSettingsView()
                }
            } header: {
                Text("Reminders")
            } footer: {
                Text("Sunday reminder plans next week. Workout Reminders let you set rule-based alerts for meals, hydration, fuel plans, and races.")
            }

            // Planner / Coach relationship
            PlannerSettingsSection(plannerVM: plannerVM, allRelationships: allRelationships, modelContext: modelContext)

            // Preferences
            Section("Display") {
                NavigationLink("Units & Measurements") {
                    UnitsPreferenceView()
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
        #if os(macOS)
        .formStyle(.grouped)
        #endif
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
    @AppStorage("planCompletionThreshold") private var planCompletionThreshold: Double = 5.0
    @AppStorage("defaultPaceSecondsPerMile") private var defaultPaceSecondsPerMile: Int = 0
    @AppStorage("defaultPlannedTimeMinutesSinceMidnight") private var defaultPlannedTimeMinutes: Int = 0

    private var paceMinutes: Int { defaultPaceSecondsPerMile / 60 }
    private var paceSeconds: Int { defaultPaceSecondsPerMile % 60 }

    /// Converts defaultPlannedTimeMinutes ↔ a full Date (time component only) for DatePicker.
    private var defaultPlannedTimeBinding: Binding<Date> {
        Binding(
            get: {
                let mins = defaultPlannedTimeMinutes > 0 ? defaultPlannedTimeMinutes : 360
                return Calendar.current.date(
                    bySettingHour: mins / 60,
                    minute: mins % 60,
                    second: 0,
                    of: .now
                ) ?? .now
            },
            set: { date in
                let h = Calendar.current.component(.hour, from: date)
                let m = Calendar.current.component(.minute, from: date)
                defaultPlannedTimeMinutes = h * 60 + m
            }
        )
    }

    var body: some View {
        unitsForm
            #if os(macOS)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, alignment: .center)
            #endif
            .navigationTitle("Units & Matching")
    }

    private var unitsForm: some View {
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
            Section {
                Stepper(value: $planCompletionThreshold, in: 1...25, step: 1) {
                    HStack {
                        Text("Completion Threshold")
                        Spacer()
                        Text("\(Int(planCompletionThreshold))%")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Plan Matching")
            } footer: {
                Text("When a synced activity is within this percentage of a planned workout's distance or duration, the planned workout is marked as completed.")
            }
            Section {
                Toggle("Set a default time", isOn: Binding(
                    get: { defaultPlannedTimeMinutes > 0 },
                    set: { enabled in
                        defaultPlannedTimeMinutes = enabled ? 360 : 0  // default to 6 AM when first enabled
                    }
                ))
                if defaultPlannedTimeMinutes > 0 {
                    DatePicker(
                        "Default Time",
                        selection: defaultPlannedTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                }
            } header: {
                Text("Default Planned Workout Time")
            } footer: {
                Text("When adding a new planned workout, the time field will be pre-filled with this value. You can override it per workout.")
            }

            Section {
                Stepper(value: Binding(
                    get: { paceMinutes },
                    set: { defaultPaceSecondsPerMile = $0 * 60 + paceSeconds }
                ), in: 0...30) {
                    HStack {
                        Text("Minutes")
                        Spacer()
                        Text("\(paceMinutes)")
                            .foregroundStyle(.secondary)
                    }
                }
                Stepper(value: Binding(
                    get: { paceSeconds },
                    set: { defaultPaceSecondsPerMile = paceMinutes * 60 + $0 }
                ), in: 0...59) {
                    HStack {
                        Text("Seconds")
                        Spacer()
                        Text(String(format: "%02d", paceSeconds))
                            .foregroundStyle(.secondary)
                    }
                }
                if defaultPaceSecondsPerMile > 0 {
                    HStack {
                        Text("Default pace")
                        Spacer()
                        Text(String(format: "%d:%02d /mi", paceMinutes, paceSeconds))
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Default Running Pace")
            } footer: {
                Text("Used to estimate distance for planned runs that have a duration but no set distance. Shown as ~X mi in the plan.")
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
    }
}


// MARK: - Planning Reminder Row

private struct PlanningReminderRow: View {
    @AppStorage("planningReminderEnabled") private var enabled: Bool = false
    @AppStorage("planningReminderMinutesSinceMidnight") private var reminderMinutes: Int = 720

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                let mins = reminderMinutes > 0 ? reminderMinutes : 720
                return Calendar.current.date(
                    bySettingHour: mins / 60,
                    minute: mins % 60,
                    second: 0,
                    of: .now
                ) ?? .now
            },
            set: { date in
                let h = Calendar.current.component(.hour, from: date)
                let m = Calendar.current.component(.minute, from: date)
                reminderMinutes = h * 60 + m
                WeeklyPlanningReminderService.scheduleReminder(hour: h, minute: m)
            }
        )
    }

    var body: some View {
        Toggle("Sunday Planning Reminder", isOn: Binding(
            get: { enabled },
            set: { newValue in
                enabled = newValue
                if newValue {
                    Task {
                        await WeeklyPlanningReminderService.requestPermission()
                        let mins = reminderMinutes > 0 ? reminderMinutes : 720
                        WeeklyPlanningReminderService.scheduleReminder(hour: mins / 60, minute: mins % 60)
                    }
                } else {
                    WeeklyPlanningReminderService.cancelReminder()
                }
            }
        ))

        if enabled {
            DatePicker("Reminder Time", selection: reminderTime, displayedComponents: .hourAndMinute)
        }
    }
}

// MARK: - Planner Settings Section

/// The "Planner" block in Settings — shown to both athletes (managing their coach) and
/// planners (entering a code to accept access to an athlete).
struct PlannerSettingsSection: View {
    @Bindable var plannerVM: PlannerViewModel
    let allRelationships: [PlannerRelationship]
    let modelContext: ModelContext

    // Athlete side: pending outgoing invites
    private var pendingInvites: [PlannerRelationship] {
        allRelationships.filter { $0.currentUserIsAthlete && $0.status == .pendingOutgoing }
    }

    // Athlete side: accepted planner relationship (at most one)
    private var activePlannerRelationship: PlannerRelationship? {
        allRelationships.first { $0.currentUserIsAthlete && $0.status == .accepted }
    }

    // Planner side: accepted coaching relationships (one per athlete)
    private var coachingRelationships: [PlannerRelationship] {
        allRelationships.filter { !$0.currentUserIsAthlete && $0.status == .accepted }
    }

    var body: some View {
        // Athlete section — only shown when relevant (has a planner or pending invite)
        if activePlannerRelationship != nil || !pendingInvites.isEmpty {
            Section {
                if let active = activePlannerRelationship {
                    activePlannerRow(active)
                }
                ForEach(pendingInvites) { invite in
                    pendingInviteRow(invite)
                        .task(id: invite.id) {
                            await plannerVM.checkPendingInviteAcceptance(invite: invite, modelContext: modelContext)
                        }
                }
            } header: {
                Label("Your Planner", systemImage: "person.badge.shield.checkmark.fill")
            } footer: {
                Text("Your planner can add, edit, and remove planned workouts on your behalf. They cannot see your logged activities, health data, or Strava data.")
            }
        }

        // Coaching section — shown when user is coaching someone
        if !coachingRelationships.isEmpty {
            Section {
                ForEach(coachingRelationships) { rel in
                    coachingRow(rel)
                }
            } header: {
                Label("Athletes You Coach", systemImage: "person.2.fill")
            } footer: {
                Text("You can add, edit, and remove planned workouts for these athletes from the Athletes tab.")
            }
        }

        // Actions
        Section {
            // Generate invite (athlete inviting a planner) — only if no planner yet and no pending invite
            if activePlannerRelationship == nil && pendingInvites.isEmpty {
                Button {
                    plannerVM.generatedInviteCode = ""  // ensure name-entry phase
                    plannerVM.publishError = nil
                    plannerVM.isShowingInviteSheet = true
                } label: {
                    Label("Invite a Coach", systemImage: "person.badge.plus")
                }
            }

            // Accept an invite (planner entering athlete's code)
            Button {
                plannerVM.isShowingAcceptSheet = true
            } label: {
                Label("Enter Athlete's Invite Code", systemImage: "qrcode")
            }
        } header: {
            Text("Planner")
        } footer: {
            Text("Athletes send you an invite code; enter it here to become their planner. Or invite a coach to manage your training plan.")
        }
        .sheet(isPresented: $plannerVM.isShowingInviteSheet) {
            InviteCodeSheet(plannerVM: plannerVM, modelContext: modelContext)
        }
        .sheet(isPresented: $plannerVM.isShowingAcceptSheet) {
            AcceptInviteSheet(plannerVM: plannerVM, modelContext: modelContext)
        }
    }

    // MARK: - Row Views

    @ViewBuilder
    private func activePlannerRow(_ rel: PlannerRelationship) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.purple)
            VStack(alignment: .leading, spacing: 2) {
                Text(rel.plannerDisplayName)
                    .font(.subheadline.weight(.semibold))
                Text("Active planner")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Revoke", role: .destructive) {
                plannerVM.revoke(rel, modelContext: modelContext)
            }
            .font(.caption)
        }
    }

    @ViewBuilder
    private func pendingInviteRow(_ invite: PlannerRelationship) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.badge.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Invite pending")
                    .font(.subheadline.weight(.semibold))
                Text("Code: \(invite.inviteCode)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                plannerVM.isShowingInviteSheet = true
                plannerVM.generatedInviteCode = invite.inviteCode
            } label: {
                Image(systemName: "square.on.square")
            }
            .font(.subheadline)
            .foregroundStyle(.orange)

            Button(role: .destructive) {
                plannerVM.cancelInvite(invite, modelContext: modelContext)
            } label: {
                Image(systemName: "xmark.circle")
            }
            .font(.subheadline)
        }
    }

    @ViewBuilder
    private func coachingRow(_ rel: PlannerRelationship) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(rel.athleteDisplayName)
                    .font(.subheadline.weight(.semibold))
                Text("You are their planner")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Remove", role: .destructive) {
                plannerVM.revoke(rel, modelContext: modelContext)
            }
            .font(.caption)
        }
    }
}

// MARK: - Invite Code Sheet (athlete shares their code)

private struct InviteCodeSheet: View {
    @Bindable var plannerVM: PlannerViewModel
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss

    @State private var athleteName: String = ""

    var body: some View {
        NavigationStack {
            if plannerVM.generatedInviteCode.isEmpty {
                nameEntryView
            } else {
                codeDisplayView
            }
        }
    }

    // MARK: Phase 1 — name entry

    private var nameEntryView: some View {
        Form {
            Section {
                TextField("Your name (shown to your coach)", text: $athleteName)
                    .autocorrectionDisabled()
            } header: {
                Text("Your Name")
            } footer: {
                Text("This is how your coach will see you in their app.")
            }
        }
        .navigationTitle("Invite a Coach")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Generate Code") {
                    let name = athleteName.trimmingCharacters(in: .whitespacesAndNewlines)
                    plannerVM.currentUserName = name.isEmpty ? plannerVM.currentUserName : name
                    plannerVM.generateInvite(
                        athleteDisplayName: name.isEmpty ? (plannerVM.currentUserName.isEmpty ? "Athlete" : plannerVM.currentUserName) : name,
                        modelContext: modelContext
                    )
                }
                .disabled(false)
            }
        }
        .onAppear {
            athleteName = plannerVM.currentUserName
        }
    }

    // MARK: Phase 2 — code display

    private var codeDisplayView: some View {
        VStack(spacing: 28) {
            VStack(spacing: 12) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)

                Text("Invite a Coach")
                    .font(.title2.weight(.bold))

                Text("Share this code with your coach. Once they enter it in their app, they'll be able to manage your training plan.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Text(plannerVM.generatedInviteCode)
                .font(.system(.title, design: .monospaced, weight: .bold))
                .tracking(6)
                .foregroundStyle(.orange)
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))

            Button {
                plannerVM.copyToClipboard(plannerVM.generatedInviteCode)
            } label: {
                Label(
                    plannerVM.isCopied ? "Copied!" : "Copy Code",
                    systemImage: plannerVM.isCopied ? "checkmark" : "doc.on.doc"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding(.horizontal)
            .disabled(plannerVM.isPublishingInvite)

            if plannerVM.isPublishingInvite {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Publishing invite…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let err = plannerVM.publishError {
                VStack(spacing: 8) {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task {
                            await plannerVM.publishToCloudKit(
                                code: plannerVM.generatedInviteCode,
                                athleteDisplayName: plannerVM.currentUserName.isEmpty ? "Athlete" : plannerVM.currentUserName
                            )
                        }
                    }
                    .font(.caption)
                }
            } else {
                Text("This invite is valid until cancelled in Settings.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.top, 32)
        .navigationTitle("Your Invite Code")
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

// MARK: - Accept Invite Sheet (planner enters athlete's code)

private struct AcceptInviteSheet: View {
    @Bindable var plannerVM: PlannerViewModel
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss

    @State private var myName: String = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. A1B2C3D4", text: $plannerVM.acceptCodeInput)
                        #if os(iOS)
                        .textInputAutocapitalization(.characters)
                        #endif
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                } header: {
                    Text("Athlete's Invite Code")
                } footer: {
                    Text("Ask the athlete to share their invite code from Settings → Planner.")
                }

                Section {
                    TextField("Your name (shown to athlete)", text: $myName)
                } header: {
                    Text("Your Name")
                } footer: {
                    Text("This is how the athlete will see you in their app.")
                }

                if let error = plannerVM.acceptError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Accept Invite")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #if os(macOS)
            .formStyle(.grouped)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        plannerVM.acceptError = nil
                        plannerVM.acceptCodeInput = ""
                        dismiss()
                    }
                    .disabled(isLoading)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button("Accept") { accept() }
                            .disabled(plannerVM.acceptCodeInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }

    private func accept() {
        isLoading = true
        Task {
            await plannerVM.acceptInvite(
                code: plannerVM.acceptCodeInput,
                plannerDisplayName: myName,
                modelContext: modelContext
            )
            isLoading = false
            if plannerVM.acceptError == nil {
                dismiss()
            }
        }
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
