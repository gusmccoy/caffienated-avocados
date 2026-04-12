// Views/Dashboard/SuggestionsCard.swift
// Surfaces training suggestions derived by SuggestionEngine in the Dashboard.

import SwiftUI

struct SuggestionsCard: View {
    let suggestions: [TrainingSuggestion]

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — tap to collapse/expand
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Label("Training Insights", systemImage: "lightbulb.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    if suggestions.count > 1 {
                        Text("\(suggestions.count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange, in: Capsule())
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().padding(.horizontal)
                VStack(spacing: 0) {
                    ForEach(suggestions) { suggestion in
                        SuggestionRow(suggestion: suggestion)
                        if suggestion.id != suggestions.last?.id {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Suggestion Row

private struct SuggestionRow: View {
    let suggestion: TrainingSuggestion

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: suggestion.systemImage)
                .font(.title3)
                .foregroundStyle(accentColor)
                .frame(width: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(suggestion.title)
                    .font(.subheadline.weight(.semibold))
                Text(suggestion.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var accentColor: Color {
        switch suggestion.accentColor {
        case "green":  return .green
        case "blue":   return .blue
        case "orange": return .orange
        case "yellow": return .yellow
        case "red":    return .red
        default:       return .orange
        }
    }
}
