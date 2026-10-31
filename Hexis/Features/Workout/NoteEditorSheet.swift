import SwiftUI

/// Small sheet with both notes of an exercise, each saved as it is typed.
struct NoteEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let setting: Binding<String>?
    let reminder: Binding<String>

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            if let setting { field(.exercise, setting) }
            field(.nextTime, reminder)
            Button("OK") { dismiss() }
                .font(Theme.Fonts.headline)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(Theme.Spacing.m)
        .presentationDetents([.height(setting == nil ? 250 : 400)])
        .presentationBackground(Theme.Colors.surface)
    }

    private func field(_ kind: NoteKind, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Label(kind.title, systemImage: kind.symbol)
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.accent)
            Text(kind.hint).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            TextField(kind.placeholder, text: text, axis: .vertical)
                .font(Theme.Fonts.body)
                .lineLimit(1...3)
                .padding(Theme.Spacing.m)
                .background(Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous))
        }
    }
}
