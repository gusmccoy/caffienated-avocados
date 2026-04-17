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
    @State private var waypoints: [RouteWaypoint] = []
    @State private var polyline: [RouteCoordinate] = []
    @State private var showingRoutePlanner = false

    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Map preview
                Section {
                    if polyline.count >= 2 {
                        RoutePreviewMap(polyline: polyline, height: 160)
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                        HStack {
                            Label(
                                String(format: "%.2f mi on map", distanceMiles),
                                systemImage: "map"
                            )
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            Spacer()
                            Button("Edit on Map") { showingRoutePlanner = true }
                                .font(.caption)
                                .buttonStyle(.bordered)
                        }
                    } else {
                        Button {
                            showingRoutePlanner = true
                        } label: {
                            Label("Draw on Map", systemImage: "map")
                        }
                    }
                } header: {
                    Text("Route Map")
                } footer: {
                    if polyline.count < 2 {
                        Text("Draw the route on Apple Maps. Distance is calculated from the path.")
                    }
                }

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
            #if os(macOS)
            .sheet(isPresented: $showingRoutePlanner) { routePlanner }
            #else
            .fullScreenCover(isPresented: $showingRoutePlanner) { routePlanner }
            #endif
        }
    }

    private var routePlanner: some View {
        RoutePlannerView(
            existingWaypoints: waypoints,
            existingPolyline: polyline,
            existingDistanceMiles: distanceMiles,
            onSave: { wps, poly, miles in
                waypoints = wps
                polyline = poly
                distanceMiles = miles
            },
            onClear: {
                waypoints = []
                polyline = []
            }
        )
    }

    private func populate() {
        guard let r = editingRoute else { return }
        name          = r.name
        distanceMiles = r.distanceMiles
        surface       = r.surface
        isFavorite    = r.isFavorite
        notes         = r.notes
        waypoints     = r.routeWaypoints
        polyline      = r.routePolyline
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let route = editingRoute {
            route.name             = trimmed
            route.distanceMiles    = distanceMiles
            route.surfaceRaw       = surface.rawValue
            route.isFavorite       = isFavorite
            route.notes            = notes
            route.routeWaypoints   = waypoints
            route.routePolyline    = polyline
        } else {
            let route = SavedRoute(
                name: trimmed,
                distanceMiles: distanceMiles,
                notes: notes,
                isFavorite: isFavorite,
                surface: surface
            )
            route.routeWaypoints = waypoints
            route.routePolyline  = polyline
            modelContext.insert(route)
        }
        dismiss()
    }
}
