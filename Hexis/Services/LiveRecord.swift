import Foundation

/// A real improvement while the session runs: a heavier weight than ever, or more reps than ever at that weight or above.
/// Judged against the exercise's whole earlier history (never the first time: nothing to beat) and the sets already done today,
/// so only the set that first reaches a new best gets the medal.
enum LiveRecord {
    enum Kind: Equatable {
        case weight, reps

        var text: String { self == .weight ? "Record de poids" : "Record de reps" }
    }

    struct Prior: Equatable {
        var weight: Double
        var reps: Int
    }

    static func kind(weight: Double, reps: Int, prior: [Prior]) -> Kind? {
        guard weight > 0, reps > 0, let top = prior.map(\.weight).max(), top > 0 else { return nil }
        if weight > top { return .weight }
        let best = prior.filter { $0.weight >= weight }.map(\.reps).max() ?? 0
        return reps > best ? .reps : nil
    }

    /// The medals of a list of done work sets, in order: `history` is what came before the session.
    static func medals(done sets: [(index: Int, weight: Double, reps: Int)], history: [Prior]) -> [Int: Kind] {
        guard !history.isEmpty else { return [:] }
        var prior = history
        var result: [Int: Kind] = [:]
        for set in sets {
            if let kind = kind(weight: set.weight, reps: set.reps, prior: prior) { result[set.index] = kind }
            prior.append(Prior(weight: set.weight, reps: set.reps))
        }
        return result
    }
}
