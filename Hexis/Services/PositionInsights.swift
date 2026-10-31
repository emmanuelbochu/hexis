import Foundation

/// Does an exercise go better early or late in the session? Compares its best e1RM in the first and in the last places.
enum PositionInsights {
    private static let minPerGroup = 3
    private static let minGap = 0.05

    static func insights(sessions: [WorkoutSession], sets: [SetLog], names: [UUID: String], limit: Int = 2) -> [Insights.Insight] {
        let finished = Set(sessions.filter { $0.state == .finished }.map(\.id))
        let work = sets.filter { finished.contains($0.sessionID) && $0.kind == .work && $0.weight > 0 }
        // exercise → (place in the session, best e1RM) per session
        var samples: [UUID: [(early: Bool, e1RM: Double)]] = [:]
        for (_, logs) in Dictionary(grouping: work, by: \.sessionID) {
            var order: [UUID] = []
            for log in logs.sorted(by: { $0.completedAt < $1.completedAt }) where !order.contains(log.exerciseID) { order.append(log.exerciseID) }
            guard order.count >= 4 else { continue }
            for (place, id) in order.enumerated() where place < 2 || place >= order.count - 2 {
                let best = logs.filter { $0.exerciseID == id }.map { Performance.e1RM(weight: $0.weight, reps: $0.reps) }.max() ?? 0
                samples[id, default: []].append((place < 2, best))
            }
        }
        let found = samples.compactMap { id, list -> (Insights.Insight, Double)? in
            let early = list.filter(\.early).map(\.e1RM), late = list.filter { !$0.early }.map(\.e1RM)
            guard early.count >= minPerGroup, late.count >= minPerGroup, let name = names[id] else { return nil }
            let e = early.reduce(0, +) / Double(early.count), l = late.reduce(0, +) / Double(late.count)
            guard l > 0, abs(e - l) / l >= minGap else { return nil }
            let percent = Int((abs(e - l) / l * 100).rounded())
            let text = e > l ? "\(name) : +\(percent) % de force quand tu le fais en début de séance." : "\(name) : +\(percent) % de force quand tu le fais en fin de séance."
            return (Insights.Insight(id: "position-\(id)", symbol: "list.number", text: text, sampleSize: early.count + late.count), abs(e - l) / l)
        }
        return found.sorted { $0.1 > $1.1 }.prefix(limit).map(\.0)
    }
}
