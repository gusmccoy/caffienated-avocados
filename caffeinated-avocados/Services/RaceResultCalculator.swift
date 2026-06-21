// Services/RaceResultCalculator.swift
// Computes a race "result" from the activities recorded on race day.
//
// The result is the *fastest* effort over the race's distance found in that day's
// running sessions. When a run has mile/km splits, we slide a window across them to
// find the fastest contiguous segment covering the race distance — which naturally
// excludes warm-up and cool-down miles, whether they were logged as a separate
// activity or as part of one long run.

import Foundation

/// A computed race outcome derived from recorded activities (not persisted).
struct RaceResult: Equatable {
    let timeSeconds: Int
    let stravaActivityId: String?
    let date: Date
}

enum RaceResultCalculator {

    /// Best (fastest) result for `race` among that day's running sessions, or `nil`
    /// if no recorded activity covers the race distance.
    static func result(for race: Race, from sessions: [WorkoutSession]) -> RaceResult? {
        let targetMiles = race.distanceMiles
        guard targetMiles > 0 else { return nil }

        let raceDay = race.date.startOfDay
        var best: RaceResult?

        for session in sessions {
            guard session.type == .running,
                  session.date.startOfDay == raceDay,
                  let run = session.runningWorkout else { continue }

            let time: Int?
            if !run.splits.isEmpty {
                time = fastestWindow(targetMiles, in: run.splits)
            } else if run.distanceMiles >= targetMiles * 0.97 {
                // No split data — fall back to a distance-scaled time for the race
                // distance, or the whole-activity duration if no pace is recorded.
                time = run.averagePaceSecondsPerMile > 0
                    ? Int((Double(run.averagePaceSecondsPerMile) * targetMiles).rounded())
                    : (session.durationSeconds > 0 ? session.durationSeconds : nil)
            } else {
                time = nil
            }

            guard let t = time, t > 0 else { continue }
            if best == nil || t < best!.timeSeconds {
                best = RaceResult(timeSeconds: t, stravaActivityId: session.stravaActivityId, date: session.date)
            }
        }

        return best
    }

    /// Fastest contiguous time (seconds) to cover `targetMiles` within a single run's
    /// splits. Returns `nil` when the splits don't span the full distance.
    static func fastestWindow(_ targetMiles: Double, in splits: [RunningSplit]) -> Int? {
        guard targetMiles > 0 else { return nil }

        let sorted = splits.sorted { $0.splitNumber < $1.splitNumber }
        guard !sorted.isEmpty else { return nil }

        // Per-split distance (miles) and time (seconds), with cumulative boundaries.
        let splitMiles = sorted.map { $0.distanceUnit == .miles ? 1.0 : (1.0 / 1.60934) }
        let splitTime  = sorted.map { Double($0.paceSecondsPerUnit) }

        var boundaries: [Double] = [0]
        for m in splitMiles { boundaries.append(boundaries.last! + m) }
        let total = boundaries.last!

        let epsilon = 1e-6
        guard total + epsilon >= targetMiles else { return nil }

        // The traversal time as a function of window start is piecewise-linear with
        // breakpoints where a split boundary enters or leaves the window. The minimum
        // therefore sits at one of those breakpoints: each boundary, and each
        // (boundary - targetMiles). Evaluate all valid candidates and take the min.
        let maxStart = total - targetMiles
        var candidates: Set<Double> = [0, maxStart]
        for b in boundaries {
            candidates.insert(b)
            candidates.insert(b - targetMiles)
        }

        var bestTime: Double?
        for raw in candidates {
            let start = min(max(raw, 0), maxStart)
            let t = traversalTime(from: start, length: targetMiles,
                                  boundaries: boundaries, splitMiles: splitMiles, splitTime: splitTime)
            if bestTime == nil || t < bestTime! { bestTime = t }
        }

        return bestTime.map { Int($0.rounded()) }
    }

    /// Linearly-interpolated time to traverse `length` miles starting at `start` miles
    /// into the run, assuming constant pace within each split.
    private static func traversalTime(from start: Double, length: Double,
                                      boundaries: [Double], splitMiles: [Double], splitTime: [Double]) -> Double {
        let end = start + length
        var time = 0.0
        for i in 0..<splitMiles.count {
            let lo = boundaries[i]
            let hi = boundaries[i + 1]
            let overlap = min(end, hi) - max(start, lo)
            if overlap > 0 {
                time += splitTime[i] * (overlap / splitMiles[i])
            }
        }
        return time
    }
}
