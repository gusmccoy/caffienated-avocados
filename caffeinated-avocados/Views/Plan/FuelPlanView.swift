// Views/Plan/FuelPlanView.swift
// View for editing the fuel and nutrition plan attached to a planned workout or race.

import SwiftUI
import SwiftData

struct FuelPlanView: View {
    /// Pass the existing FuelPlan, or nil to create a new one lazily.
    let fuelPlan: FuelPlan?
    /// Called with the created or updated plan (caller inserts it into the model context).
    let onSave: (FuelPlan) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Work on a local copy; only write back to the passed-in plan (or a new plan) on Save.
    @State private var preNotes: String = ""
    @State private var preCarbsGrams: String = ""
    @State private var preProteinGrams: String = ""
    @State private var preFluidsMl: String = ""

    @State private var postNotes: String = ""
    @State private var postCarbsGrams: String = ""
    @State private var postProteinGrams: String = ""
    @State private var postFluidsMl: String = ""

    @State private var generalNotes: String = ""
    @State private var entries: [FuelEntry] = []

    @State private var showingAddEntry = false
    @State private var editingEntry: FuelEntry? = nil

    var body: some View {
        NavigationStack {
            fuelForm
                #if os(macOS)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity, alignment: .center)
                #endif
                .navigationTitle("Fuel Plan")
                #if !os(macOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { save() }
                    }
                }
                .onAppear { populate() }
                .sheet(isPresented: $showingAddEntry) {
                    AddFuelEntryView(existingEntry: nil) { newEntry in
                        entries.append(newEntry)
                    }
                }
                .sheet(item: $editingEntry) { entry in
                    AddFuelEntryView(existingEntry: entry) { updated in
                        if let idx = entries.firstIndex(where: { $0.id == updated.id }) {
                            entries[idx] = updated
                        }
                    }
                }
        }
    }

    // MARK: - Form

    private var fuelForm: some View {
        Form {
            // MARK: Pre-Workout
            Section {
                TextField("e.g. Oatmeal + coffee 2h before", text: $preNotes, axis: .vertical)
                    .lineLimit(3...5)
                MacroRow(label: "Carbs (g)", value: $preCarbsGrams)
                MacroRow(label: "Protein (g)", value: $preProteinGrams)
                MacroRow(label: "Fluids (ml)", value: $preFluidsMl)
            } header: {
                Label("Pre-Workout", systemImage: FuelPhase.pre.systemImage)
            }

            // MARK: Mid-Workout Entries
            Section {
                let midEntries = entries.filter { $0.phase == .mid }.sorted { $0.timingMinutes < $1.timingMinutes }
                let preEntries = entries.filter { $0.phase == .pre }
                let postEntries = entries.filter { $0.phase == .post }

                let allEntries = preEntries + midEntries + postEntries

                if allEntries.isEmpty {
                    Text("No items yet — tap Add to plan gels, fluids, and food.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(allEntries) { entry in
                        FuelEntryRow(entry: entry) {
                            editingEntry = entry
                        } onDelete: {
                            entries.removeAll { $0.id == entry.id }
                        } onToggleConsumed: {
                            if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
                                entries[idx].isConsumed.toggle()
                            }
                        }
                    }
                }

                Button {
                    showingAddEntry = true
                } label: {
                    Label("Add Fuel Item", systemImage: "plus.circle")
                }
            } header: {
                Label("Fuel Items", systemImage: FuelPhase.mid.systemImage)
            } footer: {
                Text("Add gels, chews, fluids, and food with timing cues. Mark items consumed when you log the workout.")
            }

            // MARK: Post-Workout
            Section {
                TextField("e.g. Protein shake + banana within 30 min", text: $postNotes, axis: .vertical)
                    .lineLimit(3...5)
                MacroRow(label: "Carbs (g)", value: $postCarbsGrams)
                MacroRow(label: "Protein (g)", value: $postProteinGrams)
                MacroRow(label: "Fluids (ml)", value: $postFluidsMl)
            } header: {
                Label("Post-Workout", systemImage: FuelPhase.post.systemImage)
            }

            // MARK: General Notes
            Section("Notes") {
                TextField("Any other nutrition notes...", text: $generalNotes, axis: .vertical)
                    .lineLimit(3...8)
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
    }

    // MARK: - Helpers

    private func populate() {
        guard let plan = fuelPlan else { return }
        preNotes       = plan.preNotes
        preCarbsGrams  = plan.preCarbsGrams.map(String.init) ?? ""
        preProteinGrams = plan.preProteinGrams.map(String.init) ?? ""
        preFluidsMl    = plan.preFluidsMl.map(String.init) ?? ""

        postNotes      = plan.postNotes
        postCarbsGrams = plan.postCarbsGrams.map(String.init) ?? ""
        postProteinGrams = plan.postProteinGrams.map(String.init) ?? ""
        postFluidsMl   = plan.postFluidsMl.map(String.init) ?? ""

        generalNotes   = plan.generalNotes
        entries        = plan.entries
    }

    private func save() {
        let plan = fuelPlan ?? FuelPlan()

        plan.preNotes       = preNotes
        plan.preCarbsGrams  = Int(preCarbsGrams)
        plan.preProteinGrams = Int(preProteinGrams)
        plan.preFluidsMl    = Int(preFluidsMl)

        plan.postNotes      = postNotes
        plan.postCarbsGrams = Int(postCarbsGrams)
        plan.postProteinGrams = Int(postProteinGrams)
        plan.postFluidsMl   = Int(postFluidsMl)

        plan.generalNotes   = generalNotes
        plan.entries        = entries

        onSave(plan)
        dismiss()
    }
}

// MARK: - Macro Row

private struct MacroRow: View {
    let label: String
    @Binding var value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("—", text: $value)
                #if !os(macOS)
                .keyboardType(.numberPad)
                #endif
                .multilineTextAlignment(.trailing)
                .frame(width: 70)
        }
    }
}

// MARK: - Fuel Entry Row

private struct FuelEntryRow: View {
    let entry: FuelEntry
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleConsumed: () -> Void

    var timingLabel: String {
        switch entry.phase {
        case .pre:  return "Pre"
        case .post: return "Post"
        case .mid:
            let h = entry.timingMinutes / 60
            let m = entry.timingMinutes % 60
            return h > 0 ? "\(h)h \(m)m" : "\(m)m"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: entry.type.systemImage)
                .foregroundStyle(entry.isConsumed ? .green : .orange)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.displayName)
                        .font(.subheadline.weight(.medium))
                        .strikethrough(entry.isConsumed)
                    if !entry.quantity.isEmpty {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(entry.quantity)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 6) {
                    Text(timingLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let carbs = entry.carbsGrams {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(carbs)g carbs")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Button {
                onToggleConsumed()
            } label: {
                Image(systemName: entry.isConsumed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(entry.isConsumed ? .green : .secondary)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) { onDelete() }
        }
        .contextMenu {
            Button("Edit") { onEdit() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }
}

// MARK: - Add Fuel Entry View

struct AddFuelEntryView: View {
    let existingEntry: FuelEntry?
    let onSave: (FuelEntry) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var itemType: FuelItemType = .gel
    @State private var phase: FuelPhase = .mid
    @State private var timingMinutes: Int = 45
    @State private var quantity: String = ""
    @State private var carbsGrams: String = ""
    @State private var caloriesKcal: String = ""
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name (e.g. GU Salted Caramel)", text: $name)
                    Picker("Type", selection: $itemType) {
                        ForEach(FuelItemType.allCases, id: \.self) {
                            Label($0.rawValue, systemImage: $0.systemImage).tag($0)
                        }
                    }
                }

                Section("Timing") {
                    Picker("Phase", selection: $phase) {
                        ForEach(FuelPhase.allCases, id: \.self) {
                            Label($0.rawValue, systemImage: $0.systemImage).tag($0)
                        }
                    }
                    if phase == .mid {
                        Stepper("At \(timingMinutes) min", value: $timingMinutes, in: 5...600, step: 5)
                    }
                }

                Section("Amount") {
                    TextField("e.g. 1 gel, 500 ml, 2 pieces", text: $quantity)
                    HStack {
                        Text("Carbs (g)")
                        Spacer()
                        TextField("—", text: $carbsGrams)
                            #if !os(macOS)
                            .keyboardType(.numberPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                    HStack {
                        Text("Calories (kcal)")
                        Spacer()
                        TextField("—", text: $caloriesKcal)
                            #if !os(macOS)
                            .keyboardType(.numberPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                }

                Section("Notes") {
                    TextField("Optional", text: $notes)
                }
            }
            #if os(macOS)
            .formStyle(.grouped)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, alignment: .center)
            #endif
            .navigationTitle(existingEntry == nil ? "Add Fuel Item" : "Edit Fuel Item")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear { populateIfEditing() }
        }
    }

    private func populateIfEditing() {
        guard let e = existingEntry else { return }
        name         = e.name
        itemType     = e.type
        phase        = e.phase
        timingMinutes = e.timingMinutes
        quantity     = e.quantity
        carbsGrams   = e.carbsGrams.map(String.init) ?? ""
        caloriesKcal = e.caloriesKcal.map(String.init) ?? ""
        notes        = e.notes
    }

    private func save() {
        var entry = existingEntry ?? FuelEntry()
        entry.name         = name
        entry.typeRaw      = itemType.rawValue
        entry.phaseRaw     = phase.rawValue
        entry.timingMinutes = phase == .mid ? timingMinutes : 0
        entry.quantity     = quantity
        entry.carbsGrams   = Int(carbsGrams)
        entry.caloriesKcal = Int(caloriesKcal)
        entry.notes        = notes
        onSave(entry)
        dismiss()
    }
}
