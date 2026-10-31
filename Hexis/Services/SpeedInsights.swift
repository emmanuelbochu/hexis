import Foundation

/// When (and where) sessions go fastest: duration against the usual duration of the same session, by gym and time of day.
enum SpeedInsights {
    private enum Slot: Int, CaseIterable {
        case morning, midday, afternoon, evening

        init(hour: Int) {
            switch hour {
            case ..<10: self = .morning
            case 10..<14: self = .midday
            case 14..<18: self = .afternoon
            default: self = .evening
            }
        }

        var label: String { ["le matin", "le midi", "l'après-midi", "le soir"][rawValue] }
    }

    private struct Sample {
        var gymID: UUID?
        var slot: Slot
        /// 1.0 = the usual duration of this session; below 1 = faster.
        var index: Double
    }

    /// A slot needs this many sessions to be compared, and the gap this size to be worth saying.
    private static let minPerSlot = 3
    private static let minGap = 0.08

    static func insights(sessions: [WorkoutSession], gymNames: [UUID: String]) -> [Insights.Insight] {
        let samples = self.samples(sessions)
        var found: [Insights.Insight] = []
        for gymID in Set(samples.compactMap(\.gymID)) {
            let name = (gymNames[gymID] ?? "").replacingOccurrences(of: "Basic-Fit ", with: "")
            if let line = compare(samples.filter { $0.gymID == gymID }, id: "speed-\(gymID)", place: name.isEmpty ? "cette salle" : "à \(name)") {
                found.append(line)
            }
        }
        if let line = compare(samples, id: "speed-all", place: "en général") { found.append(line) }
        return found
    }

    /// Said on the home screen when the usual slot of right now is clearly slower than another one (needs 3 sessions each).
    static func advice(sessions: [WorkoutSession], now: Date = .now) -> SessionAdjustments.Note? {
        let byslot = Dictionary(grouping: samples(sessions), by: \.slot).filter { $0.value.count >= minPerSlot }
            .mapValues { (mean: $0.reduce(0) { $0 + $1.index } / Double($0.count), count: $0.count) }
        let current = Slot(hour: Calendar.current.component(.hour, from: now))
        guard let here = byslot[current], let best = byslot.min(by: { $0.value.mean < $1.value.mean }),
              best.key != current, here.mean - best.value.mean >= 0.1
        else { return nil }
        let percent = Int(((1 - best.value.mean / here.mean) * 100).rounded())
        return .init(
            id: "speed", symbol: "speedometer",
            text: "Tes séances sont \(percent) % plus courtes \(best.key.label) (\(best.value.count + here.count) séances) : à privilégier quand tu peux."
        )
    }

    private static func compare(_ samples: [Sample], id: String, place: String) -> Insights.Insight? {
        let byslot = Dictionary(grouping: samples, by: \.slot).filter { $0.value.count >= minPerSlot }
            .mapValues { (mean: $0.reduce(0) { $0 + $1.index } / Double($0.count), count: $0.count) }
        guard byslot.count >= 2, let best = byslot.min(by: { $0.value.mean < $1.value.mean }),
              let worst = byslot.max(by: { $0.value.mean < $1.value.mean }), worst.value.mean - best.value.mean >= minGap
        else { return nil }
        let percent = Int(((1 - best.value.mean / worst.value.mean) * 100).rounded())
        return Insights.Insight(
            id: id, symbol: "speedometer",
            text: "Tu vas plus vite \(best.key.label) \(place) : séances \(percent) % plus courtes que \(worst.key.label).",
            sampleSize: best.value.count + worst.value.count
        )
    }

    /// Finished sessions between 15 min and 3 h, as a ratio to the median of their template (needs 4 sessions of it).
    private static func samples(_ sessions: [WorkoutSession]) -> [Sample] {
        let timed = sessions.compactMap { session -> (WorkoutSession, Double)? in
            guard session.state == .finished, session.templateID != nil, let end = session.endedAt else { return nil }
            let minutes = end.timeIntervalSince(session.startedAt) / 60
            return (15...180).contains(minutes) ? (session, minutes) : nil
        }
        let byTemplate = Dictionary(grouping: timed, by: { $0.0.templateID })
        return byTemplate.values.filter { $0.count >= 4 }.flatMap { group -> [Sample] in
            let median = group.map(\.1).sorted()[group.count / 2]
            return group.map { session, minutes in
                Sample(
                    gymID: session.gymID, slot: Slot(hour: Calendar.current.component(.hour, from: session.startedAt)),
                    index: minutes / median
                )
            }
        }
    }
}
