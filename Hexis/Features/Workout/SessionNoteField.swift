import SwiftData
import SwiftUI

/// Note and pain flag for one exercise in the running session (`exerciseID == nil`: whole session).
struct SessionNoteField: View {
    @Environment(\.modelContext) private var context
    let sessionID: UUID
    let exerciseID: UUID?
    var showsPain = true
    /// Roomy multi-line style for the end-of-session note.
    var large = false
    @State private var text = ""
    @State private var hasPain = false

    var body: some View {
        HStack {
            TextField(exerciseID == nil ? "Note de séance" : "Note", text: $text, axis: large ? .vertical : .horizontal)
                .font(large ? Theme.Fonts.body : Theme.Fonts.caption)
                .lineLimit(large ? 4...8 : 1...1)
                .padding(.vertical, large ? Theme.Spacing.m : 0)
                .submitLabel(large ? .return : .done)
                .onSubmit(save)
            if showsPain {
                Button {
                    hasPain.toggle()
                    save()
                } label: {
                    Image(systemName: hasPain ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                        .foregroundStyle(hasPain ? Theme.Colors.accent : Theme.Colors.textSecondary)
                        .frame(minWidth: Theme.Layout.minTapHeight / 1.4, minHeight: Theme.Layout.minTapHeight / 1.4)
                }
                .sensoryFeedback(.impact(weight: .light), trigger: hasPain)
            }
        }
        .padding(.horizontal, Theme.Spacing.m)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .onAppear {
            let note = existing()
            text = note?.text ?? ""
            hasPain = note?.hasPain ?? false
        }
        .onDisappear(perform: save)
    }

    private func existing() -> SessionNote? {
        let id = sessionID
        let ex = exerciseID
        let descriptor = FetchDescriptor<SessionNote>(predicate: #Predicate { $0.sessionID == id && $0.exerciseID == ex })
        return try? context.fetch(descriptor).first
    }

    private func save() {
        if let note = existing() {
            note.text = text
            note.hasPain = hasPain
        } else if !text.isEmpty || hasPain {
            context.insert(SessionNote(sessionID: sessionID, exerciseID: exerciseID, text: text, hasPain: hasPain))
        }
        context.saveReportingFailure()
    }
}
