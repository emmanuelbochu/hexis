import Foundation

/// When the phone should nudge her (Hexis Elle), and about what. Pure rules: only when it is needed (she is late on her week or
/// away), never two in a day, spaced out more and more, at the hour she usually trains minus two. Nothing on a week already done,
/// nothing the day after a session. The words come later (`NudgeService`).
enum NudgePlan {
    enum Kind: String, Equatable {
        /// A while without a session: the ladder of days since the last one.
        case absence
        /// This week's goal is still open on Thursday.
        case weekAtRisk
    }

    struct Slot: Equatable {
        var date: Date
        var kind: Kind
        /// Figures handed to the AI (and nothing else).
        var facts: String
    }

    /// Days after the last session at which an absence nudge goes out (a week of 2 sessions is never more than 4 days apart).
    static let ladder = [5, 8, 12, 17, 23, 30, 37, 44]
    /// Days after the install when no session was ever done.
    static let firstLadder = [2, 5, 9, 14, 20, 27, 35, 44]
    static let maxSlots = 8
    static let defaultHour = 17
    /// Minutes rotated so that the phone does not buzz at the same minute every time.
    static let minutes = [10, 40, 25, 5]

    /// The hour to nudge: two hours before the median start hour of her sessions, between 9 and 19.
    static func hour(sessionDates: [Date], calendar: Calendar = .current) -> Int {
        let hours = sessionDates.map { calendar.component(.hour, from: $0) }.sorted()
        guard !hours.isEmpty else { return defaultHour }
        return min(max(hours[hours.count / 2] - 2, 9), 19)
    }

    /// The weekday (1 = Sunday) she trains most, with at least 3 sessions behind it: her own habit, the best moment to ask.
    static func usualWeekday(sessionDates: [Date], calendar: Calendar = .current) -> Int? {
        let counts = Dictionary(grouping: sessionDates, by: { calendar.component(.weekday, from: $0) }).mapValues(\.count)
        guard sessionDates.count >= 3, let best = counts.max(by: { $0.value < $1.value }), best.value >= 2 else { return nil }
        return best.key
    }

    static func slots(sessionDates: [Date], weeklyTarget: Int, now: Date = .now, calendar: Calendar = .current) -> [Slot] {
        let hour = hour(sessionDates: sessionDates, calendar: calendar)
        func at(_ day: Date, index: Int) -> Date? {
            calendar.date(bySettingHour: hour, minute: minutes[index % minutes.count], second: 0, of: day)
        }
        let last = sessionDates.max()
        let usual = usualWeekday(sessionDates: sessionDates, calendar: calendar)
        let regularity = Regularity(sessionDates: sessionDates, weeklyTarget: weeklyTarget, now: now)
        let weekStart = WeekReview.weekStart(containing: now)
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? now
        let weekDone = regularity.thisWeek >= regularity.weeklyTarget
        var slots: [Slot] = []

        for (index, offset) in (last == nil ? firstLadder : ladder).enumerated() {
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: last ?? now)),
                  let date = at(day, index: index), date > now else { continue }
            // The week is already done: nothing to push until the next one starts.
            if weekDone, date < nextWeek { continue }
            var facts = last == nil ? "Elle n'a pas encore fait sa première séance." : "Dernière séance il y a \(offset) jours."
            if let usual, calendar.component(.weekday, from: date) == usual, let name = WeekdayName.short(usual) {
                facts += " C'est un de ses jours habituels (\(name))."
            }
            slots.append(Slot(date: date, kind: .absence, facts: facts))
        }
        if !weekDone, let thursday = calendar.date(byAdding: .day, value: 3, to: weekStart), let date = at(thursday, index: 1), date > now {
            let done = regularity.thisWeek
            slots.append(Slot(
                date: date, kind: .weekAtRisk,
                facts: "\(done) séance\(done > 1 ? "s" : "") sur \(regularity.weeklyTarget) cette semaine, on est jeudi."
            ))
        }
        return thinned(slots.sorted { $0.date < $1.date }, calendar: calendar)
    }

    /// One slot a day at most (the week reminder wins over an absence one), the first `maxSlots` only.
    static func thinned(_ slots: [Slot], calendar: Calendar = .current) -> [Slot] {
        var kept: [Slot] = []
        for slot in slots {
            if let index = kept.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: slot.date) }) {
                if slot.kind == .weekAtRisk { kept[index] = slot }
            } else {
                kept.append(slot)
            }
        }
        return Array(kept.sorted { $0.date < $1.date }.prefix(maxSlots))
    }
}
