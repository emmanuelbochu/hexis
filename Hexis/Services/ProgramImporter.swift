import Foundation
import SwiftData

/// JSON program format. Every field except names is optional.
struct ProgramSpec: Decodable {
    var name: String
    var workouts: [Workout]
    /// Muscles that may get one more set when they stall (see `SessionAdjuster`).
    var priorities: [String]?
    /// Weekly direct sets aimed at per muscle, [min, max].
    var volume: [String: [Int]]?
    var rehab: Rehab?
    /// Sessions of a week that can only hold 3 (`WeekRotation`), in order; empty = no variant.
    var shortWeek: [String]?
    /// First weeks of a cycle spent a notch easier (default 1), and the reps in reserve they ask for at least (default: one more than usual).
    var rampWeeks: Int?
    /// Training weeks before the deload week (default 5), and the reps in reserve the deload week asks for (default: the usual ones).
    var trainingWeeks: Int?
    var deloadRIR: Int?
    var rampRIR: Int?

    /// A rehab done in phases: each phase lasts `weeksPerPhase` clean weeks; a week with a pain flag sends it back one week.
    struct Rehab: Decodable {
        var name: String
        var weeksPerPhase: Int
        /// Exercises of each phase per slot of the workouts (a `rehab` block names its slot, e.g. "mollet").
        var phases: [[String: [Exercise]]]
    }

    struct Workout: Decodable {
        var name: String
        var blocks: [Block]
        /// Usual sessions this one stands in for in a 3-session week; non-empty = never proposed in a usual week.
        var replaces: [String]?
    }

    /// More than one exercise = superset. A `rehab` block holds the exercises of the current rehab phase for that slot.
    struct Block: Decodable {
        var rehab: String?
        var exercises: [Exercise]?
    }

    struct Exercise: Decodable {
        var name: String
        var muscleGroup: String
        var unilateral: Bool
        var sets: Int
        var repsMin: Int
        var repsMax: Int
        var rest: Int
        var rir: Int
        var tempo: String
        var step: Double
        /// How to do it, shown under the name.
        var cue: String
        /// "s" or "min" when the reps are a duration.
        var unit: String
        /// Load raised at most once a week (rehab: one plate a week).
        var weekly: Bool
        /// Applied once to the last weight when the exercise changes execution with a new program (slower tempo…).
        var loadFactor: Double
        /// Key facts shown in the exercise sheet of the Program screen ("Pourquoi : …", "Réglage : …", "Mouvement : …").
        var points: [String]
        /// Muscles named precisely in the exercise sheet ("Biceps (longue portion)"); `muscleGroup` stays the volume key.
        var target: String
        /// Former name: the stored exercise is renamed, so its history and last weights carry over.
        var renamedFrom: String
        /// Ramp-up sets written by the program, `[[% of the work weight, reps], …]` (« ~50 % ×6 » = `[0.5, 6]`). When a program
        /// writes any, only those exercises warm up; otherwise the app picks its own (`WorkoutPlanner`).
        var warmups: [[Double]]?
        /// Weight to start with in the very first session of the exercise, in the unit typed in the app (`StartWeight`).
        var start: Double?

        enum CodingKeys: String, CodingKey {
            case name, muscleGroup, unilateral, sets, repsMin, repsMax, rest, rir, tempo, step, cue, unit, weekly, loadFactor, points
            case target, renamedFrom, warmups, start
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = try c.decode(String.self, forKey: .name)
            muscleGroup = try c.decodeIfPresent(String.self, forKey: .muscleGroup) ?? ""
            unilateral = try c.decodeIfPresent(Bool.self, forKey: .unilateral) ?? false
            sets = try c.decodeIfPresent(Int.self, forKey: .sets) ?? 3
            repsMin = try c.decodeIfPresent(Int.self, forKey: .repsMin) ?? 8
            repsMax = try c.decodeIfPresent(Int.self, forKey: .repsMax) ?? repsMin
            rest = try c.decodeIfPresent(Int.self, forKey: .rest) ?? 90
            rir = try c.decodeIfPresent(Int.self, forKey: .rir) ?? 2
            tempo = try c.decodeIfPresent(String.self, forKey: .tempo) ?? ""
            step = try c.decodeIfPresent(Double.self, forKey: .step) ?? 2.5
            cue = try c.decodeIfPresent(String.self, forKey: .cue) ?? ""
            unit = try c.decodeIfPresent(String.self, forKey: .unit) ?? ""
            weekly = try c.decodeIfPresent(Bool.self, forKey: .weekly) ?? false
            loadFactor = try c.decodeIfPresent(Double.self, forKey: .loadFactor) ?? 1
            points = try c.decodeIfPresent([String].self, forKey: .points) ?? []
            target = try c.decodeIfPresent(String.self, forKey: .target) ?? ""
            renamedFrom = try c.decodeIfPresent(String.self, forKey: .renamedFrom) ?? ""
            warmups = try c.decodeIfPresent([[Double]].self, forKey: .warmups)
            start = try c.decodeIfPresent(Double.self, forKey: .start)
        }
    }
}

enum ProgramImporter {
    static func parse(_ data: Data) throws -> ProgramSpec {
        try JSONDecoder().decode(ProgramSpec.self, from: data)
    }

    /// Inserts the program and makes it the active one. Exercises are matched by name (case-insensitive);
    /// their muscle group follows the file. Every rehab exercise gets its record now so its history has a stable id.
    @discardableResult
    static func insert(_ spec: ProgramSpec, into context: ModelContext) throws -> Program {
        var known: [String: Exercise] = [:]
        for e in try context.fetch(FetchDescriptor<Exercise>()) { known[e.name.lowercased()] = e }
        let programs = try context.fetch(FetchDescriptor<Program>())
        // Same sessions (by name) as the active program, maybe plus new ones: updated in place, so past sessions keep their template.
        if let active = programs.first(where: \.isActive),
           Set(active.templates.map(\.name)).isSubset(of: Set(spec.workouts.map(\.name))),
           Set(active.templates.map(\.name)).count == active.templates.count {
            active.name = spec.name
            for e in spec.rehab?.phases.flatMap({ $0.values.flatMap { $0 } }) ?? [] { _ = exercise(e, known: &known, context: context) }
            for template in active.templates {
                guard let w = spec.workouts.first(where: { $0.name == template.name }) else { continue }
                template.blocks.forEach(context.delete)
                template.blocks = []
                addBlocks(w.blocks, rehab: spec.rehab, to: template, known: &known, context: context)
            }
            let existing = Set(active.templates.map(\.name))
            addWorkouts(spec.workouts.filter { !existing.contains($0.name) }, rehab: spec.rehab, to: active, known: &known, context: context)
            try context.save()
            return active
        }
        for p in programs { p.isActive = false }

        let program = Program(name: spec.name, isActive: true)
        context.insert(program)
        for e in spec.rehab?.phases.flatMap({ $0.values.flatMap { $0 } }) ?? [] { _ = exercise(e, known: &known, context: context) }
        addWorkouts(spec.workouts, rehab: spec.rehab, to: program, known: &known, context: context)
        try context.save()
        return program
    }

    private static func exercise(_ e: ProgramSpec.Exercise, known: inout [String: Exercise], context: ModelContext) -> Exercise {
        let key = e.name.lowercased()
        if known[key] == nil, !e.renamedFrom.isEmpty, let former = known.removeValue(forKey: e.renamedFrom.lowercased()) {
            former.name = e.name
            known[key] = former
        }
        if let found = known[key] {
            if !e.muscleGroup.isEmpty { found.muscleGroup = e.muscleGroup }
            found.isUnilateral = e.unilateral
            return found
        }
        let created = Exercise(name: e.name, muscleGroup: e.muscleGroup, isUnilateral: e.unilateral)
        context.insert(created)
        known[key] = created
        return created
    }

    private static func addWorkouts(
        _ workouts: [ProgramSpec.Workout], rehab: ProgramSpec.Rehab?, to program: Program, known: inout [String: Exercise], context: ModelContext
    ) {
        let firstOrder = (program.templates.map(\.order).max() ?? -1) + 1
        for (wi, w) in workouts.enumerated() {
            let template = WorkoutTemplate(name: w.name, weekday: nil, order: firstOrder + wi)
            context.insert(template)
            template.program = program
            addBlocks(w.blocks, rehab: rehab, to: template, known: &known, context: context)
        }
    }

    private static func addBlocks(
        _ blocks: [ProgramSpec.Block], rehab: ProgramSpec.Rehab?, to template: WorkoutTemplate, known: inout [String: Exercise], context: ModelContext
    ) {
        for (bi, b) in blocks.enumerated() {
            let block = TemplateBlock(order: bi)
            context.insert(block)
            block.template = template
            // A rehab slot is stored with its first phase; the session swaps in the current one (`Rehab`).
            let items = b.rehab.map { rehab?.phases.first?[$0] ?? [] } ?? b.exercises ?? []
            for (ei, e) in items.enumerated() {
                let record = exercise(e, known: &known, context: context)
                let item = TemplateExercise(
                    order: ei, exerciseID: record.id, sets: e.sets, repsMin: e.repsMin, repsMax: e.repsMax,
                    restSeconds: e.rest, targetRIR: e.rir, setupNotes: "", tempo: e.tempo,
                    progressionStep: e.step
                )
                context.insert(item)
                item.block = block
            }
        }
    }
}
