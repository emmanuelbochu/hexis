import Foundation

struct DeloadAdvice: Equatable {
    /// Monday of the suggested week.
    var weekStart: Date
    var reason: String
    var holiday: String?
}

/// Decides when a lighter week is due, and puts it in a school holiday week when one is close.
enum DeloadAdvisor {
    /// Training weeks in a row before a deload is due: the 6th week of the cycle is the deload.
    static var dueAfterWeeks: Int { TrainingCycle.trainingWeeks }
    static let maxLookAheadWeeks = 4

    /// Training weeks since the last deload, counted like the cycle does (one missed week tolerated, two in a row restart it).
    /// The running week counts once it has a session. Weeks before `resetWeek` (a new program) do not count.
    static func trainingWeeks(sessionDates: [Date], deloadStarts: [Date], now: Date, resetWeek: Date? = nil) -> Int {
        let current = WeekReview.weekStart(containing: now)
        let cycle = TrainingCycle(deloadStarts: deloadStarts, programStart: resetWeek, programLoadedAt: nil)
        let started = sessionDates.contains { $0 >= current }
        let anchor = started ? WeekReview.weekStart(containing: current, offset: 1) : current
        return cycle.weeksBefore(anchor, sessionDates: sessionDates)
    }

    static func advice(
        now: Date, sessionDates: [Date], deloadStarts: [Date], plateauCount: Int, recentRPE: Double? = nil,
        tiredSessions: Int = 0, programStart: Date? = nil, holidays: [SchoolHoliday] = SchoolHoliday.current,
        dueAfterWeeks: Int = DeloadAdvisor.dueAfterWeeks
    ) -> DeloadAdvice? {
        let current = WeekReview.weekStart(containing: now)
        guard !deloadStarts.contains(where: { $0 >= current }) else { return nil }
        // A week already started at full load cannot become a deload week: look from the next one.
        let firstOffset = sessionDates.contains { $0 >= current } ? 1 : 0
        let weeks = trainingWeeks(sessionDates: sessionDates, deloadStarts: deloadStarts, now: now, resetWeek: programStart)
        // Effort is the main signal: a mean RPE of 9 or more over two weeks means the body is not recovering.
        // « Fatigué » on 3 sessions of the last 2 weeks says the same.
        let fatigued = (recentRPE ?? 0) >= 9 || tiredSessions >= 3
        // Plateaus alone bring it forward 2 weeks at most (his 5-week cycle: from week 3; her 6-week one: from week 4).
        let strained = (plateauCount >= 2 && weeks >= dueAfterWeeks - 2) || fatigued
        guard weeks >= dueAfterWeeks - 1 || (weeks >= 3 && strained) else { return nil }

        func holiday(at offset: Int) -> (week: Date, name: String)? {
            let week = WeekReview.weekStart(containing: current, offset: offset)
            return holidays.first { $0.overlapDays(weekStarting: week) >= 4 }.map { (week, $0.name) }
        }
        let due = weeks >= dueAfterWeeks || (weeks >= 3 && strained)
        let reason: String
        if tiredSessions >= 3, weeks < dueAfterWeeks {
            reason = "Fatigué sur \(tiredSessions) séances ces 2 dernières semaines."
        } else if fatigued, let recentRPE, weeks < dueAfterWeeks {
            reason = "Effort moyen élevé ces 2 dernières semaines (\(EffortScale.average(rpe: recentRPE)))."
        } else if plateauCount >= 2, weeks < dueAfterWeeks {
            reason = "\(plateauCount) exercices stagnent après \(weeks) semaines d'entraînement."
        } else {
            reason = "\(weeks) semaines d'entraînement d'affilée."
        }

        // A holiday week close enough is the best moment: never more than a week after the due date (or the cycle drifts),
        // and before the due date only when it lands near it.
        if let found = (firstOffset...maxLookAheadWeeks).lazy.compactMap({ offset in holiday(at: offset).map { (offset, $0) } })
            .first(where: { (due || weeks + $0.0 >= dueAfterWeeks - 1) && weeks + $0.0 - firstOffset <= dueAfterWeeks + 1 }) {
            return DeloadAdvice(weekStart: found.1.week, reason: reason, holiday: found.1.name)
        }
        guard due else { return nil }
        // Due: this week when it has not started yet, else the next one (never later, or the cycle drifts).
        return DeloadAdvice(weekStart: WeekReview.weekStart(containing: current, offset: firstOffset), reason: reason, holiday: nil)
    }
}
