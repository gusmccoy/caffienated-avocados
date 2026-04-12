// Views/Dashboard/TrendDashboardView.swift
// Trend charts — weekly mileage, pace, volume, heart-rate zones, and W-o-W / M-o-M deltas.

import SwiftUI
import SwiftData
import Charts

struct TrendDashboardView: View {
    @Query(sort: \WorkoutSession.date, order: .forward)
    private var allSessions: [WorkoutSession]

    @State private var selectedRange: TrendRange = .threeMonths

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    rangePicker
                    deltaCards
                    weeklyMileageChart
                    avgPaceChart
                    weeklyVolumeChart
                    heartRateZoneChart
                }
                .padding()
            }
            .navigationTitle("Trends")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
    }

    // MARK: - Range Picker

    private var rangePicker: some View {
        Picker("Range", selection: $selectedRange) {
            ForEach(TrendRange.allCases, id: \.self) {
                Text($0.label).tag($0)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Filtered data

    private var windowSessions: [WorkoutSession] {
        let cutoff = selectedRange.cutoffDate
        return allSessions.filter { $0.date >= cutoff }
    }

    private var weeklyBuckets: [WeekBucket] {
        TrendDataSource.weeklyBuckets(from: windowSessions, range: selectedRange)
    }

    private var pacePoints: [PacePoint] {
        TrendDataSource.pacePoints(from: windowSessions, range: selectedRange)
    }

    // MARK: - Delta Cards

    private var deltaCards: some View {
        let deltas = TrendDataSource.deltas(from: allSessions)
        return HStack(spacing: 12) {
            DeltaCard(
                title: "Miles",
                value: String(format: "%.1f", deltas.currentMiles),
                delta: String(format: "%+.1f vs last wk", deltas.milesDelta),
                color: deltaColor(deltas.milesDeltaPct)
            )
            DeltaCard(
                title: "Workouts",
                value: "\(deltas.currentWorkouts)",
                delta: String(format: "%+d vs last wk", deltas.workoutsDelta),
                color: deltaColor(Double(deltas.workoutsDelta) / max(1, Double(deltas.lastWorkouts)) * 100)
            )
            DeltaCard(
                title: "Time",
                value: deltas.currentDuration.formattedAsTime,
                delta: durationDeltaLabel(deltas.durationDeltaSeconds),
                color: deltaColor(deltas.durationDeltaPct)
            )
        }
    }

    private func deltaColor(_ pct: Double) -> Color {
        if pct > 5    { return .green }
        if pct >= -5  { return .primary }
        if pct >= -10 { return .yellow }
        return .red
    }

    private func durationDeltaLabel(_ seconds: Int) -> String {
        let abs = Swift.abs(seconds)
        let h = abs / 3600; let m = (abs % 3600) / 60
        let str = h > 0 ? "\(h)h \(m)m" : "\(m)m"
        return seconds >= 0 ? "+\(str) vs last wk" : "-\(str) vs last wk"
    }

    // MARK: - Weekly Mileage Chart

    private var weeklyMileageChart: some View {
        ChartCard(title: "Weekly Mileage", systemImage: "figure.run") {
            if weeklyBuckets.isEmpty {
                emptyChartPlaceholder("No running data in this period")
            } else {
                Chart(weeklyBuckets) { bucket in
                    BarMark(
                        x: .value("Week", bucket.weekStart, unit: .weekOfYear),
                        y: .value("Miles", bucket.runningMiles)
                    )
                    .foregroundStyle(Color.orange.gradient)
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) {
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
                .chartYAxisLabel("miles")
                .frame(height: 180)
            }
        }
    }

    // MARK: - Average Pace Chart

    private var avgPaceChart: some View {
        ChartCard(title: "Average Running Pace", systemImage: "speedometer") {
            if pacePoints.isEmpty {
                emptyChartPlaceholder("No timed runs in this period")
            } else {
                Chart(pacePoints) { pt in
                    LineMark(
                        x: .value("Date", pt.date),
                        y: .value("Pace", pt.paceSecondsPerMile)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.blue)
                    PointMark(
                        x: .value("Date", pt.date),
                        y: .value("Pace", pt.paceSecondsPerMile)
                    )
                    .foregroundStyle(Color.blue)
                    .symbolSize(30)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) {
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks { v in
                        if let s = v.as(Int.self) {
                            AxisValueLabel {
                                Text(s.formattedAsPace)
                                    .font(.caption2)
                            }
                            AxisGridLine()
                        }
                    }
                }
                // Lower pace = faster = better → invert axis
                .chartYScale(domain: .automatic(includesZero: false, reversed: true))
                .chartYAxisLabel("min/mi")
                .frame(height: 180)
            }
        }
    }

    // MARK: - Weekly Volume (total time) Chart

    private var weeklyVolumeChart: some View {
        ChartCard(title: "Weekly Training Volume", systemImage: "clock") {
            if weeklyBuckets.isEmpty {
                emptyChartPlaceholder("No workouts in this period")
            } else {
                Chart(weeklyBuckets) { bucket in
                    BarMark(
                        x: .value("Week", bucket.weekStart, unit: .weekOfYear),
                        y: .value("Minutes", bucket.totalMinutes)
                    )
                    .foregroundStyle(Color.purple.gradient)
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) {
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
                .chartYAxisLabel("minutes")
                .frame(height: 160)
            }
        }
    }

    // MARK: - Heart Rate Zone Chart

    private var heartRateZoneChart: some View {
        ChartCard(title: "Intensity Distribution", systemImage: "heart.fill") {
            let zones = TrendDataSource.intensityDistribution(from: windowSessions)
            if zones.isEmpty {
                emptyChartPlaceholder("No workouts in this period")
            } else {
                Chart(zones) { z in
                    SectorMark(
                        angle: .value("Workouts", z.count),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(z.intensity.swiftUIColor)
                    .cornerRadius(4)
                    .annotation(position: .overlay) {
                        if z.count > 0 {
                            Text("\(z.count)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .frame(height: 180)

                // Legend
                HStack(spacing: 14) {
                    ForEach(zones.filter { $0.count > 0 }) { z in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(z.intensity.swiftUIColor)
                                .frame(width: 10, height: 10)
                            Text(z.intensity.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func emptyChartPlaceholder(_ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 80)
    }
}

// MARK: - Supporting Types

enum TrendRange: String, CaseIterable {
    case oneMonth    = "1M"
    case threeMonths = "3M"
    case sixMonths   = "6M"
    case oneYear     = "1Y"

    var label: String { rawValue }

    var cutoffDate: Date {
        let cal = Calendar.current
        let now = Date.now
        switch self {
        case .oneMonth:    return cal.date(byAdding: .month, value: -1, to: now) ?? now
        case .threeMonths: return cal.date(byAdding: .month, value: -3, to: now) ?? now
        case .sixMonths:   return cal.date(byAdding: .month, value: -6, to: now) ?? now
        case .oneYear:     return cal.date(byAdding: .year, value: -1, to: now) ?? now
        }
    }
}

struct WeekBucket: Identifiable {
    let id = UUID()
    let weekStart: Date
    var runningMiles: Double
    var totalMinutes: Double
    var workoutCount: Int
}

struct PacePoint: Identifiable {
    let id = UUID()
    let date: Date
    let paceSecondsPerMile: Int
}

struct IntensityZone: Identifiable {
    let id = UUID()
    let intensity: IntensityLevel
    var count: Int
}

// MARK: - Trend Data Source

enum TrendDataSource {
    static func weeklyBuckets(from sessions: [WorkoutSession], range: TrendRange) -> [WeekBucket] {
        let cal = Calendar.mondayFirst
        var bucketMap: [Date: WeekBucket] = [:]

        for session in sessions {
            guard let weekInterval = cal.dateInterval(of: .weekOfYear, for: session.date) else { continue }
            let key = weekInterval.start
            var bucket = bucketMap[key] ?? WeekBucket(weekStart: key, runningMiles: 0, totalMinutes: 0, workoutCount: 0)
            bucket.runningMiles += session.runningWorkout?.distanceMiles ?? 0
            bucket.totalMinutes += Double(session.durationSeconds) / 60.0
            bucket.workoutCount += 1
            bucketMap[key] = bucket
        }

        return bucketMap.values.sorted { $0.weekStart < $1.weekStart }
    }

    static func pacePoints(from sessions: [WorkoutSession], range: TrendRange) -> [PacePoint] {
        sessions
            .compactMap { session -> PacePoint? in
                guard let run = session.runningWorkout,
                      run.averagePaceSecondsPerMile > 0 else { return nil }
                return PacePoint(date: session.date, paceSecondsPerMile: run.averagePaceSecondsPerMile)
            }
            .sorted { $0.date < $1.date }
    }

    static func intensityDistribution(from sessions: [WorkoutSession]) -> [IntensityZone] {
        var counts: [IntensityLevel: Int] = [:]
        for s in sessions { counts[s.intensityLevel, default: 0] += 1 }
        return IntensityLevel.allCases.map { IntensityZone(intensity: $0, count: counts[$0] ?? 0) }
    }

    struct Deltas {
        var currentMiles: Double
        var lastMiles: Double
        var milesDelta: Double
        var milesDeltaPct: Double

        var currentWorkouts: Int
        var lastWorkouts: Int
        var workoutsDelta: Int

        var currentDuration: Int
        var lastDuration: Int
        var durationDeltaSeconds: Int
        var durationDeltaPct: Double
    }

    static func deltas(from allSessions: [WorkoutSession]) -> Deltas {
        let cal = Calendar.mondayFirst
        let now = Date.now
        guard let thisWeekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start,
              let lastWeekStart = cal.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) else {
            return Deltas(currentMiles: 0, lastMiles: 0, milesDelta: 0, milesDeltaPct: 0,
                          currentWorkouts: 0, lastWorkouts: 0, workoutsDelta: 0,
                          currentDuration: 0, lastDuration: 0, durationDeltaSeconds: 0, durationDeltaPct: 0)
        }

        let thisWeek = allSessions.filter { $0.date >= thisWeekStart && $0.date < now }
        let lastWeek = allSessions.filter { $0.date >= lastWeekStart && $0.date < thisWeekStart }

        let currMiles = thisWeek.reduce(0.0) { $0 + ($1.runningWorkout?.distanceMiles ?? 0) }
        let lastMiles = lastWeek.reduce(0.0) { $0 + ($1.runningWorkout?.distanceMiles ?? 0) }

        let currDur = thisWeek.reduce(0) { $0 + $1.durationSeconds }
        let lastDur = lastWeek.reduce(0) { $0 + $1.durationSeconds }

        return Deltas(
            currentMiles: currMiles,
            lastMiles: lastMiles,
            milesDelta: currMiles - lastMiles,
            milesDeltaPct: lastMiles > 0 ? (currMiles - lastMiles) / lastMiles * 100 : 0,
            currentWorkouts: thisWeek.count,
            lastWorkouts: lastWeek.count,
            workoutsDelta: thisWeek.count - lastWeek.count,
            currentDuration: currDur,
            lastDuration: lastDur,
            durationDeltaSeconds: currDur - lastDur,
            durationDeltaPct: lastDur > 0 ? Double(currDur - lastDur) / Double(lastDur) * 100 : 0
        )
    }
}

// MARK: - IntensityLevel color extension

private extension IntensityLevel {
    var swiftUIColor: Color {
        switch self {
        case .easy:     return .green
        case .moderate: return .blue
        case .hard:     return .orange
        case .max:      return .red
        }
    }
}

// MARK: - Int pace formatter

private extension Int {
    var formattedAsPace: String {
        guard self > 0 else { return "" }
        return String(format: "%d:%02d", self / 60, self % 60)
    }
}

// MARK: - Chart Card

private struct ChartCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            content()
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Delta Card

private struct DeltaCard: View {
    let title: String
    let value: String
    let delta: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
            Text(delta)
                .font(.caption2)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
