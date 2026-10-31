import SwiftUI

/// Entry point to the batch cooking, with its progress.
struct BatchLinkCard: View {
    let steps: [BatchStep]

    var body: some View {
        let done = steps.filter { $0.isDone() }.count
        NavigationLink {
            BatchCookingView()
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: "frying.pan.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.Colors.accent)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Batch cooking")
                        .font(Theme.Fonts.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(done == steps.count ? "Terminé" : "\(done)/\(steps.count) étapes")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(Theme.Spacing.m)
            .frame(minHeight: Theme.Layout.minTapHeight)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}
