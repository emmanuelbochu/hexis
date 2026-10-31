import Foundation
import SwiftData

/// What the app changes by itself in the next session, from the real history (the program file is never edited).
struct SessionAdjustments: Equatable {
    struct Note: Identifiable, Equatable {
        var id: String
        var symbol: String
        var text: String
        /// The exercise concerned; nil for notes about the whole session.
        var exerciseID: UUID?
    }

    /// A lasting change kept in `ExerciseTweak`.
    struct Tweak: Equatable {
        var setsDelta = 0
        var repsShift = 0
        var since: Date
        var reason = ""
    }

    /// Seconds added to (or removed from) the rest after each set of an exercise.
    var restDelta: [UUID: Int] = [:]
    /// Kg added to (or removed from) the suggested weight of a stalled exercise.
    var shift: [UUID: Double] = [:]
    /// Sets added (plateau on a priority muscle) or removed (performance dropping) for this session.
    var setsDelta: [UUID: Int] = [:]
    /// Added to both ends of the rep range (plateau that resisted a lighter load).
    var repsShift: [UUID: Int] = [:]
    /// What `ExerciseTweak` should hold after this session starts (nil = no tweak).
    var tweaks: [UUID: Tweak?] = [:]
    /// Multiplier on the suggested weights after a long absence (1 = none).
    var weightFactor = 1.0
    /// Added to every target RIR (first week of a cycle).
    var rirDelta = 0
    /// Reps in reserve asked for at least (first weeks of a program that spells it out); nil = `rirDelta` only.
    var rirFloor: Int?
    var isDeload = false
    var rehab: Rehab.Status?
    var notes: [Note] = []

    static let none = SessionAdjustments()
}

/// Rules, all bounded and explained (the « i » of the exercise, « Séance ajustée » on the home screen):
/// - cycle: first week +1 RIR; deload week (6th) same loads, half the sets; after 8 days off −5 %, after 15 days −10 %;
/// - rests (exercises done alone; a superset's other exercise is its rest) start from the rest really taken (median of the
///   last 3 sessions) and move 15 s with the reps lost between the first and the last set: ≥ 25 % lost → +15 s, ≤ 10 % → −15 s,
///   never under 60 s (90 s for heavy work), never over 90 s (150 s for heavy work);
/// - plateau (`StagnationDetector`), one step at a time, each left 3 sessions to work: low effort → +1 step;
///   priority muscle with a good recovery → +1 set (kept, never past the weekly target); otherwise → about −5 %
///   to climb the reps again; still stuck after that → rep range moved by 2 (heavy) or 4 for 12 weeks (new stimulus);
/// - performance dropping (2 sessions 7 % under the recent best at the same effort) or « Fatigué » twice → the added set goes, else −1 set;
/// - plateau while the scale says the bulk is too slow → nothing changes, the plan feeds more first;
/// - « Gêne » → nothing is pushed.
enum SessionAdjuster {
    typealias Tweak = SessionAdjustments.Tweak
    static let restStep = 15
    static let minRest = 60
    private static let minHeavyRest = 90
    private static let maxRest = 90
    private static let maxHeavyRest = 150
    /// Reps lost between the first and the last set, as a share of the first (above: rest more; below: rest less).
    private static let bigLoss = 0.25
    private static let smallLoss = 0.10
    private static let secondsPerRep = 3.5
    private static let sessionsNeeded = 3
    /// Most sets one muscle gets in a single session (Pelland 2024, Remmert 2025: beyond it, little gain).
    private static let maxSessionSets = 11
    /// e1RM loss over the last 2 sessions that counts as a drop (beyond the day-to-day noise of ~3-5 %).
    static let dropThreshold = 0.07
    /// How long a moved rep range lasts (2 cycles).
    static let repsShiftWeeks = 12

    struct PlanItem {
        var id: UUID
        var name: String
        var muscle = ""
        var sets = 3
        var repsMin = 8
        var repsMax = 12
        var rest: Int
        var step: Double
        var priority = false
        /// One more set fits the block (alone, first of a superset, or a second one doing fewer sets than the first).
        var canAddSet = true
        /// Done alone (not in a superset): its rest can be measured and tuned.
        var alone = true
        /// Sets of its muscle in this session, tweaks included.
        var sessionSets = 0
        /// Weekly sets of its muscle in the program, tweaks included.
        var weeklySets = 0
        var maxWeeklySets: Int?
    }

    /// `sets` are the work sets of these exercises in this gym, deload weeks and the running session excluded.
    static func compute(
        plan: [PlanItem], sets: [SetLog], feelings: [ExerciseFeeling] = [], tweaks: [UUID: Tweak] = [:],
        isDeload: Bool, isRestart: Bool = false, daysAway: Int = 0, underfed: Bool = false, rampRIR: Int? = ProgramCatalog.rampRIR, deloadRIR: Int? = ProgramCatalog.deloadRIR, now: Date = .now
    ) -> SessionAdjustments {
        var result = SessionAdjustments()
        result.isDeload = isDeload
        if !isDeload, daysAway >= 8 {
            result.weightFactor = daysAway >= 15 ? 0.9 : 0.95
            result.notes.append(.init(id: "away", symbol: "arrow.counterclockwise", text: "Reprise après \(daysAway) jours : charges −\(daysAway >= 15 ? 10 : 5) %."))
        }
        if isDeload {
            result.rirFloor = deloadRIR
            result.notes.append(.init(
                id: "deload", symbol: "arrow.down.right",
                text: "Semaine de déload : mêmes charges, moitié des séries" + (deloadRIR.map { ", \($0) reps en réserve." } ?? ".")
            ))
        } else if isRestart, let floor = rampRIR {
            result.rirFloor = floor
            result.notes.append(.init(id: "restart", symbol: "arrow.clockwise", text: "Début de cycle : \(floor) reps en réserve partout, le temps de caler les charges."))
        } else if isRestart {
            result.rirDelta = 1
            result.notes.append(.init(id: "restart", symbol: "arrow.clockwise", text: "1re semaine du cycle : 1 rep de plus en réserve (RIR +1)."))
        }
        let byExercise = Dictionary(grouping: sets.filter { $0.kind == .work }, by: \.exerciseID)
        let sessionWide = feelings.filter(\.isSessionWide)
        let feelingsByExercise = Dictionary(grouping: feelings, by: \.exerciseID)
        for item in plan {
            let logs = byExercise[item.id] ?? []
            let sessions = recentSessions(logs)
            if sessions.count >= sessionsNeeded, let target = restTarget(item, sessions: sessions), target != item.rest {
                result.restDelta[item.id] = target - item.rest
                let why = target > item.rest ? "tu perds trop de reps entre la 1re et la dernière série" : "tu reprends plus vite que prévu sans perdre trop de reps"
                result.notes.append(.init(id: "rest-\(item.id)", symbol: "timer", text: "\(item.name) : repos \(clock(item.rest)) → \(clock(target)), \(why).", exerciseID: item.id))
            }
            let perfs = Performance.sessions(sets: logs, feelings: (feelingsByExercise[item.id] ?? []) + sessionWide)
            plateau(item, perfs: perfs, sessions: sessions, tweak: tweaks[item.id], isDeload: isDeload, underfed: underfed, now: now, into: &result)
        }
        return result
    }

    /// The plateau ladder of one exercise, and the lasting tweak it leaves.
    private static func plateau(
        _ item: PlanItem, perfs: [SessionPerf], sessions: [[SetLog]], tweak: Tweak?, isDeload: Bool, underfed: Bool, now: Date,
        into result: inout SessionAdjustments
    ) {
        var kept = tweak
        func note(_ symbol: String, _ text: String) {
            result.notes.append(.init(id: "shift-\(item.id)-\(symbol)", symbol: symbol, text: "\(item.name) : \(text)", exerciseID: item.id))
        }
        defer {
            if let kept, kept.setsDelta != 0 || kept.repsShift != 0 {
                result.tweaks[item.id] = kept
                if kept.setsDelta != 0 { result.setsDelta[item.id, default: 0] += kept.setsDelta }
                if kept.repsShift != 0 { result.repsShift[item.id] = kept.repsShift }
            } else if tweak != nil {
                result.tweaks[item.id] = .some(nil)
            }
        }
        // A moved range lasts two cycles, then the plan's range comes back.
        if let current = kept, current.repsShift != 0,
           now.timeIntervalSince(current.since) > Double(repsShiftWeeks * 7 * 86_400) {
            kept?.repsShift = 0
            note("arrow.uturn.backward", "retour à la fourchette du programme (\(item.repsMin)–\(item.repsMax) reps).")
        }
        guard !isDeload, perfs.count >= StagnationDetector.minSessions else { return }

        // Dropping performance or repeated fatigue: less volume first.
        let recentFeelings = perfs.suffix(3).compactMap(\.feeling)
        // A session marked tired says nothing about the trend: it is left out of drops and plateaus.
        let steady = perfs.filter { $0.feeling != .tired }
        // Weaker at an effort at least as high (a lighter load on purpose, or a calmer day, is not a drop).
        let earlier = steady.dropLast(2).suffix(4)
        let before = earlier.map(\.e1RM).max() ?? 0
        let effortBefore = mean(earlier.compactMap(\.avgRPE))
        // A session without an effort entered proves nothing: it never counts as a drop.
        let dropping = before > 0 && steady.count >= 4 && steady.suffix(2).allSatisfy {
            guard let effort = $0.avgRPE else { return false }
            return $0.e1RM < before * (1 - dropThreshold) && effort >= (effortBefore ?? 0)
        }
        if recentFeelings.contains(.pain) { return }
        if dropping || recentFeelings.filter({ $0 == .tired }).count >= 2 {
            let why = dropping ? "perfs en baisse sur 2 séances" : "fatigué 2 séances sur 3"
            if (kept?.setsDelta ?? 0) > 0 {
                kept?.setsDelta = 0
                note("minus.circle", "série ajoutée retirée, \(why).")
            } else if item.sets >= 3 {
                result.setsDelta[item.id, default: 0] -= 1
                note("minus.circle", "\(item.sets - 1) séries au lieu de \(item.sets), \(why) : tu récupères mieux avec moins.")
            }
            return
        }

        if let current = kept, current.setsDelta != 0 || current.repsShift != 0 {
            note(current.repsShift != 0 ? "arrow.left.and.right" : "plus.circle", current.reason)
        }
        // Each change gets 3 sessions to work before the next one.
        let sinceTweak = kept.map { change in steady.filter { $0.date >= change.since }.count } ?? .max
        guard sinceTweak >= 3, let finding = StagnationDetector.finding(exerciseID: item.id, perfs: steady) else { return }
        let date = now.formatted(.dateTime.day().month(.abbreviated))
        // Weight under the bulk's pace: the plan feeds more first (`PlanAutoAdjust`), the session is not reshaped around it.
        if underfed, finding.advice == .change {
            note("fork.knife", "plateau avec un poids sous la cible : l'alimentation monte d'abord, la séance ne change pas.")
            return
        }
        switch finding.advice {
        case .checkPain:
            return
        case .increase:
            guard item.step > 0, stillAtTop(sessions) else { return }
            result.shift[item.id] = item.step
            note("arrow.up.right", "charge +\(item.step.formatted()) kg, tu stagnes avec un effort modéré.")
        case .change where item.priority && item.canAddSet && (kept?.setsDelta ?? 0) == 0
            && item.weeklySets + 1 <= (item.maxWeeklySets ?? .max) && item.sessionSets + 1 <= maxSessionSets:
            let reason = "\(item.sets + 1) séries au lieu de \(item.sets) depuis le \(date) : plateau de \(finding.sessions) séances avec une bonne récup, muscle prioritaire."
            kept = Tweak(setsDelta: 1, repsShift: kept?.repsShift ?? 0, since: now, reason: reason)
            note("plus.circle", reason)
        case .change, .deload:
            if item.step > 0, stillAtTop(sessions), let top = sessions.first.flatMap(topWeight) {
                let drop = max(item.step, (top * 0.05 / item.step).rounded() * item.step)
                result.shift[item.id] = -drop
                note("arrow.down.right", "charge −\(drop.formatted()) kg, tu stagnes depuis \(finding.sessions) séances ; tu remontes les reps depuis un peu plus bas.")
            } else if (kept?.repsShift ?? 0) == 0, finding.sessions >= 6 || item.step == 0 {
                // Higher ranges go down (heavier), the others go up: either way a new stimulus at the same effort.
                let shift = item.repsMax >= 15 ? -4 : (item.repsMax <= 8 ? 2 : 4)
                let low = max(item.repsMin + shift, 4), high = min(item.repsMax + shift, 30)
                let reason = "\(low)–\(high) reps au lieu de \(item.repsMin)–\(item.repsMax) depuis le \(date) : plateau de \(finding.sessions) séances malgré la charge plus basse. Pendant \(repsShiftWeeks) semaines."
                kept = Tweak(setsDelta: kept?.setsDelta ?? 0, repsShift: shift, since: now, reason: reason)
                note("arrow.left.and.right", reason)
            }
        }
    }

    /// Sets of each session, most recent session first.
    private static func recentSessions(_ sets: [SetLog]) -> [[SetLog]] {
        Dictionary(grouping: sets, by: \.sessionID).values
            .sorted { ($0.map(\.completedAt).max() ?? .distantPast) > ($1.map(\.completedAt).max() ?? .distantPast) }
    }

    /// Rest to prescribe for an exercise done alone: the rest really taken, moved by the reps lost; nil without enough data.
    private static func restTarget(_ item: PlanItem, sessions: [[SetLog]]) -> Int? {
        guard item.alone else { return nil }
        let recent = sessions.prefix(sessionsNeeded)
        let losses = recent.compactMap(repsLoss)
        let rests = recent.compactMap { restTaken($0, item: item) }
        guard losses.count >= 2, rests.count >= 2 else { return nil }
        let loss = losses.reduce(0, +) / Double(losses.count)
        var target = Int((rests.sorted()[rests.count / 2] / Double(restStep)).rounded()) * restStep
        let heavy = item.repsMax <= 8
        // Many reps lost: never less rest than prescribed. Few lost: shorter.
        // A hair of tolerance: three losses of exactly 10 % average to 0.10000000000000002.
        if loss >= bigLoss - 1e-9 { target = max(target + restStep, item.rest) } else if loss <= smallLoss + 1e-9 { target -= restStep }
        let floor = heavy ? minHeavyRest : minRest
        return min(max(target, floor), max(heavy ? maxHeavyRest : maxRest, item.rest))
    }

    /// The heaviest weight of a session without its typos (an extra zero: 350 for 35): a plateau must not cut 5 % of a typo.
    static func topWeight(_ sets: [SetLog]) -> Double? {
        Progression.withoutTypos(sets.map { (weight: $0.weight, reps: $0.reps) }).map(\.weight).max()
    }

    /// Share of the first set's reps lost by the last set, at the heaviest weight; nil under 3 such sets.
    private static func repsLoss(_ session: [SetLog]) -> Double? {
        guard let top = topWeight(session) else { return nil }
        let reps = session.filter { $0.weight == top && $0.side != .left }.sorted { $0.index < $1.index }.map(\.reps)
        guard reps.count >= 3, let first = reps.first, let last = reps.last, first > 0 else { return nil }
        return Double(first - last) / Double(first)
    }

    /// Median rest really taken in one session (gap between sets minus the set itself); machine taken or a pause is ignored.
    private static func restTaken(_ session: [SetLog], item: PlanItem) -> Double? {
        let timeline = SessionTimeline(sets: session)
        guard timeline.isReliable, let gaps = timeline.entries.first?.restSeconds else { return nil }
        let set = Double((item.repsMin + item.repsMax) / 2) * secondsPerRep
        let rests = gaps.filter { $0 <= Double(item.rest) * 2 + 60 }.map { $0 - set }.filter { $0 > 0 }.sorted()
        return rests.count >= 2 ? rests[rests.count / 2] : nil
    }

    /// True while the last session is still at the best weight of the recent ones (no back-off done yet).
    private static func stillAtTop(_ sessions: [[SetLog]]) -> Bool {
        let tops = sessions.prefix(4).map { topWeight($0) ?? 0 }
        guard let last = tops.first, let best = tops.max() else { return false }
        return last >= best
    }

    private static func mean(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    private static func clock(_ seconds: Int) -> String { String(format: "%d:%02d", seconds / 60, seconds % 60) }
}
