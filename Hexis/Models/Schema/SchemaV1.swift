import SwiftData

/// Models are top-level types for now. When a `@Model` changes, freeze the
/// previous definitions inside a nested `SchemaV1` and add `SchemaV2`.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Exercise.self, Gym.self, ExerciseGymNote.self,
            Program.self, WorkoutTemplate.self, TemplateBlock.self, TemplateExercise.self,
            WorkoutSession.self, SetLog.self, AppSettings.self,
        ]
    }
}
