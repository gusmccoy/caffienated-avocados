// Models/FuelPlan.swift
// Fuel and nutrition plan that can be attached to a planned workout or race.

import Foundation
import SwiftData

// MARK: - Enums

/// Timing phase within a workout for a fuel item.
enum FuelPhase: String, Codable, CaseIterable {
    case pre  = "Pre-Workout"
    case mid  = "Mid-Workout"
    case post = "Post-Workout"

    var systemImage: String {
        switch self {
        case .pre:  return "fork.knife"
        case .mid:  return "bolt.fill"
        case .post: return "leaf.fill"
        }
    }
}

/// Category of a fuel item.
enum FuelItemType: String, Codable, CaseIterable {
    case gel         = "Gel"
    case chew        = "Chew"
    case fluid       = "Fluid"
    case realFood    = "Real Food"
    case electrolyte = "Electrolyte"
    case supplement  = "Supplement"
    case other       = "Other"

    var systemImage: String {
        switch self {
        case .gel:         return "drop.fill"
        case .chew:        return "square.grid.2x2.fill"
        case .fluid:       return "waterbottle.fill"
        case .realFood:    return "fork.knife"
        case .electrolyte: return "bolt.circle.fill"
        case .supplement:  return "pills.fill"
        case .other:       return "circle.fill"
        }
    }
}

// MARK: - FuelEntry (struct, stored as JSON)

/// A single planned fuel item within a FuelPlan.
struct FuelEntry: Codable, Identifiable {
    var id: UUID         = UUID()
    var name: String     = ""
    var typeRaw: String  = FuelItemType.gel.rawValue
    /// Which phase this item belongs to.
    var phaseRaw: String = FuelPhase.mid.rawValue
    /// Minutes after workout start (meaningful for mid-workout items).
    var timingMinutes: Int = 45
    /// Human-readable quantity, e.g. "1 gel", "500 ml", "2 squares".
    var quantity: String   = ""
    var carbsGrams: Int?   = nil
    var caloriesKcal: Int? = nil
    var notes: String      = ""
    /// True when the user marks this item as actually consumed.
    var isConsumed: Bool   = false

    var type: FuelItemType  { FuelItemType(rawValue: typeRaw) ?? .other }
    var phase: FuelPhase    { FuelPhase(rawValue: phaseRaw) ?? .mid }

    var displayName: String {
        name.isEmpty ? type.rawValue : name
    }
}

// MARK: - FuelPlan (@Model)

/// Nutrition and hydration plan for a planned workout or race.
/// Attach via `PlannedWorkout.fuelPlan` or `Race.fuelPlan`.
@Model
final class FuelPlan {
    var id: UUID
    var createdAt: Date

    // MARK: Pre-workout targets
    var preNotes: String       = ""
    var preCarbsGrams: Int?    = nil
    var preProteinGrams: Int?  = nil
    var preFluidsMl: Int?      = nil

    // MARK: Post-workout targets
    var postNotes: String      = ""
    var postCarbsGrams: Int?   = nil
    var postProteinGrams: Int? = nil
    var postFluidsMl: Int?     = nil

    // MARK: Overall notes
    var generalNotes: String = ""

    // MARK: Mid-workout fuel entries (JSON-encoded [FuelEntry])
    // Stored as Data to match the runSegmentsData pattern.
    private var entriesData: Data = Data()

    var entries: [FuelEntry] {
        get {
            guard !entriesData.isEmpty else { return [] }
            return (try? JSONDecoder().decode([FuelEntry].self, from: entriesData)) ?? []
        }
        set {
            entriesData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    // MARK: - Convenience

    var hasContent: Bool {
        !preNotes.isEmpty || preCarbsGrams != nil || preFluidsMl != nil ||
        !entries.isEmpty ||
        !postNotes.isEmpty || postCarbsGrams != nil || postFluidsMl != nil ||
        !generalNotes.isEmpty
    }

    init() {
        self.id = UUID()
        self.createdAt = .now
    }
}
