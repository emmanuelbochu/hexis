import SwiftData

enum HexisMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV4.self, SchemaV5.self, SchemaV6.self, SchemaV7.self, SchemaV8.self, SchemaV9.self, SchemaV10.self, SchemaV11.self, SchemaV12.self, SchemaV13.self, SchemaV14.self, SchemaV15.self, SchemaV16.self]
    }
    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
            .lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self),
            .lightweight(fromVersion: SchemaV3.self, toVersion: SchemaV4.self),
            .lightweight(fromVersion: SchemaV4.self, toVersion: SchemaV5.self),
            .lightweight(fromVersion: SchemaV5.self, toVersion: SchemaV6.self),
            .lightweight(fromVersion: SchemaV6.self, toVersion: SchemaV7.self),
            .lightweight(fromVersion: SchemaV7.self, toVersion: SchemaV8.self),
            .lightweight(fromVersion: SchemaV8.self, toVersion: SchemaV9.self),
            .lightweight(fromVersion: SchemaV9.self, toVersion: SchemaV10.self),
            .lightweight(fromVersion: SchemaV10.self, toVersion: SchemaV11.self),
            .lightweight(fromVersion: SchemaV11.self, toVersion: SchemaV12.self),
            .lightweight(fromVersion: SchemaV12.self, toVersion: SchemaV13.self),
            .lightweight(fromVersion: SchemaV13.self, toVersion: SchemaV14.self),
            .lightweight(fromVersion: SchemaV14.self, toVersion: SchemaV15.self),
            .lightweight(fromVersion: SchemaV15.self, toVersion: SchemaV16.self),
        ]
    }
}
