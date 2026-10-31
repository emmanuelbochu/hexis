import SwiftUI

/// What the app already changed in the coming session; closed by default, one line, nothing to validate.
struct AdjustmentsCard: View {
    let notes: [SessionAdjustments.Note]
    @State private var open = false

    var body: some View {
        if !notes.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Button {
                    if !open { UsageCounter.hit(.adjustments) }
                    withAnimation(.snappy) { open.toggle() }
                } label: {
                    HStack {
                        Label("Séance ajustée · \(notes.count)", systemImage: "wand.and.stars")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.accent)
                        Spacer()
                        Image(systemName: open ? "chevron.up" : "info.circle")
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .frame(minHeight: 32)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if open {
                    ForEach(notes) { note in
                        Label(note.text, systemImage: note.symbol)
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .labelStyle(NoteLabelStyle())
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
    }
}

private struct NoteLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s) {
            configuration.icon.foregroundStyle(Theme.Colors.textSecondary).frame(width: 18)
            configuration.title.multilineTextAlignment(.leading)
        }
    }
}

#Preview {
    AdjustmentsCard(notes: [.init(id: "a", symbol: "timer", text: "Leg extension : repos 1:00 → 0:45, tu ne perds pas de reps.")])
        .padding().screenBackground().appAppearance()
}
