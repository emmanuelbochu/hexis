import Foundation

/// Stats of one week (Monday to Sunday) from finished sessions and their sets.
struct WeekReview: Equatable {
    var start: Date
    var sessionCount: Int
    var workSets: Int
    var volume: Double
    var seconds: TimeInterval
    var avgRPE: Double?
    /// Work sets per muscle group, most trained first.
    var setsByMuscle: [(muscle: String, sets: Int)]
    /// Exercises whose heaviest weight of the week beats everything before it.
    var records: [SessionReview.Record]

    static func == (a: WeekReview, b: WeekReview) -> Bool {
        a.start == b.start && a.sessionCount == b.sessionCount && a.workSets == b.workSets && a.volume == b.volume
    }

    var end: Date { Self.calendar.date(byAdding: .day, value: 6, to: start) ?? start }

    /// A week is comparable to the previous one only once it is over (Monday 00:00 of the next one): on a Saturday it holds a fraction of it.
    func isOver(now: Date) -> Bool {
        now >= (Self.calendar.date(byAdding: .day, value: 7, to: start) ?? start)
    }

    /// « +12 % vs sem. préc. »: nil while the week runs or when the previous one has no data.
    static func change(_ now: Double, vs before: Double, weekIsOver: Bool) -> String? {
        guard weekIsOver, before > 0 else { return nil }
        let percent = Int(((now - before) / before * 100).rounded())
        return "\(percent >= 0 ? "+" : "")\(percent) % vs sem. préc."
    }

    static var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    /// Monday of the week containing `date`, shifted by `offset` weeks.
    static func weekStart(containing date: Date, offset: Int = 0) -> Date {
        let monday = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        return calendar.date(byAdding: .weekOfYear, value: offset, to: monday) ?? monday
    }

    init(start: Date, sessions: [WorkoutSession], sets: [SetLog], exercises: [UUID: Exercise], loads: LoadResolver? = nil) {
        self.start = start
        let next = Self.calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
        let week = sessions.filter { $0.state == .finished && $0.startedAt >= start && $0.startedAt < next }
        let ids = Set(week.map(\.id))
        let weekWork = sets.filter { ids.contains($0.sessionID) && $0.kind == .work }
        sessionCount = week.count
        // A unilateral set is logged once per side: it counts once.
        let countable = weekWork.filter { $0.side != .left }
        workSets = countable.count
        volume = weekWork.reduce(0) { $0 + (loads?.effective($1) ?? $1.weight) * Double($1.reps) }
        seconds = week.reduce(0) { $0 + ($1.endedAt ?? $1.startedAt).timeIntervalSince($1.startedAt) }
        let efforts = weekWork.compactMap { $0.rir.map { 10 - $0 } }
        avgRPE = efforts.isEmpty ? nil : Double(efforts.reduce(0, +)) / Double(efforts.count)
        setsByMuscle = Dictionary(grouping: countable, by: { exercises[$0.exerciseID]?.muscleGroup ?? "" })
            .filter { !$0.key.isEmpty }
            .map { (muscle: $0.key, sets: $0.value.count) }
            .sorted { $0.sets > $1.sets }
        // Set lookup instead of a scan of the sessions per set (quadratic, froze the app on a full history).
        let earlierIDs = Set(sessions.filter { $0.startedAt < start }.map(\.id))
        let earlierBest = Dictionary(
            grouping: sets.filter { earlierIDs.contains($0.sessionID) && $0.kind == .work },
            by: \.exerciseID
        ).mapValues { $0.map(\.weight).max() ?? 0 }
        records = Dictionary(grouping: weekWork, by: \.exerciseID).compactMap { id, logs in
            let best = logs.map(\.weight).max() ?? 0
            guard let before = earlierBest[id], before > 0, best > before else { return nil }
            return SessionReview.Record(name: exercises[id]?.name ?? "Exercice", weight: best)
        }
        .sorted { $0.name < $1.name }
    }
}
