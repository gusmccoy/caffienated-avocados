// Views/Plan/TemplateLibraryView.swift
// Browse, manage, and apply saved workout templates.
// Used standalone (from Plan tab toolbar) and as a picker (from AddPlannedWorkoutView).

import SwiftUI
import SwiftData

struct TemplateLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// When non-nil, tapping a template calls this instead of navigating to edit.
    var onSelect: ((WorkoutTemplate) -> Void)? = nil

    @Query(sort: \WorkoutTemplate.templateName, order: .forward)
    private var templates: [WorkoutTemplate]

    @State private var searchText = ""
    @State private var editingTemplate: WorkoutTemplate? = nil

    private var displayed: [WorkoutTemplate] {
        guard !searchText.isEmpty else { return templates }
        let q = searchText.lowercased()
        return templates.filter {
            $0.templateName.lowercased().contains(q) ||
            $0.workoutType.rawValue.lowercased().contains(q) ||
            $0.runCategory.rawValue.lowercased().contains(q) ||
            $0.crossTrainingActivityType.rawValue.lowercased().contains(q) ||
            $0.title.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if templates.isEmpty {
                    emptyState
                } else if displayed.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    list
                }
            }
            .navigationTitle(onSelect != nil ? "Choose Template" : "Workout Templates")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $searchText, prompt: "Search templates")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editingTemplate) { t in
                EditTemplateNameView(template: t)
            }
        }
    }

    // MARK: - List

    private var list: some View {
        List {
            ForEach(displayed) { template in
                TemplateRow(template: template) {
                    if let onSelect {
                        onSelect(template)
                        dismiss()
                    } else {
                        editingTemplate = template
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        modelContext.delete(template)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        editingTemplate = template
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    .tint(.orange)
                }
                .contextMenu {
                    Button { editingTemplate = template } label: {
                        Label("Rename / Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        modelContext.delete(template)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Templates Yet", systemImage: "doc.text")
        } description: {
            Text("Save any planned workout as a template to quickly reuse it in future weeks.")
        }
    }
}

// MARK: - Template Row

private struct TemplateRow: View {
    let template: WorkoutTemplate
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: template.workoutType.systemImage)
                    .font(.title3)
                    .foregroundStyle(.orange)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(template.templateName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(template.summaryLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if template.usageCount > 0 {
                        Text("Used \(template.usageCount)×")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                if !template.runSegments.isEmpty {
                    Text("\(template.runSegments.count) seg")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.12), in: Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Edit Template Name Sheet

struct EditTemplateNameView: View {
    @Environment(\.dismiss) private var dismiss
    let template: WorkoutTemplate

    @State private var name: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Template Name") {
                    TextField("Name", text: $name)
                }
                Section {
                    LabeledContent("Type", value: template.workoutType.rawValue)
                    if template.plannedDistanceMiles > 0 {
                        LabeledContent("Distance", value: String(format: "%.2g mi", template.plannedDistanceMiles))
                    }
                    if template.plannedDurationSeconds > 0 {
                        LabeledContent("Duration", value: template.plannedDurationSeconds.formattedAsTime)
                    }
                    if !template.runSegments.isEmpty {
                        LabeledContent("Segments", value: "\(template.runSegments.count)")
                    }
                } header: {
                    Text("Workout Details")
                }
            }
            .navigationTitle("Rename Template")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty { template.templateName = trimmed }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { name = template.templateName }
        }
    }
}
