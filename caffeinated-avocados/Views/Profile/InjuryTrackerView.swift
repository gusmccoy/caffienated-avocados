// Views/Profile/InjuryTrackerView.swift
// Injury & comeback tracker — log injuries, track recovery phases, and link
// comeback progress to a post-injury PR milestone era.

import SwiftUI
import SwiftData

// MARK: - Injury Tracker (embedded section for Profile)

struct InjuryStatusCard: View {
    @Query(sort: \InjuryRecord.startDate, order: .reverse)
    private var records: [InjuryRecord]

    @State private var showingTracker = false

    private var activeRecord: InjuryRecord? {
        records.first { $0.isActive }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let active = activeRecord {
                ActiveInjuryBanner(record: active) {
                    showingTracker = true
                }
            } else {
                Button {
                    showingTracker = true
                } label: {
                    HStack {
                        Label("Injury / Break Tracker", systemImage: "bandage")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(.primary)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingTracker) {
            InjuryTrackerSheetView(records: records)
        }
    }
}

// MARK: - Active Injury Banner

private struct ActiveInjuryBanner: View {
    let record: InjuryRecord
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: "bandage.fill")
                    .font(.title2)
                    .foregroundStyle(.red)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Currently Injured / On Break")
                        .font(.subheadline.weight(.semibold))
                    HStack(spacing: 6) {
                        Text(record.durationLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(record.recoveryPhase.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Injury Tracker Sheet

struct InjuryTrackerSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let records: [InjuryRecord]

    @State private var showingAddInjury = false
    @State private var editingRecord: InjuryRecord? = nil

    private var activeRecord: InjuryRecord? { records.first { $0.isActive } }
    private var pastRecords: [InjuryRecord] { records.filter { !$0.isActive } }

    var body: some View {
        NavigationStack {
            List {
                if let active = activeRecord {
                    Section("Current Status") {
                        ActiveRecordRow(record: active) {
                            editingRecord = active
                        } onMarkResolved: {
                            active.isActive = false
                            active.endDate = .now
                            if active.recoveryPhase != RecoveryPhase.fullTraining {
                                active.recoveryPhase = .fullTraining
                                var milestone = ComebackMilestone()
                                milestone.phase = .fullTraining
                                milestone.date = .now
                                milestone.notes = "Cleared to full training"
                                var ms = active.comebackMilestones
                                ms.append(milestone)
                                active.comebackMilestones = ms
                            }
                        }
                    }
                } else {
                    Section {
                        Button {
                            showingAddInjury = true
                        } label: {
                            Label("Log Injury or Break", systemImage: "plus.circle")
                                .foregroundStyle(.orange)
                        }
                    } footer: {
                        Text("Track injuries and extended breaks to silence notifications and monitor your comeback.")
                    }
                }

                if !pastRecords.isEmpty {
                    Section("Past Injuries") {
                        ForEach(pastRecords) { record in
                            PastRecordRow(record: record)
                        }
                        .onDelete { offsets in
                            for i in offsets { modelContext.delete(pastRecords[i]) }
                        }
                    }
                }
            }
            .navigationTitle("Injury Tracker")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddInjury = true
                    } label: {
                        Label("Log Injury", systemImage: "plus")
                    }
                    .disabled(activeRecord != nil)
                }
            }
            .sheet(isPresented: $showingAddInjury) {
                AddInjuryView()
            }
            .sheet(item: $editingRecord) { record in
                EditInjuryView(record: record)
            }
        }
    }
}

// MARK: - Active Record Row

private struct ActiveRecordRow: View {
    let record: InjuryRecord
    let onEdit: () -> Void
    let onMarkResolved: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if !record.injuryDescription.isEmpty {
                        Text(record.injuryDescription)
                            .font(.subheadline.weight(.medium))
                    }
                    Text("Started \(record.startDate.formatted(date: .abbreviated, time: .omitted)) · \(record.durationLabel) ago")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Edit") { onEdit() }
                    .font(.caption)
                    .buttonStyle(.bordered)
            }

            // Phase progress
            PhaseProgressView(currentPhase: record.recoveryPhase)

            // Comeback milestones
            if !record.comebackMilestones.isEmpty {
                Divider()
                ForEach(record.comebackMilestones) { ms in
                    HStack(spacing: 8) {
                        Image(systemName: ms.phase.systemImage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(ms.phase.rawValue)
                                .font(.caption.weight(.medium))
                            Text(ms.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Button("Mark as Resolved", action: onMarkResolved)
                .font(.subheadline)
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Past Record Row

private struct PastRecordRow: View {
    let record: InjuryRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(record.injuryDescription.isEmpty ? "Injury / Break" : record.injuryDescription)
                .font(.subheadline.weight(.medium))
            HStack(spacing: 6) {
                Text(record.startDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let end = record.endDate {
                    Text("→")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(end.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("·")
                    .foregroundStyle(.secondary)
                Text(record.durationLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Phase Progress View

private struct PhaseProgressView: View {
    let currentPhase: RecoveryPhase

    private let phases = RecoveryPhase.allCases

    var body: some View {
        HStack(spacing: 2) {
            ForEach(phases, id: \.self) { phase in
                let isReached = phases.firstIndex(of: phase)! <= phases.firstIndex(of: currentPhase)!
                VStack(spacing: 3) {
                    Image(systemName: phase.systemImage)
                        .font(.caption2)
                    Rectangle()
                        .frame(height: 3)
                        .cornerRadius(2)
                }
                .foregroundStyle(isReached ? .orange : .secondary.opacity(0.3))
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Add Injury Sheet

struct AddInjuryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var startDate = Date.now
    @State private var description = ""
    @State private var phase: RecoveryPhase = .resting
    @State private var createPRMilestone = false

    // PRMilestone context
    @Query(sort: \PRMilestone.orderIndex) private var existingMilestones: [PRMilestone]

    var body: some View {
        NavigationStack {
            Form {
                Section("Injury / Break") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    TextField("Description (e.g. Left knee strain)", text: $description)
                    Picker("Current Phase", selection: $phase) {
                        ForEach(RecoveryPhase.allCases, id: \.self) { p in
                            Label(p.rawValue, systemImage: p.systemImage).tag(p)
                        }
                    }
                }
                Section {
                    Toggle("Create a \"Post-Injury\" PR Milestone Era", isOn: $createPRMilestone)
                } footer: {
                    Text("Adds a milestone to your Profile so you can track PRs separately in your comeback phase.")
                }
            }
            .navigationTitle("Log Injury")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
    }

    private func save() {
        let record = InjuryRecord(
            startDate: startDate,
            injuryDescription: description,
            recoveryPhase: phase
        )
        modelContext.insert(record)

        if createPRMilestone {
            let label = description.isEmpty ? "Post-Injury" : "Post-\(description)"
            let milestone = PRMilestone(
                name: label,
                startDate: startDate,
                orderIndex: existingMilestones.count
            )
            modelContext.insert(milestone)
            record.linkedPRMilestoneId = milestone.id
        }

        dismiss()
    }
}

// MARK: - Edit Injury Sheet

struct EditInjuryView: View {
    @Environment(\.dismiss) private var dismiss
    let record: InjuryRecord

    @State private var phase: RecoveryPhase = .resting
    @State private var description = ""
    @State private var newMilestoneNote = ""
    @State private var showingAddMilestone = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Status") {
                    TextField("Description", text: $description)
                    Picker("Current Phase", selection: $phase) {
                        ForEach(RecoveryPhase.allCases, id: \.self) { p in
                            Label(p.rawValue, systemImage: p.systemImage).tag(p)
                        }
                    }
                }

                Section("Comeback Milestones") {
                    ForEach(record.comebackMilestones) { ms in
                        HStack(spacing: 8) {
                            Image(systemName: ms.phase.systemImage)
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading) {
                                Text(ms.phase.rawValue).font(.subheadline)
                                Text(ms.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption).foregroundStyle(.secondary)
                                if !ms.notes.isEmpty {
                                    Text(ms.notes).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    Button {
                        showingAddMilestone = true
                    } label: {
                        Label("Log New Milestone", systemImage: "plus.circle")
                    }
                    .foregroundStyle(.orange)
                }
            }
            .navigationTitle("Update Status")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        record.recoveryPhase = phase
                        record.injuryDescription = description
                        dismiss()
                    }
                }
            }
            .onAppear {
                phase = record.recoveryPhase
                description = record.injuryDescription
            }
            .sheet(isPresented: $showingAddMilestone) {
                AddComebackMilestoneView { milestone in
                    var ms = record.comebackMilestones
                    ms.append(milestone)
                    record.comebackMilestones = ms
                    // Update phase to the newest milestone
                    record.recoveryPhase = milestone.phase
                    phase = milestone.phase
                }
            }
        }
    }
}

// MARK: - Add Comeback Milestone

struct AddComebackMilestoneView: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (ComebackMilestone) -> Void

    @State private var phase: RecoveryPhase = .walking
    @State private var date = Date.now
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Phase", selection: $phase) {
                        ForEach(RecoveryPhase.allCases, id: \.self) { p in
                            Label(p.rawValue, systemImage: p.systemImage).tag(p)
                        }
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Notes (optional)", text: $notes)
                }
            }
            .navigationTitle("Log Milestone")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var ms = ComebackMilestone()
                        ms.phase = phase
                        ms.date = date
                        ms.notes = notes
                        onSave(ms)
                        dismiss()
                    }
                }
            }
        }
    }
}
