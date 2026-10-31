import SwiftUI

struct PlaceholderView: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(Theme.Colors.accent)
            Text(title)
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(subtitle)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    PlaceholderView(systemImage: "dumbbell.fill", title: "Titre", subtitle: "Sous-titre")
        .screenBackground()
        .appAppearance()
}
