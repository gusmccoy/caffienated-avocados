// ViewModels/RunningViewModel.swift
// Manages state for creating and editing running workout sessions.

import Foundation
import SwiftData
import Observation

@Observable
final class RunningViewModel {

    // MARK: - Form State (bound to the Add/Edit running view)
    var date: Date = .now
    var title: String = ""
    var runType: RunType = .easy
    var distanceMiles: Double = 0
    var hours: Int = 0
    var minutes: Int = 0
    var seconds: Int = 0
    var intensityLevel: IntensityLevel = .moderate
    var heartRateAvg: String = ""
    var heartRateMax: String = ""
    var caloriesBurned: String = ""
    var elevationGainFeet: String = ""
    var cadenceAvg: String = ""
    var route: String = ""
    var notes: String = ""

    // MARK: - Validation
    var isFormValid: Bool {
        distanceMiles > 0 && durationSeconds > 0
    }

    var durationSeconds: Int {
        hours * 3600 + minutes * 60 + seconds
    }

    var averagePaceSecondsPerMile: Int {
        guard distanceMiles > 0 else { return 0 }
        return Int(Double(durationSeconds) / distanceMiles)
    }

    var formattedPace: String {
        let spm = averagePaceSecondsPerMile
        guard spm > 0 else { return "--:--" }
        return String(format: "%d:%02d /mi", spm / 60, spm % 60)
    }

    // MARK: - Reset

    func reset() {
        date = .now
        title = ""
        runType = .easy
        distanceMiles = 0
        hours = 0
        minutes = 0
        seconds = 0
        intensityLevel = .moderate
        heartRateAvg = ""
        heartRateMax = ""
        caloriesBurned = ""
        elevationGainFeet = ""
        cadenceAvg = ""
        route = ""
        notes = ""
    }

    // MARK: - Populate from existing session (for editing)

    func populate(from session: WorkoutSession) {
        date = session.date
        title = session.title
        intensityLevel = session.intensityLevel
        notes = session.notes
        heartRateAvg = session.heartRateAvg.map(String.init) ?? ""
        heartRateMax = session.heartRateMax.map(String.init) ?? ""
        caloriesBurned = session.caloriesBurned.map(String.init) ?? ""

        let duration = session.durationSeconds
        hours   = duration / 3600
        minutes = (duration % 3600) / 60
        seconds = duration % 60

        if let run = session.runningWorkout {
            runType = run.runType
            distanceMiles = run.distanceMiles
            elevationGainFeet = run.elevationGainFeet.map { String($0) } ?? ""
            cadenceAvg = run.cadenceAvg.map(String.init) ?? ""
            route = run.route ?? ""
        }
    }

    // MARK: - Build model objects

    func buildWorkoutSession(modelContext: ModelContext) -> WorkoutSession {
        let session = WorkoutSession(
            date: date,
            type: .running,
            title: title.isEmpty ? runType.rawValue : title,
            notes: notes,
            durationSeconds: durationSeconds,
            intensityLevel: intensityLevel,
            caloriesBurned: Int(caloriesBurned),
            heartRateAvg: Int(heartRateAvg),
            heartRateMax: Int(heartRateMax)
        )

        let run = RunningWorkout(
            distanceMiles: distanceMiles,
            runType: runType,
            averagePaceSecondsPerMile: averagePaceSecondsPerMile,
            elevationGainFeet: Double(elevationGainFeet),
            cadenceAvg: Int(cadenceAvg),
            route: route.isEmpty ? nil : route
        )

        run.session = session
        session.runningWorkout = run

        modelContext.insert(session)
        modelContext.insert(run)
        return session
    }
}
