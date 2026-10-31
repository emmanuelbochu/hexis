import Foundation

/// Deterministic dice (SplitMix64): a failing seed replays exactly the same life.
struct Dice: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func chance(_ p: Double) -> Bool { p > 0 && Double.random(in: 0..<1, using: &self) < p }
    mutating func between(_ range: ClosedRange<Double>) -> Double { Double.random(in: range, using: &self) }
}

/// How a person really uses the app: the messy parts the rules must survive.
struct Habits {
    var sessionsPerWeek = 4
    /// A planned session not done (busy day).
    var skip = 0.0
    /// Per week: one or two weeks off (trip, illness).
    var holiday = 0.0
    /// A set validated without touching the effort gauge.
    var noEffort = 0.0
    /// Weight typed ×10 by mistake (« 800 » for 80).
    var typo = 0.0
    /// « Fatigué » ticked at the start.
    var tired = 0.0
    /// « Gêne » ticked on one exercise.
    var pain = 0.0
    /// Leaves after about half the session and never closes it (the app must close it).
    var leaveEarly = 0.0
    /// Trains in the second gym that day.
    var otherGym = 0.0
    /// Does the exercises in another order (machine taken).
    var shuffle = 0.0
    /// Real strength gained per session on a trained exercise (0.004 = +0.4 %).
    var growth = 0.004
    /// From this week on the body stops progressing (plateau).
    var plateauFrom: Int?
}

/// A virtual person: a true strength per exercise, unknown to the app, that grows with training and fades without it.
struct Athlete {
    var habits: Habits
    var dice: Dice
    /// True one-rep max (Epley) per exercise and gym (machines differ between gyms).
    private(set) var strength: [String: Double] = [:]
    /// The weight first chosen when the app has no history yet.
    private(set) var everLoaded: Set<String> = []

    init(habits: Habits, seed: UInt64) {
        self.habits = habits
        dice = Dice(state: seed)
    }

    static func key(_ exercise: UUID, _ gym: UUID?) -> String { "\(exercise)-\(gym?.uuidString ?? "-")" }

    mutating func oneRepMax(_ key: String, step: Double) -> Double {
        if let known = strength[key] { return known }
        // Isolation moves (small steps) are lighter than compound ones.
        let value = step <= 1.25 ? dice.between(20...45) : dice.between(45...110)
        strength[key] = value
        return value
    }

    /// Reps possible at `weight` with `fatigue` (0 = fresh, 0.1 = 10 % weaker).
    mutating func capacity(_ key: String, weight: Double, step: Double, fatigue: Double) -> Double {
        let max = oneRepMax(key, step: step) * (1 - fatigue)
        return weight <= 0 ? 15 : Swift.max(0, 30 * (max / weight - 1))
    }

    /// The weight a person picks for an exercise the app knows nothing about yet: comfortable for the top of the range.
    mutating func firstWeight(_ key: String, repsMax: Int, step: Double) -> Double {
        everLoaded.insert(key)
        let weight = oneRepMax(key, step: step) / (1 + Double(repsMax + 2) / 30)
        return Swift.max(step, (weight / step).rounded(.down) * step)
    }

    /// The weight that would give the top of the range at the target effort: what a perfect coach would suggest.
    mutating func idealWeight(_ key: String, reps: Int, rir: Int, step: Double) -> Double {
        oneRepMax(key, step: step) / (1 + Double(reps + rir) / 30)
    }

    mutating func trained(_ key: String, week: Int) {
        if let from = habits.plateauFrom, week >= from { return }
        strength[key, default: 0] *= 1 + habits.growth * dice.between(0.5...1.5)
    }

    mutating func detrain(weeks: Int) {
        guard weeks >= 2 else { return }
        for key in strength.keys { strength[key]? *= pow(0.985, Double(weeks - 1)) }
    }
}
