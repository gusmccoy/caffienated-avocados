// Views/Plan/PlanningReminderBanner.swift
// Prompts to plan next week when viewing the current week on Sunday.

import SwiftUI

struct PlanningReminderBanner: View {
    let onPlanNextWeek: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Plan Next Week")
                    .font(.subheadline.weight(.semibold))
                Text("No workouts scheduled yet for next week.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Plan", action: onPlanNextWeek)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.orange, in: Capsule())
                .foregroundStyle(.white)
                .buttonStyle(.plain)
        }
        .cardStyle()
    }
}
