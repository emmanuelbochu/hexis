import SwiftUI

/// One session of a program: name and a one-line summary (exercises, sets, duration, muscles).
struct TemplateCard: View {
    let template: WorkoutTemplate
    let summary: TemplateSummary
    var trailingSymbol: String? = "chevron.right"
    /// The suggested session on Home: its name as a large title.
    var hero = false

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(template.name).font(hero ? Theme.Fonts.largeTitle : Theme.Fonts.title).foregroundStyle(Theme.Colors.textPrimary)
                Text("\(summary.exerciseCount) exercices · \(summary.setCount) séries\(summary.timeText)")
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Text(summary.muscles.joined(separator: " · "))
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary.opacity(0.8))
                    .lineLimit(1)
            }
            Spacer()
            if let trailingSymbol { Image(systemName: trailingSymbol).foregroundStyle(Theme.Colors.textSecondary) }
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
