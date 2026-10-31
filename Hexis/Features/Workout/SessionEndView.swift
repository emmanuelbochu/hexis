import SwiftUI

/// End of the session: the figures, what stood out, a note, and one clear button.
struct SessionEndView: View {
    let model: WorkoutViewModel
    let onEnd: () -> Void
    let onResume: () -> Void

    /// Computed once when the screen appears, not on every redraw.
    @State private var figures: (summary: SessionSummary, review: SessionReview)?

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            ScrollView {
                VStack(spacing: Theme.Spacing.m) {
                    header
                    CheerLine(alignment: .center) { context in await Cheer.afterSession(model.session, review: model.review, in: context) }
                    if let figures {
                        let summary = figures.summary, review = figures.review
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.s) {
                            tile("Durée", summary.durationText)
                            tile("Séries", "\(summary.workSets)")
                            tile("Volume", summary.volumeText)
                            tile("Effort moyen", summary.averageRPE.map { EffortScale.average(rpe: $0) } ?? "–")
                        }
                        if !review.records.isEmpty || review.volumeDelta != nil { highlights(review) }
                    }
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        Text("Note de séance").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                        SessionNoteField(sessionID: model.session.id, exerciseID: nil, showsPain: false, large: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, Theme.Spacing.m)
            }
            .scrollDismissesKeyboard(.interactively)
            VStack(spacing: Theme.Spacing.s) {
                Button("Terminer", action: onEnd).buttonStyle(PrimaryButtonStyle())
                Button("Reprendre la séance", action: onResume).buttonStyle(SecondaryButtonStyle())
            }
            .padding(.bottom, Theme.Spacing.m)
        }
        .task {
            figures = (model.summary, model.review)
            SoundService.play(figures?.review.records.isEmpty == false ? .record : .sessionEnd)
        }
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.s) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.Colors.accent)
            Text("Séance terminée")
                .font(Theme.Fonts.title)
                .foregroundStyle(Theme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    private func tile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            Text(value)
                .font(Theme.Fonts.title.monospacedDigit())
                .foregroundStyle(Theme.Colors.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func highlights(_ review: SessionReview) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            ForEach(review.records, id: \.name) { record in
                Label("Record : \(record.name) \(record.weight.formatted()) kg", systemImage: "trophy.fill")
                    .foregroundStyle(Theme.Colors.accent)
            }
            if let delta = review.volumeDelta {
                Label(
                    "Volume \(delta >= 0 ? "+" : "")\(Int((delta * 100).rounded())) % vs la dernière fois",
                    systemImage: delta >= 0 ? "arrow.up.right" : "arrow.down.right"
                )
                .foregroundStyle(Theme.Colors.textPrimary)
            }
        }
        .font(Theme.Fonts.body)
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
