import Foundation

/// Words for each point of the 1–10 effort gauge (RPE), with the matching reps in reserve.
enum EffortScale {
    /// Hexis Elle's way to say the effort: how many more reps she could have done (each is an effort 10 → 7 behind the scenes).
    static let simple: [(label: String, rpe: Int)] = [
        ("Aucune de plus", 10), ("1 de plus", 9), ("2 de plus", 8), ("3 de plus ou plus", 7),
    ]

    /// The option an effort lands on (the nearest, 3 or more being the easiest one).
    static func simpleIndex(_ rpe: Int) -> Int { min(max(10 - rpe, 0), 3) }

    static func title(_ rpe: Int) -> String {
        switch rpe {
        case ...2: "Très facile"
        case 3...4: "Facile"
        case 5: "Modéré"
        case 6: "Soutenu"
        case 7: "Costaud"
        case 8: "Intense"
        case 9: "Presque max"
        default: "Max"
        }
    }

    /// The target effort as each app says it: "RIR 2" (his), "reste +2" (hers: the reps she could still do, like her sets show).
    static func target(rir: Int, elle: Bool = Edition.isElle) -> String { elle ? "reste +\(rir)" : "RIR \(rir)" }

    /// A mean effort: "RPE 8.4" (his), "reste +1.6" (hers).
    static func average(rpe: Double, elle: Bool = Edition.isElle) -> String {
        elle ? String(format: "reste +%.1f", max(0, 10 - rpe)) : String(format: "RPE %.1f", rpe)
    }

    /// Reps left in the tank at this effort.
    static func detail(_ rpe: Int) -> String {
        switch rpe {
        case ...5: "Beaucoup de marge"
        case 10: "Rien en réserve"
        case 9: "1 rep en réserve"
        default: "\(10 - rpe) reps en réserve"
        }
    }
}
