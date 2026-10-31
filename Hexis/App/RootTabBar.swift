import SwiftUI

/// Floating tab bar of the current part of the app.
struct RootTabBar: View {
    struct Item: Identifiable {
        var title: String
        var systemImage: String
        var id: String { title }
    }

    let items: [Item]
    @Binding var selection: Int
    /// Finger position along the bar while it is down: the glass lens follows it.
    @State private var fingerX: CGFloat?
    @State private var width: CGFloat = 0

    private var itemWidth: CGFloat { items.isEmpty ? 0 : width / CGFloat(items.count) }
    private var pressed: Bool { fingerX != nil }

    /// Centre of the lens: under the finger, else on the selected tab.
    private var lensCenter: CGFloat {
        let wanted = fingerX ?? (CGFloat(selection) + 0.5) * itemWidth
        return min(max(wanted, itemWidth / 2), max(width - itemWidth / 2, itemWidth / 2))
    }

    private var highlighted: Int { index(at: lensCenter) }

    var body: some View {
        GlassEffectContainer(spacing: Theme.Spacing.m) {
            ZStack(alignment: .leading) {
                lens
                HStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        VStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: item.systemImage).font(.system(size: 20))
                            Text(item.title).font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(highlighted == index ? Theme.Colors.accent : Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: Theme.Layout.minTapHeight)
                    }
                }
            }
            .contentShape(Rectangle())
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        if fingerX == nil {
                            withAnimation(.bouncy(duration: 0.4)) { fingerX = drag.location.x }
                        } else {
                            fingerX = drag.location.x
                        }
                    }
                    .onEnded { drag in
                        let index = index(at: min(max(drag.location.x, 0), width))
                        withAnimation(.bouncy(duration: 0.5, extraBounce: 0.15)) {
                            selection = index
                            fingerX = nil
                        }
                    }
            )
            .padding(Theme.Spacing.xs)
            .glassEffect(.regular, in: .capsule)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.bottom, Theme.Spacing.xs)
        .sensoryFeedback(.selection, trigger: highlighted)
    }

    /// The glass lens: at rest a neutral capsule on the selected tab (the accent is on the symbol only); under the finger it lifts and follows it.
    private var lens: some View {
        Capsule()
            .fill(.clear)
            .glassEffect(.regular.tint(Theme.Colors.selection).interactive(), in: .capsule)
            .frame(width: itemWidth, height: Theme.Layout.minTapHeight)
            .scaleEffect(x: pressed ? 1.12 : 1, y: pressed ? 1.22 : 1)
            .offset(x: lensCenter - itemWidth / 2)
    }

    private func index(at x: CGFloat) -> Int {
        guard itemWidth > 0 else { return selection }
        return min(max(Int(x / itemWidth), 0), items.count - 1)
    }
}

#Preview {
    @Previewable @State var selection = 0
    RootTabBar(
        items: [.init(title: "Accueil", systemImage: "house.fill"), .init(title: "Programme", systemImage: "list.bullet.rectangle.fill")],
        selection: $selection
    )
    .screenBackground()
    .appAppearance()
}
