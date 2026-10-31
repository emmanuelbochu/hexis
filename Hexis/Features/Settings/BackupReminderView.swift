import SwiftUI

/// Once a week: a copy of the latest snapshot goes off the phone, so a lost or reset iPhone does not take the history with it.
struct BackupReminderView: View {
    let file: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            Spacer()
            Image(systemName: "externaldrive.badge.icloud")
                .font(.system(size: 48))
                .foregroundStyle(Theme.Colors.accent)
            Text("Copie ta sauvegarde de la semaine")
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
            Text("Fichiers, AirDrop vers le Mac, ou un mail à toi : si l'iPhone est perdu ou réinitialisé, tout l'historique reste.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            ShareLink(item: file) {
                Label("Envoyer la sauvegarde", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(PrimaryButtonStyle())
            Button("Plus tard") { dismiss() }.buttonStyle(SecondaryButtonStyle())
        }
        .padding(Theme.Spacing.m)
        .screenBackground()
    }
}

#Preview {
    BackupReminderView(file: URL(fileURLWithPath: "/tmp/hexis-auto.json")).appAppearance()
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
