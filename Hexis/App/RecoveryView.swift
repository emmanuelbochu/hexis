import SwiftData
import SwiftUI

/// Shown instead of a crash when the database cannot be opened: the latest backup can be shared, and the database reset.
struct RecoveryView: View {
    let error: String
    @State private var confirmsReset = false
    @State private var done = false

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundStyle(Theme.Colors.accent)
            Text("Les données ne s'ouvrent pas").font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
            Text(error).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary).multilineTextAlignment(.center)
            if let file = AutoBackup.latestFile() {
                ShareLink(item: file) { Label("Garder la dernière sauvegarde", systemImage: "square.and.arrow.up") }
                    .buttonStyle(PrimaryButtonStyle())
            }
            if done {
                Text("Base réinitialisée : ferme et rouvre l'app, la dernière sauvegarde est remise toute seule.")
                    .font(Theme.Fonts.body).foregroundStyle(Theme.Colors.accent).multilineTextAlignment(.center)
            } else {
                Button("Réinitialiser la base") { confirmsReset = true }.buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
        .alert("Réinitialiser la base ?", isPresented: $confirmsReset) {
            Button("Annuler", role: .cancel) {}
            Button("Réinitialiser", role: .destructive) { done = Self.resetStore() }
        } message: {
            Text("Les données de la base sont effacées. Les sauvegardes dans Fichiers restent.")
        }
    }

    /// Removes the store files (the backups in Documents are not touched).
    private static func resetStore() -> Bool {
        let url = ModelConfiguration().url
        let manager = FileManager.default
        var removed = false
        for suffix in ["", "-shm", "-wal"] {
            let file = URL(fileURLWithPath: url.path + suffix)
            if manager.fileExists(atPath: file.path) { removed = ((try? manager.removeItem(at: file)) != nil) || removed }
        }
        return removed
    }
}

#Preview {
    RecoveryView(error: "Exemple")
        .appAppearance()
}
