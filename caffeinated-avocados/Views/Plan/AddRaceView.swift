// Views/Plan/AddRaceView.swift
// Sheet for adding or editing a goal race.

import SwiftUI
import SwiftData

struct AddRaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var editingRace: Race? = nil
    let calendarService: CalendarService

    @State private var name: String = ""
    @State private var date: Date = Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now
    @State private var raceDistance: RaceDistance = .marathon
    @State private var customDistanceMiles: Double = 0
    @State private var location: String = ""
    @State private var goalHours: Int = 0
    @State private var goalMinutes: Int = 0
    @State private var goalSeconds: Int = 0
    @State private var notes: String = ""

    private var effectiveDistanceMiles: Double {
        raceDistance == .custom ? customDistanceMiles : (raceDistance.presetMiles ?? 0)
    }

    private var goalTimeSeconds: Int? {
        let total = goalHours * 3600 + goalMinutes * 60 + goalSeconds
        return total > 0 ? total : nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Race Info") {
                    TextField("Race Name", text: $name)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Location (optional)", text: $location)
                }

                Section("Distance") {
                    Picker("Distance", selection: $raceDistance) {
                        ForEach(RaceDistance.allCases, id: \.self) { dist in
                            Text(dist.rawValue).tag(dist)
                        }
                    }
                    if raceDistance == .custom {
                        HStack {
                            Text("Miles")
                            Spacer()
                            TextField("0.00", value: $customDistanceMiles, format: .number)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                                .multilineTextAlignment(.trailing)
                        }
                    } else if let preset = raceDistance.presetMiles {
                        LabeledContent("Distance") {
                            Text(String(format: "%.3f mi", preset))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    HStack {
                        DurationPicker(label: "h", value: $goalHours, range: 0...23)
                        DurationPicker(label: "m", value: $goalMinutes, range: 0...59)
                        DurationPicker(label: "s", value: $goalSeconds, range: 0...59)
                    }
                } header: {
                    Text("Goal Time (optional)")
                } footer: {
                    if let secs = goalTimeSeconds {
                        let pace = effectiveDistanceMiles > 0
                            ? Int(Double(secs) / effectiveDistanceMiles)
                            : 0
                        if pace > 0 {
                            Text("Avg pace: \(pace / 60):\(String(format: "%02d", pace % 60)) /mi")
                        }
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle(editingRace == nil ? "Add Race" : "Edit Race")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingRace == nil ? "Add" : "Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { populateIfEditing() }
        }
    }

    private func populateIfEditing() {
        guard let race = editingRace else { return }
        name = race.name
        date = race.date
        raceDistance = race.raceDistance
        customDistanceMiles = raceDistance == .custom ? race.distanceMiles : 0
        location = race.location
        notes = race.notes
        if let secs = race.goalTimeSeconds {
            goalHours   = secs / 3600
            goalMinutes = (secs % 3600) / 60
            goalSeconds = secs % 60
        }
    }

    private func save() {
        if let race = editingRace {
            let oldEventId = race.calendarEventIdentifier
            race.name = name.trimmingCharacters(in: .whitespaces)
            race.date = date
            race.raceDistance = raceDistance
            race.distanceMiles = effectiveDistanceMiles
            race.location = location
            race.goalTimeSeconds = goalTimeSeconds
            race.notes = notes
            Task { @MainActor in
                if let id = oldEventId {
                    try? await calendarService.deleteEvent(identifier: id)
                }
                if let eventId = try? await calendarService.createEvent(for: race) {
                    race.calendarEventIdentifier = eventId
                }
            }
        } else {
            let race = Race(
                name: name.trimmingCharacters(in: .whitespaces),
                date: date,
                raceDistance: raceDistance,
                distanceMiles: effectiveDistanceMiles,
                location: location,
                goalTimeSeconds: goalTimeSeconds,
                notes: notes
            )
            modelContext.insert(race)
            Task { @MainActor in
                if let eventId = try? await calendarService.createEvent(for: race) {
                    race.calendarEventIdentifier = eventId
                }
            }
        }
        dismiss()
    }
}
