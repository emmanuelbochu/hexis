import SwiftData

/// V9 adds `AIInsight` (cached coach texts).
enum SchemaV9: VersionedSchema {
    static var versionIdentifier = Schema.Version(9, 0, 0)

    static var models: [any PersistentModel.Type] {
        SchemaV8.models + [AIInsight.self]
    }
}
