import SwiftUI

/// Small glass island at the top left of the pager: the selected side expands with its label on a neutral pill.
struct ModeSwitcher: View {
    @Binding var mode: AppMode
    @Namespace private var pill

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(AppMode.allCases) { item in
                Button {
                    withAnimation(.spring(duration: 0.4, bounce: 0.25)) { mode = item }
                } label: {
                    HStack(spacing: Theme.Spacing.s) {
                        Image(systemName: item.systemImage)
                        if mode == item { Text(item.label).transition(.opacity.combined(with: .scale(scale: 0.8))) }
                    }
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(mode == item ? Theme.Colors.accent : Theme.Colors.textPrimary)
                    .padding(.horizontal, Theme.Spacing.m)
                    .frame(height: 36)
                    .background {
                        if mode == item {
                            Capsule()
                                .fill(Theme.Colors.selection)
                                .matchedGeometryEffect(id: "pill", in: pill)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .glassEffect(.regular.interactive(), in: .capsule)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.m)
        .sensoryFeedback(.selection, trigger: mode)
    }
}

#Preview {
    @Previewable @State var mode = AppMode.workout
    ModeSwitcher(mode: $mode)
        .screenBackground()
        .appAppearance()
}
