// ContentView.swift
// Root view — hosts the main TabView for the entire app.

import SwiftUI

struct ContentView: View {
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
