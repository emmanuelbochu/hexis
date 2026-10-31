import SwiftData
import SwiftUI

/// What to remember on an exercise card: the machine setting of this gym (accent), and the reminder left last time (grey).
struct GymNoteLine: View {
    @Query private var notes: [ExerciseGymNote]
    @Query private var reminders: [CarryNote]
    /// The machine setting is shown only on an unfolded card; a reminder always.
    var showsSetting = true

    init(exerciseID: UUID, gymID: UUID?, sessionID: UUID, showsSetting: Bool = true) {
        self.showsSetting = showsSetting
        let gym = gymID ?? UUID()
        _notes = Query(filter: #Predicate { $0.exerciseID == exerciseID && $0.gymID == gym })
        _reminders = Query(filter: #Predicate { $0.exerciseID == exerciseID && $0.sessionID != sessionID })
    }

    var body: some View {
        if showsSetting, let text = notes.first?.note, !text.isEmpty {
            Label(text, systemImage: NoteKind.exercise.symbol)
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.accent)
        }
        if let text = reminders.first?.text, !text.isEmpty {
            Label(text, systemImage: NoteKind.nextTime.symbol)
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }
}
