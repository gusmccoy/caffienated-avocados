# McCoy Fitness

A personal fitness tracking app for iOS and macOS — log runs, strength sessions, and cross-training, plan your training week, and optionally sync with Strava.

## Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI |
| Architecture | MVVM + `@Observable` |
| Persistence | SwiftData (iOS 17+ / macOS 14+) |
| Auth | ASWebAuthenticationSession (Strava OAuth 2.0) |
| Secure storage | Keychain |

## Features

### Dashboard
Weekly summary of workouts, total time, and mileage with a week-over-week delta indicator. Quick-add buttons for all activity types and a recent activity feed.

### Activities
Unified tab for all activity types with a segmented picker (Run · Strength · Cross Train).

- **Running** — distance, duration, pace, splits, elevation, cadence, heart rate, route notes
- **Strength** — exercises with sets / reps / weight, volume tracking, RPE, effort notes
- **Cross Training** — 10+ activity types (cycling, swimming, yoga, rowing, HIIT, elliptical, hiking, and more)

### Training Plan
Week-by-week planner (Monday → Sunday) with forward/back navigation.

- **Run types** — Base Mileage, Recovery, Workout, Long Run
- **Structured segments** — chain together Warm Up, Easy, Tempo, Repeats, Fartlek, Ladder, and Cool Down blocks in any order
  - Each segment supports exact pace (MM:SS /mi) or race-reference pace
  - Repeats and Fartlek prompt for interval count + per-rep distance + recovery time
  - Ladder segments have a dynamic, reorderable step list
- **Auto distance** — total distance is calculated from segments automatically; override with a manual value any time (Σ icon marks segment-derived distances)
- **Strength and cross-training** workouts can also be planned with title, duration, intensity, and notes
- **Races** — add upcoming races with distance and goal time; countdown shown in the plan and as a banner
- **Calendar export** — planned workouts can be pushed to Apple Calendar
- **Copy last week** — duplicate the previous week's plan with one tap
- **Auto-matching** — synced Strava activities are automatically matched against planned workouts and marked complete

### Settings
- **Strava** — OAuth connect / disconnect, manual sync, undo when a Strava import overrides a manual entry
- **Sunday reminder** — optional notification to plan next week
- **Units** — miles or kilometers, lbs or kg
- **Default running pace** — set a MM:SS /mi pace used to estimate distance for planned runs that have duration but no explicit distance (shown as *~X mi* in the plan row)
- **Plan matching threshold** — tune how close an activity needs to be to count as completing a planned workout
- **Export** — coming soon

## Project Structure

```
caffeinated-avocados/
├── App.swift                          # Entry point, SwiftData container setup
├── ContentView.swift                  # Root TabView (Plan · Dashboard · Activities · Settings)
│
├── Models/
│   ├── WorkoutSession.swift           # Logged activity (all types)
│   ├── PlannedWorkout.swift           # Planned workout + run categories, segments, races
│   ├── Race.swift                     # Race model with countdown + goal time
│   └── StravaConnection.swift         # Strava OAuth tokens + athlete DTOs
│
├── ViewModels/
│   ├── PlanViewModel.swift            # Weekly plan state + segment calculations
│   ├── WorkoutListViewModel.swift     # Filtering, sorting, weekly stats (Mon–Sun)
│   ├── RunningViewModel.swift
│   ├── StrengthViewModel.swift
│   ├── CrossTrainingViewModel.swift
│   └── StravaViewModel.swift          # Connect / sync / override flow
│
├── Views/
│   ├── Dashboard/DashboardView.swift
│   ├── Activities/ActivitiesView.swift  # Segmented Run · Strength · CrossTrain list
│   ├── Running/
│   ├── Strength/
│   ├── CrossTraining/
│   ├── Plan/
│   │   ├── PlanView.swift             # Week grid with day sections
│   │   ├── AddPlannedWorkoutView.swift
│   │   └── AddRunSegmentView.swift    # Segment editor sheet
│   └── Settings/SettingsView.swift
│
├── Services/
│   ├── StravaService.swift            # OAuth + REST API
│   ├── CalendarService.swift          # EventKit integration
│   └── WeeklyPlanningReminderService.swift
│
└── Utilities/
    └── Extensions.swift               # Date, Double, Calendar helpers
```

## Getting Started

### 1. Open in Xcode

Clone the repo and open `caffeinated-avocados.xcodeproj`. No package dependencies to resolve.

### 2. Set up Strava (optional)

1. Create a Strava API app at [strava.com/settings/api](https://www.strava.com/settings/api)
2. Set the **Authorization Callback Domain** to `mccoy-fitness`
3. Copy `Secrets.plist.template` → `Secrets.plist` and fill in your Client ID and Client Secret
4. `Secrets.plist` is gitignored — never commit real credentials

### 3. Build and run

Target any iOS 17+ simulator/device or macOS 14+ (Designed for iPad / native Mac). Hit **Run**.

## macOS Notes

The app runs natively on macOS. Form sheets (Add Segment, Settings, Units) are constrained to 640 pt and centered, with `.formStyle(.grouped)` for an iOS-style card appearance. Wheel pickers are replaced with menu pickers on macOS.

## Architecture Notes

- **SwiftData enum safety** — all post-migration enum properties are stored as `String` raw values with computed accessors (e.g. `runCategoryRaw: String` + `var runCategory: RunCategory`). This prevents `Optional<Any>` cast crashes during lightweight migration.
- **Nested array storage** — `[PlannedRunSegment]` is stored as JSON `Data` via a `runSegmentsData` backing property to avoid SwiftData's limitation with nested `Codable` arrays.
- **ISO 8601 week** — all weekly windows use `Calendar(identifier: .iso8601)` so the week always runs Monday → Sunday.
- **Migration safety** — `App.swift` catches `ModelContainer` init failures, wipes the store, and retries rather than crashing.
