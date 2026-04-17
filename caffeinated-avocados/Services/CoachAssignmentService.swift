// Services/CoachAssignmentService.swift
// Syncs coach-assigned workouts to athletes via CloudKit's public database.
//
// SwiftData uses the *private* CloudKit container, which is per-iCloud-account.
// A workout the coach inserts on their device never reaches the athlete's device.
// The public DB is readable/writable by all authenticated app users, making it
// the right shared medium for cross-user delivery.
//
// Security: each CoachAssignment record is keyed by an inviteCode (8-char random
// UUID fragment) that only the coach and athlete know.
//
// Record type: "CoachAssignment" (public DB)
//   inviteCode   String   — identifies the coach/athlete pair
//   workoutId    String   — PlannedWorkout.id.uuidString; used as a stable key
//   payloadJSON  String   — JSON-encoded CoachAssignmentPayload
//   isDeleted    Int64    — 0 = active, 1 = deleted by coach
//   updatedAt    Date
//   Record name: "coachassign-{workoutId}"
//
// IMPORTANT: The "CoachAssignment" record type and its fields (especially
// `inviteCode` which must be queryable) need to be deployed to production in
// the CloudKit Dashboard before App Store / TestFlight builds can use them.

import CloudKit
import Foundation

// MARK: - Payload

/// Codable snapshot of a PlannedWorkout's fields, stored as JSON in CloudKit.
struct CoachAssignmentPayload: Codable, Sendable {
    var id: String                          // PlannedWorkout.id.uuidString
    var date: Date
    var workoutTypeRaw: String
    var title: String
    var plannedDistanceMiles: Double
    var plannedDurationSeconds: Int
    var strengthTypeRaw: String
    var crossTrainingActivityTypeRaw: String
    var runCategoryRaw: String
    var runSegmentsData: Data               // already JSON-encoded by PlannedWorkout
    var notes: String
    var postRunStrides: Bool
    var intensityLevelRaw: String
    var plannerDisplayName: String
}

// MARK: - Record wrapper

struct CoachAssignmentRecord: Sendable {
    var workoutId: String
    var payload: CoachAssignmentPayload?    // nil when isDeleted == true
    var isDeleted: Bool
}

// MARK: - Service

actor CoachAssignmentService {
    static let shared = CoachAssignmentService()
    private init() {}

    private let db = CKContainer(identifier: "iCloud.io.mccoy.caffeinated-avocados").publicCloudDatabase
    private static let recordType = "CoachAssignment"

    private func recordID(for workoutId: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "coachassign-\(workoutId)")
    }

    // MARK: Coach — publish (create or overwrite)

    func publish(payload: CoachAssignmentPayload, inviteCode: String) async throws {
        let data   = try JSONEncoder().encode(payload)
        let json   = String(data: data, encoding: .utf8) ?? "{}"
        let record = CKRecord(recordType: Self.recordType, recordID: recordID(for: payload.id))
        record["inviteCode"]   = inviteCode as CKRecordValue
        record["workoutId"]    = payload.id as CKRecordValue
        record["payloadJSON"]  = json as CKRecordValue
        record["isDeleted"]    = Int64(0) as CKRecordValue
        record["updatedAt"]    = Date() as CKRecordValue
        _ = try await db.save(record)
    }

    // MARK: Coach — mark deleted

    func markDeleted(workoutId: String) async {
        let rid = recordID(for: workoutId)
        guard let record = try? await db.record(for: rid) else { return }
        record["isDeleted"] = Int64(1) as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue
        _ = try? await db.save(record)
    }

    // MARK: Athlete — fetch all (active + deleted) for an invite code

    func fetchAll(inviteCode: String) async throws -> [CoachAssignmentRecord] {
        let predicate = NSPredicate(format: "inviteCode == %@", inviteCode)
        let query     = CKQuery(recordType: Self.recordType, predicate: predicate)
        let (matchResults, _) = try await db.records(matching: query, resultsLimit: 500)

        var results: [CoachAssignmentRecord] = []
        for (_, result) in matchResults {
            guard let record = try? result.get() else { continue }
            let workoutId = record["workoutId"] as? String ?? ""
            let deleted   = (record["isDeleted"] as? Int64 ?? 0) == 1

            if deleted {
                results.append(CoachAssignmentRecord(workoutId: workoutId, payload: nil, isDeleted: true))
            } else if let json    = record["payloadJSON"] as? String,
                      let data    = json.data(using: .utf8),
                      let payload = try? JSONDecoder().decode(CoachAssignmentPayload.self, from: data) {
                results.append(CoachAssignmentRecord(workoutId: workoutId, payload: payload, isDeleted: false))
            }
        }
        return results
    }
}
