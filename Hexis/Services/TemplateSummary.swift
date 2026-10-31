import Foundation

/// Pure stats of a workout template, for the program screens.
struct TemplateSummary: Equatable {
    var exerciseCount: Int
    var setCount: Int
    /// The real average of its last sessions (`DurationStats`), nil until known: never an estimate written in advance.
    var minutes: Int?
    var muscles: [String]

    /// " · ~50 min" once the duration is known, else nothing.
    var timeText: String { minutes.map { " · ~\($0) min" } ?? "" }

    init(_ template: WorkoutTemplate, exercises: [UUID: Exercise]) {
        let blocks = template.blocks.sorted { $0.order < $1.order }
        let items = blocks.flatMap(\.exercises)
        exerciseCount = items.count
        setCount = blocks.reduce(0) { $0 + Self.sets(in: $1) }
        var seen = Set<String>()
        muscles = items.compactMap { exercises[$0.exerciseID]?.muscleGroup }.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    /// Sets actually performed in a block (a superset does every exercise's sets, see `WorkoutPlanner`).
    static func sets(in block: TemplateBlock) -> Int {
        block.exercises.reduce(0) { $0 + $1.sets }
    }
}

enum WeekdayName {
    private static let names = ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]

    /// French name for a `Calendar` weekday (1 = Sunday), whatever the language of the phone.
    static func short(_ weekday: Int?) -> String? {
        guard let weekday, (1...7).contains(weekday) else { return nil }
        return names[weekday - 1]
    }
}
