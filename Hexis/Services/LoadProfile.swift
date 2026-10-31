import Foundation

/// Turns the typed weight of an exercise into the real load moved.
struct LoadProfile: Equatable {
    var kind: LoadKind
    var base: Double

    func effective(_ weight: Double) -> Double {
        switch kind {
        case .perSide: 2 * weight + base
        case .perHand: 2 * weight
        case .stack, .total: weight
        }
    }

    static let barbell = LoadProfile(kind: .perSide, base: 20)
    static let plateMachine = LoadProfile(kind: .perSide, base: 0)
    static let stack = LoadProfile(kind: .stack, base: 0)
    static let dumbbells = LoadProfile(kind: .perHand, base: 0)
    static let total = LoadProfile(kind: .total, base: 0)

    /// Presets offered in the exercise menu.
    static let presets: [(title: String, profile: LoadProfile)] = [
        ("Par côté · barre 20 kg", .barbell), ("Par côté · machine", .plateMachine),
        ("Poulie / stack", .stack), ("Par haltère", .dumbbells), ("Poids total", .total),
    ]

    /// Default by exercise name: the user types the weight of one side, except cables, machines with a stack and dumbbells.
    static func guess(name: String) -> LoadProfile {
        let text = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        func has(_ words: [String]) -> Bool { words.contains { text.contains($0) } }
        if has(["haltere", "dumbbell", "marteau", "rdl"]) { return .dumbbells }
        // Bodyweight or a plate held (rehab single leg, pistol, step-up, neck, ab wheel, bike): the weight typed is the total.
        if has(["1 jambe", "pistol", "marche", "nuque", "neck", "ab wheel", "velo"]) { return .total }
        // Selectorized-weight hip thrust machine: the number on the machine is the whole load, nothing per side.
        if has(["hip thrust machine"]) { return .total }
        // Loaded with plates (« chargé avec disques »), whatever the machine is called.
        if has(["disque"]) { return .plateMachine }
        if has(["poulie", "cable", "pec deck", "leg extension", "leg curl", "tirage", "corde", "face pull", "pulldown", "abduction", "adduction", "oiseau"]) { return .stack }
        // A plate-loaded machine (and the Smith, counterweighted) has no 20 kg bar, even named « hip thrust » or « squat ».
        if has(["machine", "smith"]) { return .plateMachine }
        if has(["barre", "squat", "souleve", "developpe couche", "hip thrust", "rowing", "military"]) { return .barbell }
        return .plateMachine
    }
}

struct LoadResolver {
    private let stored: [UUID: LoadProfile]
    private let names: [UUID: String]

    init(loads: [ExerciseLoad], exercises: [Exercise]) {
        stored = Dictionary(loads.map { ($0.exerciseID, LoadProfile(kind: $0.kind, base: $0.baseWeight)) }, uniquingKeysWith: { first, _ in first })
        names = Dictionary(exercises.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    func profile(_ exerciseID: UUID) -> LoadProfile {
        stored[exerciseID] ?? .guess(name: names[exerciseID] ?? "")
    }

    func effective(_ set: SetLog) -> Double { profile(set.exerciseID).effective(set.weight) }

    /// Tonnage of work sets with the real loads.
    func volume(_ sets: [SetLog]) -> Double {
        sets.filter { $0.kind == .work }.reduce(0) { $0 + effective($1) * Double($1.reps) }
    }
}
