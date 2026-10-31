import Foundation

/// What the bundled `Program.json` says beyond the stored templates: cues, units, priority muscles, weekly volume targets, rehab phases.
/// Read once; the file is the source of truth (it ships with the build, like the templates `ProgramSync` stores).
enum ProgramCatalog {
    /// The file read (the logic tests point it at the repo's copy, his or hers: changing it reads the new file).
    static var fileURL = Bundle.main.url(forResource: "Program", withExtension: "json") {
        didSet { loaded = nil }
    }
    static var spec: ProgramSpec? { catalog.spec }

    private static var loaded: (spec: ProgramSpec?, byName: [String: ProgramSpec.Exercise])?
    private static var catalog: (spec: ProgramSpec?, byName: [String: ProgramSpec.Exercise]) {
        if let loaded { return loaded }
        let spec = fileURL.flatMap { try? Data(contentsOf: $0) }.flatMap { try? ProgramImporter.parse($0) }
        let result = (spec, index(spec))
        loaded = result
        return result
    }

    /// Every exercise of the file by lowercased name (rehab included); the first non-empty cue wins.
    private static var byName: [String: ProgramSpec.Exercise] { catalog.byName }

    private static func index(_ spec: ProgramSpec?) -> [String: ProgramSpec.Exercise] {
        guard let spec else { return [:] }
        let all = spec.workouts.flatMap { $0.blocks.flatMap { $0.exercises ?? [] } } + rehabExercises(of: spec)
        var result: [String: ProgramSpec.Exercise] = [:]
        for e in all {
            let key = e.name.lowercased()
            if let found = result[key] {
                if found.cue.isEmpty, !e.cue.isEmpty { result[key]?.cue = e.cue }
            } else {
                result[key] = e
            }
        }
        return result
    }

    static var rehab: ProgramSpec.Rehab? { spec?.rehab }

    /// The program writes its own ramp-up sets (some exercise has `warmups`): the others get none.
    static var writesWarmups: Bool { spec?.workouts.contains { $0.blocks.contains { ($0.exercises ?? []).contains { $0.warmups != nil } } } ?? false }

    /// First weeks of each cycle done a notch easier, and the floor of reps in reserve they ask for (nil = one more than usual).
    static var rampWeeks: Int { max(spec?.rampWeeks ?? 1, 1) }
    static var rampRIR: Int? { spec?.rampRIR }
    static var trainingWeeks: Int { max(spec?.trainingWeeks ?? 5, 2) }
    static var deloadRIR: Int? { spec?.deloadRIR }

    /// Sessions of a 3-session week, in order (empty when the file has no variant).
    static var shortWeek: [String] { spec?.shortWeek ?? [] }

    /// Usual sessions a 3-session-week session stands in for (empty for a usual session).
    static func replaces(_ workout: String) -> [String] {
        spec?.workouts.first { $0.name == workout }?.replaces ?? []
    }

    /// The templates of a usual week (the 3-session-only ones left out).
    static func usualWeek(_ templates: [WorkoutTemplate]) -> [WorkoutTemplate] {
        templates.filter { replaces($0.name).isEmpty }
    }

    /// The week a template belongs to, for its weekly sets: the 3-session variant for its own sessions, else the usual week.
    static func week(of template: WorkoutTemplate, in templates: [WorkoutTemplate]) -> [WorkoutTemplate] {
        guard !replaces(template.name).isEmpty else { return usualWeek(templates) }
        return templates.filter { shortWeek.contains($0.name) }
    }

    static var rehabExercises: [ProgramSpec.Exercise] { rehabExercises(of: spec) }

    private static func rehabExercises(of spec: ProgramSpec?) -> [ProgramSpec.Exercise] {
        spec?.rehab?.phases.flatMap { phase in phase.keys.sorted().flatMap { phase[$0] ?? [] } } ?? []
    }

    static func exercise(named name: String) -> ProgramSpec.Exercise? { byName[name.lowercased()] }

    static func isPriority(muscle: String) -> Bool { spec?.priorities?.contains(muscle) ?? false }

    /// Weekly direct sets aimed at, per muscle.
    static var weeklyTargets: [String: ClosedRange<Int>] {
        (spec?.volume ?? [:]).compactMapValues { $0.count == 2 && $0[0] <= $0[1] ? $0[0]...$0[1] : nil }
    }

    /// Upper bound of the weekly sets aimed at for a muscle (an added set never goes past it).
    static func maxWeeklySets(muscle: String) -> Int? {
        spec?.volume?[muscle].flatMap { $0.count == 2 ? $0[1] : nil }
    }
}
