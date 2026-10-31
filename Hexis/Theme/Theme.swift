import SwiftUI
import UIKit

/// Single source of truth for colors, fonts, spacing and shared styles.
enum Theme {
    enum Colors {
        // Each color has a light and a dark value; `Appearance` picks the mode (system, light, dark).
        // Apple's grouped grays: pure black night, cards that stand out by their tone alone (no border).
        #if ELLE
        // Hexis Elle: same structure, a faint warm tint on the grays.
        static let background = Color(light: 0xF5F2F2, dark: 0x000000)
        static let surface = Color(light: 0xFFFFFF, dark: 0x1D1C1C)
        static let surfaceRaised = Color(light: 0xE9E5E4, dark: 0x2D2B2B)
        #else
        static let background = Color(light: 0xF2F2F7, dark: 0x000000)
        static let surface = Color(light: 0xFFFFFF, dark: 0x1C1C1E)
        static let surfaceRaised = Color(light: 0xE5E5EA, dark: 0x2C2C2E)
        #endif
        static let textPrimary = Color(light: 0x000000, dark: 0xFFFFFF)
        static let textSecondary = Color(light: 0x6C6C70, dark: 0x98989F)
        static let separator = Color(light: 0xC6C6C8, dark: 0x38383A)
        static let border = Color(light: 0x000000, dark: 0xFFFFFF, alpha: 0.08)
        #if ELLE
        /// Rose gold, like her icon.
        static let accent = Color(light: 0xB5655B, dark: 0xE3A89B)
        #else
        static let accent = Color(light: 0x4A55E8, dark: 0x6E78FF)
        #endif
        static let accentSoft = accent.opacity(0.16)
        /// Neutral highlight of a selected item on glass (tab, mode): the accent stays on the symbol only.
        static let selection = Color(light: 0x000000, dark: 0xFFFFFF, alpha: 0.12)
        #if ELLE
        static let onAccent = Color(light: 0xFFFFFF, dark: 0x2A1510)
        #else
        static let onAccent = Color.white
        #endif
        /// The record medal: the one place a second warm color is allowed.
        static let record = Color(light: 0xB8860B, dark: 0xF2C14E)
        static let shadow = Color(light: 0x000000, dark: 0x000000, alpha: 0.25)

        /// One color per superset of a session (soft, distinct, readable on both backgrounds), so linked exercises read at a glance.
        static let supersetPalette: [Color] = [
            Color(light: 0x0FA37F, dark: 0x34D3A6),
            Color(light: 0xE08A00, dark: 0xFFB648),
            Color(light: 0xD9466A, dark: 0xFF7A95),
            Color(light: 0x1E88C9, dark: 0x5BC0F8),
            Color(light: 0x8E5BD9, dark: 0xB794F6),
            Color(light: 0x6E9E1C, dark: 0xA6D96A),
        ]

        static func superset(_ index: Int) -> Color {
            supersetPalette[index % supersetPalette.count]
        }

        /// Effort gauge colors: easy (green) → hard (amber) → max (red).
        static func effort(_ rpe: Int) -> Color {
            let t = Double(min(max(rpe, 1), 10) - 1) / 9
            let stops: [(r: Double, g: Double, b: Double)] = [(0.24, 0.86, 0.60), (1.0, 0.78, 0.25), (1.0, 0.35, 0.37)]
            let (a, b, f) = t < 0.5 ? (stops[0], stops[1], t * 2) : (stops[1], stops[2], (t - 0.5) * 2)
            return Color(red: a.r + (b.r - a.r) * f, green: a.g + (b.g - a.g) * f, blue: a.b + (b.b - a.b) * f)
        }
    }

    enum Fonts {
        static let largeTitle = Font.system(size: 34, weight: .bold)
        static let title = Font.system(size: 28, weight: .bold)
        /// Section header in a page (« Autres séances »), like Apple Music's.
        static let section = Font.system(size: 22, weight: .bold)
        static let headline = Font.system(size: 17, weight: .semibold)
        static let body = Font.system(size: 17, weight: .regular)
        static let caption = Font.system(size: 13, weight: .medium)
        static let bigNumber = Font.system(size: 56, weight: .bold).monospacedDigit()
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
    }

    enum Radius {
        static let card: CGFloat = 22
        static let button: CGFloat = 16
        static let field: CGFloat = 12
    }

    enum Layout {
        static let minTapHeight: CGFloat = 56
        /// Room under non-scrolling pages for the floating tab bar.
        static let tabBarClearance: CGFloat = 76
    }
}

extension Color {
    /// A color that follows the light / dark mode.
    init(light: UInt32, dark: UInt32, alpha: Double = 1) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .light ? light : dark
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: alpha
            )
        })
    }

    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Large accent button: the one obvious action of a screen. Tinted Liquid Glass capsule.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.headline)
            .foregroundStyle(Theme.Colors.onAccent)
            .frame(maxWidth: .infinity, minHeight: Theme.Layout.minTapHeight)
            .glassEffect(.regular.tint(Theme.Colors.accent.opacity(isEnabled ? 1 : 0.35)).interactive(), in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, pressed in pressed }
    }
}

extension View {
    /// Surface card: its tone alone sets it apart from the background, as in Apple's apps.
    func cardStyle() -> some View {
        background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    /// Colored bar on the left edge of a card that belongs to a superset (same color = done together).
    func supersetBar(_ color: Color?) -> some View {
        overlay(alignment: .leading) {
            if let color {
                Capsule()
                    .fill(color)
                    .frame(width: 4)
                    .padding(.vertical, Theme.Spacing.m)
                    .padding(.leading, Theme.Spacing.xs + 2)
            }
        }
    }

    func screenBackground() -> some View {
        background(Theme.Colors.background.ignoresSafeArea())
    }
}

/// Secondary action next to a primary button: clear Liquid Glass capsule.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.headline)
            .foregroundStyle(Theme.Colors.textPrimary)
            .frame(maxWidth: .infinity, minHeight: Theme.Layout.minTapHeight)
            .glassEffect(.regular.interactive(), in: .capsule)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
