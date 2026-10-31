import Foundation

/// His notifications: figures, not cheering. A Sunday evening review with the real numbers of the week (and the lighter week
/// that follows, when one is due), plus the same sober absence and open-week reminders as hers. The text is worked out from what
/// the app knows when it is planned, and that only changes when he opens the app, which plans again: it is never stale.
enum PerfNotices {
    struct Snapshot {
        var now: Date
        var sessionDates: [Date]
        var weeklyTarget: Int
        var thisWeek: WeekReview?
        var previousWeek: WeekReview?
        var deloadWeekStart: Date?
    }

    /// Below this, a change of volume is noise and not worth a line.
    static let meaningfulChange = 0.08

    static func candidates(_ snapshot: Snapshot, calendar: Calendar = WeekReview.calendar) -> [Notice] {
        var notices = nudges(snapshot, calendar: calendar)
        if let review = review(snapshot, calendar: calendar) { notices.append(review) }
        return notices
    }

    /// Sunday 18:30, only when the week has a session; the day before a lighter week it says so.
    static func review(_ s: Snapshot, calendar: Calendar) -> Notice? {
        guard let week = s.thisWeek, week.sessionCount > 0 else { return nil }
        let weekStart = WeekReview.weekStart(containing: s.now)
        guard let sunday = calendar.date(byAdding: .day, value: 6, to: weekStart),
              let date = calendar.date(bySettingHour: 18, minute: 30, second: 0, of: sunday), date > s.now else { return nil }
        var parts = ["\(week.sessionCount)/\(s.weeklyTarget) séances"]
        if !week.records.isEmpty {
            let names = week.records.prefix(2).map { "\($0.name) \(weight($0.weight))" }.joined(separator: ", ")
            parts.append("\(week.records.count) record\(week.records.count > 1 ? "s" : "") (\(names))")
        }
        // The week is compared only once it is complete: a partial week against a full one says nothing.
        if week.sessionCount >= s.weeklyTarget, let before = s.previousWeek?.volume, before > 0 {
            let delta = (week.volume - before) / before
            if abs(delta) >= meaningfulChange { parts.append("volume \(delta > 0 ? "+" : "")\(Int((delta * 100).rounded())) %") }
        }
        var body = parts.joined(separator: " · ")
        if let deload = s.deloadWeekStart, calendar.isDate(deload, inSameDayAs: WeekReview.weekStart(containing: s.now, offset: 1)) {
            body += ". Semaine allégée demain : moitié des séries, mêmes charges."
        }
        return Notice(kind: .review, date: date, title: "Bilan de la semaine", body: body)
    }

    /// The absence ladder and the open week (Thursday), in plain figures.
    static func nudges(_ s: Snapshot, calendar: Calendar) -> [Notice] {
        NudgePlan.slots(sessionDates: s.sessionDates, weeklyTarget: s.weeklyTarget, now: s.now, calendar: calendar).map {
            Notice(kind: $0.kind == .weekAtRisk ? .weekAtRisk : .absence, date: $0.date, title: "Hexis", body: $0.facts)
        }
    }

    private static func weight(_ kilos: Double) -> String {
        kilos.formatted(.number.precision(.fractionLength(0...1))) + " kg"
    }
}
