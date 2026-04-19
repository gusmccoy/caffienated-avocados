// Views/Plan/RoutePlannerView.swift
// Full-screen map for drawing a running route by placing waypoints.
// Uses MapKit MKDirections (walking) to calculate pedestrian paths between pins.

import SwiftUI
import MapKit
import SwiftData

struct RoutePlannerView: View {
    /// Existing waypoints to resume editing (empty for a new route).
    var existingWaypoints: [RouteWaypoint]
    var existingPolyline: [RouteCoordinate]
    var existingDistanceMiles: Double

    /// Called when the user saves the route.
    var onSave: (_ waypoints: [RouteWaypoint], _ polyline: [RouteCoordinate], _ distanceMiles: Double) -> Void
    /// Called when the user clears the route entirely.
    var onClear: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var locationManager = LocationManager()
    @State private var hasCenteredOnUser = false
    @State private var waypoints: [RouteWaypoint] = []
    @State private var polylineCoords: [CLLocationCoordinate2D] = []
    @State private var distanceMeters: Double = 0
    @State private var isCalculating = false
    @State private var errorMessage: String?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false

    // MARK: - Library state
    @State private var showingLibraryPicker = false
    @State private var showingSaveSheet = false
    @State private var newRouteName = ""

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                mapContent

                VStack(spacing: 0) {
                    // Search bar
                    searchBar

                    Spacer()

                    // Bottom info bar
                    bottomBar
                }
            }
            .navigationTitle("Plan Route")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingLibraryPicker = true
                    } label: {
                        Label("Load from Library", systemImage: "books.vertical")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveRoute() }
                        .disabled(waypoints.count < 2)
                }
            }
            .onAppear {
                loadExisting()
                locationManager.requestLocation()
            }
            .onChange(of: locationManager.lastCoordinate?.latitude) { _, _ in
                centerOnUserIfNeeded()
            }
            .sheet(isPresented: $showingLibraryPicker) {
                RoutePickerView(targetDistanceMiles: existingDistanceMiles) { route in
                    loadRoute(route)
                }
            }
            .sheet(isPresented: $showingSaveSheet) {
                saveToLibrarySheet
            }
        }
    }

    /// Centers the camera on the user's current location the first time it's available,
    /// unless the user is already editing an existing route.
    private func centerOnUserIfNeeded() {
        guard !hasCenteredOnUser,
              waypoints.isEmpty,
              let coord = locationManager.lastCoordinate else { return }
        hasCenteredOnUser = true
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: coord,
                latitudinalMeters: 1500,
                longitudinalMeters: 1500
            ))
        }
    }

    // MARK: - Map

    private var mapContent: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                // Waypoint markers
                ForEach(Array(waypoints.enumerated()), id: \.offset) { index, wp in
                    Annotation(
                        index == 0 ? "Start" : index == waypoints.count - 1 ? "End" : "",
                        coordinate: CLLocationCoordinate2D(latitude: wp.latitude, longitude: wp.longitude)
                    ) {
                        waypointPin(index: index)
                    }
                }

                // Route polyline
                if polylineCoords.count >= 2 {
                    MapPolyline(coordinates: polylineCoords)
                        .stroke(.orange, lineWidth: 4)
                }
            }
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .including([.park, .beach, .marina])))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .onTapGesture { screenPoint in
                if let coord = proxy.convert(screenPoint, from: .local) {
                    addWaypoint(at: coord)
                }
            }
        }
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search for a location", text: $searchText)
                .textFieldStyle(.plain)
                .onSubmit { performSearch() }
                #if !os(macOS)
                .autocorrectionDisabled()
                #endif
            if !searchText.isEmpty {
                Button { searchText = ""; searchResults = [] } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.top, 8)
        .overlay(alignment: .top) {
            if !searchResults.isEmpty {
                searchResultsList
                    .padding(.top, 52)
                    .padding(.horizontal)
            }
        }
    }

    private var searchResultsList: some View {
        VStack(spacing: 0) {
            ForEach(searchResults, id: \.self) { item in
                Button {
                    selectSearchResult(item)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name ?? "Unknown")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        if let subtitle = item.addressRepresentations?.cityWithContext ?? item.addressRepresentations?.regionName {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                }
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(distanceLabel)
                    .font(.headline)
                Text("\(waypoints.count) waypoint\(waypoints.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isCalculating {
                ProgressView()
                    .controlSize(.small)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            // Save to Library
            Button {
                newRouteName = ""
                showingSaveSheet = true
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .font(.title3)
            }
            .disabled(waypoints.count < 2)

            Button {
                undoLastWaypoint()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.title3)
            }
            .disabled(waypoints.isEmpty)

            Button(role: .destructive) {
                clearRoute()
            } label: {
                Image(systemName: "trash")
                    .font(.title3)
            }
            .disabled(waypoints.isEmpty)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Save to Library Sheet

    private var saveToLibrarySheet: some View {
        NavigationStack {
            Form {
                Section("Route Name") {
                    TextField("e.g. Morning Loop", text: $newRouteName)
                }
                Section {
                    HStack {
                        Text("Distance")
                        Spacer()
                        Text(distanceLabel)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Waypoints")
                        Spacer()
                        Text("\(waypoints.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            #if os(macOS)
            .formStyle(.grouped)
            .frame(minWidth: 400, minHeight: 250)
            #endif
            .navigationTitle("Save to Library")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingSaveSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = newRouteName.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        saveToLibrary(name: trimmed)
                        showingSaveSheet = false
                    }
                    .disabled(newRouteName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Waypoint Pin

    private func waypointPin(index: Int) -> some View {
        ZStack {
            Circle()
                .fill(pinColor(for: index))
                .frame(width: 28, height: 28)
            if index == 0 {
                Image(systemName: "figure.run")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
            } else if index == waypoints.count - 1 && waypoints.count > 1 {
                Image(systemName: "flag.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
            } else {
                Text("\(index)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
    }

    private func pinColor(for index: Int) -> Color {
        if index == 0 { return .green }
        if index == waypoints.count - 1 && waypoints.count > 1 { return .red }
        return .orange
    }

    // MARK: - Distance Label

    private var distanceLabel: String {
        let miles = distanceMeters / 1609.34
        if miles < 0.01 { return "0.00 mi" }
        return String(format: "%.2f mi", miles)
    }

    // MARK: - Actions

    /// Loads a route from the library into the planner.
    /// Uses the cached polyline if available; otherwise re-queries MKDirections.
    private func loadRoute(_ route: SavedRoute) {
        let routeWaypoints = route.routeWaypoints
        guard routeWaypoints.count >= 2 else {
            errorMessage = "\"\(route.name)\" has no map data. Open it in the planner to draw the route first."
            return
        }

        waypoints = routeWaypoints
        polylineCoords = []
        distanceMeters = 0
        errorMessage = nil

        let storedPolyline = route.routePolyline
        if !storedPolyline.isEmpty {
            polylineCoords = storedPolyline.map {
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            }
            distanceMeters = route.distanceMiles * 1609.34
        } else {
            recalculateFullRoute()
        }

        fitCamera(to: routeWaypoints)
    }

    /// Creates a new SavedRoute in the library from the current map state.
    private func saveToLibrary(name: String) {
        let polyline = polylineCoords.map { RouteCoordinate(latitude: $0.latitude, longitude: $0.longitude) }
        let miles = distanceMeters / 1609.34
        let route = SavedRoute(
            name: name,
            distanceMiles: miles,
            routeWaypoints: waypoints,
            routePolyline: polyline
        )
        modelContext.insert(route)
    }

    /// Moves the map camera to frame all waypoints with padding.
    private func fitCamera(to wps: [RouteWaypoint]) {
        guard !wps.isEmpty else { return }
        var minLat = wps[0].latitude, maxLat = wps[0].latitude
        var minLon = wps[0].longitude, maxLon = wps[0].longitude
        for wp in wps {
            minLat = min(minLat, wp.latitude)
            maxLat = max(maxLat, wp.latitude)
            minLon = min(minLon, wp.longitude)
            maxLon = max(maxLon, wp.longitude)
        }
        let center = CLLocationCoordinate2D(
            latitude:  (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta:  max(0.01, (maxLat - minLat) * 1.4),
            longitudeDelta: max(0.01, (maxLon - minLon) * 1.4)
        )
        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }

    private func loadExisting() {
        if !existingWaypoints.isEmpty {
            waypoints = existingWaypoints
            distanceMeters = existingDistanceMiles * 1609.34
            if !existingPolyline.isEmpty {
                polylineCoords = existingPolyline.map {
                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                }
            } else {
                recalculateFullRoute()
            }
        }
    }

    private func addWaypoint(at coord: CLLocationCoordinate2D) {
        let wp = RouteWaypoint(latitude: coord.latitude, longitude: coord.longitude)
        waypoints.append(wp)
        errorMessage = nil

        if waypoints.count >= 2 {
            // Calculate directions from the previous waypoint to this new one
            let prev = waypoints[waypoints.count - 2]
            calculateSegment(
                from: CLLocationCoordinate2D(latitude: prev.latitude, longitude: prev.longitude),
                to: coord
            )
        }
    }

    private func undoLastWaypoint() {
        guard !waypoints.isEmpty else { return }
        waypoints.removeLast()
        errorMessage = nil
        recalculateFullRoute()
    }

    private func clearRoute() {
        waypoints = []
        polylineCoords = []
        distanceMeters = 0
        errorMessage = nil
    }

    private func saveRoute() {
        let polyline = polylineCoords.map { RouteCoordinate(latitude: $0.latitude, longitude: $0.longitude) }
        let miles = distanceMeters / 1609.34
        onSave(waypoints, polyline, miles)
        dismiss()
    }

    // MARK: - Search

    private func performSearch() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        // Note: MapCameraPosition doesn't expose its region directly for search biasing
        // The search will use the device's current location by default
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            isSearching = false
            if let items = response?.mapItems {
                searchResults = Array(items.prefix(5))
            }
        }
    }

    private func selectSearchResult(_ item: MKMapItem) {
        searchResults = []
        searchText = ""
        let coord = item.location.coordinate
        cameraPosition = .region(MKCoordinateRegion(
            center: coord,
            latitudinalMeters: 2000,
            longitudinalMeters: 2000
        ))
    }

    // MARK: - Routing

    private func calculateSegment(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) {
        isCalculating = true
        let request = MKDirections.Request()
        request.source = MKMapItem(location: CLLocation(latitude: from.latitude, longitude: from.longitude), address: nil)
        request.destination = MKMapItem(location: CLLocation(latitude: to.latitude, longitude: to.longitude), address: nil)
        request.transportType = .walking

        MKDirections(request: request).calculate { response, error in
            isCalculating = false
            if let route = response?.routes.first {
                let segmentCoords = route.polyline.coordinates
                // Append segment to existing polyline (skip first point to avoid duplicate)
                if polylineCoords.isEmpty {
                    polylineCoords = segmentCoords
                } else {
                    polylineCoords.append(contentsOf: segmentCoords.dropFirst())
                }
                distanceMeters += route.distance
            } else {
                // Fallback: draw straight line
                if polylineCoords.isEmpty {
                    polylineCoords = [from, to]
                } else {
                    polylineCoords.append(to)
                }
                let straight = MKMapPoint(from).distance(to: MKMapPoint(to))
                distanceMeters += straight
                errorMessage = "No walking path found — straight line used"
            }
        }
    }

    private func recalculateFullRoute() {
        polylineCoords = []
        distanceMeters = 0

        guard waypoints.count >= 2 else { return }

        // Calculate each consecutive pair
        let pairs = zip(waypoints, waypoints.dropFirst())
        var remaining = Array(pairs)
        calculateNextPair(remaining: &remaining)
    }

    private func calculateNextPair(remaining: inout [(RouteWaypoint, RouteWaypoint)]) {
        guard let pair = remaining.first else { return }
        var rest = Array(remaining.dropFirst())

        let from = CLLocationCoordinate2D(latitude: pair.0.latitude, longitude: pair.0.longitude)
        let to = CLLocationCoordinate2D(latitude: pair.1.latitude, longitude: pair.1.longitude)

        isCalculating = true
        let request = MKDirections.Request()
        request.source = MKMapItem(location: CLLocation(latitude: from.latitude, longitude: from.longitude), address: nil)
        request.destination = MKMapItem(location: CLLocation(latitude: to.latitude, longitude: to.longitude), address: nil)
        request.transportType = .walking

        MKDirections(request: request).calculate { response, error in
            if let route = response?.routes.first {
                let segmentCoords = route.polyline.coordinates
                if polylineCoords.isEmpty {
                    polylineCoords = segmentCoords
                } else {
                    polylineCoords.append(contentsOf: segmentCoords.dropFirst())
                }
                distanceMeters += route.distance
            } else {
                if polylineCoords.isEmpty {
                    polylineCoords = [from, to]
                } else {
                    polylineCoords.append(to)
                }
                distanceMeters += MKMapPoint(from).distance(to: MKMapPoint(to))
            }

            if rest.isEmpty {
                isCalculating = false
            } else {
                calculateNextPair(remaining: &rest)
            }
        }
    }
}

// MARK: - MKPolyline Extension

extension MKPolyline {
    /// Extracts CLLocationCoordinate2D array from the polyline.
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}
