import Foundation

/// Versioned, self-contained snapshot of all user data. Unknown JSON keys are ignored on decode.
nonisolated struct BackupDocument: Codable {
    static let currentVersion = 1

    var version: Int
    var exportedAt: Date
    var exercises: [ExerciseDTO]
    var gyms: [GymDTO]
    var gymNotes: [GymNoteDTO]
    var programs: [ProgramDTO]
    var sessions: [SessionDTO]
    var sets: [SetDTO]
    var settings: SettingsDTO?
    var preferences: PreferencesDTO?
    var sessionNotes: [SessionNoteDTO]
    var carryNotes: [CarryNoteDTO]
    var feelings: [FeelingDTO]
    var foodEntries: [FoodEntryDTO]
    var ingredients: [IngredientDTO]
    var planMeals: [PlanMealDTO]
    var planLogs: [PlanLogDTO]
    var shoppingChecks: [ShoppingCheckDTO]
    var batchSteps: [BatchStepDTO]
    var exerciseLoads: [ExerciseLoadDTO]
    var deloadWeeks: [DeloadWeekDTO]
    var purchases: [PurchaseDTO]
    var insights: [InsightDTO]
    var aliases: [AliasDTO]
    var extras: [ExtraDTO]
    var tweaks: [TweakDTO]
    var shoppingNotes: [ShoppingNoteDTO]
    var products: [ProductDTO]
    var offPlan: [OffPlanDTO]
    var flatStocks: [FlatStockDTO]

    init() {
        version = Self.currentVersion
        exportedAt = .now
        exercises = []
        gyms = []
        gymNotes = []
        programs = []
        sessions = []
        sets = []
        settings = nil
        preferences = nil
        sessionNotes = []
        carryNotes = []
        feelings = []
        foodEntries = []
        ingredients = []
        planMeals = []
        planLogs = []
        shoppingChecks = []
        batchSteps = []
        exerciseLoads = []
        deloadWeeks = []
        purchases = []
        insights = []
        aliases = []
        extras = []
        tweaks = []
        shoppingNotes = []
        products = []
        offPlan = []
        flatStocks = []
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        exportedAt = try c.decodeIfPresent(Date.self, forKey: .exportedAt) ?? .now
        exercises = try c.decodeIfPresent([ExerciseDTO].self, forKey: .exercises) ?? []
        gyms = try c.decodeIfPresent([GymDTO].self, forKey: .gyms) ?? []
        gymNotes = try c.decodeIfPresent([GymNoteDTO].self, forKey: .gymNotes) ?? []
        programs = try c.decodeIfPresent([ProgramDTO].self, forKey: .programs) ?? []
        sessions = try c.decodeIfPresent([SessionDTO].self, forKey: .sessions) ?? []
        sets = try c.decodeIfPresent([SetDTO].self, forKey: .sets) ?? []
        settings = try c.decodeIfPresent(SettingsDTO.self, forKey: .settings)
        preferences = try c.decodeIfPresent(PreferencesDTO.self, forKey: .preferences)
        sessionNotes = try c.decodeIfPresent([SessionNoteDTO].self, forKey: .sessionNotes) ?? []
        carryNotes = try c.decodeIfPresent([CarryNoteDTO].self, forKey: .carryNotes) ?? []
        feelings = try c.decodeIfPresent([FeelingDTO].self, forKey: .feelings) ?? []
        foodEntries = try c.decodeIfPresent([FoodEntryDTO].self, forKey: .foodEntries) ?? []
        ingredients = try c.decodeIfPresent([IngredientDTO].self, forKey: .ingredients) ?? []
        planMeals = try c.decodeIfPresent([PlanMealDTO].self, forKey: .planMeals) ?? []
        planLogs = try c.decodeIfPresent([PlanLogDTO].self, forKey: .planLogs) ?? []
        shoppingChecks = try c.decodeIfPresent([ShoppingCheckDTO].self, forKey: .shoppingChecks) ?? []
        batchSteps = try c.decodeIfPresent([BatchStepDTO].self, forKey: .batchSteps) ?? []
        exerciseLoads = try c.decodeIfPresent([ExerciseLoadDTO].self, forKey: .exerciseLoads) ?? []
        deloadWeeks = try c.decodeIfPresent([DeloadWeekDTO].self, forKey: .deloadWeeks) ?? []
        purchases = try c.decodeIfPresent([PurchaseDTO].self, forKey: .purchases) ?? []
        insights = try c.decodeIfPresent([InsightDTO].self, forKey: .insights) ?? []
        aliases = try c.decodeIfPresent([AliasDTO].self, forKey: .aliases) ?? []
        extras = try c.decodeIfPresent([ExtraDTO].self, forKey: .extras) ?? []
        tweaks = try c.decodeIfPresent([TweakDTO].self, forKey: .tweaks) ?? []
        shoppingNotes = try c.decodeIfPresent([ShoppingNoteDTO].self, forKey: .shoppingNotes) ?? []
        products = try c.decodeIfPresent([ProductDTO].self, forKey: .products) ?? []
        offPlan = try c.decodeIfPresent([OffPlanDTO].self, forKey: .offPlan) ?? []
        flatStocks = try c.decodeIfPresent([FlatStockDTO].self, forKey: .flatStocks) ?? []
    }

    struct ExerciseDTO: Codable {
        var id: UUID
        var name: String
        var muscleGroup: String
        var isUnilateral: Bool
    }

    struct GymDTO: Codable {
        var id: UUID
        var name: String
        var latitude: Double?
        var longitude: Double?
        var radius: Double
    }

    struct GymNoteDTO: Codable {
        var exerciseID: UUID
        var gymID: UUID
        var note: String
    }

    struct ProgramDTO: Codable {
        var id: UUID
        var name: String
        var isActive: Bool
        var templates: [TemplateDTO]
    }

    struct TemplateDTO: Codable {
        var id: UUID
        var name: String
        var weekday: Int?
        var order: Int
        var blocks: [BlockDTO]
    }

    struct BlockDTO: Codable {
        var order: Int
        var supersetRounds: Int?
        var extraSetsOfFirst: Int?
        var exercises: [TemplateExerciseDTO]
    }

    struct TemplateExerciseDTO: Codable {
        var order: Int
        var exerciseID: UUID
        var sets: Int
        var repsMin: Int
        var repsMax: Int
        var restSeconds: Int
        var targetRIR: Int
        var setupNotes: String
        var tempo: String
        var progressionStep: Double
    }

    struct SessionDTO: Codable {
        var id: UUID
        var date: Date
        var gymID: UUID?
        var templateID: UUID?
        var startedAt: Date
        var endedAt: Date?
        var state: String
    }

    struct SetDTO: Codable {
        var sessionID: UUID
        var exerciseID: UUID
        var gymID: UUID?
        var index: Int
        var kind: String
        var weight: Double
        var reps: Int
        var rir: Int?
        var completedAt: Date
        var side: String?
    }

    struct SessionNoteDTO: Codable {
        var sessionID: UUID
        var exerciseID: UUID?
        var text: String
        var hasPain: Bool
        var createdAt: Date
    }

    struct CarryNoteDTO: Codable {
        var exerciseID: UUID
        var sessionID: UUID
        var text: String
        var createdAt: Date
        var carrySessionID: UUID?
    }

    struct FeelingDTO: Codable {
        var sessionID: UUID
        var exerciseID: UUID
        var feeling: String
        var createdAt: Date
    }

    struct FoodEntryDTO: Codable {
        var id: UUID
        var date: Date
        var meal: String
        var name: String
        var kcal: Int
        var protein: Double
        var carbs: Double
        var fat: Double
    }

    struct IngredientDTO: Codable {
        var id: UUID
        var name: String
        var emoji: String
        var category: String
        var kcal: Double
        var protein: Double
        var carbs: Double
        var fat: Double
        var pieceGrams: Double
        var pieceLabel: String
        var packGrams: Double
        var packPrice: Double
        var stockGrams: Double
    }

    struct PlanMealDTO: Codable {
        var id: UUID
        var weekday: Int
        var slot: String
        var items: [PlanItem]
    }

    struct PlanLogDTO: Codable {
        var planMealID: UUID
        var day: Date
        var entryID: UUID
    }

    struct ShoppingCheckDTO: Codable {
        var ingredientID: UUID
        var cycleStart: Date
    }

    struct BatchStepDTO: Codable {
        var id: UUID
        var order: Int
        var title: String
        var detail: String
        var timerSeconds: Int
        var completedAt: Date?
    }

    struct ExerciseLoadDTO: Codable {
        var exerciseID: UUID
        var kind: String
        var baseWeight: Double
    }

    struct DeloadWeekDTO: Codable {
        var start: Date
        var reason: String
        var createdAt: Date
    }

    struct PurchaseDTO: Codable {
        var ingredientID: UUID
        var date: Date
        var grams: Double
        var price: Double
    }

    struct ShoppingNoteDTO: Codable {
        var emoji: String
        var name: String
        var quantity: String
        var cycleStart: Date
        var checked: Bool
        var createdAt: Date
    }

    struct FlatStockDTO: Codable {
        var ingredientID: UUID
        var grams: Double
        var updatedAt: Date
    }

    struct OffPlanDTO: Codable {
        var label: String
        var name: String
        var category: String
        var seen: Int
        var lastSeen: Date
    }

    struct ProductDTO: Codable {
        var label: String
        var ingredientID: UUID
        var unitGrams: Double
        var unitPrice: Double
        var seen: Int
        var lastSeen: Date
    }

    struct ExtraDTO: Codable {
        var label: String
        var category: String
        var price: Double
        var date: Date
    }

    struct TweakDTO: Codable {
        var exerciseID: UUID
        var gymID: UUID?
        var setsDelta: Int
        var repsShift: Int
        var since: Date
        var reason: String
    }

    struct AliasDTO: Codable {
        var label: String
        var ingredientID: UUID
        var createdAt: Date
    }

    struct InsightDTO: Codable {
        var kind: String
        var key: String
        var text: String
        var createdAt: Date
    }

    struct SettingsDTO: Codable {
        var useKilograms: Bool
        var unilateralRestSeconds: Int
        var warmupPercents: [Double]
    }
}
