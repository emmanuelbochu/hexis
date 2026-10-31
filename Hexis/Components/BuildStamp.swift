import SwiftUI

/// One discreet line at the bottom of the home screen: when this version was built (accent while it is new).
struct BuildStamp: View {
    var built: Date? = BuildInfo.builtAt
    var now: Date = .now

    var body: some View {
        if let built {
            let label = BuildInfo.label(built: built, now: now)
            Text(label.text)
                .font(Theme.Fonts.caption)
                .foregroundStyle(label.isFresh ? Theme.Colors.accent : Theme.Colors.textSecondary.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.s)
        }
    }
}

#Preview {
    VStack {
        BuildStamp(built: .now.addingTimeInterval(-3 * 3600))
        BuildStamp(built: .now.addingTimeInterval(-5 * 86_400))
    }
    .appAppearance()
}
