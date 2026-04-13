// Services/InviteService.swift
// Cross-device invite handshake via CloudKit's public database.
//
// Why two record types?
// In CloudKit's public database only the *creator* of a record can write to it
// by default.  If we stored the invite in a single record and had the coach
// update it, the WRITE would be rejected because the coach didn't create it.
//
// Solution: each party creates their own record — no cross-user writes needed.
//
//   PendingInvite   — created by the *athlete*
//                     fields: inviteCode, athleteDisplayName, createdAt
//                     record name: "pending-{CODE}"
//
//   AcceptedInvite  — created by the *coach* after looking up the code
//                     fields: inviteCode, plannerDisplayName, createdAt
//                     record name: "accepted-{CODE}"
//
// Lifecycle:
//   1. Athlete generates code → publish() writes a PendingInvite record.
//   2. Coach enters code  → accept() fetches PendingInvite (read ✓),
//                           creates AcceptedInvite (own record ✓),
//                           returns the athleteDisplayName to caller.
//   3. Athlete's app polls → checkAcceptance() fetches AcceptedInvite by code.
//                           On match: local record is activated, PendingInvite
//                           is deleted (athlete is the creator ✓).
//
// IMPORTANT: Both "PendingInvite" and "AcceptedInvite" record types must be
// deployed to production in the CloudKit Dashboard before App Store / TestFlight
// builds can use them.  In development they are created automatically on first write.

import CloudKit
import Foundation

// MARK: - Errors

enum InviteError: LocalizedError {
    case notFound
    case alreadyAccepted

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "No pending invite found for that code. Make sure the athlete sent an invite and the code is correct."
        case .alreadyAccepted:
            return "This invite code has already been used."
        }
    }
}

// MARK: - Service

actor InviteService {
    static let shared = InviteService()
    private init() {}

    private let db = CKContainer(identifier: "iCloud.io.mccoy.caffeinated-avocados").publicCloudDatabase
    private static let pendingType  = "PendingInvite"
    private static let acceptedType = "AcceptedInvite"

    private func pendingID(for code: String)  -> CKRecord.ID { CKRecord.ID(recordName: "pending-\(code.uppercased())") }
    private func acceptedID(for code: String) -> CKRecord.ID { CKRecord.ID(recordName: "accepted-\(code.uppercased())") }

    // MARK: Athlete — publish

    func publish(code: String, athleteDisplayName: String) async throws {
        let record = CKRecord(recordType: Self.pendingType, recordID: pendingID(for: code))
        record["inviteCode"]         = code.uppercased() as CKRecordValue
        record["athleteDisplayName"] = athleteDisplayName as CKRecordValue
        record["createdAt"]          = Date() as CKRecordValue
        _ = try await db.save(record)
    }

    // MARK: Athlete — poll for acceptance

    /// Returns the planner's display name once the coach has accepted, nil otherwise.
    func checkAcceptance(code: String) async -> String? {
        guard let record = try? await db.record(for: acceptedID(for: code)) else { return nil }
        return record["plannerDisplayName"] as? String
    }

    // MARK: Athlete — delete pending invite (on revoke or after confirmed acceptance)

    func deletePending(code: String) async {
        _ = try? await db.deleteRecord(withID: pendingID(for: code))
    }

    // MARK: Coach — accept
    //
    // Reads the athlete's PendingInvite (read-only, any user can read public DB),
    // then creates an AcceptedInvite owned by the coach (creator can always write).

    /// Returns the athlete's display name on success.
    /// Throws InviteError.notFound if the code doesn't exist,
    /// or InviteError.alreadyAccepted if the coach already created an acceptance record.
    func accept(code: String, plannerDisplayName: String) async throws -> String {
        // 1. Look up the athlete's pending invite
        let pending: CKRecord
        do {
            pending = try await db.record(for: pendingID(for: code))
        } catch let e as CKError where e.code == .unknownItem {
            throw InviteError.notFound
        }

        // 2. Check the invite hasn't already been claimed
        if (try? await db.record(for: acceptedID(for: code))) != nil {
            throw InviteError.alreadyAccepted
        }

        // 3. Create the coach's own acceptance record (creator write — always allowed)
        let athleteName = (pending["athleteDisplayName"] as? String) ?? "Athlete"
        let acceptance = CKRecord(recordType: Self.acceptedType, recordID: acceptedID(for: code))
        acceptance["inviteCode"]        = code.uppercased() as CKRecordValue
        acceptance["plannerDisplayName"] = plannerDisplayName as CKRecordValue
        acceptance["createdAt"]          = Date() as CKRecordValue
        _ = try await db.save(acceptance)

        return athleteName
    }
}
