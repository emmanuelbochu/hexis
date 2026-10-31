import Foundation

/// End-of-session highlights: weight records and volume against the previous same session.
struct SessionReview: Equatable {
    struct Record: Equatable {
        var name: String
        var weight: Double
        /// The best weight before this session.
        var previous: Double = 0
    }

    var records: [Record]
    /// Fraction, e.g. 0.04 = +4 % volume vs the last time; nil without a previous session.
    var volumeDelta: Double?

    init(sessionSets: [SetLog], earlierSets: [SetLog], names: [UUID: String], previousVolume: Double?) {
        let work = sessionSets.filter { $0.kind == .work }
        let earlierBest = Dictionary(grouping: earlierSets.filter { $0.kind == .work }, by: \.exerciseID)
            .mapValues { $0.map(\.weight).max() ?? 0 }
        records = Dictionary(grouping: work, by: \.exerciseID).compactMap { id, logs in
            let best = logs.map(\.weight).max() ?? 0
            guard let before = earlierBest[id], before > 0, best > before else { return nil }
            return Record(name: names[id] ?? "Exercice", weight: best, previous: before)
        }
        .sorted { $0.name < $1.name }
        let volume = work.reduce(0) { $0 + $1.weight * Double($1.reps) }
        volumeDelta = previousVolume.flatMap { $0 > 0 ? (volume - $0) / $0 : nil }
    }
}
