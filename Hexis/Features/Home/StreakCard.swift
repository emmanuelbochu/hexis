import SwiftUI

/// Hexis Elle's rhythm on Home: weeks held in a row (one joker in four), the last 8 weeks as dots, the month against the one before.
struct StreakCard: View {
    let streak: HabitStreak

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(streak.streak)").font(Theme.Fonts.title.monospacedDigit()).foregroundStyle(Theme.Colors.accent)
                Text(streak.streak > 1 ? "semaines tenues" : "semaine tenue").font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                if streak.jokerAvailable { Label("Joker", systemImage: "sparkle").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary) }
            }
            HStack(spacing: Theme.Spacing.s) {
                ForEach(Array(streak.weeks.enumerated()), id: \.offset) { _, week in column(week) }
            }
            Text(monthText).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// One week: a dot per session of the target, full when done.
    private func column(_ week: HabitStreak.Week) -> some View {
        let done: Int
        switch week {
        case .done: done = streak.weeklyTarget
        case .running(let count): done = count
        default: done = 0
        }
        return VStack(spacing: 4) {
            ForEach(0..<streak.weeklyTarget, id: \.self) { index in
                Circle()
                    .fill(index < done ? Theme.Colors.accent : Theme.Colors.surfaceRaised)
                    .frame(width: 12, height: 12)
                    .overlay { if week == .joker { Image(systemName: "sparkle").font(.system(size: 7)).foregroundStyle(Theme.Colors.textSecondary) } }
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(week == .before ? 0.35 : 1)
    }

    private var monthText: String {
        let month = streak.thisMonth, before = streak.lastMonth
        return "\(month) séance\(month > 1 ? "s" : "") ce mois-ci" + (before > 0 ? " · \(before) le mois dernier" : "")
    }
}

#Preview {
    StreakCard(streak: HabitStreak(sessionDates: [.now, .now.addingTimeInterval(-86400 * 8), .now.addingTimeInterval(-86400 * 9)], weeklyTarget: 2))
        .padding()
        .screenBackground()
        .appAppearance()
}
