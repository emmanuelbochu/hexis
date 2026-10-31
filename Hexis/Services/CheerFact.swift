import Foundation

/// One thing worth a word of encouragement: what happened (in figures), when it can be said, and which line says it.
struct CheerFact: Equatable {
    enum Moment: String, CaseIterable {
        case milestone, record, weekDone, comeback, volumeUp, regular, streakAtRisk, progress
    }

    var moment: Moment
    /// Unique per occurrence: the same fact is never worded twice.
    var key: String
    /// Figures handed to the AI, nothing else.
    var facts: String
    /// The same figures for the local lines (`CheerPool`).
    var values: [String: String]
}

/// Which fact deserves a word, and when. Pure; the biggest fact wins, there is always one after a session and rarely one on Home.
enum CheerFacts {
    /// Sessions that mark a round number.
    static func isMilestone(_ count: Int) -> Bool { count == 10 || count == 25 || (count >= 50 && count % 50 == 0) }

    /// After a session: `sessionDates` holds every finished session, this one included.
    static func afterSession(
        sessionID: UUID, sessionDates: [Date], weeklyTarget: Int, records: [SessionReview.Record], volumeDelta: Double?, now: Date = .now
    ) -> CheerFact {
        let count = sessionDates.count
        let regularity = Regularity(sessionDates: sessionDates, weeklyTarget: weeklyTarget, now: now)
        let week = isoDay(WeekReview.weekStart(containing: now))
        let id = sessionID.uuidString
        if isMilestone(count) {
            return CheerFact(moment: .milestone, key: "milestone|\(count)", facts: "Séance n°\(count) depuis le début de l'app.", values: ["n": "\(count)"])
        }
        if let best = records.max(by: { gain($0) < gain($1) }) {
            let weight = kg(best.weight), before = kg(best.previous)
            var facts = "Record battu : \(best.name) à \(weight) kg (avant : \(before) kg)."
            if records.count > 1 { facts += " Plus \(records.count - 1) autre\(records.count > 2 ? "s" : "") record\(records.count > 2 ? "s" : "") dans la séance." }
            return CheerFact(moment: .record, key: "record|\(id)", facts: facts, values: ["name": best.name, "weight": weight, "previous": before])
        }
        if regularity.thisWeek == regularity.weeklyTarget {
            var facts = "Objectif de la semaine atteint : \(regularity.thisWeek)/\(regularity.weeklyTarget) séances."
            if regularity.streak >= 2 { facts += " \(regularity.streak) semaines d'affilée à l'objectif." }
            return CheerFact(
                moment: .weekDone, key: "week|\(week)", facts: facts,
                values: ["target": "\(regularity.weeklyTarget)", "streak": "\(regularity.streak >= 2 ? regularity.streak : 0)"]
            )
        }
        let dates = sessionDates.sorted()
        if dates.count >= 2, let gap = days(from: dates[dates.count - 2], to: dates[dates.count - 1]), gap >= 7 {
            return CheerFact(moment: .comeback, key: "comeback|\(id)", facts: "Reprise après \(gap) jours sans séance.", values: ["days": "\(gap)"])
        }
        if let delta = volumeDelta, delta >= 0.05 {
            let percent = "\(Int((delta * 100).rounded()))"
            return CheerFact(moment: .volumeUp, key: "volume|\(id)", facts: "Volume de la séance : +\(percent) % par rapport à la dernière fois.", values: ["pct": percent])
        }
        return CheerFact(
            moment: .regular, key: "regular|\(id)", facts: "Séance \(regularity.thisWeek) sur \(regularity.weeklyTarget) de la semaine, \(count) au total.",
            values: ["done": "\(regularity.thisWeek)", "target": "\(regularity.weeklyTarget)", "n": "\(count)"]
        )
    }

    /// On the Home screen, rarely: a return after a break, a streak at risk, a step of strength gained. Nil most days.
    static func onHome(sessionDates: [Date], weeklyTarget: Int, journey: Journey?, now: Date = .now) -> CheerFact? {
        guard let last = sessionDates.max() else { return nil }
        if let gap = days(from: last, to: now), gap >= 6 {
            return CheerFact(moment: .comeback, key: "back|\(isoDay(last))", facts: "Dernière séance il y a \(gap) jours.", values: ["days": "\(gap)"])
        }
        let regularity = Regularity(sessionDates: sessionDates, weeklyTarget: weeklyTarget, now: now)
        // Monday = 2 … Thursday = 5 in Calendar weekdays: from Thursday on, a missing session starts to matter.
        let weekday = WeekReview.calendar.component(.weekday, from: now)
        if regularity.streak >= 2, regularity.thisWeek < regularity.weeklyTarget, weekday == 1 || weekday >= 5 {
            let week = isoDay(WeekReview.weekStart(containing: now))
            return CheerFact(
                moment: .streakAtRisk, key: "risk|\(week)",
                facts: "\(regularity.streak) semaines d'affilée à l'objectif ; cette semaine \(regularity.thisWeek)/\(regularity.weeklyTarget) séances.",
                values: ["streak": "\(regularity.streak)", "done": "\(regularity.thisWeek)", "target": "\(regularity.weeklyTarget)"]
            )
        }
        if let strength = journey?.strength, let weeks = journey?.weeks {
            let step = Int((strength * 100 / 5).rounded(.down)) * 5
            if step >= 5 {
                return CheerFact(
                    moment: .progress, key: "progress|\(step)", facts: "Force estimée +\(step) % sur les \(weeks) dernières semaines (moyenne de ses exercices).",
                    values: ["pct": "\(step)", "weeks": "\(weeks)"]
                )
            }
        }
        return nil
    }

    private static func gain(_ record: SessionReview.Record) -> Double { record.previous > 0 ? record.weight / record.previous : record.weight }

    private static func kg(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...2))) }

    private static func days(from start: Date, to end: Date) -> Int? {
        let calendar = WeekReview.calendar
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: end)).day
    }

    static func isoDay(_ date: Date) -> String {
        let parts = WeekReview.calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
