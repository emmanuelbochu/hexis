import SwiftData
import SwiftUI

/// « En plus cette semaine » : the off-plan items typed for this week, ticked like the others, gone once bought and the cycle over.
struct ShoppingNotesSection: View {
    let cycle: Date
    @Environment(\.modelContext) private var context
    @Query(sort: \ShoppingNote.createdAt) private var notes: [ShoppingNote]
    @State private var deleting: ShoppingNote?

    private var current: [ShoppingNote] { ShoppingNotes.visible(notes, cycle: cycle) }

    var body: some View {
        let items = current
        if !items.isEmpty {
            Text("En plus cette semaine").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, note in
                    if index > 0 { Divider().overlay(Theme.Colors.separator).padding(.leading, Theme.Spacing.m) }
                    row(note)
                }
            }
            .cardStyle()
            .alert("Retirer de la liste ?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
                Button("Annuler", role: .cancel) { deleting = nil }
                Button("Retirer", role: .destructive) {
                    if let note = deleting { context.delete(note); context.saveReportingFailure() }
                    deleting = nil
                }
            } message: {
                Text(deleting.map { "\($0.emoji) \($0.name)" } ?? "")
            }
        }
    }

    private func row(_ note: ShoppingNote) -> some View {
        Button {
            ShoppingNotes.toggle(note, cycle: cycle)
            context.saveReportingFailure()
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: note.checked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(note.checked ? Theme.Colors.accent : Theme.Colors.textSecondary)
                Text("\(note.emoji) \(note.name)")
                    .font(Theme.Fonts.body)
                    .foregroundStyle(note.checked ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                    .strikethrough(note.checked)
                Spacer()
                Text(note.quantity)
                    .font(Theme.Fonts.headline.monospacedDigit())
                    .foregroundStyle(note.checked ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
            }
            .padding(.horizontal, Theme.Spacing.m)
            .frame(minHeight: Theme.Layout.minTapHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: note.checked)
        .contextMenu { Button("Retirer", systemImage: "trash", role: .destructive) { deleting = note } }
    }
}

#Preview {
    VStack(alignment: .leading) { ShoppingNotesSection(cycle: .now) }
        .padding()
        .modelContainer(for: ShoppingNote.self, inMemory: true)
        .screenBackground()
        .appAppearance()
}
