import SwiftUI

/// The cards of the week review: tiles, muscle check, records, plateaus to watch.
extension WeekReviewView {
    func tiles(_ week: WeekReview, previous: WeekReview, target: Int) -> some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        let over = week.isOver(now: .now)
        return LazyVGrid(columns: columns, spacing: Theme.Spacing.s) {
            tile("Séances", "\(week.sessionCount)/\(target)", delta: nil)
            tile("Séries", "\(week.workSets)", delta: WeekReview.change(Double(week.workSets), vs: Double(previous.workSets), weekIsOver: over))
            tile("Volume", "\(Int(week.volume.rounded())) kg", delta: WeekReview.change(week.volume, vs: previous.volume, weekIsOver: over))
            tile("Effort moyen", week.avgRPE.map { EffortScale.average(rpe: $0) } ?? "–", delta: nil)
        }
    }

    func tile(_ title: String, _ value: String, delta: String?) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            Text(value).font(Theme.Fonts.title).foregroundStyle(Theme.Colors.textPrimary).minimumScaleFactor(0.6).lineLimit(1)
            Text(delta ?? " ").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.accent)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// Sets per muscle against the program's targets: one line when all is in range, else only the muscles off it.
    func muscleCheck(_ week: WeekReview, isDeload: Bool) -> some View {
        let targets = ProgramCatalog.weeklyTargets
        // A deload week is light on purpose: nothing to flag.
        let gaps = isDeload ? [] : VolumeCheck.gaps(setsByMuscle: week.setsByMuscle, targets: targets, weekIsOver: week.isOver(now: .now))
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Séries par muscle").font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
            if gaps.isEmpty {
                Text(week.end < .now ? "Tous les muscles dans leur cible." : "Rien au-dessus de la cible pour l'instant.")
                    .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            }
            ForEach(gaps, id: \.muscle) { gap in
                HStack {
                    Text(gap.muscle).font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    Text("\(gap.sets) séries · cible \(gap.range.lowerBound)-\(gap.range.upperBound)")
                        .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.accent)
                }
            }
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    func records(_ week: WeekReview) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Records").font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
            ForEach(week.records, id: \.name) { record in
                Label("\(record.name) · \(record.weight.formatted()) kg", systemImage: "trophy.fill")
                    .font(Theme.Fonts.body).foregroundStyle(Theme.Colors.accent)
            }
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// Plateaus across all exercises, whatever the week shown.
    @ViewBuilder func attention(_ findings: [(name: String, message: String)]) -> some View {
        if !findings.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("À surveiller").font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
                ForEach(findings, id: \.name) { finding in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(finding.name).font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textPrimary)
                        Text(finding.message).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
            .padding(Theme.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
    }
}
