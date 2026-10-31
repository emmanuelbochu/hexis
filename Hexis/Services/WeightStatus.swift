import Foundation

/// The scale in one glance for the Today screen: the 7-day average and whether the phase is on track.
struct WeightStatus: Equatable {
    /// Mean of the weigh-ins of the last 7 days (the latest weigh-in when there is none this week).
    var average: Double
    var perWeek: Double?
    var verdict: PhaseCheck.Verdict?
    var phase: NutritionPhase.Kind

    static func make(weights: [HealthService.Day], phase: NutritionPhase.Kind, now: Date = .now) -> WeightStatus? {
        let sorted = weights.filter { $0.date <= now }.sorted { $0.date < $1.date }
        guard let last = sorted.last else { return nil }
        let week = sorted.filter { $0.date > now.addingTimeInterval(-7 * 86_400) }
        let average = week.isEmpty ? last.value : week.reduce(0) { $0 + $1.value } / Double(week.count)
        let slope = BodyInsights.slope(weights: sorted, intake: [:], now: now)
        let range = PhaseCheck.range(for: phase)
        let verdict = slope.map { s -> PhaseCheck.Verdict in
            range.contains(s.kgPerWeek) ? .onTrack : s.kgPerWeek < range.lowerBound ? .tooSlow : .tooFast
        }
        return WeightStatus(average: average, perWeek: slope?.kgPerWeek, verdict: verdict, phase: phase)
    }
}
