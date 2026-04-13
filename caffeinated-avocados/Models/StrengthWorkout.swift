// Models/StrengthWorkout.swift
// Strength training data — exercises, sets, reps, and weights.

import Foundation
import SwiftData

/// Broad classification for a strength session.
enum StrengthType: String, Codable, CaseIterable {
    case unspecified = "Unspecified"
    case upper    = "Upper Body"
    case lower    = "Lower Body"
    case core     = "Core"
    case fullBody = "Full Body"
}

/// High-level muscle group category.
enum MuscleGroup: String, Codable, CaseIterable {
    case chest      = "Chest"
    case back       = "Back"
    case shoulders  = "Shoulders"
    case biceps     = "Biceps"
    case triceps    = "Triceps"
    case legs       = "Legs"
    case glutes     = "Glutes"
    case core       = "Core"
    case fullBody   = "Full Body"
    case other      = "Other"
}

/// Weight unit preference.
enum WeightUnit: String, Codable, CaseIterable {
    case lbs = "lbs"
    case kg  = "kg"

    func convert(_ value: Double) -> Double {
        switch self {
        case .lbs: return value
        case .kg:  return value * 0.453592
        }
    }
}

@Model
final class StrengthWorkout {
    var id: UUID = UUID()
    var workoutTemplate: String?      // e.g. "Push Day A", "5/3/1 Week 1"
    var strengthTypeRaw: String = StrengthType.unspecified.rawValue
    var strengthType: StrengthType {
        get { StrengthType(rawValue: strengthTypeRaw) ?? .unspecified }
        set { strengthTypeRaw = newValue.rawValue }
    }
    var primaryMuscleGroups: [MuscleGroup] = []
    var totalVolumeLbs: Double = 0    // Computed sum of (weight × reps) for all sets
    var restBetweenSetsSecs: Int?

    @Relationship(deleteRule: .cascade) var exercises: [ExerciseSet]?

    var session: WorkoutSession?

    init(
        workoutTemplate: String? = nil,
        strengthType: StrengthType = .unspecified,
        primaryMuscleGroups: [MuscleGroup] = [],
        restBetweenSetsSecs: Int? = nil
    ) {
        self.id = UUID()
        self.workoutTemplate = workoutTemplate
        self.strengthTypeRaw = strengthType.rawValue
        self.primaryMuscleGroups = primaryMuscleGroups
        self.totalVolumeLbs = 0
        self.restBetweenSetsSecs = restBetweenSetsSecs
        self.exercises = []
    }

    /// Recalculates total volume from all exercise sets.
    func recalculateVolume() {
        totalVolumeLbs = (exercises ?? []).reduce(0) { sum, exercise in
            sum + exercise.sets.reduce(0) { setSum, set in
                setSum + (set.weightLbs ?? 0) * Double(set.reps ?? 0)
            }
        }
    }
}

// MARK: - ExerciseSet

/// One exercise entry (e.g. "Bench Press") within a strength workout.
@Model
final class ExerciseSet {
    var id: UUID = UUID()
    var name: String = ""
    var muscleGroup: MuscleGroup = MuscleGroup.other
    var orderIndex: Int = 0           // Display order within the workout
    var sets: [SetEntry] = []
    var notes: String = ""

    var strengthWorkout: StrengthWorkout?

    init(
        name: String,
        muscleGroup: MuscleGroup = .other,
        orderIndex: Int = 0,
        notes: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.muscleGroup = muscleGroup
        self.orderIndex = orderIndex
        self.sets = []
        self.notes = notes
    }
}

// MARK: - SetEntry

/// One individual set within an exercise (e.g. "225 lbs × 5 reps").
struct SetEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var setNumber: Int
    var weightLbs: Double?
    var reps: Int?
    var rpe: Double?                  // Rate of Perceived Exertion (1-10)
    var isWarmup: Bool
    var durationSeconds: Int?         // For timed holds (planks, wall sits, etc.)
    var completed: Bool

    init(
        setNumber: Int,
        weightLbs: Double? = nil,
        reps: Int? = nil,
        rpe: Double? = nil,
        isWarmup: Bool = false,
        durationSeconds: Int? = nil,
        completed: Bool = false
    ) {
        self.setNumber = setNumber
        self.weightLbs = weightLbs
        self.reps = reps
        self.rpe = rpe
        self.isWarmup = isWarmup
        self.durationSeconds = durationSeconds
        self.completed = completed
    }

    var formattedWeight: String {
        guard let w = weightLbs else { return "BW" }
        return w.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(w)) lbs"
            : String(format: "%.1f lbs", w)
    }
}
