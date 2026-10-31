import Foundation

/// What an exercise picture shows, guessed from the exercise name: the muscle worked and the kind of equipment.
struct ExerciseVisual: Equatable {
    enum Muscle { case chest, shoulders, rearDelts, traps, lats, biceps, triceps, abs, quads, hamstrings, glutes, calves, neck }
    enum Equipment { case stackMachine, plateMachine, cable, smith, dumbbell, barbell, bodyweight }

    var muscle: Muscle
    var equipment: Equipment

    /// Rear muscles are drawn on the back of the figure.
    var showsBack: Bool {
        [.rearDelts, .traps, .lats, .triceps, .glutes, .hamstrings, .calves, .neck].contains(muscle)
    }

    static func guess(name: String) -> ExerciseVisual {
        let text = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()
        func has(_ words: String...) -> Bool { words.contains { text.contains($0) } }
        return ExerciseVisual(muscle: muscle(has), equipment: equipment(has))
    }

    private static func muscle(_ has: (String...) -> Bool) -> Muscle {
        if has("neck") { return .neck }
        if has("shrug") { return .traps }
        if has("triceps", "skull") { return .triceps }
        if has("leg curl", "ischio", "rdl") { return .hamstrings }
        if has("leg extension", "squat", "fente", "presse a cuisses") { return .quads }
        if has("mollet") { return .calves }
        if has("abduction", "hip thrust", "fessier") { return .glutes }
        if has("ab wheel", "pallof", "crunch", "gainage") { return .abs }
        if has("oiseau", "face pull") { return .rearDelts }
        if has("elevation", "epaule", "militaire") { return .shoulders }
        if has("curl") { return .biceps }
        if has("tirage", "rowing", "pull-over", "pull over") { return .lats }
        return .chest
    }

    private static func equipment(_ has: (String...) -> Bool) -> Equipment {
        if has("smith") { return .smith }
        if has("haltere", "rdl") { return .dumbbell }
        if has("poulie", "corde", "face pull", "pallof") { return .cable }
        if has("ab wheel", "1 jambe", "pistol", "marche") { return .bodyweight }
        if has("presse", "convergent") { return .plateMachine }
        if has("barre", "squat", "souleve") { return .barbell }
        return .stackMachine
    }
}
