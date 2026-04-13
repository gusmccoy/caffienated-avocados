// Models/PlannerRelationship.swift
// Represents one side of a coach/athlete planner relationship.
//
// Invite flow:
//   1. Athlete taps "Invite Coach" → generates a short code → stored as (pendingOutgoing, isAthlete=true)
//   2. Athlete shares code out-of-band (copy/paste, AirDrop, etc.)
//   3. Planner enters code → app looks up the matching pendingOutgoing record, activates both sides:
//      - existing record updated to (accepted, isAthlete=true)
//      - new record inserted as           (accepted, isAthlete=false) with plannerDisplayName filled
//
// For cross-device support this store would be backed by CloudKit
// (ModelConfiguration(cloudKitDatabase: .automatic)).

import Foundation
import SwiftData

// MARK: - Status

enum PlannerRelationshipStatus: String, Codable {
    /// Athlete generated an invite code; planner hasn't entered it yet.
    case pendingOutgoing = "pendingOutgoing"
    /// Active — both sides are linked.
    case accepted        = "accepted"
}

// MARK: - Model

@Model
final class PlannerRelationship {
    var id: UUID = UUID()
    /// Short code (8 uppercase chars) used to pair the two sides.
    var inviteCode: String = ""
    /// Raw string backing the status enum.
    var statusRaw: String = PlannerRelationshipStatus.pendingOutgoing.rawValue

    var status: PlannerRelationshipStatus {
        get { PlannerRelationshipStatus(rawValue: statusRaw) ?? .pendingOutgoing }
        set { statusRaw = newValue.rawValue; updatedAt = .now }
    }

    /// True when the current device/user is the **athlete** in this relationship.
    /// False when the current user is the **planner** for `athleteDisplayName`.
    var currentUserIsAthlete: Bool = false

    /// Display name of the athlete (shown in planner's Athletes tab).
    var athleteDisplayName: String = ""
    /// Display name of the planner (shown in athlete's Settings and plan rows).
    var plannerDisplayName: String = ""

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        inviteCode: String,
        status: PlannerRelationshipStatus,
        currentUserIsAthlete: Bool,
        athleteDisplayName: String,
        plannerDisplayName: String
    ) {
        self.id = UUID()
        self.inviteCode = inviteCode
        self.statusRaw  = status.rawValue
        self.currentUserIsAthlete = currentUserIsAthlete
        self.athleteDisplayName  = athleteDisplayName
        self.plannerDisplayName  = plannerDisplayName
        self.createdAt = .now
        self.updatedAt = .now
    }
}
