import SwiftData

/// V6 adds the nutrition plan: `Ingredient`, `PlanMeal`, `PlanMealLog`, `ShoppingCheck`, `BatchStep`.
enum SchemaV6: VersionedSchema {
    static var versionIdentifier = Schema.Version(6, 0, 0)

    static var models: [any PersistentModel.Type] {
        SchemaV5.models + [Ingredient.self, PlanMeal.self, PlanMealLog.self, ShoppingCheck.self, BatchStep.self]
    }
}
