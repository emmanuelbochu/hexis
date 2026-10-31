import Foundation

/// Pure per-exercise stats from work sets: records and one data point per session.
enum PersonalRecords {
    struct Point: Identifiable, Equatable {
        var id: UUID { sessionID }
        var sessionID: UUID
        var date: Date
        var topWeight: Double
        var volume: Double
    }

    struct Records: Equatable {
        var maxWeight: Double
        var maxReps: Int
        var maxVolume: Double
    }

    static func points(from sets: [SetLog]) -> [Point] {
        Dictionary(grouping: sets.filter { $0.kind == .work }, by: \.sessionID)
            .map { id, logs in
                Point(
                    sessionID: id, date: logs.map(\.completedAt).min() ?? .now,
                    topWeight: logs.map(\.weight).max() ?? 0,
                    volume: logs.reduce(0) { $0 + $1.weight * Double($1.reps) }
                )
            }
            .sorted { $0.date < $1.date }
    }

    static func records(from sets: [SetLog]) -> Records? {
        let work = sets.filter { $0.kind == .work }
        guard !work.isEmpty else { return nil }
        return Records(
            maxWeight: work.map(\.weight).max() ?? 0,
            maxReps: work.map(\.reps).max() ?? 0,
            maxVolume: points(from: work).map(\.volume).max() ?? 0
        )
    }
}
