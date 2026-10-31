import Foundation

/// The two notes of an exercise: the machine setting (permanent, per gym) and the reminder (one session).
enum NoteKind: CaseIterable, Identifiable {
    /// Stays on the exercise in this gym: seat height, pin position...
    case exercise
    /// Shown greyed at the next session of the exercise, then gone.
    case nextTime

    var id: Self { self }

    var symbol: String {
        switch self {
        case .exercise: "pin.fill"
        case .nextTime: "arrow.uturn.forward.circle.fill"
        }
    }

    var title: String {
        switch self {
        case .exercise: "Réglage machine"
        case .nextTime: "Rappel pour la prochaine fois"
        }
    }

    var hint: String {
        switch self {
        case .exercise: "Toujours affiché sur l'exercice, dans cette salle."
        case .nextTime: "Affiché en gris à la prochaine séance, puis effacé."
        }
    }

    var placeholder: String {
        switch self {
        case .exercise: "Siège 2, dossier 4…"
        case .nextTime: "Monter la charge, ralentir la descente…"
        }
    }
}
