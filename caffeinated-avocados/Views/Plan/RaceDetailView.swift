import SwiftUI
import SwiftData

struct RaceDetailView: View {
    var race: Race
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddItem = false
    @State private var newItemName = ""
    @State private var newItemCategory: PrepCategory = .gear
    @State private var isLoadingSuggestions = false

    private var racePrep: RacePrep? {
        race.racePrep
    }

    var completionPercentage: Double {
        guard let items = racePrep?.items, !items.isEmpty else { return 0 }
        let completed = items.filter { $0.isCompleted }.count
        return Double(completed) / Double(items.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Race info header
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "flag.checkered")
                            .font(.title2)
                            .foregroundStyle(.orange)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(race.name)
                                .font(.title3.weight(.semibold))
                            HStack(spacing: 8) {
                                Text(race.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("·")
                                    .foregroundStyle(.secondary)
                                Text(race.raceDistance.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(race.countdownLabel)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.orange)
                            if let loc = race.location.isEmpty ? nil : race.location {
                                Text(loc)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                // Prep checklist section
                if let prep = racePrep, !prep.items.isEmpty {
                    // Progress indicator
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Race Prep Progress")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(Int(prep.items.filter { $0.isCompleted }.count)) of \(prep.items.count)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        ProgressView(value: completionPercentage)
                            .tint(.orange)
                    }

                    // Items by category
                    ForEach(PrepCategory.allCases, id: \.self) { category in
                        let categoryItems = prep.items.filter { $0.category == category }
                        if !categoryItems.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(category.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.orange)

                                ForEach(categoryItems) { item in
                                    PrepItemRow(item: item, onToggle: { toggleItem(item) }, onDelete: { deleteItem(item) })
                                }
                            }
                        }
                    }
                } else {
                    // No prep checklist yet
                    VStack(spacing: 12) {
                        Image(systemName: "checklist")
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        Text("No prep checklist yet")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text("Get AI suggestions based on race distance and weather to build your prep checklist.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)

                        Button(action: generateSuggestions) {
                            if isLoadingSuggestions {
                                ProgressView()
                                    .tint(.orange)
                            } else {
                                Label("Get Suggestions", systemImage: "sparkles")
                            }
                        }
                        .disabled(isLoadingSuggestions || race.isPast)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.orange, in: Capsule())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }

                // Add item section
                if let prep = racePrep {
                    VStack(spacing: 8) {
                        if showingAddItem {
                            HStack(spacing: 8) {
                                TextField("Item name", text: $newItemName)
                                    .textFieldStyle(.roundedBorder)

                                Picker("Category", selection: $newItemCategory) {
                                    ForEach(PrepCategory.allCases, id: \.self) { category in
                                        Text(category.displayName).tag(category)
                                    }
                                }
                                .pickerStyle(.menu)

                                Button(action: addItem) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                                .disabled(newItemName.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        } else {
                            Button(action: { showingAddItem = true }) {
                                Label("Add Item", systemImage: "plus.circle")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.orange)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Race Prep")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func generateSuggestions() {
        isLoadingSuggestions = true
        Task { @MainActor in
            do {
                let suggestions = try await RacePrepSuggestionService.generateSuggestions(for: race)

                // Create or update RacePrep
                if race.racePrep == nil {
                    let newPrep = RacePrep()
                    modelContext.insert(newPrep)
                    race.racePrep = newPrep
                }

                // Add suggested items (items is a computed property on Data, so reassign)
                if let prep = race.racePrep {
                    var updated = prep.items
                    updated.append(contentsOf: suggestions)
                    prep.items = updated
                    try modelContext.save()
                }

                isLoadingSuggestions = false
            } catch {
                print("Error generating suggestions: \(error)")
                isLoadingSuggestions = false
            }
        }
    }

    private func toggleItem(_ item: PrepItem) {
        guard let prep = racePrep else { return }
        var updated = prep.items
        if let idx = updated.firstIndex(where: { $0.id == item.id }) {
            updated[idx].isCompleted.toggle()
            prep.items = updated
            try? modelContext.save()
        }
    }

    private func deleteItem(_ item: PrepItem) {
        guard let prep = racePrep else { return }
        var updated = prep.items
        updated.removeAll { $0.id == item.id }
        prep.items = updated
        try? modelContext.save()
    }

    private func addItem() {
        let newItem = PrepItem(name: newItemName, category: newItemCategory)

        // Create or update RacePrep
        if race.racePrep == nil {
            let newPrep = RacePrep()
            modelContext.insert(newPrep)
            race.racePrep = newPrep
        }

        if let prep = race.racePrep {
            var updated = prep.items
            updated.append(newItem)
            prep.items = updated
            try? modelContext.save()
        }

        // Reset form
        newItemName = ""
        newItemCategory = .gear
        showingAddItem = false
    }
}

// MARK: - Prep Item Row

private struct PrepItemRow: View {
    let item: PrepItem
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isCompleted ? .green : .gray.opacity(0.5))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline.weight(.medium))
                    .strikethrough(item.isCompleted, color: .secondary)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)

                if !item.notes.isEmpty {
                    Text(item.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let dueDate = item.dueDate {
                    Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.red.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(item.isCompleted ? Color.green.opacity(0.05) : Color.gray.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    let race = Race(name: "Spring Marathon", date: Date(timeIntervalSinceNow: 86400 * 30), raceDistance: .marathon, location: "San Francisco, CA")
    NavigationStack {
        RaceDetailView(race: race)
    }
}
