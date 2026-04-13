// Models/InjuryRecord.swift
// Injury or extended break record with comeback phase milestones.

import Foundation
import SwiftData

// MARK: - Recovery Phase

enum RecoveryPhase: String, Codable, CaseIterable {
    case resting      = "Resting"
    case walking      = "Walking"
    case easyRunning  = "Easy Running"
    case buildingBack = "Building Back"
    case fullTraining = "Full Training"

    var systemImage: String {
        switch self {
        case .resting:      return "bed.double.fill"
        case .walking:      return "figure.walk"
        case .easyRunning:  return "figure.run"
        case .buildingBack: return "arrow.up.circle"
        case .fullTraining: return "checkmark.seal.fill"
        }
    }

    var color: String {
        switch self {
        case .resting:      return "red"
        case .walking:      return "orange"
        case .easyRunning:  return "yellow"
        case .buildingBack: return "blue"
        case .fullTraining: return "green"
        }
    }
}

// MARK: - Comeback Milestone (value type)

struct ComebackMilestone: Codable, Identifiable {
    var id: UUID = UUID()
    var phaseRaw: String = RecoveryPhase.walking.rawValue
    var date: Date = .now
    var notes: String = ""

    var phase: RecoveryPhase {
        get { RecoveryPhase(rawValue: phaseRaw) ?? .walking }
        set { phaseRaw = newValue.rawValue }
    }
}

// MARK: - InjuryRecord (@Model)

@Model
final class InjuryRecord {
    var id: UUID = UUID()
    var startDate: Date = Date()
    /// nil = injury is still ongoing.
    var endDate: Date? = nil
    /// Brief description of what happened.
    var injuryDescription: String = ""
    var isActive: Bool = true
    /// Current comeback phase (updated as the athlete progresses).
    var recoveryPhaseRaw: String = RecoveryPhase.resting.rawValue
    /// JSON-encoded [ComebackMilestone] progress log.
    var milestonesData: Data = Data()
    /// UUID of a PRMilestone created for post-injury era tracking.
    var linkedPRMilestoneIdString: String? = nil
    var createdAt: Date = Date()

    var recoveryPhase: RecoveryPhase {
        get { RecoveryPhase(rawValue: recoveryPhaseRaw) ?? .resting }
        set { recoveryPhaseRaw = newValue.rawValue }
    }

    var comebackMilestones: [ComebackMilestone] {
        get {
            guard !milestonesData.isEmpty else { return [] }
            return (try? JSONDecoder().decode([ComebackMilestone].self, from: milestonesData)) ?? []
        }
        set {
            milestonesData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    var linkedPRMilestoneId: UUID? {
        get { linkedPRMilestoneIdString.flatMap { UUID(uuidString: $0) } }
        set { linkedPRMilestoneIdString = newValue?.uuidString }
    }

    init(
        startDate: Date = .now,
        injuryDescription: String = "",
        recoveryPhase: RecoveryPhase = .resting
    ) {
        self.id = UUID()
        self.startDate = startDate
        self.injuryDescription = injuryDescription
        self.recoveryPhaseRaw = recoveryPhase.rawValue
        self.isActive = true
        self.createdAt = .now
    }

    /// Duration label — e.g. "12 days" or "3 weeks".
    var durationLabel: String {
        let end = endDate ?? .now
        let days = Calendar.current.dateComponents([.day], from: startDate, to: end).day ?? 0
        if days < 14 { return "\(days) day\(days == 1 ? "" : "s")" }
        let weeks = days / 7
        return "\(weeks) week\(weeks == 1 ? "" : "s")"
    }
}
