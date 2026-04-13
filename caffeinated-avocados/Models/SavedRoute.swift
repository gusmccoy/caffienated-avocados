// Models/SavedRoute.swift
// A named route in the user's personal route library.

import Foundation
import SwiftData

// MARK: - Route Surface

enum RouteSurface: String, Codable, CaseIterable {
    case road  = "Road"
    case trail = "Trail"
    case track = "Track"
    case mixed = "Mixed"

    var systemImage: String {
        switch self {
        case .road:  return "road.lanes"
        case .trail: return "leaf.fill"
        case .track: return "oval"
        case .mixed: return "arrow.triangle.branch"
        }
    }
}

// MARK: - SavedRoute (@Model)

@Model
final class SavedRoute {
    var id: UUID = UUID()
    var name: String = ""
    var distanceMiles: Double = 0
    var notes: String = ""
    var isFavorite: Bool = false
    /// Raw storage for `RouteSurface`.
    var surfaceRaw: String = RouteSurface.road.rawValue
    /// Number of times this route was applied to a logged run.
    var usageCount: Int = 0
    var createdAt: Date = Date()

    var surface: RouteSurface {
        get { RouteSurface(rawValue: surfaceRaw) ?? .road }
        set { surfaceRaw = newValue.rawValue }
    }

    init(
        name: String = "",
        distanceMiles: Double = 0,
        notes: String = "",
        isFavorite: Bool = false,
        surface: RouteSurface = .road
    ) {
        self.id = UUID()
        self.name = name
        self.distanceMiles = distanceMiles
        self.notes = notes
        self.isFavorite = isFavorite
        self.surfaceRaw = surface.rawValue
        self.usageCount = 0
        self.createdAt = .now
    }

    /// Formatted distance string.
    var distanceLabel: String {
        distanceMiles > 0 ? String(format: "%.2g mi", distanceMiles) : "Distance not set"
    }
}
