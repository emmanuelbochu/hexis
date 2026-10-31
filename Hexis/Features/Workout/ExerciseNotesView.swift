import SwiftData
import SwiftUI

/// One button per exercise: opens the machine setting and the reminder for the next session.
struct ExerciseNotesView: View {
    @Environment(\.modelContext) private var context
    let sessionID: UUID
    let exerciseID: UUID
    let gymID: UUID?
    @Query private var gymNotes: [ExerciseGymNote]
    @Query(sort: \CarryNote.createdAt) private var carryNotes: [CarryNote]
    @State private var editing = false

    init(sessionID: UUID, exerciseID: UUID, gymID: UUID?) {
        self.sessionID = sessionID
        self.exerciseID = exerciseID
        self.gymID = gymID
        let gym = gymID ?? UUID()
        _gymNotes = Query(filter: #Predicate { $0.exerciseID == exerciseID && $0.gymID == gym })
        _carryNotes = Query(filter: #Predicate { $0.exerciseID == exerciseID }, sort: \.createdAt)
    }

    private var gymNote: ExerciseGymNote? { gymNotes.first }
    private var ownCarry: CarryNote? { carryNotes.first { $0.sessionID == sessionID } }
    private var hasAny: Bool { !(gymNote?.note.isEmpty ?? true) || !(ownCarry?.text.isEmpty ?? true) }

    var body: some View {
        Button { editing = true } label: {
            Image(systemName: "note.text")
                .font(.system(size: 15))
                .foregroundStyle(hasAny ? Theme.Colors.accent : Theme.Colors.textSecondary)
                .frame(width: 40, height: 36)
                .background(hasAny ? Theme.Colors.accentSoft : Theme.Colors.surfaceRaised.opacity(0.6), in: Capsule())
        }
        .sheet(isPresented: $editing, onDismiss: removeEmpty) {
            NoteEditorSheet(setting: gymID == nil ? nil : settingBinding, reminder: reminderBinding)
                .appAppearance()
        }
    }

    private var settingBinding: Binding<String> {
        Binding(get: { gymNote?.note ?? "" }, set: { text in
            if let gymNote { gymNote.note = text } else if let gymID {
                context.insert(ExerciseGymNote(exerciseID: exerciseID, gymID: gymID, note: text))
            }
        })
    }

    private var reminderBinding: Binding<String> {
        Binding(get: { ownCarry?.text ?? "" }, set: { text in
            if let ownCarry { ownCarry.text = text } else {
                context.insert(CarryNote(exerciseID: exerciseID, sessionID: sessionID, text: text))
            }
        })
    }

    /// Drops notes left empty.
    private func removeEmpty() {
        if let gymNote, gymNote.note.isEmpty { context.delete(gymNote) }
        if let ownCarry, ownCarry.text.isEmpty { context.delete(ownCarry) }
        context.saveReportingFailure()
    }
}
