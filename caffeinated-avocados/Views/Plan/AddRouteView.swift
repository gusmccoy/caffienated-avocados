// Views/Plan/AddRouteView.swift
// Sheet form for creating or editing a SavedRoute.

import SwiftUI
import SwiftData

struct AddRouteView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var editingRoute: SavedRoute? = nil

    @State private var name = ""
    @State private var distanceMiles: Double = 0
    @State private var surface: RouteSurface = .road
    @State private var isFavorite = false
    @State private var notes = ""

    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Route Info") {
                    TextField("Route Name", text: $name)

                    HStack {
                        Text("Distance")
                        Spacer()
                        TextField("0.00", value: $distanceMiles, format: .number)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                        Text("mi")
                            .foregroundStyle(.secondary)
                    }

                    Picker("Surface", selection: $surface) {
                        ForEach(RouteSurface.allCases, id: \.self) { s in
                            Label(s.rawValue, systemImage: s.systemImage).tag(s)
                        }
                    }

                    Toggle("Favorite", isOn: $isFavorite)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle(editingRoute == nil ? "New Route" : "Edit Route")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }
            }
            .onAppear { populate() }
        }
    }

    private func populate() {
        guard let r = editingRoute else { return }
        name          = r.name
        distanceMiles = r.distanceMiles
        surface       = r.surface
        isFavorite    = r.isFavorite
        notes         = r.notes
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let route = editingRoute {
            route.name          = trimmed
            route.distanceMiles = distanceMiles
            route.surfaceRaw    = surface.rawValue
            route.isFavorite    = isFavorite
            route.notes         = notes
        } else {
            let route = SavedRoute(
                name: trimmed,
                distanceMiles: distanceMiles,
                notes: notes,
                isFavorite: isFavorite,
                surface: surface
            )
            modelContext.insert(route)
        }
        dismiss()
    }
}
