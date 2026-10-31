import Foundation
import Testing
@testable import HexisLogic

@Suite struct UsageTests {
    private func freshDefaults() -> UserDefaults {
        let name = "usage-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func eachHitCountsAndKeepsTheLastDate() {
        let defaults = freshDefaults()
        let first = Date(timeIntervalSince1970: 1_000), second = Date(timeIntervalSince1970: 5_000)
        UsageCounter.hit(.analyse, now: first, defaults: defaults)
        UsageCounter.hit(.analyse, now: second, defaults: defaults)
        UsageCounter.hit(.pantry, now: first, defaults: defaults)
        let entries = UsageCounter.entries(defaults: defaults)
        #expect(entries[.analyse] == .init(count: 2, last: second))
        #expect(entries[.pantry]?.count == 1)
        #expect(entries[.gyms] == nil)
    }

    @Test func profilesAreCountedApart() {
        let defaults = freshDefaults()
        UsageCounter.hit(.analyse, profile: "a", defaults: defaults)
        #expect(UsageCounter.entries(profile: "b", defaults: defaults).isEmpty)
    }

    @Test func aRestoreNeverLowersACount() {
        let defaults = freshDefaults()
        let now = Date(timeIntervalSince1970: 9_000)
        UsageCounter.hit(.time, now: now, defaults: defaults)
        UsageCounter.hit(.time, now: now, defaults: defaults)
        UsageCounter.merge(["time": .init(count: 1, last: now), "gyms": .init(count: 4, last: now), "unknown": .init(count: 9, last: now)],
                           defaults: defaults)
        let entries = UsageCounter.entries(defaults: defaults)
        #expect(entries[.time]?.count == 2)
        #expect(entries[.gyms]?.count == 4)
        #expect(entries.count == 2)
    }
}
