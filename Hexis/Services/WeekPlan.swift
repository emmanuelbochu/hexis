import Foundation

/// Catches up a short week: when more sessions are left than the days can hold, proposes the stalest ones first and postpones the rest.
struct WeekPlan: Equatable {
    /// Sessions to do in the days left, most urgent first.
    var queue: [UUID]
    /// Sessions pushed to next week (they will be the stalest then, so they come first).
    var postponed: [UUID]
    var daysLeft: Int
    var needed: Int

    /// nil when the week is on track (the program order keeps going as usual).
    static func make(
        templates: [(id: UUID, order: Int)], lastDone: [UUID: Date], doneThisWeek: Int, target: Int,
        now: Date = .now, calendar: Calendar = WeekReview.calendar
    ) -> WeekPlan? {
        let needed = target - doneThisWeek
        let monday = WeekReview.weekStart(containing: now)
        let elapsed = calendar.dateComponents([.day], from: monday, to: calendar.startOfDay(for: now)).day ?? 0
        let daysLeft = max(7 - elapsed, 1)
        // Capacity at his usual pace: `target` sessions over 7 days.
        let capacity = max(Int((Double(daysLeft) * Double(target) / 7).rounded(.up)), 1)
        // Catching up only makes sense from 3 sessions a week: a 2-session week is always 2 (A then B), never postponed.
        guard needed > capacity, templates.count > 2 else { return nil }
        let ranked = templates.sorted {
            let a = lastDone[$0.id] ?? .distantPast, b = lastDone[$1.id] ?? .distantPast
            return a == b ? $0.order < $1.order : a < b
        }.map(\.id)
        let take = min(capacity, ranked.count)
        return WeekPlan(queue: Array(ranked.prefix(take)), postponed: Array(ranked.dropFirst(take).prefix(needed - capacity)), daysLeft: daysLeft, needed: needed)
    }

    /// Convenience over the finished sessions: the week's done count and each template's last date.
    static func make(
        templates: [(id: UUID, order: Int)], sessions: [(templateID: UUID?, date: Date)], now: Date = .now
    ) -> WeekPlan? {
        let thisWeek = WeekReview.weekStart(containing: now)
        let lastDone = Dictionary(sessions.compactMap { s in s.templateID.map { ($0, s.date) } }, uniquingKeysWith: max)
        return make(
            templates: templates, lastDone: lastDone, doneThisWeek: sessions.filter { $0.date >= thisWeek }.count,
            target: templates.count, now: now
        )
    }

    /// What the app tells the user it decided; nil when nothing is postponed.
    func note(names: [UUID: String]) -> SessionAdjustments.Note? {
        guard !postponed.isEmpty else { return nil }
        let late = postponed.compactMap { names[$0] }.joined(separator: ", ")
        return .init(
            id: "week-plan", symbol: "calendar.badge.clock",
            text: "Il reste \(daysLeft) jour\(daysLeft > 1 ? "s" : "") pour \(needed) séances : je commence par les plus en retard et je décale \(late) à la semaine prochaine."
        )
    }
}
