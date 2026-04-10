// ContentView.swift
// Root view — hosts the main TabView for the entire app.

import SwiftUI
import SwiftData

struct ContentView: View {
    // Shows the Athletes tab when the user is coaching at least one athlete
    @Query private var allRelationships: [PlannerRelationship]

    private var isCoachingAnyone: Bool {
        allRelationships.contains { !$0.currentUserIsAthlete && $0.status == .accepted }
    }

    var body: some View {
        TabView {
            PlanView()
                .tabItem {
                    Label("Plan", systemImage: "calendar.badge.plus")
                }

            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }

            ActivitiesView()
                .tabItem {
                    Label("Activities", systemImage: "figure.run")
                }

            // Athletes tab — only visible when the user is acting as a planner for someone
            if isCoachingAnyone {
                AthletesView()
                    .tabItem {
                        Label("Athletes", systemImage: "person.2.fill")
                    }
            }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(.orange) // Brand accent color
    }
}

#Preview {
    ContentView()
}
