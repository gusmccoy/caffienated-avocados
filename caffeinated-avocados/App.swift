// McCoyFitnessApp.swift
// Entry point for the McCoy Fitness iOS app.
// Architecture: SwiftUI + MVVM | Persistence: SwiftData | Target: iOS 17+

import SwiftUI
import SwiftData
import UserNotifications

@main
struct McCoyFitnessApp: App {

    // MARK: - SwiftData Model Container
    //
    // The container is split into two persistent stores:
    //
    // • CloudStore  — CloudKit-backed, synced across the user's devices.
    //                 Contains plan and profile data: PlannedWorkout, Race,
    //                 FuelPlan, PersonalRecord, PRMilestone, NotificationRule.
    //
    // • LocalStore  — On-device only. Contains workout sessions, health data,
    //                 and credentials that should NOT leave the device.
    //                 Reuses the pre-split "default.store" URL so existing
    //                 logged activities are preserved on app update.
    //
    // CloudKit container: iCloud.io.mccoy.caffeinated-avocados
    // Prerequisites (one-time in Xcode / Developer Portal):
    //   1. Enable iCloud capability → CloudKit.
    //   2. Add container "iCloud.io.mccoy.caffeinated-avocados" in the portal.
    //   3. Enable Push Notifications capability (needed for CK change tokens).

    let modelContainer: ModelContainer = {
        // Models that sync via CloudKit
        let cloudSchema = Schema([
            PlannedWorkout.self,
            Race.self,
            FuelPlan.self,
            PersonalRecord.self,
            PRMilestone.self,
            NotificationRule.self,
        ])

        // Models stored on-device only
        let localSchema = Schema([
            WorkoutSession.self,
            RunningWorkout.self,
            StrengthWorkout.self,
            ExerciseSet.self,
            CrossTrainingWorkout.self,
            StravaConnection.self,
            PlannerRelationship.self,
        ])

        let cloudConfig = ModelConfiguration(
            "CloudStore",
            schema: cloudSchema,
            cloudKitDatabase: .private("iCloud.io.mccoy.caffeinated-avocados")
        )

        // Point the local store at the legacy "default.store" URL so that
        // existing logged workout data is preserved after the migration.
        let legacyURL = URL.applicationSupportDirectory
            .appending(path: "default.store")
        let localConfig = ModelConfiguration(
            "LocalStore",
            schema: localSchema,
            url: legacyURL
        )

        let fullSchema = Schema(
            cloudSchema.entities + localSchema.entities
        )

        do {
            return try ModelContainer(
                for: fullSchema,
                configurations: [cloudConfig, localConfig]
            )
        } catch {
            // Schema migration failure — wipe both stores and start fresh.
            print("⚠️ SwiftData migration failed (\(error)). Wiping stores and recreating.")
            let storeBase = URL.applicationSupportDirectory
            // Legacy / local store files
            for ext in ["store", "store-shm", "store-wal"] {
                try? FileManager.default.removeItem(
                    at: storeBase.appending(path: "default.\(ext)")
                )
            }
            // CloudKit store files
            for ext in ["store", "store-shm", "store-wal"] {
                try? FileManager.default.removeItem(
                    at: storeBase.appending(path: "CloudStore.\(ext)")
                )
            }
            do {
                return try ModelContainer(
                    for: fullSchema,
                    configurations: [cloudConfig, localConfig]
                )
            } catch {
                fatalError("Could not create ModelContainer even after store wipe: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Weekly planning reminder
                    let enabled = UserDefaults.standard.bool(forKey: "planningReminderEnabled")
                    if enabled {
                        await WeeklyPlanningReminderService.requestPermission()
                        let raw = UserDefaults.standard.object(forKey: "planningReminderMinutesSinceMidnight") as? Int ?? 720
                        let mins = raw > 0 ? raw : 720
                        WeeklyPlanningReminderService.scheduleReminder(hour: mins / 60, minute: mins % 60)
                    }

                    // Enhanced rule-based notifications
                    await EnhancedNotificationService.requestPermission()
                    let ctx = modelContainer.mainContext
                    let rules    = (try? ctx.fetch(FetchDescriptor<NotificationRule>())) ?? []
                    let workouts = (try? ctx.fetch(FetchDescriptor<PlannedWorkout>())) ?? []
                    let races    = (try? ctx.fetch(FetchDescriptor<Race>())) ?? []
                    EnhancedNotificationService.scheduleNotifications(
                        rules: rules,
                        plannedWorkouts: workouts,
                        races: races
                    )
                }
        }
        .modelContainer(modelContainer)
    }
}
