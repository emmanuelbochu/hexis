import SwiftUI

/// Light or dark, chosen with the sun / moon button of the top row; applied at the root and on every sheet.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case light, dark

    static let key = "appearance"
    var id: String { rawValue }

    var scheme: ColorScheme {
        switch self {
        case .light: .light
        case .dark: .dark
        }
    }

    var toggled: AppearanceMode { self == .dark ? .light : .dark }
}

private struct AppearanceModifier: ViewModifier {
    @AppStorage(AppearanceMode.key) private var appearance = AppearanceMode.dark.rawValue

    func body(content: Content) -> some View {
        // A value left by the old « Auto » mode falls back to dark.
        content.preferredColorScheme((AppearanceMode(rawValue: appearance) ?? .dark).scheme)
    }
}

extension View {
    func appAppearance() -> some View { modifier(AppearanceModifier()) }
}
