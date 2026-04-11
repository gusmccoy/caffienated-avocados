// McCoyFitnessApp.swift
// Entry point for the McCoy Fitness iOS app.
// Architecture: SwiftUI + MVVM | Persistence: SwiftData | Target: iOS 17+

import SwiftUI
import SwiftData
import UserNotifications

@main
struct McCoyFitnessApp: App {

    // MARK: - SwiftData Model Container
    // All models that need persistence are registered here.
    let modelContainer: ModelContainer = {
        let schema = Schema([
            WorkoutSession.self,
            RunningWorkout.self,
            StrengthWorkout.self,
            ExerciseSet.self,
            CrossTrainingWorkout.self,
            StravaConnection.self,
            PlannedWorkout.self,
            Race.self,
            PlannerRelationship.self,
            PersonalRecord.self,
            PRMilestone.self,
            FuelPlan.self,
            NotificationRule.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Schema migration failure — wipe the local store and start fresh.
            // This happens when new model properties can't be automatically migrated.
            // User data is lost, but the app no longer crashes on update.
            print("⚠️ SwiftData migration failed (\(error)). Wiping store and recreating.")
            let storeBase = URL.applicationSupportDirectory
            let extensions = ["store", "store-shm", "store-wal"]
            for ext in extensions {
                let url = storeBase.appending(path: "default.\(ext)")
                try? FileManager.default.removeItem(at: url)
            }
            do {
                return try ModelContainer(for: schema, configurations: [config])
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
                    let rules = (try? ctx.fetch(FetchDescriptor<NotificationRule>())) ?? []
                    let workouts = (try? ctx.fetch(FetchDescriptor<PlannedWorkout>())) ?? []
                    let races = (try? ctx.fetch(FetchDescriptor<Race>())) ?? []
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
