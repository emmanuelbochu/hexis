import Foundation
import SwiftData

/// Writes and restores the JSON backup of the whole database (`BackupDocument`).
enum BackupError: LocalizedError {
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let v): "Version de sauvegarde non supportée (\(v))."
        }
    }
}

nonisolated enum BackupService {
    static func makeDocument(from context: ModelContext) throws -> BackupDocument {
        var doc = BackupDocument()
        doc.exercises = try context.fetch(FetchDescriptor<Exercise>()).map {
            .init(id: $0.id, name: $0.name, muscleGroup: $0.muscleGroup, isUnilateral: $0.isUnilateral)
        }
        doc.gyms = try context.fetch(FetchDescriptor<Gym>()).map {
            .init(id: $0.id, name: $0.name, latitude: $0.latitude, longitude: $0.longitude, radius: $0.radius)
        }
        doc.gymNotes = try context.fetch(FetchDescriptor<ExerciseGymNote>()).map {
            .init(exerciseID: $0.exerciseID, gymID: $0.gymID, note: $0.note)
        }
        doc.programs = try context.fetch(FetchDescriptor<Program>()).map { programDTO($0) }
        doc.sessions = try context.fetch(FetchDescriptor<WorkoutSession>()).map {
            .init(
                id: $0.id, date: $0.date, gymID: $0.gymID, templateID: $0.templateID,
                startedAt: $0.startedAt, endedAt: $0.endedAt, state: $0.stateRaw
            )
        }
        doc.sets = try context.fetch(FetchDescriptor<SetLog>()).map {
            .init(
                sessionID: $0.sessionID, exerciseID: $0.exerciseID, gymID: $0.gymID, index: $0.index,
                kind: $0.kindRaw, weight: $0.weight, reps: $0.reps, rir: $0.rir,
                completedAt: $0.completedAt, side: $0.sideRaw
            )
        }
        doc.settings = try context.fetch(FetchDescriptor<AppSettings>()).first.map {
            .init(
                useKilograms: $0.useKilograms, unilateralRestSeconds: $0.unilateralRestSeconds,
                warmupPercents: $0.warmupPercents
            )
        }
        doc.preferences = BackupPreferences.read()
        doc.sessionNotes = try context.fetch(FetchDescriptor<SessionNote>()).map {
            .init(sessionID: $0.sessionID, exerciseID: $0.exerciseID, text: $0.text, hasPain: $0.hasPain, createdAt: $0.createdAt)
        }
        doc.carryNotes = try context.fetch(FetchDescriptor<CarryNote>()).map {
            .init(exerciseID: $0.exerciseID, sessionID: $0.sessionID, text: $0.text, createdAt: $0.createdAt, carrySessionID: $0.carrySessionID)
        }
        doc.feelings = try context.fetch(FetchDescriptor<ExerciseFeeling>()).map {
            .init(sessionID: $0.sessionID, exerciseID: $0.exerciseID, feeling: $0.feelingRaw, createdAt: $0.createdAt)
        }
        doc.foodEntries = try context.fetch(FetchDescriptor<FoodEntry>()).map {
            .init(id: $0.id, date: $0.date, meal: $0.mealRaw, name: $0.name, kcal: $0.kcal, protein: $0.protein, carbs: $0.carbs, fat: $0.fat)
        }
        doc.ingredients = try context.fetch(FetchDescriptor<Ingredient>()).map {
            .init(
                id: $0.id, name: $0.name, emoji: $0.emoji, category: $0.category, kcal: $0.kcal, protein: $0.protein,
                carbs: $0.carbs, fat: $0.fat, pieceGrams: $0.pieceGrams, pieceLabel: $0.pieceLabel,
                packGrams: $0.packGrams, packPrice: $0.packPrice, stockGrams: $0.stockGrams
            )
        }
        doc.planMeals = try context.fetch(FetchDescriptor<PlanMeal>()).map {
            .init(id: $0.id, weekday: $0.weekday, slot: $0.slotRaw, items: $0.items)
        }
        doc.planLogs = try context.fetch(FetchDescriptor<PlanMealLog>()).map {
            .init(planMealID: $0.planMealID, day: $0.day, entryID: $0.entryID)
        }
        doc.shoppingChecks = try context.fetch(FetchDescriptor<ShoppingCheck>()).map {
            .init(ingredientID: $0.ingredientID, cycleStart: $0.cycleStart)
        }
        doc.batchSteps = try context.fetch(FetchDescriptor<BatchStep>()).map {
            .init(id: $0.id, order: $0.order, title: $0.title, detail: $0.detail, timerSeconds: $0.timerSeconds, completedAt: $0.completedAt)
        }
        doc.exerciseLoads = try context.fetch(FetchDescriptor<ExerciseLoad>()).map {
            .init(exerciseID: $0.exerciseID, kind: $0.kindRaw, baseWeight: $0.baseWeight)
        }
        doc.deloadWeeks = try context.fetch(FetchDescriptor<DeloadWeek>()).map {
            .init(start: $0.start, reason: $0.reason, createdAt: $0.createdAt)
        }
        doc.purchases = try context.fetch(FetchDescriptor<PurchaseLog>()).map {
            .init(ingredientID: $0.ingredientID, date: $0.date, grams: $0.grams, price: $0.price)
        }
        doc.shoppingNotes = try context.fetch(FetchDescriptor<ShoppingNote>()).map {
            .init(emoji: $0.emoji, name: $0.name, quantity: $0.quantity, cycleStart: $0.cycleStart, checked: $0.checked, createdAt: $0.createdAt)
        }
        doc.flatStocks = try context.fetch(FetchDescriptor<FlatStock>()).map {
            .init(ingredientID: $0.ingredientID, grams: $0.grams, updatedAt: $0.updatedAt)
        }
        doc.offPlan = try context.fetch(FetchDescriptor<OffPlanProduct>()).map {
            .init(label: $0.label, name: $0.name, category: $0.category, seen: $0.seen, lastSeen: $0.lastSeen)
        }
        doc.products = try context.fetch(FetchDescriptor<ProductMemory>()).map {
            .init(label: $0.label, ingredientID: $0.ingredientID, unitGrams: $0.unitGrams, unitPrice: $0.unitPrice, seen: $0.seen, lastSeen: $0.lastSeen)
        }
        doc.extras = try context.fetch(FetchDescriptor<ExtraPurchase>()).map {
            .init(label: $0.label, category: $0.category, price: $0.price, date: $0.date)
        }
        doc.tweaks = try context.fetch(FetchDescriptor<ExerciseTweak>()).map {
            .init(exerciseID: $0.exerciseID, gymID: $0.gymID, setsDelta: $0.setsDelta, repsShift: $0.repsShift, since: $0.since, reason: $0.reason)
        }
        doc.aliases = try context.fetch(FetchDescriptor<ReceiptAlias>()).map {
            .init(label: $0.label, ingredientID: $0.ingredientID, createdAt: $0.createdAt)
        }
        doc.insights = try context.fetch(FetchDescriptor<AIInsight>()).map {
            .init(kind: $0.kind, key: $0.key, text: $0.text, createdAt: $0.createdAt)
        }
        return doc
    }

    static func exportData(from context: ModelContext) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(makeDocument(from: context))
    }

    /// Replaces ALL existing data with the content of the backup.
    static func restore(_ data: Data, into context: ModelContext, snapshotFirst: Bool = true) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let doc = try decoder.decode(BackupDocument.self, from: data)
        guard doc.version <= BackupDocument.currentVersion else {
            throw BackupError.unsupportedVersion(doc.version)
        }
        // Restoring replaces everything: keep what is there until the new data is in.
        if snapshotFirst { AutoBackup.save(from: context) }

        try deleteAll(Exercise.self, in: context)
        try deleteAll(Gym.self, in: context)
        try deleteAll(ExerciseGymNote.self, in: context)
        try deleteAll(Program.self, in: context)
        try context.delete(model: WorkoutSession.self)
        try context.delete(model: SetLog.self)
        try deleteAll(AppSettings.self, in: context)
        try context.delete(model: SessionNote.self)
        try deleteAll(CarryNote.self, in: context)
        try context.delete(model: ExerciseFeeling.self)
        try context.delete(model: FoodEntry.self)
        try deleteAll(Ingredient.self, in: context)
        try deleteAll(PlanMeal.self, in: context)
        try context.delete(model: PlanMealLog.self)
        try deleteAll(ShoppingCheck.self, in: context)
        try deleteAll(BatchStep.self, in: context)
        try deleteAll(ExerciseLoad.self, in: context)
        try deleteAll(DeloadWeek.self, in: context)
        try context.delete(model: PurchaseLog.self)
        try context.delete(model: AIInsight.self)
        try deleteAll(ReceiptAlias.self, in: context)
        try deleteAll(ExtraPurchase.self, in: context)
        try deleteAll(ProductMemory.self, in: context)
        try deleteAll(OffPlanProduct.self, in: context)
        try deleteAll(FlatStock.self, in: context)
        try deleteAll(ShoppingNote.self, in: context)
        try deleteAll(ExerciseTweak.self, in: context)
        try context.save()

        for e in doc.exercises {
            context.insert(Exercise(id: e.id, name: e.name, muscleGroup: e.muscleGroup, isUnilateral: e.isUnilateral))
        }
        for g in doc.gyms {
            context.insert(Gym(id: g.id, name: g.name, latitude: g.latitude, longitude: g.longitude, radius: g.radius))
        }
        for n in doc.gymNotes {
            context.insert(ExerciseGymNote(exerciseID: n.exerciseID, gymID: n.gymID, note: n.note))
        }
        for p in doc.programs { insertProgram(p, into: context) }
        for s in doc.sessions {
            let session = WorkoutSession(id: s.id, date: s.date, gymID: s.gymID, templateID: s.templateID)
            session.startedAt = s.startedAt
            session.endedAt = s.endedAt
            session.stateRaw = s.state
            context.insert(session)
        }
        for s in doc.sets {
            let log = SetLog(
                sessionID: s.sessionID, exerciseID: s.exerciseID, gymID: s.gymID, index: s.index,
                weight: s.weight, reps: s.reps, rir: s.rir, completedAt: s.completedAt
            )
            log.kindRaw = s.kind
            log.sideRaw = s.side
            context.insert(log)
        }
        if let s = doc.settings {
            context.insert(AppSettings(
                useKilograms: s.useKilograms, unilateralRestSeconds: s.unilateralRestSeconds,
                warmupPercents: s.warmupPercents
            ))
        }
        for n in doc.sessionNotes {
            context.insert(SessionNote(
                sessionID: n.sessionID, exerciseID: n.exerciseID, text: n.text, hasPain: n.hasPain, createdAt: n.createdAt
            ))
        }
        for n in doc.carryNotes {
            context.insert(CarryNote(
                exerciseID: n.exerciseID, sessionID: n.sessionID, text: n.text, createdAt: n.createdAt, carrySessionID: n.carrySessionID
            ))
        }
        for f in doc.feelings {
            let entry = ExerciseFeeling(sessionID: f.sessionID, exerciseID: f.exerciseID, feeling: .good, createdAt: f.createdAt)
            entry.feelingRaw = f.feeling
            context.insert(entry)
        }
        for f in doc.foodEntries {
            let entry = FoodEntry(
                id: f.id, date: f.date, meal: .snack, name: f.name,
                kcal: f.kcal, protein: f.protein, carbs: f.carbs, fat: f.fat
            )
            entry.mealRaw = f.meal
            context.insert(entry)
        }
        for i in doc.ingredients {
            context.insert(Ingredient(
                id: i.id, name: i.name, emoji: i.emoji, category: i.category, kcal: i.kcal, protein: i.protein,
                carbs: i.carbs, fat: i.fat, pieceGrams: i.pieceGrams, pieceLabel: i.pieceLabel,
                packGrams: i.packGrams, packPrice: i.packPrice, stockGrams: i.stockGrams
            ))
        }
        for m in doc.planMeals {
            let meal = PlanMeal(id: m.id, weekday: m.weekday, slot: .snack, items: m.items)
            meal.slotRaw = m.slot
            context.insert(meal)
        }
        for l in doc.planLogs { context.insert(PlanMealLog(planMealID: l.planMealID, day: l.day, entryID: l.entryID)) }
        for c in doc.shoppingChecks { context.insert(ShoppingCheck(ingredientID: c.ingredientID, cycleStart: c.cycleStart)) }
        for l in doc.exerciseLoads {
            let load = ExerciseLoad(exerciseID: l.exerciseID, kind: .total, baseWeight: l.baseWeight)
            load.kindRaw = l.kind
            context.insert(load)
        }
        for p in doc.purchases { context.insert(PurchaseLog(ingredientID: p.ingredientID, date: p.date, grams: p.grams, price: p.price)) }
        for e in doc.extras { context.insert(ExtraPurchase(label: e.label, category: e.category, price: e.price, date: e.date)) }
        for f in doc.flatStocks { context.insert(FlatStock(ingredientID: f.ingredientID, grams: f.grams, updatedAt: f.updatedAt)) }
        for o in doc.offPlan { context.insert(OffPlanProduct(label: o.label, name: o.name, category: o.category, seen: o.seen, lastSeen: o.lastSeen)) }
        for m in doc.products {
            context.insert(ProductMemory(label: m.label, ingredientID: m.ingredientID, unitGrams: m.unitGrams, unitPrice: m.unitPrice, seen: m.seen, lastSeen: m.lastSeen))
        }
        for n in doc.shoppingNotes {
            context.insert(ShoppingNote(emoji: n.emoji, name: n.name, quantity: n.quantity, cycleStart: n.cycleStart, checked: n.checked, createdAt: n.createdAt))
        }
        for t in doc.tweaks {
            context.insert(ExerciseTweak(exerciseID: t.exerciseID, gymID: t.gymID, setsDelta: t.setsDelta, repsShift: t.repsShift, since: t.since, reason: t.reason))
        }
        for a in doc.aliases { context.insert(ReceiptAlias(label: a.label, ingredientID: a.ingredientID, createdAt: a.createdAt)) }
        for i in doc.insights { context.insert(AIInsight(kind: i.kind, key: i.key, text: i.text, createdAt: i.createdAt)) }
        for d in doc.deloadWeeks { context.insert(DeloadWeek(start: d.start, reason: d.reason, createdAt: d.createdAt)) }
        for s in doc.batchSteps {
            context.insert(BatchStep(
                id: s.id, order: s.order, title: s.title, detail: s.detail,
                timerSeconds: s.timerSeconds, completedAt: s.completedAt
            ))
        }
        try context.save()
        if let prefs = doc.preferences { BackupPreferences.apply(prefs) }
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
        for item in try context.fetch(FetchDescriptor<T>()) { context.delete(item) }
    }

    private static func programDTO(_ p: Program) -> BackupDocument.ProgramDTO {
        .init(
            id: p.id, name: p.name, isActive: p.isActive,
            templates: p.templates.sorted { $0.order < $1.order }.map { t in
                .init(
                    id: t.id, name: t.name, weekday: t.weekday, order: t.order,
                    blocks: t.blocks.sorted { $0.order < $1.order }.map { b in
                        .init(
                            order: b.order, supersetRounds: b.supersetRounds, extraSetsOfFirst: b.extraSetsOfFirst,
                            exercises: b.exercises.sorted { $0.order < $1.order }.map { e in
                                .init(
                                    order: e.order, exerciseID: e.exerciseID, sets: e.sets, repsMin: e.repsMin,
                                    repsMax: e.repsMax, restSeconds: e.restSeconds, targetRIR: e.targetRIR,
                                    setupNotes: e.setupNotes, tempo: e.tempo, progressionStep: e.progressionStep
                                )
                            }
                        )
                    }
                )
            }
        )
    }

    private static func insertProgram(_ dto: BackupDocument.ProgramDTO, into context: ModelContext) {
        let program = Program(id: dto.id, name: dto.name, isActive: dto.isActive)
        context.insert(program)
        for t in dto.templates {
            let template = WorkoutTemplate(id: t.id, name: t.name, weekday: t.weekday, order: t.order)
            context.insert(template)
            template.program = program
            for b in t.blocks {
                let block = TemplateBlock(order: b.order, supersetRounds: b.supersetRounds, extraSetsOfFirst: b.extraSetsOfFirst)
                context.insert(block)
                block.template = template
                for e in b.exercises {
                    let ex = TemplateExercise(
                        order: e.order, exerciseID: e.exerciseID, sets: e.sets, repsMin: e.repsMin,
                        repsMax: e.repsMax, restSeconds: e.restSeconds, targetRIR: e.targetRIR,
                        setupNotes: e.setupNotes, tempo: e.tempo, progressionStep: e.progressionStep
                    )
                    context.insert(ex)
                    ex.block = block
                }
            }
        }
    }
}
