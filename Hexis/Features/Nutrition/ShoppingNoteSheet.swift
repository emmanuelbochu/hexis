import SwiftData
import SwiftUI

/// Type what else to buy this week, as it comes (« lessive, 2 éponges, huile d'olive ») : the app tidies it.
struct ShoppingNoteSheet: View {
    let cycle: Date
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var working = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("En plus cette semaine").font(Theme.Fonts.section).foregroundStyle(Theme.Colors.textPrimary)
            TextField("Lessive, 2 éponges, huile d'olive…", text: $text, axis: .vertical)
                .font(Theme.Fonts.body)
                .lineLimit(3...8)
                .focused($focused)
                .padding(Theme.Spacing.m)
                .cardStyle()
            Button {
                working = true
                Task {
                    ShoppingNotes.add(await ShoppingNotes.tidy(text), cycle: cycle, in: context)
                    dismiss()
                }
            } label: {
                if working { ProgressView().tint(Theme.Colors.onAccent) } else { Text("Ajouter") }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(working || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Spacer()
        }
        .padding(Theme.Spacing.m)
        .screenBackground()
        .presentationDetents([.medium])
        .onAppear { focused = true }
    }
}

#Preview {
    ShoppingNoteSheet(cycle: .now).appAppearance()
}
