import Foundation

/// Weekly direct sets per muscle against the program's targets (`volume` in `Program.json`): only what is off is worth showing.
enum VolumeCheck {
    struct Gap: Equatable {
        var muscle: String
        var sets: Int
        var range: ClosedRange<Int>
    }

    /// A week still running can only be over the target; a finished one also under it.
    static func gaps(setsByMuscle: [(muscle: String, sets: Int)], targets: [String: ClosedRange<Int>], weekIsOver: Bool) -> [Gap] {
        let done = Dictionary(setsByMuscle.map { ($0.muscle, $0.sets) }, uniquingKeysWith: +)
        return targets.compactMap { muscle, range in
            let sets = done[muscle] ?? 0
            guard sets > range.upperBound || (weekIsOver && sets < range.lowerBound) else { return nil }
            return Gap(muscle: muscle, sets: sets, range: range)
        }
        .sorted { $0.muscle < $1.muscle }
    }
}
