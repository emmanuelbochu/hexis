import Foundation

/// Where time goes over the last sessions: rests longer than prescribed, pauses, exercises done out of order.
enum TimeInsights {
    struct Sink: Identifiable {
        var exerciseID: UUID
        /// Average extra seconds per set compared with the prescribed rest.
        var extraPerSet: Int
        var plannedRest: Int
        var sessions: Int
        var id: UUID { exerciseID }
    }

    struct Summary {
        var sessions: Int
        var sinks: [Sink]
        /// Average minutes of pauses (> 8 min) per session.
        var pauseMinutes: Int
        /// Sessions where at least one exercise was done out of the program order.
        var reordered: Int
    }

    /// Needs at least 3 sessions with a real timeline; an exercise needs 3 sessions of data to be named.
    static func summary(_ timelines: [SessionTimeline]) -> Summary? {
        let reliable = timelines.filter(\.isReliable)
        guard reliable.count >= 3 else { return nil }
        let byExercise = Dictionary(grouping: reliable.flatMap(\.entries).filter { !$0.overrun.isEmpty }, by: \.exerciseID)
        let sinks = byExercise.compactMap { id, entries -> Sink? in
            guard entries.count >= 3, let planned = entries.compactMap(\.plannedRest).first else { return nil }
            let all = entries.flatMap(\.overrun)
            let average = all.reduce(0, +) / Double(all.count)
            return average >= 30 ? Sink(exerciseID: id, extraPerSet: Int(average.rounded()), plannedRest: planned, sessions: entries.count) : nil
        }
        .sorted { $0.extraPerSet > $1.extraPerSet }
        let pauses = reliable.reduce(0) { $0 + $1.pauseTotal } / Double(reliable.count) / 60
        return Summary(
            sessions: reliable.count, sinks: Array(sinks.prefix(4)), pauseMinutes: Int(pauses.rounded()),
            reordered: reliable.filter { $0.movedCount > 0 }.count
        )
    }
}
