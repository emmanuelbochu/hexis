import Foundation

/// How one exercise went in one session.
struct SessionPerf: Equatable {
    var date: Date
    /// Best estimated one-rep max of the session (Epley), comparable across weight/rep schemes.
    var e1RM: Double
    /// Mean perceived effort (RPE) of the work sets that have one.
    var avgRPE: Double?
    var feeling: Feeling?
}

enum Performance {
    static func e1RM(weight: Double, reps: Int) -> Double {
        weight * (1 + Double(min(max(reps, 0), 30)) / 30)
    }

    /// One entry per session, oldest first, from the sets of a single exercise.
    static func sessions(sets: [SetLog], feelings: [ExerciseFeeling]) -> [SessionPerf] {
        // Pain on the exercise wins over a tired day; feelings of other exercises are ignored.
        let exerciseIDs = Set(sets.map(\.exerciseID))
        let relevant = feelings.filter { $0.isSessionWide || exerciseIDs.contains($0.exerciseID) }
        let feelingBySession = Dictionary(relevant.map { ($0.sessionID, $0.feeling) }, uniquingKeysWith: { a, b in a == .pain ? a : b == .pain ? b : a ?? b })
        let work = sets.filter { $0.kind == .work && $0.weight > 0 && $0.reps > 0 }
        // A typo (one extra zero on the weight or the reps) would become an unbeatable best and fake a plateau forever:
        // sets far above the usual level are left out.
        // Compared with the 20 sets before it, so real progress over months is never cut.
        var valid: [SetLog] = []
        var previous: [Double] = []
        for set in work.sorted(by: { $0.completedAt < $1.completedAt }) {
            let level = e1RM(weight: set.weight, reps: set.reps)
            let window = previous.suffix(20).sorted()
            // Kept in the window either way: a real change of level (weight typed per side instead of total) soon becomes the norm.
            previous.append(level)
            if window.count >= 6, level > window[window.count / 2] * 1.45 { continue }
            valid.append(set)
        }
        return Dictionary(grouping: valid, by: \.sessionID)
            .map { id, logs in
                let efforts = logs.compactMap { $0.rir.map { 10 - $0 } }
                return SessionPerf(
                    date: logs.map(\.completedAt).min() ?? .now,
                    e1RM: logs.map { e1RM(weight: $0.weight, reps: $0.reps) }.max() ?? 0,
                    avgRPE: efforts.isEmpty ? nil : Double(efforts.reduce(0, +)) / Double(efforts.count),
                    feeling: feelingBySession[id] ?? nil
                )
            }
            .sorted { $0.date < $1.date }
    }
}
