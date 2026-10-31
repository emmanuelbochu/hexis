import SwiftUI

/// Sun / moon button: switches between the day and the night look.
struct AppearanceToggle: View {
    @AppStorage(AppearanceMode.key) private var appearance = AppearanceMode.dark.rawValue

    private var mode: AppearanceMode { AppearanceMode(rawValue: appearance) ?? .dark }

    var body: some View {
        Button { appearance = mode.toggled.rawValue } label: {
            Image(systemName: mode == .dark ? "moon.fill" : "sun.max.fill")
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(width: 44, height: 44)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: appearance)
        .accessibilityLabel(mode == .dark ? "Passer en mode jour" : "Passer en mode nuit")
    }
}

#Preview {
    AppearanceToggle().screenBackground().appAppearance()
}
