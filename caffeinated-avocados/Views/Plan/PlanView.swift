// Views/Plan/PlanView.swift
// Weekly training plan tab — Mon through Sun with Apple Calendar integration.

import SwiftUI
import SwiftData

struct PlanView: View {
    @State private var vm = PlanViewModel()
    private let calendarService = CalendarService()

    @Query(sort: \PlannedWorkout.date, order: .forward)
    private var allPlanned: [PlannedWorkout]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    WeekNavigationHeader(vm: vm)
                    WeekMileageCard(miles: vm.totalPlannedMiles(from: weekWorkouts))
                    ForEach(vm.weekDays, id: \.self) { day in
                        DaySection(
                            day: day,
                            workouts: vm.workouts(for: day, from: allPlanned),
                            vm: vm,
                            calendarService: calendarService
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Training Plan")
            .sheet(isPresented: $vm.isShowingAddSheet) {
                AddPlannedWorkoutView(vm: vm, calendarService: calendarService)
            }
        }
    }

    private var weekWorkouts: [PlannedWorkout] {
        vm.workoutsInCurrentWeek(from: allPlanned)
    }
}

// MARK: - Week Navigation Header

private struct WeekNavigationHeader: View {
    var vm: PlanViewModel

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Button {
                    vm.goToPreviousWeek()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.orange)
                }

                Spacer()

                Text(vm.weekLabel)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button {
                    vm.goToNextWeek()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }

            if !vm.isCurrentWeek {
                Button("Today") { vm.goToCurrentWeek() }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
            }
        }
    }
}

// MARK: - Week Mileage Card

private struct WeekMileageCard: View {
    let miles: Double
    @AppStorage("distanceUnit") private var distanceUnit: String = DistanceUnit.miles.rawValue

    private var displayValue: String {
        if distanceUnit == DistanceUnit.kilometers.rawValue {
            return String(format: "%.1f km planned", miles.milesToKm)
        }
        return String(format: "%.1f mi planned", miles)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.run")
                .font(.title2)
                .foregroundStyle(.orange)
            Text(displayValue)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.orange)
            Spacer()
        }
        .cardStyle()
    }
}

// MARK: - Day Section

private struct DaySection: View {
    let day: Date
    let workouts: [PlannedWorkout]
    var vm: PlanViewModel
    let calendarService: CalendarService
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.formatted(.dateTime.weekday(.wide)))
                        .font(.headline)
                    Text(day.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    vm.openAddSheet(for: day)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                }
            }

            if workouts.isEmpty {
                Text("Rest day")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 2)
            } else {
                ForEach(workouts) { workout in
                    PlannedWorkoutRow(workout: workout)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteWorkout(workout)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                vm.openEditSheet(for: workout)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                        .contextMenu {
                            Button {
                                vm.openEditSheet(for: workout)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                deleteWorkout(workout)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .cardStyle()
    }

    private func deleteWorkout(_ workout: PlannedWorkout) {
        let identifier = workout.calendarEventIdentifier
        modelContext.delete(workout)
        if let id = identifier {
            Task {
                try? await calendarService.deleteEvent(identifier: id)
            }
        }
    }
}

// MARK: - Planned Workout Row

private struct PlannedWorkoutRow: View {
    let workout: PlannedWorkout
    @AppStorage("distanceUnit") private var distanceUnit: String = DistanceUnit.miles.rawValue

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: workout.workoutType.systemImage)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(typeColor, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(workout.title)
                    .font(.subheadline.weight(.medium))

                HStack(spacing: 8) {
                    Text(workout.intensityLevel.rawValue)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.intensityColor(workout.intensityLevel).opacity(0.15),
                                    in: Capsule())
                        .foregroundStyle(Color.intensityColor(workout.intensityLevel))

                    if workout.plannedDistanceMiles > 0 {
                        Text(distanceText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if workout.calendarEventIdentifier != nil {
                Spacer()
                Image(systemName: "calendar.badge.checkmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var typeColor: Color {
        switch workout.workoutType {
        case .running:       return .green
        case .strength:      return .orange
        case .crossTraining: return .blue
        }
    }

    private var distanceText: String {
        if distanceUnit == DistanceUnit.kilometers.rawValue {
            return String(format: "%.2f km", workout.plannedDistanceMiles.milesToKm)
        }
        return String(format: "%.2f mi", workout.plannedDistanceMiles)
    }
}
