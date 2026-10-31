import Foundation

/// « Ta progression » : did the app serve? Strength, scale and attendance since the first session, from data the app already holds.
struct Journey: Equatable {
    struct Lift: Equatable {
        var name: String
        /// Heaviest weight of the first and of the last sessions compared (what the user sees on the machine).
        var fromWeight: Double
        var toWeight: Double
        /// e1RM change (a fraction): fair when the reps change too.
        var change: Double
        /// Sessions done on this exercise (all of them): the most trained come first.
        var sessions: Int
    }

    /// Weeks measured: the recent window only (fresh data wins over an old program).
    var weeks: Int
    /// Mean e1RM change of the lifts measured over the window, and how many.
    var strength: Double?
    var measured: Int
    /// Weight change over the last 4 weeks.
    var weightChange: Double?
    /// Sessions this week against the weekly target.
    var thisWeek: Int
    var weeklyTarget: Int

    /// Below this, the figures would only be noise: the card stays hidden.
    static let minWeeks = 4
    static let minSessions = 8
    /// Only the last 12 weeks count: older sessions belong to other programs and would blur the picture.
    static let windowDays = 84
    /// Sessions of an exercise (one gym, one setup) needed to compare its start with its present.
    static let minPerfs = 4
    /// Between two sessions, a jump this big is not strength but a new setup (weight per side, other machine, slower tempo):
    /// the comparison starts again after it.
    static let setupChange: ClosedRange<Double> = 0.75...1.4

    /// `eligible` = exercises worth measuring (no rehab, no cardio, no timed holds). Sets are all the work sets.
    static func make(
        sets: [SetLog], sessionDates: [Date], names: [UUID: String], eligible: Set<UUID>, weights: [HealthService.Day],
        weeklyTarget: Int, now: Date = .now
    ) -> Journey? {
        guard let first = sessionDates.min(), sessionDates.count >= minSessions else { return nil }
        let calendar = WeekReview.calendar
        let currentWeek = WeekReview.weekStart(containing: now)
        let weeks = calendar.dateComponents([.weekOfYear], from: WeekReview.weekStart(containing: first), to: currentWeek).weekOfYear ?? 0
        guard weeks >= minWeeks else { return nil }
        let windowStart = now.addingTimeInterval(-Double(windowDays) * 86_400)
        let all = measure(sets: sets.filter { $0.completedAt >= windowStart }, names: names, eligible: eligible)
        let regularity = Regularity(sessionDates: sessionDates, weeklyTarget: weeklyTarget, now: now)
        return Journey(
            weeks: min(weeks, windowDays / 7),
            strength: all.count >= 2 ? all.reduce(0) { $0 + $1.change } / Double(all.count) : nil, measured: all.count,
            weightChange: weightDelta(weights.filter { $0.date >= now.addingTimeInterval(-28 * 86_400) }),
            thisWeek: regularity.thisWeek, weeklyTarget: regularity.weeklyTarget
        )
    }

    /// Per exercise, in its busiest gym (machines differ), since its last setup change: best of the first sessions against
    /// best of the last ones (3 each, fewer on a short run). Most trained first.
    static func measure(sets: [SetLog], names: [UUID: String], eligible: Set<UUID>) -> [Lift] {
        struct Key: Hashable { var exercise: UUID; var gym: UUID? }
        let work = sets.filter { $0.kind == .work && eligible.contains($0.exerciseID) }
        let groups = Dictionary(grouping: work, by: { Key(exercise: $0.exerciseID, gym: $0.gymID) })
        var busiest: [UUID: (perfs: [SessionPerf], logs: [SetLog])] = [:]
        for (key, logs) in groups {
            let perfs = Performance.sessions(sets: logs, feelings: [])
            guard perfs.count > (busiest[key.exercise]?.perfs.count ?? 0) else { continue }
            busiest[key.exercise] = (perfs, logs)
        }
        return busiest.compactMap { id, entry -> Lift? in
            let run = stableRun(entry.perfs)
            guard run.count >= minPerfs else { return nil }
            let k = min(3, run.count / 2)
            let start = run.prefix(k), end = run.suffix(k)
            let from = start.map(\.e1RM).max() ?? 0, to = end.map(\.e1RM).max() ?? 0
            guard from > 0 else { return nil }
            // The weight shown is the heaviest of the same sessions, read from the sets (dated by their first set, like the perfs).
            let weightByDate = Dictionary(grouping: entry.logs, by: \.sessionID).values.reduce(into: [Date: Double]()) { result, logs in
                if let date = logs.map(\.completedAt).min() { result[date] = logs.map(\.weight).max() ?? 0 }
            }
            func heaviest(_ perfs: ArraySlice<SessionPerf>) -> Double { perfs.compactMap { weightByDate[$0.date] }.max() ?? 0 }
            return Lift(name: names[id] ?? "Exercice", fromWeight: heaviest(start), toWeight: heaviest(end), change: to / from - 1, sessions: entry.perfs.count)
        }
        .sorted { $0.sessions != $1.sessions ? $0.sessions > $1.sessions : $0.name < $1.name }
    }

    /// The sessions since the last setup change (a jump outside `setupChange` between two sessions in a row).
    static func stableRun(_ perfs: [SessionPerf]) -> ArraySlice<SessionPerf> {
        var start = 0
        for i in perfs.indices.dropFirst() where perfs[i - 1].e1RM > 0 && !setupChange.contains(perfs[i].e1RM / perfs[i - 1].e1RM) {
            start = i
        }
        return perfs[start...]
    }

    /// Mean of the first week of weigh-ins against the mean of the latest week; needs 2 weigh-ins at each end and 2 weeks between.
    static func weightDelta(_ weights: [HealthService.Day]) -> Double? {
        let days = weights.sorted { $0.date < $1.date }
        guard let firstDate = days.first?.date, let lastDate = days.last?.date, lastDate.timeIntervalSince(firstDate) >= 14 * 86_400 else { return nil }
        let week: TimeInterval = 7 * 86_400
        let start = days.filter { $0.date < firstDate.addingTimeInterval(week) }
        let end = days.filter { $0.date > lastDate.addingTimeInterval(-week) }
        guard start.count >= 2, end.count >= 2 else { return nil }
        func mean(_ list: [HealthService.Day]) -> Double { list.reduce(0) { $0 + $1.value } / Double(list.count) }
        return mean(end) - mean(start)
    }
}
