// ViewModels/StrengthViewModel.swift
// Manages state for logging strength training sessions.

import Foundation
import SwiftData
import Observation

@Observable
final class StrengthViewModel {

    // MARK: - Session-level state
    var date: Date = .now
    var title: String = ""
    var workoutTemplate: String = ""
    var hours: Int = 0
    var minutes: Int = 0
    var seconds: Int = 0
    var intensityLevel: IntensityLevel = .moderate
    var heartRateAvg: String = ""
    var caloriesBurned: String = ""
    var notes: String = ""
    var selectedMuscleGroups: Set<MuscleGroup> = []

    // MARK: - Exercise builder state
    var exercises: [ExerciseEntry] = []
    var isAddingExercise: Bool = false
    var newExerciseName: String = ""
    var newExerciseMuscleGroup: MuscleGroup = .other

    struct ExerciseEntry: Identifiable {
        var id = UUID()
        var name: String
        var muscleGroup: MuscleGroup
        var sets: [SetEntry]

        mutating func addSet() {
            let lastWeight = sets.last?.weightLbs
            let lastReps = sets.last?.reps
            sets.append(SetEntry(
                setNumber: sets.count + 1,
                weightLbs: lastWeight,
                reps: lastReps,
                completed: false
            ))
        }

        mutating func removeSet(at index: Int) {
            guard sets.indices.contains(index) else { return }
            sets.remove(at: index)
            // Re-number
            for i in sets.indices {
                sets[i].setNumber = i + 1
            }
        }
    }

    // MARK: - Computed

    var durationSeconds: Int {
        hours * 3600 + minutes * 60 + seconds
    }

    var totalVolumeLbs: Double {
        exercises.reduce(0) { sum, ex in
            sum + ex.sets.reduce(0) { setSum, set in
                setSum + (set.weightLbs ?? 0) * Double(set.reps ?? 0)
            }
        }
    }

    var isFormValid: Bool {
        !exercises.isEmpty && durationSeconds > 0
    }

    // MARK: - Exercise management

    func addExercise() {
        guard !newExerciseName.isEmpty else { return }
        exercises.append(ExerciseEntry(
            name: newExerciseName,
            muscleGroup: newExerciseMuscleGroup,
            sets: [SetEntry(setNumber: 1, completed: false)]
        ))
        newExerciseName = ""
        newExerciseMuscleGroup = .other
        isAddingExercise = false
    }

    func removeExercise(at offsets: IndexSet) {
        exercises.remove(atOffsets: offsets)
    }

    func moveExercise(from source: IndexSet, to destination: Int) {
        exercises.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Reset

    func reset() {
        date = .now
        title = ""
        workoutTemplate = ""
        hours = 0
        minutes = 0
        seconds = 0
        intensityLevel = .moderate
        heartRateAvg = ""
        caloriesBurned = ""
        notes = ""
        selectedMuscleGroups = []
        exercises = []
    }

    // MARK: - Build model objects

    func buildWorkoutSession(modelContext: ModelContext) -> WorkoutSession {
        let session = WorkoutSession(
            date: date,
            type: .strength,
            title: title.isEmpty ? (workoutTemplate.isEmpty ? "Strength" : workoutTemplate) : title,
            notes: notes,
            durationSeconds: durationSeconds,
            intensityLevel: intensityLevel,
            caloriesBurned: Int(caloriesBurned),
            heartRateAvg: Int(heartRateAvg)
        )

        let strength = StrengthWorkout(
            workoutTemplate: workoutTemplate.isEmpty ? nil : workoutTemplate,
            primaryMuscleGroups: Array(selectedMuscleGroups)
        )

        for entry in exercises {
            let exModel = ExerciseSet(
                name: entry.name,
                muscleGroup: entry.muscleGroup,
                orderIndex: exercises.firstIndex(where: { $0.id == entry.id }) ?? 0
            )
            exModel.sets = entry.sets
            exModel.strengthWorkout = strength
            strength.exercises.append(exModel)
            modelContext.insert(exModel)
        }

        strength.recalculateVolume()
        strength.session = session
        session.strengthWorkout = strength

        modelContext.insert(session)
        modelContext.insert(strength)
        return session
    }
}
