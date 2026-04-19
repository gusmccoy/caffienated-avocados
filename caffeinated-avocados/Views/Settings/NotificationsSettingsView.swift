// Views/Settings/NotificationsSettingsView.swift
// Manage enhanced rule-based workout notifications.

import SwiftUI
import SwiftData
import UserNotifications

struct NotificationsSettingsView: View {
    @Query(sort: \NotificationRule.createdAt) private var rules: [NotificationRule]
    @Query private var plannedWorkouts: [PlannedWorkout]
    @Query private var races: [Race]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAddRule = false
    @State private var editingRule: NotificationRule? = nil
    @State private var permissionGranted: Bool? = nil

    var body: some View {
        notificationsForm
            #if os(macOS)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, alignment: .center)
            #endif
            .navigationTitle("Notifications")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddRule = true
                    } label: {
                        Label("Add Rule", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddRule) {
                AddNotificationRuleView(existingRule: nil, onSave: { rule in
                    modelContext.insert(rule)
                    reschedule()
                })
            }
            .sheet(item: $editingRule) { rule in
                AddNotificationRuleView(existingRule: rule, onSave: { _ in
                    reschedule()
                })
            }
            .task { await checkPermission() }
    }

    private var notificationsForm: some View {
        Form {
            // Permission banner
            if permissionGranted == false {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notifications Disabled")
                                .font(.subheadline.weight(.semibold))
                            Text("Enable notifications in System Settings to receive workout reminders.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "bell.slash.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }

            if rules.isEmpty {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "bell.badge")
                            .font(.largeTitle)
                            .foregroundStyle(.orange.opacity(0.5))
                        Text("No notification rules yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(activateVerb) + to add reminders for meals, hydration, fuel plans, and more.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            } else {
                Section {
                    ForEach(rules) { rule in
                        NotificationRuleRow(rule: rule) {
                            editingRule = rule
                        } onToggle: {
                            rule.isEnabled.toggle()
                            reschedule()
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Delete", role: .destructive) {
                                modelContext.delete(rule)
                                reschedule()
                            }
                        }
                    }
                } header: {
                    Text("Active Rules")
                } footer: {
                    Text("Rules fire based on your upcoming planned workouts and races. \(swipeDeleteHint)")
                }
            }

            Section {
                Button("Refresh Scheduled Notifications") {
                    reschedule()
                }
                .foregroundStyle(.orange)
            } footer: {
                Text("\(activateVerb) to re-evaluate all rules against your current plan. Happens automatically on sync.")
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
    }

    private func reschedule() {
        EnhancedNotificationService.scheduleNotifications(
            rules: rules,
            plannedWorkouts: plannedWorkouts,
            races: races
        )
    }

    private func checkPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permissionGranted = settings.authorizationStatus == .authorized
    }
}

// MARK: - Rule Row

private struct NotificationRuleRow: View {
    let rule: NotificationRule
    let onEdit: () -> Void
    let onToggle: () -> Void

    var subtitle: String {
        switch rule.type {
        case .preWorkoutMeal, .hydration, .fuelPlan:
            let mins = rule.leadMinutes
            let h = mins / 60; let m = mins % 60
            let timeStr = h > 0 ? (m > 0 ? "\(h)h \(m)m" : "\(h)h") : "\(m)m"
            return "\(timeStr) before · \(rule.workoutFilter.rawValue)"
        case .upcomingRace:
            let days = rule.leadMinutes / 1440
            let hours = (rule.leadMinutes % 1440) / 60
            return days > 0 ? "\(days) day\(days == 1 ? "" : "s") before race" : "\(hours)h before race"
        case .longRunFuel:
            return "Every \(rule.leadMinutes) min during long runs"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: rule.type.systemImage)
                .foregroundStyle(rule.isEnabled ? .orange : .secondary)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.type.rawValue)
                    .font(.subheadline.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
        }
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
    }
}

// MARK: - Add / Edit Rule View

struct AddNotificationRuleView: View {
    let existingRule: NotificationRule?
    let onSave: (NotificationRule) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var ruleType: NotificationRuleType = .preWorkoutMeal
    @State private var leadHours: Int = 1
    @State private var leadMinutes: Int = 30
    @State private var workoutFilter: NotificationWorkoutFilter = .allWorkouts
    @State private var soundEnabled: Bool = true
    @State private var customMessage: String = ""

    private var totalLeadMinutes: Int { leadHours * 60 + leadMinutes }

    var body: some View {
        NavigationStack {
            Form {
                Section("Rule Type") {
                    Picker("Type", selection: $ruleType) {
                        ForEach(NotificationRuleType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.systemImage).tag(type)
                        }
                    }
                    .onChange(of: ruleType) { _, newType in
                        setDefaultLeadTime(for: newType)
                    }

                    Text(ruleType.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    HStack {
                        Text(ruleType == .longRunFuel ? "Every" : "Before")
                        Spacer()
                        Picker("Hours", selection: $leadHours) {
                            ForEach(0...23, id: \.self) { Text("\($0)h").tag($0) }
                        }
                        #if os(macOS)
                        .pickerStyle(.menu)
                        .frame(width: 80)
                        #else
                        .pickerStyle(.wheel)
                        .frame(width: 70)
                        .clipped()
                        #endif
                        Picker("Minutes", selection: $leadMinutes) {
                            ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) {
                                Text("\($0)m").tag($0)
                            }
                        }
                        #if os(macOS)
                        .pickerStyle(.menu)
                        .frame(width: 80)
                        #else
                        .pickerStyle(.wheel)
                        .frame(width: 70)
                        .clipped()
                        #endif
                    }
                    #if !os(macOS)
                    .frame(height: 90)
                    #endif
                } header: {
                    Text(ruleType == .longRunFuel ? "Interval" : "Lead Time")
                }

                if ruleType != .upcomingRace && ruleType != .longRunFuel {
                    Section("Applies To") {
                        Picker("Workouts", selection: $workoutFilter) {
                            ForEach(NotificationWorkoutFilter.allCases, id: \.self) {
                                Text($0.rawValue).tag($0)
                            }
                        }
                    }
                }

                Section("Delivery") {
                    Toggle("Play Sound", isOn: $soundEnabled)
                }

                Section {
                    TextField("Leave blank for the default message", text: $customMessage, axis: .vertical)
                        .lineLimit(3...5)
                } header: {
                    Text("Custom Message (optional)")
                } footer: {
                    Text("Overrides the default reminder message.")
                }
            }
            #if os(macOS)
            .formStyle(.grouped)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, alignment: .center)
            #endif
            .navigationTitle(existingRule == nil ? "Add Rule" : "Edit Rule")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(totalLeadMinutes == 0)
                }
            }
            .onAppear { populateIfEditing() }
        }
    }

    private func populateIfEditing() {
        guard let rule = existingRule else { return }
        ruleType      = rule.type
        leadHours     = rule.leadMinutes / 60
        leadMinutes   = rule.leadMinutes % 60
        workoutFilter = rule.workoutFilter
        soundEnabled  = rule.soundEnabled
        customMessage = rule.customMessage
    }

    private func setDefaultLeadTime(for type: NotificationRuleType) {
        let mins = type.defaultLeadMinutes
        leadHours   = mins / 60
        leadMinutes = mins % 60
    }

    private func save() {
        let rule = existingRule ?? NotificationRule(
            type: ruleType,
            workoutFilter: workoutFilter
        )
        rule.type          = ruleType
        rule.leadMinutes   = totalLeadMinutes
        rule.workoutFilter = workoutFilter
        rule.soundEnabled  = soundEnabled
        rule.customMessage = customMessage
        onSave(rule)
        dismiss()
    }
}
