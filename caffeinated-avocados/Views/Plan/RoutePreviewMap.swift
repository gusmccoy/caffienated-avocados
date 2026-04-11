// Views/Plan/RoutePreviewMap.swift
// Small, non-interactive map that shows a route polyline preview.

import SwiftUI
import MapKit

struct RoutePreviewMap: View {
    let polyline: [RouteCoordinate]
    var height: CGFloat = 120

    var body: some View {
        Map(position: .constant(cameraPosition), interactionModes: []) {
            if coordinates.count >= 2 {
                MapPolyline(coordinates: coordinates)
                    .stroke(.orange, lineWidth: 3)
            }

            // Start pin
            if let first = coordinates.first {
                Annotation("", coordinate: first) {
                    Circle()
                        .fill(.green)
                        .frame(width: 10, height: 10)
                }
            }

            // End pin
            if coordinates.count > 1, let last = coordinates.last {
                Annotation("", coordinate: last) {
                    Circle()
                        .fill(.red)
                        .frame(width: 10, height: 10)
                }
            }
        }
        .mapStyle(.standard)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .allowsHitTesting(false)
    }

    private var coordinates: [CLLocationCoordinate2D] {
        polyline.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    private var cameraPosition: MapCameraPosition {
        guard !coordinates.isEmpty else { return .automatic }

        let lats = coordinates.map(\.latitude)
        let lons = coordinates.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lons.min()! + lons.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((lats.max()! - lats.min()!) * 1.4, 0.005),
            longitudeDelta: max((lons.max()! - lons.min()!) * 1.4, 0.005)
        )
        return .region(MKCoordinateRegion(center: center, span: span))
    }
}
