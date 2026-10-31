import SwiftUI

/// Small glass capsule of icon buttons at the top right of a root screen (the screens have no navigation bar of their own).
struct PageActionRow<Content: View>: View {
    /// Large page title on the left, as in Apple's apps (none: the buttons alone, on the right).
    var title: String?
    @ViewBuilder let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 0) {
            if let title {
                Text(title).font(Theme.Fonts.largeTitle).foregroundStyle(Theme.Colors.textPrimary).lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer()
            HStack(spacing: 0) { content }
                .padding(.horizontal, Theme.Spacing.xs)
                .glassEffect(.regular.interactive(), in: .capsule)
        }
        .font(.title3)
        .foregroundStyle(Theme.Colors.textPrimary)
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .frame(height: Theme.Layout.minTapHeight)
        .padding(.horizontal, Theme.Spacing.m)
    }
}

#Preview {
    PageActionRow {
        Button { } label: { Label("Scan", systemImage: "doc.text.viewfinder").frame(width: 44, height: 44) }
    }
    .screenBackground().appAppearance()
}
