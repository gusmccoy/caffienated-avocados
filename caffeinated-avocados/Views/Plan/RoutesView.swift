// Views/Plan/RoutesView.swift
// Personal route library — browse, star, add, and edit saved routes.

import SwiftUI
import SwiftData

struct RoutesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \SavedRoute.name, order: .forward)
    private var allRoutes: [SavedRoute]

    @State private var searchText = ""
    @State private var showingAddRoute = false
    @State private var editingRoute: SavedRoute? = nil

    // MARK: - Filtered / sorted routes

    private var displayedRoutes: [SavedRoute] {
        let filtered: [SavedRoute]
        if searchText.isEmpty {
            filtered = allRoutes
        } else {
            let q = searchText.lowercased()
            filtered = allRoutes.filter {
                $0.name.lowercased().contains(q) ||
                $0.notes.lowercased().contains(q) ||
                $0.surface.rawValue.lowercased().contains(q) ||
                // Allow "5 mi", "5.0", etc. to match by distance
                distanceMatchesSearch($0, query: q)
            }
        }
        // Favorites first, then alphabetical
        return filtered.sorted {
            if $0.isFavorite != $1.isFavorite { return $0.isFavorite }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if displayedRoutes.isEmpty {
                    emptyState
                } else {
                    routeList
                }
            }
            .navigationTitle("Route Library")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $searchText, prompt: "Search by name, distance, or surface")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddRoute = true
                    } label: {
                        Label("Add Route", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddRoute) {
                AddRouteView()
            }
            .sheet(item: $editingRoute) { route in
                AddRouteView(editingRoute: route)
            }
        }
    }

    // MARK: - Route List

    private var routeList: some View {
        List {
            let favorites = displayedRoutes.filter(\.isFavorite)
            let others    = displayedRoutes.filter { !$0.isFavorite }

            if !favorites.isEmpty {
                Section("Favorites") {
                    ForEach(favorites) { route in
                        RouteRow(route: route) {
                            editingRoute = route
                        } onToggleFavorite: {
                            route.isFavorite.toggle()
                        }
                    }
                    .onDelete { offsets in deleteRoutes(favorites, at: offsets) }
                }
            }

            if !others.isEmpty {
                Section(favorites.isEmpty ? "Routes" : "All Routes") {
                    ForEach(others) { route in
                        RouteRow(route: route) {
                            editingRoute = route
                        } onToggleFavorite: {
                            route.isFavorite.toggle()
                        }
                    }
                    .onDelete { offsets in deleteRoutes(others, at: offsets) }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                searchText.isEmpty ? "No Routes Yet" : "No Matches",
                systemImage: "map"
            )
        } description: {
            Text(searchText.isEmpty
                 ? "Add your favorite runs to build a personal route library."
                 : "Try a different name, distance, or surface type.")
        } actions: {
            if searchText.isEmpty {
                Button("Add Route") { showingAddRoute = true }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
            }
        }
    }

    // MARK: - Helpers

    private func deleteRoutes(_ source: [SavedRoute], at offsets: IndexSet) {
        for i in offsets { modelContext.delete(source[i]) }
    }

    private func distanceMatchesSearch(_ route: SavedRoute, query: String) -> Bool {
        guard route.distanceMiles > 0 else { return false }
        // Strip common suffixes so "5 mi" and "5.0" both match a 5-mile route
        let cleaned = query
            .replacingOccurrences(of: "mi", with: "")
            .replacingOccurrences(of: "miles", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard let target = Double(cleaned) else { return false }
        return abs(route.distanceMiles - target) < 0.5
    }
}

// MARK: - Route Row

private struct RouteRow: View {
    let route: SavedRoute
    let onEdit: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Surface icon
            Image(systemName: route.surface.systemImage)
                .font(.title3)
                .foregroundStyle(.orange)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(route.name)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text(route.distanceLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if route.usageCount > 0 {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text("Used \(route.usageCount)×")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if !route.notes.isEmpty {
                    Text(route.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button(action: onToggleFavorite) {
                Image(systemName: route.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(route.isFavorite ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
        .contextMenu {
            Button {
                onToggleFavorite()
            } label: {
                Label(
                    route.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: route.isFavorite ? "star.slash" : "star"
                )
            }
            Button { onEdit() } label: {
                Label("Edit Route", systemImage: "pencil")
            }
        }
    }
}
