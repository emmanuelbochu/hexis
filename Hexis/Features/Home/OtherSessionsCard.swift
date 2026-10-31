import SwiftUI

/// The other sessions of the week, as one grouped list with hairline separators (Apple Music's library look).
struct OtherSessionsCard: View {
    let names: [(id: UUID, name: String)]
    let start: (UUID) -> Void

    var body: some View {
        if !names.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("Autres séances")
                    .font(Theme.Fonts.section)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .padding(.top, Theme.Spacing.s)
                VStack(spacing: 0) {
                    ForEach(Array(names.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Divider().overlay(Theme.Colors.separator).padding(.leading, Theme.Spacing.m) }
                        row(item)
                    }
                }
                .cardStyle()
            }
        }
    }

    private func row(_ item: (id: UUID, name: String)) -> some View {
        Button { start(item.id) } label: {
            HStack {
                Text(item.name).font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 26))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Theme.Colors.accent)
            }
            .padding(.horizontal, Theme.Spacing.m)
            .frame(minHeight: Theme.Layout.minTapHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OtherSessionsCard(names: [(UUID(), "Lower A"), (UUID(), "Lower B"), (UUID(), "Upper B")]) { _ in }
        .padding()
        .screenBackground()
        .appAppearance()
}
