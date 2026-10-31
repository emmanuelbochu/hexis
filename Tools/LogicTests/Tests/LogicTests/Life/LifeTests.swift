import Foundation
import Testing
@testable import HexisLogic

/// Real-life scenarios lived with the real app (`LifeSimulator`). Several seeds each; `HEXIS_SEEDS=n` runs more.
/// A failure prints the seed, the week, the session and the exercise: replay it with that seed alone.
/// His lives run in the usual pass, hers in the ELLE one (`HEXIS_EDITION=elle`): each app with its own program file.
@Suite(.serialized) struct LifeTests {
    static let seeds: [UInt64] = Array(1...UInt64(ProcessInfo.processInfo.environment["HEXIS_SEEDS"].flatMap(Int.init) ?? 3))

    /// Lives the scenario for every seed; returns the stats of each life.
    @MainActor
    private func live(_ name: String, weeks: Int, _ habits: Habits, program: URL = LifeSimulator.appProgramFile) async throws -> [LifeSimulator.Stats] {
        var all: [LifeSimulator.Stats] = []
        for seed in Self.seeds {
            let sim = try LifeSimulator(habits: habits, seed: seed, program: program)
            await sim.live(weeks: weeks)
            // Same finding every week: shown once, with how often it came back.
            var seen: [String: (first: String, count: Int)] = [:]
            var order: [String] = []
            for line in sim.violations {
                let what = line.components(separatedBy: " · ").dropFirst().joined(separator: " · ")
                if seen[what] == nil { order.append(what); seen[what] = (line, 0) }
                seen[what]?.count += 1
            }
            if !order.isEmpty {
                let lines = order.prefix(12).map { "  \(seen[$0]?.first ?? $0)\((seen[$0]?.count ?? 1) > 1 ? " (×\(seen[$0]?.count ?? 1))" : "")" }
                Issue.record("\(name) · graine \(seed) :\n\(lines.joined(separator: "\n"))")
            }
            let st = sim.stats
            let ratio = median(st.ratios).formatted(.number.precision(.fractionLength(2)))
            print("life · \(name) · graine \(seed) : \(st.sessions) séances, \(st.workSets) séries, \(st.overshoots) trop lourdes, charge/idéale \(ratio), \(st.deloads) déloads, \(st.forgotten) oubliées fermées")
            all.append(st)
        }
        return all
    }

    private func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        return sorted.isEmpty ? 1 : sorted[sorted.count / 2]
    }

    #if !ELLE
    @Test @MainActor func steadyHalfYear() async throws {
        for stats in try await live("Régulier 4×/sem", weeks: 26, Habits()) {
            #expect(stats.sessions >= 90)
            #expect(stats.deloads >= 3, "un déload toutes les 6 semaines attendu, \(stats.deloads) en 26 semaines")
            #expect(Double(stats.overshoots) < Double(stats.workSets) * 0.03, "charges trop lourdes : \(stats.overshoots)/\(stats.workSets)")
            let m = median(stats.ratios)
            #expect((0.8...1.1).contains(m), "charge proposée / charge idéale : médiane \(m)")
        }
    }

    @Test @MainActor func messyRealLife() async throws {
        let habits = Habits(
            skip: 0.2, holiday: 0.08, noEffort: 0.25, typo: 0.03, tired: 0.1, pain: 0.05,
            leaveEarly: 0.08, otherGym: 0.25, shuffle: 0.3
        )
        for stats in try await live("Vie réelle désordonnée", weeks: 30, habits) {
            #expect(Double(stats.overshoots) < Double(stats.workSets) * 0.06, "charges trop lourdes : \(stats.overshoots)/\(stats.workSets)")
            #expect(stats.forgotten > 0 || habits.leaveEarly == 0)
        }
    }

    @Test @MainActor func stuckBody() async throws {
        for stats in try await live("Plateau dès S6", weeks: 24, Habits(plateauFrom: 6)) {
            #expect(Double(stats.overshoots) < Double(stats.workSets) * 0.08, "l'app pousse un corps bloqué : \(stats.overshoots)/\(stats.workSets)")
            #expect(median(stats.ratios) < 1.15)
        }
    }

    @Test @MainActor func twoSessionsAWeek() async throws {
        for stats in try await live("2 séances/sem", weeks: 16, Habits(sessionsPerWeek: 2, skip: 0.1)) {
            #expect(stats.sessions >= 20)
        }
    }

    #else
    // MARK: Hexis Elle (her program: 2 sessions A/B, 6 training weeks, 2 ramp weeks at 3 reps in reserve)

    @Test @MainActor func herSteadyHalfYear() async throws {
        for stats in try await live("Elle · régulière 2×/sem", weeks: 26, Habits(sessionsPerWeek: 2)) {
            #expect(stats.sessions >= 48)
            // 6 training weeks + 1 deload (~4 in 26 weeks); plateaus may bring one forward by 2 weeks at most, never every 4 weeks.
            #expect((3...5).contains(stats.deloads), "un déload toutes les 5 à 7 semaines attendu, \(stats.deloads) en 26 semaines")
            #expect(Double(stats.overshoots) < Double(stats.workSets) * 0.03, "charges trop lourdes : \(stats.overshoots)/\(stats.workSets)")
            let m = median(stats.ratios)
            #expect((0.8...1.1).contains(m), "charge proposée / charge idéale : médiane \(m)")
        }
    }

    @Test @MainActor func herMessyRealLife() async throws {
        let habits = Habits(
            sessionsPerWeek: 2, skip: 0.25, holiday: 0.1, noEffort: 0.35, typo: 0.03, tired: 0.12, pain: 0.05,
            leaveEarly: 0.1, otherGym: 0.1, shuffle: 0.3
        )
        for stats in try await live("Elle · vie réelle désordonnée", weeks: 30, habits) {
            #expect(Double(stats.overshoots) < Double(stats.workSets) * 0.06, "charges trop lourdes : \(stats.overshoots)/\(stats.workSets)")
            #expect(stats.sessions >= 25)
        }
    }
    #endif
}
