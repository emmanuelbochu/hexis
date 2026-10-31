import Foundation

/// Where an exercise picture is looked up: an image set named `exo-<slug>` in `Assets.xcassets`; Hexis Elle looks first for her
/// own `elle-exo-<slug>` (drawn with a woman's figure in her accent, `HexisElle/Assets.xcassets`), then for his.
enum ExerciseImage {
    /// "Développé couché" → "exo-developpe-couche".
    static func assetName(for exerciseName: String) -> String {
        let folded = exerciseName.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()
        let slug = folded.split { !$0.isLetter && !$0.isNumber }.joined(separator: "-")
        return "exo-\(slug)"
    }

    /// The names to try, in order.
    static func assetNames(for exerciseName: String, elle: Bool = Edition.isElle) -> [String] {
        let name = assetName(for: exerciseName)
        return elle ? ["elle-\(name)", name] : [name]
    }
}
