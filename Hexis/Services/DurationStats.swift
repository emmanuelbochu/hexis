import Foundation
import SwiftData

/// Learns how long sessions really last from the finished ones.
enum DurationStats {
    /// Sessions shorter than 10 min or longer than 3 h are forgotten (aborted or left open).
    private static func minutes(_ session: WorkoutSession) -> Double? {
        guard session.state == .finished, let end = session.endedAt else { return nil }
        let value = end.timeIntervalSince(session.startedAt) / 60
        return (10...180).contains(value) ? value : nil
    }

    /// Every template's real duration, from the finished sessions of the last 6 months (one fetch, for the program screens).
    @MainActor static func load(in context: ModelContext, now: Date = .now) -> [UUID: Int] {
        let since = now.addingTimeInterval(-183 * 86_400)
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.stateRaw == "finished" && $0.startedAt >= since }))) ?? []
        let deloads = TrainingCycle(deloadStarts: ((try? context.fetch(FetchDescriptor<DeloadWeek>())) ?? []).map(\.start))
        return Set(sessions.compactMap(\.templateID)).reduce(into: [:]) { out, id in out[id] = minutes(for: id, sessions: sessions, cycle: deloads) }
    }

    /// Average of the last 5 sessions of a template, to 5 min; nil under 2 sessions. A deload week (half the sets) is shorter on purpose:
    /// it is left out while enough normal sessions remain. Sessions imported from before the app (Hevy) only stand in until 2 of
    /// her own are done: from then on the average is that of the real ones.
    static func minutes(for templateID: UUID, sessions: [WorkoutSession], cycle: TrainingCycle = TrainingCycle(deloadStarts: [])) -> Int? {
        let ofTemplate = sessions.filter { $0.templateID == templateID }.sorted { $0.startedAt > $1.startedAt }
        func durations(_ list: [WorkoutSession]) -> [Double] { list.compactMap { minutes($0) } }
        var pool = ofTemplate
        if durations(pool.filter { !HistorySeed.isImported($0.id) }).count >= 2 { pool = pool.filter { !HistorySeed.isImported($0.id) } }
        let normal = pool.filter { !cycle.isDeload($0.startedAt) }
        if durations(normal).count >= 2 { pool = normal }
        let recent = durations(pool).prefix(5)
        guard recent.count >= 2 else { return nil }
        return Int((recent.reduce(0, +) / Double(recent.count) / 5).rounded()) * 5
    }
}
