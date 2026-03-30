// McCoyFitnessApp.swift
// Entry point for the McCoy Fitness iOS app.
// Architecture: SwiftUI + MVVM | Persistence: SwiftData | Target: iOS 17+

import SwiftUI
import SwiftData

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
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
