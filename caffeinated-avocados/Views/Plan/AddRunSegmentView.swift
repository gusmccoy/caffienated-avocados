// Views/Plan/AddRunSegmentView.swift
// Sheet for adding or editing a single run segment within a planned workout.

import SwiftUI

struct AddRunSegmentView: View {
    let existingSegment: PlannedRunSegment?
    let onSave: (PlannedRunSegment) -> Void
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    // Segment type
    @State private var segmentType: RunSegmentType = .easy

    // Pace
    @State private var paceReference: PaceReference = .exact
    @State private var paceMinutes: Int = 8
    @State private var paceSeconds: Int = 0

    // Volume
    @State private var distanceMiles: Double = 0
    @State private var durationMinutes: Int = 0

    // Intervals (repeats / fartlek)
    @State private var intervalCount: Int = 4
    @State private var recoveryDurationSeconds: Int = 90
    @State private var isHills: Bool = false

    // Ladder
    @State private var ladderDistances: [Double] = [0.25, 0.5, 0.75, 0.5, 0.25]
    @State private var newLadderMiles: Double = 0.25

    @State private var notes: String = ""

    init(existingSegment: PlannedRunSegment? = nil,
         onSave: @escaping (PlannedRunSegment) -> Void,
         onDelete: (() -> Void)? = nil) {
        self.existingSegment = existingSegment
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            segmentForm
                #if os(macOS)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity, alignment: .center)
                #endif
                .navigationTitle(existingSegment == nil ? "Add Segment" : "Edit Segment")
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
        }
    }

    private var segmentForm: some View {
        Form {
            // MARK: Type
            Section("Segment Type") {
                Picker("Type", selection: $segmentType) {
                    ForEach(RunSegmentType.allCases, id: \.self) { type in
                        Label(type.rawValue, systemImage: type.systemImage).tag(type)
                    }
                }
            }

            // MARK: Pace
            Section("Pace") {
                Picker("Pace By", selection: $paceReference) {
                    ForEach(PaceReference.allCases, id: \.self) { ref in
                        Text(ref.rawValue).tag(ref)
                    }
                }
                .pickerStyle(.menu)

                if paceReference == .exact {
                    HStack {
                        Text("Pace")
                        Spacer()
                        Picker("Min", selection: $paceMinutes) {
                            ForEach(4...15, id: \.self) { Text(String($0)).tag($0) }
                        }
                        #if os(macOS)
                        .pickerStyle(.menu)
                        #else
                        .pickerStyle(.wheel)
                        .frame(width: 60)
                        .clipped()
                        #endif
                        Text(":")
                        Picker("Sec", selection: $paceSeconds) {
                            ForEach(Array(stride(from: 0, through: 59, by: 5)), id: \.self) {
                                Text(String(format: "%02d", $0)).tag($0)
                            }
                        }
                        #if os(macOS)
                        .pickerStyle(.menu)
                        #else
                        .pickerStyle(.wheel)
                        .frame(width: 60)
                        .clipped()
                        #endif
                        Text("/mi")
                            .foregroundStyle(.secondary)
                    }
                    #if !os(macOS)
                    .frame(height: 100)
                    #endif
                }
            }

            // MARK: Volume — Ladder
            if segmentType.isLadder {
                Section {
                    ForEach(ladderDistances.indices, id: \.self) { i in
                        HStack {
                            Text("Step \(i + 1)")
                            Spacer()
                            Text(PlannedRunSegment.formatDistance(ladderDistances[i]))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { ladderDistances.remove(atOffsets: $0) }
                    .onMove { ladderDistances.move(fromOffsets: $0, toOffset: $1) }

                    HStack {
                        Text("Add Step")
                        Spacer()
                        Picker("", selection: $newLadderMiles) {
                            ForEach(commonLadderDistances, id: \.self) { d in
                                Text(PlannedRunSegment.formatDistance(d)).tag(d)
                            }
                        }
                        .pickerStyle(.menu)
                        Button {
                            ladderDistances.append(newLadderMiles)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.green)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    HStack {
                        Text("Ladder Steps")
                        Spacer()
                        #if !os(macOS)
                        EditButton()
                            .font(.caption)
                        #endif
                    }
                }

                Section("Recovery Between Steps") {
                    RecoveryPicker(seconds: $recoveryDurationSeconds)
                }
            }

            // MARK: Volume — Intervals
            else if segmentType.hasIntervals {
                Section {
                    Stepper("Repetitions: \(intervalCount)", value: $intervalCount, in: 1...50)
                    HStack {
                        Text("Distance per Rep")
                        Spacer()
                        Picker("", selection: $distanceMiles) {
                            Text("—").tag(0.0)
                            ForEach(commonLadderDistances, id: \.self) { d in
                                Text(PlannedRunSegment.formatDistance(d)).tag(d)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    Toggle("Hill Repeats", isOn: $isHills)
                } header: {
                    Text("Intervals")
                } footer: {
                    if isHills {
                        Text("Distance is doubled in calculations — each rep counts the uphill effort plus the downhill recovery jog.")
                    }
                }

                Section("Recovery Between Reps") {
                    RecoveryPicker(seconds: $recoveryDurationSeconds)
                }
            }

            // MARK: Volume — Standard
            else {
                Section("Volume (optional)") {
                    HStack {
                        Text("Distance (mi)")
                        Spacer()
                        TextField("0.00", value: $distanceMiles, format: .number.precision(.fractionLength(2)))
                            #if !os(macOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Duration (min)")
                        Spacer()
                        TextField("0", value: $durationMinutes, format: .number)
                            #if !os(macOS)
                            .keyboardType(.numberPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                }
            }

            // MARK: Notes
            Section("Notes") {
                TextField("Optional", text: $notes)
            }

            // MARK: Delete (edit mode only)
            if onDelete != nil {
                Section {
                    Button("Remove Segment", role: .destructive) {
                        onDelete?()
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
    }

    // MARK: - Helpers

    private var commonLadderDistances: [Double] {
        // 100m, 200m, 400m, 600m, 800m, 1000m, 1200m, 1600m
        [0.0621, 0.1243, 0.2485, 0.3728, 0.4971, 0.6214, 0.7456, 0.9942]
    }

    private func populate() {
        guard let s = existingSegment else { return }
        segmentType          = s.segmentType
        paceReference        = s.paceReference
        paceMinutes          = s.paceMinutes == 0 ? 8 : s.paceMinutes
        paceSeconds          = s.paceSeconds
        distanceMiles        = s.distanceMiles
        durationMinutes      = s.durationMinutes
        intervalCount        = s.intervalCount
        recoveryDurationSeconds = s.recoveryDurationSeconds
        isHills              = s.isHills
        ladderDistances      = s.ladderDistances.isEmpty ? [0.25, 0.5, 0.75, 0.5, 0.25] : s.ladderDistances
        notes                = s.notes
    }

    private func save() {
        var seg = existingSegment ?? PlannedRunSegment()
        seg.segmentType          = segmentType
        seg.paceReference        = paceReference
        seg.paceMinutes          = paceReference == .exact ? paceMinutes : 0
        seg.paceSeconds          = paceReference == .exact ? paceSeconds : 0
        seg.distanceMiles        = segmentType.isLadder ? 0 : distanceMiles
        seg.durationMinutes      = segmentType.isLadder || segmentType.hasIntervals ? 0 : durationMinutes
        seg.intervalCount        = segmentType.hasIntervals ? intervalCount : 0
        seg.recoveryDurationSeconds = (segmentType.hasIntervals || segmentType.isLadder) ? recoveryDurationSeconds : 0
        seg.isHills              = segmentType.hasIntervals ? isHills : false
        seg.ladderDistances      = segmentType.isLadder ? ladderDistances : []
        seg.notes                = notes
        onSave(seg)
        dismiss()
    }
}

// MARK: - Recovery Picker

private struct RecoveryPicker: View {
    @Binding var seconds: Int

    private let options: [(label: String, value: Int)] = [
        ("30s", 30), ("45s", 45), ("60s", 60), ("90s", 90),
        ("2 min", 120), ("3 min", 180), ("4 min", 240), ("5 min", 300)
    ]

    var body: some View {
        Picker("Recovery", selection: $seconds) {
            ForEach(options, id: \.value) { opt in
                Text(opt.label).tag(opt.value)
            }
        }
        .pickerStyle(.menu)
    }
}
