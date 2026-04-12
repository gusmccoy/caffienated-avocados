// Services/SuggestionEngine.swift
// Analyzes logged workout history and produces actionable training suggestions.
// All logic is pure (no SwiftData writes) — call on any [WorkoutSession] snapshot.

import Foundation

// MARK: - Suggestion

struct TrainingSuggestion: Identifiable {
    enum Kind {
        case undertraining
        case recoveryWeek
        case volumeSpike
        case comebackRamp   // rapid ramp after a gap
        case consistent     // positive reinforcement
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let body: String
    /// Higher = more urgent. Used to sort suggestions before display.
    let priority: Int

    var systemImage: String {
        switch kind {
        case .undertraining:  return "arrow.down.circle"
        case .recoveryWeek:   return "moon.zzz.fill"
        case .volumeSpike:    return "exclamationmark.triangle.fill"
        case .comebackRamp:   return "tortoise.fill"
        case .consistent:     return "checkmark.seal.fill"
        }
    }

    var accentColor: String {
        switch kind {
        case .undertraining:  return "yellow"
        case .recoveryWeek:   return "blue"
        case .volumeSpike:    return "orange"
        case .comebackRamp:   return "orange"
        case .consistent:     return "green"
        }
    }
}

// MARK: - Engine

enum SuggestionEngine {

    /// Generate suggestions for the current training week.
    /// Pass all sessions sorted by date (oldest first).
    static func suggestions(from sessions: [WorkoutSession]) -> [TrainingSuggestion] {
        let buckets = weeklyMileageBuckets(from: sessions)
        guard buckets.count >= 2 else { return [] } // Need at least 2 weeks of history

        var results: [TrainingSuggestion] = []

        let current     = buckets.last!
        let recent      = Array(buckets.dropLast())     // everything before current week
        let trailing4   = Array(recent.suffix(4))
        let trailing8   = Array(recent.suffix(8))

        let avg4 = average(trailing4.map(\.miles))
        let avg8 = average(trailing8.map(\.miles))

        // 1. Undertraining — current week < 50% of 4-week avg (only flag mid-week if ≥ Wednesday)
        //    Need 4+ weeks of history to avoid false positives early on.
        if trailing4.count >= 4 && avg4 > 2 {
            let dayOfWeek = Calendar.mondayFirst.component(.weekday, from: Date.now)
            let isAtLeastThursday = dayOfWeek >= 4 // 2=Mon..8=Sun in ISO
            if isAtLeastThursday && current.miles < avg4 * 0.5 {
                results.append(TrainingSuggestion(
                    kind: .undertraining,
                    title: "Low Mileage Week",
                    body: String(format: "You're at %.1f mi so far — well below your %.1f mi average. Still time to get a run in.", current.miles, avg4),
                    priority: 2
                ))
            }
        }

        // 2. Recovery week recommended — last 3 weeks each ≥ 120% of the preceding 3-week avg
        if recent.count >= 6 {
            let prev3  = average(Array(recent.suffix(6).prefix(3)).map(\.miles))
            let last3  = average(Array(recent.suffix(3)).map(\.miles))
            if prev3 > 1 && last3 >= prev3 * 1.20 {
                results.append(TrainingSuggestion(
                    kind: .recoveryWeek,
                    title: "Recovery Week Recommended",
                    body: String(format: "You've averaged %.1f mi/week for 3 weeks — 20%% above your prior baseline. Consider an easy week to absorb the training.", last3),
                    priority: 3
                ))
            }
        }

        // 3. Volume spike — current week already ≥ 130% of 4-week avg before the week ends
        if avg4 > 2 && current.miles >= avg4 * 1.30 {
            let dayOfWeek = Calendar.mondayFirst.component(.weekday, from: Date.now)
            let daysLeft = max(0, 7 - dayOfWeek + 1)
            if daysLeft >= 2 { // Only relevant when there are still days left
                results.append(TrainingSuggestion(
                    kind: .volumeSpike,
                    title: "Volume Spike Detected",
                    body: String(format: "You're already at %.1f mi with %d days left — that's 30%%+ above your %.1f mi average. Ease up to avoid overloading.", current.miles, daysLeft, avg4),
                    priority: 4
                ))
            }
        }

        // 4. Comeback ramp warning — gap of ≥ 2 weeks in recent runs, then sudden mileage jump
        if let gapEnd = detectRunGap(in: sessions, minWeeks: 2) {
            let weeksAgainstGap = buckets.filter { $0.weekStart >= gapEnd }
            if weeksAgainstGap.count >= 2 {
                let postGapMiles = weeksAgainstGap.map(\.miles)
                if postGapMiles.count >= 2 {
                    let weeklyIncreases = zip(postGapMiles, postGapMiles.dropFirst()).map { $1 / max($0, 0.1) }
                    if weeklyIncreases.contains(where: { $0 >= 1.30 }) {
                        results.append(TrainingSuggestion(
                            kind: .comebackRamp,
                            title: "Comeback Ramp Warning",
                            body: "Your mileage is increasing quickly after a recent break. Consider the 10% rule — gradual increases lower injury risk.",
                            priority: 5
                        ))
                    }
                }
            }
        }

        // 5. Positive reinforcement — 4+ consistent weeks within 15% of avg, no issues
        if results.isEmpty && trailing4.count >= 4 && avg4 > 0 {
            let allConsistent = trailing4.allSatisfy { abs($0.miles - avg4) / avg4 <= 0.15 }
            if allConsistent {
                results.append(TrainingSuggestion(
                    kind: .consistent,
                    title: "Consistent Training",
                    body: String(format: "Four straight weeks within 15%% of your %.1f mi average. Great consistency!", avg4),
                    priority: 0
                ))
            }
        }

        return results.sorted { $0.priority > $1.priority }
    }

    // MARK: - Helpers

    struct WeekBucket {
        let weekStart: Date
        var miles: Double
    }

    private static func weeklyMileageBuckets(from sessions: [WorkoutSession]) -> [WeekBucket] {
        let cal = Calendar.mondayFirst
        var map: [Date: Double] = [:]
        for s in sessions {
            guard let interval = cal.dateInterval(of: .weekOfYear, for: s.date) else { continue }
            let miles = s.runningWorkout?.distanceMiles ?? 0
            map[interval.start, default: 0] += miles
        }
        return map.map { WeekBucket(weekStart: $0.key, miles: $0.value) }
                  .sorted { $0.weekStart < $1.weekStart }
    }

    private static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Returns the date after the most recent ≥ `minWeeks`-long running gap,
    /// or nil if no such gap exists in the last 12 months.
    private static func detectRunGap(from sessions: [WorkoutSession], minWeeks: Int) -> Date? {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .month, value: -12, to: .now) ?? .now
        let runDates = sessions
            .filter { $0.type == .running && $0.date >= cutoff }
            .map(\.date)
            .sorted()

        guard runDates.count >= 2 else { return nil }
        for (prev, next) in zip(runDates, runDates.dropFirst()) {
            let gap = cal.dateComponents([.weekOfYear], from: prev, to: next).weekOfYear ?? 0
            if gap >= minWeeks { return next }
        }
        return nil
    }

    // Overload that matches call site with named param
    private static func detectRunGap(in sessions: [WorkoutSession], minWeeks: Int) -> Date? {
        detectRunGap(from: sessions, minWeeks: minWeeks)
    }
}
