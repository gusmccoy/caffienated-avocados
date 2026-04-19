// Views/Dashboard/WeekCompletionBanner.swift
// Celebratory banner shown when all planned workouts for the current week are completed.

import SwiftUI

struct WeekCompletionBanner: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "star.fill")
                .font(.title2)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text("Week Complete!")
                    .font(.subheadline.weight(.semibold))
                Text("You crushed all your workouts this week. Great job!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
        }
        .cardStyle()
    }
}

#Preview {
    WeekCompletionBanner()
        .padding()
}
