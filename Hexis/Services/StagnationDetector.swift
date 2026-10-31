import Foundation

/// Spots exercises that stopped progressing and suggests what to do, from the e1RM history, effort and feeling.
enum StagnationDetector {
    enum Advice: Equatable {
        case deload, increase, checkPain, change
    }

    struct Finding: Identifiable, Equatable {
        var exerciseID: UUID
        var gymID: UUID? = nil
        /// Sessions since the best performance.
        var sessions: Int
        var advice: Advice
        var id: String { "\(exerciseID)-\(gymID?.uuidString ?? "")" }

        /// What the app does about it (it acts by itself, see `SessionAdjuster`).
        var message: String {
            switch advice {
            case .deload: "Stagne depuis \(sessions) séances, effort élevé : charge un peu plus basse pour remonter les reps."
            case .increase: "Stagne depuis \(sessions) séances, effort modéré : charge +1 pas."
            case .checkPain: "Stagne depuis \(sessions) séances avec une gêne : rien n'est poussé tant que la gêne reste."
            case .change: "Stagne depuis \(sessions) séances : série en plus (muscle prioritaire) ou charge plus basse, puis fourchette de reps changée."
            }
        }
    }

    /// Sessions without progress needed to call it a plateau, and the minimum history.
    static let window = 3
    static let minSessions = 4
    /// A session within 1 % of the best still counts as "the best".
    static let tolerance = 0.01

    static func finding(exerciseID: UUID, perfs: [SessionPerf]) -> Finding? {
        guard perfs.count >= minSessions, let best = perfs.map(\.e1RM).max(),
              let bestIndex = perfs.firstIndex(where: { $0.e1RM >= best * (1 - tolerance) })
        else { return nil }
        let since = perfs.count - 1 - bestIndex
        guard since >= window else { return nil }

        let recent = perfs.suffix(window)
        let feelings = recent.compactMap(\.feeling)
        let efforts = recent.compactMap(\.avgRPE)
        let advice: Advice
        if feelings.contains(.pain) {
            advice = .checkPain
        } else if !efforts.isEmpty {
            // The RPE of the sets decides. Tired sessions never reach here (callers drop them; `DeloadAdvisor` handles tiredness).
            if efforts.filter({ $0 >= 9 }).count >= 2 {
                advice = .deload
            } else if efforts.allSatisfy({ $0 <= 7.5 }) {
                advice = .increase
            } else {
                advice = .change
            }
        } else {
            advice = .change
        }
        return Finding(exerciseID: exerciseID, sessions: since, advice: advice)
    }

    /// An exercise left aside for this long is not a current plateau.
    static let staleDays = 42

    private struct Key: Hashable {
        var exerciseID: UUID
        var gymID: UUID?
    }

    /// Findings for every exercise of the given sets, judged gym by gym (the machines differ), deload weeks excluded.
    /// One finding per exercise: the gym where it stalls the longest.
    static func findings(sets: [SetLog], feelings: [ExerciseFeeling], cycle: TrainingCycle? = nil, now: Date = .now) -> [Finding] {
        let since = Calendar.current.date(byAdding: .day, value: -staleDays, to: now) ?? now
        let sessionWide = feelings.filter(\.isSessionWide)
        let feelingsByExercise = Dictionary(grouping: feelings, by: \.exerciseID)
        let work = sets.filter { $0.kind == .work && !(cycle?.isDeload($0.completedAt) ?? false) }
        let all = Dictionary(grouping: work, by: { Key(exerciseID: $0.exerciseID, gymID: $0.gymID) }).compactMap { key, logs -> Finding? in
            // Tired days are not judged: a lower session then is not a plateau.
            let perfs = Performance.sessions(sets: logs, feelings: (feelingsByExercise[key.exerciseID] ?? []) + sessionWide)
                .filter { $0.feeling != .tired }
            guard let last = perfs.last, last.date >= since, var found = finding(exerciseID: key.exerciseID, perfs: perfs) else { return nil }
            found.gymID = key.gymID
            return found
        }
        return Dictionary(grouping: all, by: \.exerciseID).compactMap { $0.value.max { $0.sessions < $1.sessions } }
            .sorted { $0.sessions > $1.sessions }
    }
}
