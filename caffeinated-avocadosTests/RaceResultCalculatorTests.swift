// RaceResultCalculatorTests.swift
// Unit tests for the on-the-fly race result computation.

import Testing
import Foundation
@testable import caffeinated_avocados

struct RaceResultCalculatorTests {

    // MARK: - Helpers

    private func mileSplits(_ paces: [Int]) -> [RunningSplit] {
        paces.enumerated().map { idx, pace in
            RunningSplit(splitNumber: idx + 1, distanceUnit: .miles, paceSecondsPerUnit: pace)
        }
    }

    private func runningSession(on date: Date, distance: Double, splits: [RunningSplit],
                                durationSeconds: Int = 0, pace: Int = 0,
                                stravaId: String? = nil) -> WorkoutSession {
        let session = WorkoutSession(date: date, type: .running, durationSeconds: durationSeconds,
                                     stravaActivityId: stravaId)
        let run = RunningWorkout(distanceMiles: distance, averagePaceSecondsPerMile: pace)
        run.splits = splits
        session.runningWorkout = run
        return session
    }

    private func race(distanceMiles: Double, on date: Date, goal: Int? = nil) -> Race {
        let r = Race(date: date, raceDistance: .custom, distanceMiles: distanceMiles)
        r.goalTimeSeconds = goal
        return r
    }

    // MARK: - fastestWindow

    @Test func fastestWindowSkipsWarmupAndCooldown() {
        // 1mi warmup @ 600s, 3mi race-pace @ 360s, 1mi cooldown @ 660s.
        let splits = mileSplits([600, 360, 360, 360, 660])
        let time = RaceResultCalculator.fastestWindow(3.0, in: splits)
        // Fastest 3mi window is the three middle splits: 360 * 3 = 1080.
        #expect(time == 1080)
    }

    @Test func fastestWindowReturnsNilWhenTooShort() {
        let splits = mileSplits([400, 400])
        #expect(RaceResultCalculator.fastestWindow(5.0, in: splits) == nil)
    }

    @Test func fastestWindowInterpolatesPartialDistance() {
        // Two even 400s/mi miles; fastest 1.5mi = 1.5 * 400 = 600.
        let splits = mileSplits([400, 400])
        #expect(RaceResultCalculator.fastestWindow(1.5, in: splits) == 600)
    }

    // MARK: - result(for:from:)

    @Test func resultPicksFastestQualifyingRunOnRaceDay() {
        let day = Date(timeIntervalSince1970: 1_700_000_000) // fixed day
        let raceObj = race(distanceMiles: 3.0, on: day)

        let slow = runningSession(on: day, distance: 3.0, splits: mileSplits([400, 400, 400]))
        let fast = runningSession(on: day, distance: 5.0, splits: mileSplits([600, 360, 360, 360, 600]))

        let result = RaceResultCalculator.result(for: raceObj, from: [slow, fast])
        #expect(result?.timeSeconds == 1080) // fast run's middle 3 miles
    }

    @Test func resultIgnoresOtherDaysAndNonRunning() {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let otherDay = day.addingTimeInterval(48 * 3600)
        let raceObj = race(distanceMiles: 3.0, on: day)

        let wrongDay = runningSession(on: otherDay, distance: 3.0, splits: mileSplits([300, 300, 300]))
        let strength = WorkoutSession(date: day, type: .strength)

        #expect(RaceResultCalculator.result(for: raceObj, from: [wrongDay, strength]) == nil)
    }

    @Test func resultFallsBackToPaceWhenNoSplits() {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let raceObj = race(distanceMiles: 3.0, on: day)
        // No splits, distance covers the race, 360s/mi → 3mi = 1080s.
        let run = runningSession(on: day, distance: 3.1, splits: [], pace: 360)

        #expect(RaceResultCalculator.result(for: raceObj, from: [run])?.timeSeconds == 1080)
    }

    @Test func resultNilWhenDistanceTooShort() {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let raceObj = race(distanceMiles: 6.0, on: day)
        let run = runningSession(on: day, distance: 2.0, splits: mileSplits([400, 400]))

        #expect(RaceResultCalculator.result(for: raceObj, from: [run]) == nil)
    }
}
