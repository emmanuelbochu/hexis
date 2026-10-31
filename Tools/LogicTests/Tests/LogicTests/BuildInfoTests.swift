import Foundation
import Testing
@testable import HexisLogic

@Suite struct BuildInfoTests {
    private let built = Date(timeIntervalSince1970: 1_793_450_400)

    @Test func aFreshBuildSaysItWasUpdated() {
        let label = BuildInfo.label(built: built, now: built.addingTimeInterval(3 * 3600))
        #expect(label.isFresh && label.text.hasPrefix("Mise à jour"))
    }

    @Test func anOlderBuildGivesItsDate() {
        let label = BuildInfo.label(built: built, now: built.addingTimeInterval(4 * 86_400))
        #expect(!label.isFresh && label.text.hasPrefix("Version du "))
    }
}
