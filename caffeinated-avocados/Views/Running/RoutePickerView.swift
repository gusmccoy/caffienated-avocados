// Views/Running/RoutePickerView.swift
// Compact route library picker used in the run creation / edit form.
// Shows favorites first, then sorts remaining routes by proximity to a
// target distance (if provided), then alphabetically.

import SwiftUI
import SwiftData

struct RoutePickerView: View {
    @Environment(\.dismiss) private var dismiss

    /// Pre-filled target distance from the run form (0 = no filter).
    var targetDistanceMiles: Double = 0
    /// Called when the user selects a route.
    var onSelect: (SavedRoute) -> Void

    @Query(sort: \SavedRoute.name, order: .forward)
    private var allRoutes: [SavedRoute]

    @State private var searchText = ""
    @State private var showingAddRoute = false

    // MARK: - Sorted / filtered results

    private var displayedRoutes: [SavedRoute] {
        let candidates: [SavedRoute]
        if searchText.isEmpty {
            candidates = allRoutes
        } else {
            let q = searchText.lowercased()
            candidates = allRoutes.filter {
                $0.name.lowercased().contains(q) ||
                $0.surface.rawValue.lowercased().contains(q) ||
                distanceMatchesQuery($0.distanceMiles, query: q)
            }
        }
        return candidates.sorted { a, b in
            // Favorites always first
            if a.isFavorite != b.isFavorite { return a.isFavorite }
            // When a target distance is set, sort remaining by proximity
            if targetDistanceMiles > 0 {
                let da = abs(a.distanceMiles - targetDistanceMiles)
                let db = abs(b.distanceMiles - targetDistanceMiles)
                if abs(da - db) > 0.05 { return da < db }
            }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if allRoutes.isEmpty {
                    emptyLibrary
                } else if displayedRoutes.isEmpty {
                    noResults
                } else {
                    routeList
                }
            }
            .navigationTitle("Pick a Route")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $searchText, prompt: "Search routes")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddRoute = true
                    } label: {
                        Label("New Route", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddRoute) {
                AddRouteView()
            }
        }
    }

    // MARK: - Route List

    private var routeList: some View {
        List(displayedRoutes) { route in
            Button {
                route.usageCount += 1
                onSelect(route)
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: route.surface.systemImage)
                        .font(.title3)
                        .foregroundStyle(.orange)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(route.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            if route.isFavorite {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.yellow)
                            }
                        }
                        HStack(spacing: 6) {
                            Text(route.distanceLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("·")
                                .foregroundStyle(.secondary)
                            Text(route.surface.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !route.notes.isEmpty {
                            Text(route.notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    // Distance delta badge when a target is set
                    if targetDistanceMiles > 0 && route.distanceMiles > 0 {
                        let delta = route.distanceMiles - targetDistanceMiles
                        if abs(delta) > 0.05 {
                            Text(String(format: "%+.1f mi", delta))
                                .font(.caption2)
                                .foregroundStyle(abs(delta) < 1.0 ? .secondary : .tertiary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Empty States

    private var emptyLibrary: some View {
        ContentUnavailableView {
            Label("No Routes Saved", systemImage: "map")
        } description: {
            Text("Build your route library and quickly apply routes to any run.")
        } actions: {
            Button("Add Your First Route") { showingAddRoute = true }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
        }
    }

    private var noResults: some View {
        ContentUnavailableView.search(text: searchText)
    }

    // MARK: - Helpers

    private func distanceMatchesQuery(_ miles: Double, query: String) -> Bool {
        guard miles > 0 else { return false }
        let cleaned = query
            .replacingOccurrences(of: "mi", with: "")
            .replacingOccurrences(of: "miles", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard let target = Double(cleaned) else { return false }
        return abs(miles - target) < 0.5
    }
}
