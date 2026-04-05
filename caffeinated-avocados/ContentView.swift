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

            RunningListView()
                .tabItem {
                    Label("Running", systemImage: "figure.run")
                }

            StrengthListView()
                .tabItem {
                    Label("Strength", systemImage: "dumbbell.fill")
                }

            CrossTrainingListView()
                .tabItem {
                    Label("Cross Train", systemImage: "figure.cross.training")
                }
        }
        .tint(.orange) // Brand accent color
    }
}

#Preview {
    ContentView()
}
