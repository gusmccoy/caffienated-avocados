// Models/RacePrep.swift
// Race preparation checklist with items across gear, lodging, travel, and fuel categories.

import Foundation
import SwiftData

// MARK: - Enums

enum PrepCategory: String, Codable, CaseIterable {
    case gear
    case lodging
    case travel
    case fuel

    var displayName: String {
        switch self {
        case .gear:    return "Gear"
        case .lodging: return "Lodging"
        case .travel:  return "Travel"
        case .fuel:    return "Fuel"
        }
    }

    var systemImage: String {
        switch self {
        case .gear:    return "bag.fill"
        case .lodging: return "bed.double.fill"
        case .travel:  return "airplane"
        case .fuel:    return "fork.knife"
        }
    }
}

// MARK: - PrepItem (struct, stored as JSON)

/// A single item on the race prep checklist.
struct PrepItem: Codable, Identifiable {
    var id: UUID              = UUID()
    var name: String          = ""
    var categoryRaw: String   = PrepCategory.gear.rawValue
    var notes: String         = ""
    var isCompleted: Bool     = false
    var dueDate: Date?        = nil
    var createdAt: Date       = Date()

    var category: PrepCategory { PrepCategory(rawValue: categoryRaw) ?? .gear }

    init(name: String, category: PrepCategory, notes: String = "", dueDate: Date? = nil) {
        self.id = UUID()
        self.name = name
        self.categoryRaw = category.rawValue
        self.notes = notes
        self.isCompleted = false
        self.dueDate = dueDate
        self.createdAt = Date()
    }
}

// MARK: - RacePrep (@Model)

/// Race preparation checklist, attached to a Race via `Race.racePrep`.
@Model
final class RacePrep {
    var id: UUID        = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - Items (JSON-encoded [PrepItem])
    private var itemsData: Data = Data()

    var items: [PrepItem] {
        get {
            guard !itemsData.isEmpty else { return [] }
            return (try? JSONDecoder().decode([PrepItem].self, from: itemsData)) ?? []
        }
        set {
            itemsData = (try? JSONEncoder().encode(newValue)) ?? Data()
            updatedAt = Date()
        }
    }

    // MARK: - Inverse relationship (required for CloudKit)
    var race: Race?

    // MARK: - Convenience
    var completedCount: Int { items.filter { $0.isCompleted }.count }
    var totalCount: Int { items.count }
    var completionPercentage: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    init() {
        self.id = UUID()
        self.createdAt = .now
        self.updatedAt = .now
    }
}
