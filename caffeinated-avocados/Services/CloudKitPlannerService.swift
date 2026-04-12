// Services/CloudKitPlannerService.swift
// Manages coach/athlete invite handshake and planned-workout sync
// via the CloudKit **public** database so different iCloud accounts can communicate.

import Foundation
import CloudKit

// MARK: - Record Types & Keys

private enum CKRecordTypes {
    static let invite  = "PlannerInvite"
    static let workout = "CoachPlannedWorkout"
}

private enum InviteKeys {
    static let inviteCode          = "inviteCode"
    static let athleteDisplayName  = "athleteDisplayName"
    static let athleteRecordName   = "athleteRecordName"   // CKRecord.ID.recordName of the athlete's iCloud user
    static let status              = "status"               // "pending" | "accepted"
    static let plannerDisplayName  = "plannerDisplayName"
    static let plannerRecordName   = "plannerRecordName"
    static let createdAt           = "createdAt"
}

private enum WorkoutKeys {
    static let inviteCode                    = "inviteCode"
    static let workoutId                     = "workoutId"           // UUID string — stable across syncs
    static let date                          = "date"
    static let workoutTypeRaw                = "workoutTypeRaw"
    static let title                         = "title"
    static let plannedDistanceMiles          = "plannedDistanceMiles"
    static let plannedDurationSeconds        = "plannedDurationSeconds"
    static let crossTrainingActivityTypeRaw  = "crossTrainingActivityTypeRaw"
    static let runCategoryRaw                = "runCategoryRaw"
    static let runSegmentsJSON               = "runSegmentsJSON"     // JSON string
    static let notes                         = "notes"
    static let intensityLevelRaw             = "intensityLevelRaw"
    static let plannerDisplayName            = "plannerDisplayName"
    static let isDeleted                     = "isDeleted"           // soft-delete flag
    static let updatedAt                     = "updatedAt"
}

// MARK: - Errors

enum CloudKitPlannerError: LocalizedError {
    case notAuthenticated
    case inviteNotFound
    case inviteAlreadyAccepted
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to iCloud to use the planner feature."
        case .inviteNotFound:
            return "No pending invite found for that code. Make sure the athlete sent an invite and the code is correct."
        case .inviteAlreadyAccepted:
            return "That invite has already been accepted by another planner."
        case .networkError(let e):
            return "CloudKit error: \(e.localizedDescription)"
        }
    }
}

// MARK: - Service

struct CloudKitPlannerService {

    static let containerID = "iCloud.io.mccoy.caffeinated-avocados"
    private static var container: CKContainer { CKContainer(identifier: containerID) }
    private static var publicDB: CKDatabase { container.publicCloudDatabase }

    // MARK: - iCloud Identity

    /// Returns the current user's CloudKit record name (stable identifier across devices).
    static func currentUserRecordName() async throws -> String {
        do {
            let id = try await container.userRecordID()
            return id.recordName
        } catch {
            throw CloudKitPlannerError.notAuthenticated
        }
    }

    // MARK: - Invite: Create (athlete side)

    /// Athlete creates a pending invite in the CloudKit public database.
    /// Returns the 8-char invite code.
    @discardableResult
    static func createInvite(code: String, athleteDisplayName: String) async throws -> String {
        let userRecordName = try await currentUserRecordName()

        let record = CKRecord(recordType: CKRecordTypes.invite)
        record[InviteKeys.inviteCode]         = code as CKRecordValue
        record[InviteKeys.athleteDisplayName]  = athleteDisplayName as CKRecordValue
        record[InviteKeys.athleteRecordName]   = userRecordName as CKRecordValue
        record[InviteKeys.status]              = "pending" as CKRecordValue
        record[InviteKeys.plannerDisplayName]  = "" as CKRecordValue
        record[InviteKeys.plannerRecordName]   = "" as CKRecordValue
        record[InviteKeys.createdAt]           = Date.now as CKRecordValue

        do {
            try await publicDB.save(record)
        } catch {
            throw CloudKitPlannerError.networkError(error)
        }
        return code
    }

    // MARK: - Invite: Cancel (athlete side)

    /// Deletes any pending invite records matching `code` from CloudKit.
    static func cancelInvite(code: String) async throws {
        let records = try await fetchInviteRecords(code: code)
        for record in records {
            do {
                try await publicDB.deleteRecord(withID: record.recordID)
            } catch {
                throw CloudKitPlannerError.networkError(error)
            }
        }
    }

    // MARK: - Invite: Accept (planner/coach side)

    /// Planner looks up a pending invite by code, marks it accepted, and fills in planner info.
    /// Returns (athleteDisplayName, inviteCode) on success.
    @discardableResult
    static func acceptInvite(
        code: String,
        plannerDisplayName: String
    ) async throws -> (athleteDisplayName: String, inviteCode: String) {
        let userRecordName = try await currentUserRecordName()

        let records = try await fetchInviteRecords(code: code)
        guard let record = records.first else {
            throw CloudKitPlannerError.inviteNotFound
        }

        let status = record[InviteKeys.status] as? String ?? ""
        guard status == "pending" else {
            throw CloudKitPlannerError.inviteAlreadyAccepted
        }

        let athleteName = record[InviteKeys.athleteDisplayName] as? String ?? "Athlete"

        record[InviteKeys.status]             = "accepted" as CKRecordValue
        record[InviteKeys.plannerDisplayName] = plannerDisplayName as CKRecordValue
        record[InviteKeys.plannerRecordName]  = userRecordName as CKRecordValue

        do {
            try await publicDB.save(record)
        } catch {
            throw CloudKitPlannerError.networkError(error)
        }

        return (athleteName, code)
    }

    // MARK: - Invite: Check Status (athlete polls to see if accepted)

    /// Athlete checks whether their invite has been accepted.
    /// Returns the planner's display name if accepted, nil if still pending.
    static func checkInviteStatus(code: String) async throws -> String? {
        let records = try await fetchInviteRecords(code: code)
        guard let record = records.first else { return nil }

        let status = record[InviteKeys.status] as? String ?? "pending"
        if status == "accepted" {
            return record[InviteKeys.plannerDisplayName] as? String ?? "Coach"
        }
        return nil
    }

    // MARK: - Invite: Revoke (either side)

    /// Removes the invite record and all associated workout records from CloudKit.
    static func revokeRelationship(code: String) async throws {
        // Delete invite
        try await cancelInvite(code: code)
        // Delete associated workouts
        try await deleteAllWorkouts(forInviteCode: code)
    }

    // MARK: - Workouts: Save (planner/coach side)

    /// Coach pushes a planned workout to CloudKit, keyed by the invite code.
    static func saveWorkout(
        inviteCode: String,
        workoutId: String,
        date: Date,
        workoutTypeRaw: String,
        title: String,
        plannedDistanceMiles: Double,
        plannedDurationSeconds: Int,
        crossTrainingActivityTypeRaw: String,
        runCategoryRaw: String,
        runSegmentsJSON: String,
        notes: String,
        intensityLevelRaw: String,
        plannerDisplayName: String
    ) async throws {
        // Check if a record already exists for this workoutId (update vs insert)
        let existing = try await fetchWorkoutRecord(workoutId: workoutId)
        let record = existing ?? CKRecord(recordType: CKRecordTypes.workout)

        record[WorkoutKeys.inviteCode]                   = inviteCode as CKRecordValue
        record[WorkoutKeys.workoutId]                    = workoutId as CKRecordValue
        record[WorkoutKeys.date]                         = date as CKRecordValue
        record[WorkoutKeys.workoutTypeRaw]               = workoutTypeRaw as CKRecordValue
        record[WorkoutKeys.title]                        = title as CKRecordValue
        record[WorkoutKeys.plannedDistanceMiles]         = plannedDistanceMiles as CKRecordValue
        record[WorkoutKeys.plannedDurationSeconds]       = plannedDurationSeconds as CKRecordValue
        record[WorkoutKeys.crossTrainingActivityTypeRaw] = crossTrainingActivityTypeRaw as CKRecordValue
        record[WorkoutKeys.runCategoryRaw]               = runCategoryRaw as CKRecordValue
        record[WorkoutKeys.runSegmentsJSON]              = runSegmentsJSON as CKRecordValue
        record[WorkoutKeys.notes]                        = notes as CKRecordValue
        record[WorkoutKeys.intensityLevelRaw]            = intensityLevelRaw as CKRecordValue
        record[WorkoutKeys.plannerDisplayName]           = plannerDisplayName as CKRecordValue
        record[WorkoutKeys.isDeleted]                    = 0 as CKRecordValue
        record[WorkoutKeys.updatedAt]                    = Date.now as CKRecordValue

        do {
            try await publicDB.save(record)
        } catch {
            throw CloudKitPlannerError.networkError(error)
        }
    }

    // MARK: - Workouts: Soft-Delete (planner/coach side)

    /// Marks a workout as deleted in CloudKit so the athlete's next sync removes it.
    static func softDeleteWorkout(workoutId: String) async throws {
        guard let record = try await fetchWorkoutRecord(workoutId: workoutId) else { return }
        record[WorkoutKeys.isDeleted] = 1 as CKRecordValue
        record[WorkoutKeys.updatedAt] = Date.now as CKRecordValue
        do {
            try await publicDB.save(record)
        } catch {
            throw CloudKitPlannerError.networkError(error)
        }
    }

    // MARK: - Workouts: Fetch (athlete side)

    /// Returns all non-deleted workout records for the given invite code.
    static func fetchWorkouts(forInviteCode code: String) async throws -> [[String: Any]] {
        let predicate = NSPredicate(
            format: "%K == %@ AND %K == %d",
            WorkoutKeys.inviteCode, code,
            WorkoutKeys.isDeleted, 0
        )
        let query = CKQuery(recordType: CKRecordTypes.workout, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: WorkoutKeys.date, ascending: true)]

        do {
            let (results, _) = try await publicDB.records(matching: query)
            return results.compactMap { _, result in
                guard let record = try? result.get() else { return nil }
                return workoutDict(from: record)
            }
        } catch {
            throw CloudKitPlannerError.networkError(error)
        }
    }

    /// Returns workout IDs that have been soft-deleted so the athlete can remove them locally.
    static func fetchDeletedWorkoutIds(forInviteCode code: String) async throws -> [String] {
        let predicate = NSPredicate(
            format: "%K == %@ AND %K == %d",
            WorkoutKeys.inviteCode, code,
            WorkoutKeys.isDeleted, 1
        )
        let query = CKQuery(recordType: CKRecordTypes.workout, predicate: predicate)

        do {
            let (results, _) = try await publicDB.records(matching: query)
            return results.compactMap { _, result in
                guard let record = try? result.get() else { return nil }
                return record[WorkoutKeys.workoutId] as? String
            }
        } catch {
            throw CloudKitPlannerError.networkError(error)
        }
    }

    // MARK: - Private Helpers

    private static func fetchInviteRecords(code: String) async throws -> [CKRecord] {
        let predicate = NSPredicate(format: "%K == %@", InviteKeys.inviteCode, code)
        let query = CKQuery(recordType: CKRecordTypes.invite, predicate: predicate)

        do {
            let (results, _) = try await publicDB.records(matching: query)
            return results.compactMap { _, result in try? result.get() }
        } catch {
            throw CloudKitPlannerError.networkError(error)
        }
    }

    private static func fetchWorkoutRecord(workoutId: String) async throws -> CKRecord? {
        let predicate = NSPredicate(format: "%K == %@", WorkoutKeys.workoutId, workoutId)
        let query = CKQuery(recordType: CKRecordTypes.workout, predicate: predicate)

        do {
            let (results, _) = try await publicDB.records(matching: query)
            return results.compactMap({ _, result in try? result.get() }).first
        } catch {
            throw CloudKitPlannerError.networkError(error)
        }
    }

    private static func deleteAllWorkouts(forInviteCode code: String) async throws {
        let predicate = NSPredicate(format: "%K == %@", WorkoutKeys.inviteCode, code)
        let query = CKQuery(recordType: CKRecordTypes.workout, predicate: predicate)

        do {
            let (results, _) = try await publicDB.records(matching: query)
            for (_, result) in results {
                if let record = try? result.get() {
                    try await publicDB.deleteRecord(withID: record.recordID)
                }
            }
        } catch {
            throw CloudKitPlannerError.networkError(error)
        }
    }

    private static func workoutDict(from record: CKRecord) -> [String: Any] {
        [
            "workoutId":                    record[WorkoutKeys.workoutId] as? String ?? "",
            "date":                         record[WorkoutKeys.date] as? Date ?? Date(),
            "workoutTypeRaw":               record[WorkoutKeys.workoutTypeRaw] as? String ?? "",
            "title":                        record[WorkoutKeys.title] as? String ?? "",
            "plannedDistanceMiles":         record[WorkoutKeys.plannedDistanceMiles] as? Double ?? 0,
            "plannedDurationSeconds":       record[WorkoutKeys.plannedDurationSeconds] as? Int ?? 0,
            "crossTrainingActivityTypeRaw": record[WorkoutKeys.crossTrainingActivityTypeRaw] as? String ?? "",
            "runCategoryRaw":               record[WorkoutKeys.runCategoryRaw] as? String ?? "",
            "runSegmentsJSON":              record[WorkoutKeys.runSegmentsJSON] as? String ?? "[]",
            "notes":                        record[WorkoutKeys.notes] as? String ?? "",
            "intensityLevelRaw":            record[WorkoutKeys.intensityLevelRaw] as? String ?? "",
            "plannerDisplayName":           record[WorkoutKeys.plannerDisplayName] as? String ?? "",
        ]
    }
}
