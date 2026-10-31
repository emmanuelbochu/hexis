import Foundation
import Testing
@testable import HexisLogic

/// Suggested weights land on weights the machine has, learned from what was typed on it.
@Suite struct WeightGridTests {
    /// Cable stack at 4.5 kg steps (36.5, 41, 45.5): going up from 41 gives 45.5, never « 43.5 ».
    @Test func goingUpTakesTheNextRealWeight() {
        let known = WeightGrid.known([41, 41, 36.5, 41, 45.5, 36.5])
        #expect(WeightGrid.snap(43.5, known: known, last: 41) == 45.5)
        #expect(WeightGrid.snap(41, known: known, last: 41) == 41)
        // Past the heaviest ever done: the same step on.
        #expect(WeightGrid.snap(47.5, known: known, last: 45.5) == 50)
    }

    /// Dumbbells by 2 kg seen at 10, 12 and 16: 14 exists too (the step fills the gaps); 30 and 40 only seen on a 2.5 kg
    /// machine: the 10 kg gap is not its step, the suggestion stays.
    @Test func gapsAreFilledAndAWideGapIsNotTrusted() {
        #expect(WeightGrid.snap(14, known: WeightGrid.known([10, 12, 16]), last: 16, maxStep: 2) == 14)
        #expect(WeightGrid.snap(13, known: WeightGrid.known([10, 12, 16]), last: 12, maxStep: 2) == 14)
        #expect(WeightGrid.snap(32.5, known: WeightGrid.known([30, 40]), last: 30, maxStep: 5) == 32.5)
    }

    @Test func goingDownTakesTheRealWeightBelow() {
        let known = WeightGrid.known([41, 45.5])
        #expect(WeightGrid.snap(39, known: known, last: 41) == 36.5)
    }

    /// A barbell loaded by 2.5 kg changes nothing; a single weight known or none leaves the suggestion as it is.
    @Test func fineSteppedOrUnknownStaysAsSuggested() {
        #expect(WeightGrid.snap(27.5, known: WeightGrid.known([20, 22.5, 25]), last: 25) == 27.5)
        #expect(WeightGrid.snap(43.5, known: WeightGrid.known([41]), last: 41) == 43.5)
        #expect(WeightGrid.snap(43.5, known: [], last: nil) == 43.5)
    }

    /// A typo (410 for 41) and zeros never enter the machine's weights.
    @Test func typosAndZerosAreLeftOut() {
        #expect(WeightGrid.known([41, 410, 0, 45.5, 41]) == [41, 45.5])
    }

    /// Her stack went 39, 45, 50, 54 and her dumbbells 15, 16, 17.5: uneven, so nothing is invented between the real weights
    /// (never a 47 or a 16.5), and beyond them the program's step.
    @Test func unevenMachinesOnlyOfferRealWeights() {
        let stack = WeightGrid.known([39, 45, 50, 54])
        #expect(!WeightGrid.isRegular(stack, step: 4))
        #expect(WeightGrid.snap(47.5, known: stack, last: 45, maxStep: 5) == 50)
        #expect(WeightGrid.snap(41.5, known: stack, last: 39, maxStep: 5) == 45)
        #expect(WeightGrid.snap(56.5, known: stack, last: 54, maxStep: 5) == 56.5)
        let dumbbells = WeightGrid.known([15, 16, 17.5])
        #expect(WeightGrid.snap(16.5, known: dumbbells, last: 16, maxStep: 5) == 17.5)
        // A one-off heavy set (72.5 among 35 and 40) is no step of the machine: the next goal stays near the last weight.
        let oneOff = [35.0, 40, 72.5]
        #expect(WeightGrid.snap(42.5, known: oneOff, last: 40, maxStep: 5) == 42.5)
    }
}

/// Her abduction machine (45 / 50 / 54 seen, range moved to 12–20, 3 reps in reserve): the goal came out at 39, 11 kg under what she lifts.
@Suite struct RampDropTests {
    @Test func movedRangeLandsNearTheComputedWeightNotTwoRoundingsBelow() throws {
        let last: [(weight: Double, reps: Int)] = [(45, 12), (50, 10), (50, 9)]
        let target = try #require(Progression.target(lastSets: last, repsMin: 12, repsMax: 20, step: 2.5, averageRPE: nil, targetRPE: 7))
        #expect(target.weight == 45, "e1RM says ≈ 44.4: the nearest step, not 42.5")
        let known = WeightGrid.known([45, 45, 45, 39, 45, 50, 54])
        #expect(WeightGrid.snap(target.weight, known: known, last: 50, maxStep: 5) == 45)
    }

    @Test func goingDownKeepsTheNearRealWeightWhenItIsBarelyAbove() {
        let known = WeightGrid.known([39, 45, 50, 54])
        #expect(WeightGrid.snap(44, known: known, last: 50, maxStep: 5) == 45, "+2 % over the target: the real weight, not 39")
        #expect(WeightGrid.snap(42.5, known: known, last: 50, maxStep: 5) == 39, "+6 %: a real step lighter is wanted")
    }
}
