# McCoy Fitness — iOS App

A Swift hobby project to track running, strength training, and cross-training — with optional Strava integration.

## Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI |
| Architecture | MVVM + `@Observable` |
| Persistence | SwiftData (iOS 17+) |
| Auth | ASWebAuthenticationSession (Strava OAuth 2.0) |
| Secure storage | Keychain |

## Project Structure

```
McCoyFitness/
├── McCoyFitnessApp.swift          # App entry point & SwiftData container
├── ContentView.swift              # Root TabView
│
├── Models/
│   ├── WorkoutSession.swift       # Base workout model (all types share this)
│   ├── RunningWorkout.swift       # Running-specific data + splits
│   ├── StrengthWorkout.swift      # Exercises, sets, reps, weight
│   ├── CrossTrainingWorkout.swift # Cycling, swimming, yoga, etc.
│   └── StravaConnection.swift     # Strava auth + API DTOs
│
├── ViewModels/
│   ├── WorkoutListViewModel.swift # Shared filtering, sorting, stats
│   ├── RunningViewModel.swift     # Running form state
│   ├── StrengthViewModel.swift    # Strength form + exercise builder
│   ├── CrossTrainingViewModel.swift
│   └── StravaViewModel.swift      # Strava connect / sync flow
│
├── Views/
│   ├── Dashboard/DashboardView.swift
│   ├── Running/
│   │   ├── RunningListView.swift
│   │   ├── RunningDetailView.swift
│   │   └── LogRunningView.swift
│   ├── Strength/
│   │   ├── StrengthListView.swift
│   │   ├── StrengthDetailView.swift
│   │   └── LogStrengthView.swift
│   ├── CrossTraining/
│   │   ├── CrossTrainingListView.swift
│   │   ├── CrossTrainingDetailView.swift
│   │   └── LogCrossTrainingView.swift
│   └── Settings/SettingsView.swift
│
├── Services/
│   └── StravaService.swift        # OAuth + REST API calls
│
└── Utilities/
    └── Extensions.swift           # Date, Double, Int, View helpers
```

## Getting Started

### 1. Create the Xcode project

1. Open Xcode → **File → New → Project**
2. Choose **iOS → App**
3. Set:
   - Product Name: `McCoyFitness`
   - Bundle ID: `com.yourname.mccoyfitness`
   - Interface: SwiftUI
   - Language: Swift
4. Add all the `.swift` files from this folder into the project, preserving the folder structure as groups.

### 2. Enable capabilities

In Xcode's **Signing & Capabilities** tab, add:
- **Keychain Sharing** (for token storage)

### 3. Set up Strava (optional)

1. Go to [https://www.strava.com/settings/api](https://www.strava.com/settings/api) and create an app.
2. Set the **Authorization Callback Domain** to `mccoy-fitness`.
3. Copy `Secrets.plist.template` → `Secrets.plist` and fill in your credentials.
4. Add the URL scheme to `Info.plist`:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array><string>mccoy-fitness</string></array>
     </dict>
   </array>
   ```

### 4. Build and run

Target any iOS 17+ simulator or device and hit **Run**.

## Features

- **Dashboard** — Weekly summary (workouts, time, miles) + recent activity feed
- **Running** — Log runs with distance, pace auto-calculation, splits, route, elevation, cadence
- **Strength** — Log exercises with sets/reps/weight, volume tracking, RPE, workout templates
- **Cross Training** — Cycling, swimming, yoga, rowing, HIIT + 8 other activity types
- **Strava Sync** — OAuth login, import recent activities, dedup against local data
- **Settings** — Unit preferences (mi/km, lbs/kg), export placeholder

## Roadmap / Next Steps

- [ ] HealthKit integration (read HR, write workouts)
- [ ] Garmin Connect API import
- [ ] Charts & trends (weekly mileage, PR tracking)
- [ ] Workout plans / training programs
- [ ] Watch app companion
- [ ] CSV / JSON export
- [ ] Widget support
