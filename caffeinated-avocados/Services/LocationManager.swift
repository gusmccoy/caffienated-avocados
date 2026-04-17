// Services/LocationManager.swift
// Lightweight CLLocationManager wrapper for centering the route-planner map
// on the user's current location. Requests "when in use" authorization and
// publishes a one-shot location fix.

import Foundation
import CoreLocation
import Observation

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    /// The most recent coordinate, if a fix has been obtained.
    var lastCoordinate: CLLocationCoordinate2D?

    /// Current authorization status, updated on delegate callback.
    var authorizationStatus: CLAuthorizationStatus

    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Request permission (if not yet determined) and start a one-shot location request.
    func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            #if os(macOS)
            manager.requestAlwaysAuthorization()
            #else
            manager.requestWhenInUseAuthorization()
            #endif
        case .authorizedAlways:
            manager.requestLocation()
        #if !os(macOS)
        case .authorizedWhenInUse:
            manager.requestLocation()
        #endif
        default:
            break
        }
    }

    private func isAuthorized(_ status: CLAuthorizationStatus) -> Bool {
        #if os(macOS)
        return status == .authorizedAlways
        #else
        return status == .authorizedAlways || status == .authorizedWhenInUse
        #endif
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        authorizationStatus = status
        if isAuthorized(status) {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let coord = locations.last?.coordinate {
            lastCoordinate = coord
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Silently ignore — the map still works without a user-location fix.
    }
}
