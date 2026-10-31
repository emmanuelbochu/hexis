import Foundation
import Testing
@testable import HexisLogic

@Suite struct DiagnosticsTests {
    private func freshDefaults() -> UserDefaults {
        let name = "diagnostics-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func theJournalKeepsOnlyTheNewestEntries() {
        let defaults = freshDefaults()
        for i in 0..<(Diagnostics.limit + 30) {
            Diagnostics.record(.geminiFailed, "n\(i)", now: Date(timeIntervalSince1970: Double(i)), defaults: defaults)
        }
        let entries = Diagnostics.entries(defaults: defaults)
        #expect(entries.count == Diagnostics.limit)
        #expect(entries.first?.detail == "n30")
        #expect(entries.last?.detail == "n\(Diagnostics.limit + 29)")
    }

    @Test func aRestoreAddsOnlyWhatIsMissing() {
        let defaults = freshDefaults()
        let shared = Date(timeIntervalSince1970: 100)
        Diagnostics.record(.saveFailed, "a", now: shared, defaults: defaults)
        Diagnostics.merge([.init(date: shared, kind: .saveFailed, detail: "a"),
                           .init(date: Date(timeIntervalSince1970: 50), kind: .slowLaunch, detail: "b")], defaults: defaults)
        let entries = Diagnostics.entries(defaults: defaults)
        #expect(entries.map(\.detail) == ["b", "a"])
    }

    @Test func profilesAreSeparate() {
        let defaults = freshDefaults()
        Diagnostics.record(.slowLaunch, profile: "a", defaults: defaults)
        #expect(Diagnostics.entries(profile: "b", defaults: defaults).isEmpty)
    }

    @Test func aNonFiniteValueIsReplacedAndTraced() {
        let before = Diagnostics.entries().count
        #expect(Diagnostics.finite(.nan, fallback: 5, "test") == 5)
        #expect(Diagnostics.finite(.infinity, "test") == 0)
        #expect(Diagnostics.finite(42.5, "test") == 42.5)
        #expect(Diagnostics.entries().count >= min(before + 2, Diagnostics.limit))
        UserDefaults.standard.removeObject(forKey: "diagnostics.default")
    }
}
