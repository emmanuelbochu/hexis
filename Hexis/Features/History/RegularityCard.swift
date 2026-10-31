import SwiftUI

/// Streak of weeks on target, this week's progress and the last 8 weeks as small bars.
struct RegularityCard: View {
    let regularity: Regularity

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Label("\(regularity.streak) sem. à l'objectif", systemImage: "flame.fill")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(regularity.streak > 0 ? Theme.Colors.accent : Theme.Colors.textSecondary)
                Text("Cette semaine \(regularity.thisWeek)/\(regularity.weeklyTarget) · record \(regularity.longest)")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(regularity.recentWeeks.enumerated()), id: \.offset) { _, count in
                    Capsule()
                        .fill(count >= regularity.weeklyTarget ? Theme.Colors.accent : Theme.Colors.surfaceRaised)
                        .frame(width: 6, height: 8 + CGFloat(min(count, regularity.weeklyTarget + 1)) * 8)
                }
            }
            .frame(height: 8 + CGFloat(regularity.weeklyTarget + 1) * 8, alignment: .bottom)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

#Preview {
    RegularityCard(regularity: Regularity(sessionDates: [.now, .now.addingTimeInterval(-86400 * 8)], weeklyTarget: 3))
        .padding()
        .screenBackground()
        .appAppearance()
}
