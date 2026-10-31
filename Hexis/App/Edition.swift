import Foundation

/// Which app this build is: « Hexis » (Muscu + Alimentation) or « Hexis Elle » (target `HexisElle`, flag `ELLE`: Muscu only,
/// no Apple Health, one usual gym found by GPS, no gym picker).
enum Edition {
    static let isElle: Bool = {
        #if ELLE
        true
        #else
        false
        #endif
    }()

    static var hasNutrition: Bool { !isElle }
    /// Body weight and steps come from Apple Health: only in the original app.
    static var usesHealth: Bool { !isElle }
    static var hasGymPicker: Bool { !isElle }
}
