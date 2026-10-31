import Foundation
import SwiftData
import Testing
@testable import HexisLogic

/// The same checks on the real history: the latest backup of the iPhone (`Tools/data_check.sh` fetches it), restored
/// into a throwaway database. Prints what the user will see (Home, each session prefilled, Today, shopping), as of the backup's
/// time so it only changes when the code or the data does: `check.sh` shows the difference since the last green run (`HEXIS_SEEN`).
/// In the ELLE pass it is her backup, her program, and no food.
@Suite(.serialized) struct RealDataTests {
    static let file = ProcessInfo.processInfo.environment["HEXIS_DATA"].map(URL.init(fileURLWithPath:))

    @Test(.enabled(if: file != nil)) @MainActor func realHistoryHoldsAndNextSessionsMakeSense() throws {
        ProgramCatalog.fileURL = LifeSimulator.appProgramFile
        UserDefaults.standard.removeObject(forKey: "homeShown") // only the backup's own record counts
        let container = try ModelContainer(for: Schema(versionedSchema: SchemaV16.self), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        try BackupService.restore(try Data(contentsOf: try #require(Self.file)), into: context, snapshotFirst: false)
        ProgramSync.sync(in: context)
        let raw = try JSONSerialization.jsonObject(with: Data(contentsOf: try #require(Self.file))) as? [String: Any]
        let now = (raw?["exportedAt"] as? String).flatMap { try? Date($0, strategy: .iso8601) } ?? .now
        var seen: [String] = []
        func show(_ line: String) { seen.append(line); print("data · " + line) }

        var problems = LifeChecks.store(context, now: now)
        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.startedAt)]))
        let logs = try context.fetch(FetchDescriptor<SetLog>())
        let exercises = Dictionary(try context.fetch(FetchDescriptor<Exercise>()).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let unknown = Set(logs.map(\.exerciseID)).subtracting(exercises.keys).count
        if unknown > 0 { problems.append("\(unknown) exercices des séries introuvables") }
        print("data · \(sessions.count) séances, \(logs.count) séries, dernière le \(sessions.last?.startedAt.formatted(date: .abbreviated, time: .omitted) ?? "-")")

        // Heaviest work weight of the last session per exercise and gym: the reference for a sane jump.
        let bySession = Dictionary(grouping: logs.filter { $0.kind == .work }, by: \.sessionID)
        var lastTop: [String: Double] = [:]
        for session in sessions { // oldest first: the latest wins
            for (exercise, sets) in Dictionary(grouping: bySession[session.id] ?? [], by: \.exerciseID) {
                lastTop[Athlete.key(exercise, session.gymID)] = sets.map(\.weight).max()
            }
        }
        let gymID = sessions.last { $0.state == .finished }?.gymID
        let templates = (try context.fetch(FetchDescriptor<Program>(predicate: #Predicate { $0.isActive }))).first?.templates ?? []
        let finished = sessions.filter { $0.state == .finished }.map { (templateID: $0.templateID, date: $0.startedAt) }
        let rotation = WeekRotation.make(templates: templates, sessions: finished, now: now)
        let names = Dictionary(templates.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        show("Accueil : \(rotation.next.flatMap { names[$0] } ?? "-")\(rotation.short ? " · semaine à 3 séances, reste \(rotation.remaining.joined(separator: ", "))" : "")")
        if Edition.isElle {
            let streak = HabitStreak(sessionDates: finished.map(\.date), weeklyTarget: max(ProgramCatalog.usualWeek(templates).count, 1), now: now)
            show("Rythme : \(streak.streak) semaine(s) tenue(s)\(streak.jokerAvailable ? " · joker dispo" : "") · \(streak.thisMonth) séance(s) ce mois-ci")
        }
        // The screen and the logic must agree: what Home really showed, recomputed at that moment.
        if let shown = HomeShown.last() {
            let then = WeekRotation.make(templates: templates, sessions: finished.filter { $0.date <= shown.date }, now: shown.date)
            let expected = then.next.flatMap { names[$0] } ?? "-"
            if expected != shown.session || then.short != shown.short {
                problems.append("Accueil a montré \(shown.session)\(shown.short ? " (3 séances)" : "") le \(shown.date.formatted()), la logique dit \(expected)\(then.short ? " (3 séances)" : "")")
            }
        }
        for template in templates.sorted(by: { $0.order < $1.order }) {
            let session = WorkoutSession(date: now, gymID: gymID, templateID: template.id)
            context.insert(session)
            let vm = WorkoutViewModel(session: session, template: template, context: context)
            problems += LifeChecks.plan(vm, lastTop: lastTop, gymID: gymID ?? UUID()).map { "\(template.name) · \($0)" }
            show("\(template.name)\(vm.isDeload ? " (déload)" : "") : " + vm.adjustments.notes.map(\.text).joined(separator: " | "))
            var seen: Set<UUID> = []
            for (i, step) in vm.steps.enumerated() where step.warmupPercent == nil && seen.insert(step.exerciseID).inserted {
                let value = vm.values[i]
                let sets = vm.steps.filter { $0.exerciseID == step.exerciseID && $0.warmupPercent == nil && $0.side != .right }.count
                let last = lastTop[Athlete.key(step.exerciseID, gymID)].map { " (avant \($0.formatted()))" } ?? ""
                show("  \(step.name) : \(sets) × \(step.repsMin)–\(step.repsMax)\(step.unit) · \((value?.weight ?? 0).formatted()) kg × \(value?.reps ?? 0)\(last)")
            }
            SessionCloser.discard(session, context: context)
        }
        problems += try screens(context, now: now, show: show)
        if Edition.hasNutrition { problems += try food(context, now: now, show: show) }
        // Whatever a screen prints must read as text a person can trust.
        for line in seen where line.range(of: #"NaN|\binf\b|Optional\(|\bnil\b|\(null\)|-0 kg|–0 kg"#, options: .regularExpression) != nil {
            problems.append("texte cassé affiché : \(line)")
        }
        if let path = ProcessInfo.processInfo.environment["HEXIS_SEEN"] {
            try (seen.joined(separator: "\n") + "\n").write(toFile: path, atomically: true, encoding: .utf8)
        }
        if !problems.isEmpty { Issue.record("Données réelles :\n\(Array(NSOrderedSet(array: problems)).map { "  \($0)" }.joined(separator: "\n"))") }
    }

    /// Today and the shopping list, as the Alimentation screens show them.
    @MainActor private func food(_ context: ModelContext, now: Date, show: (String) -> Void) throws -> [String] {
        var problems: [String] = []
        let meals = try context.fetch(FetchDescriptor<PlanMeal>())
        let planLogs = try context.fetch(FetchDescriptor<PlanMealLog>())
        let doneToday = Set(planLogs.filter { Calendar.current.isDate($0.day, inSameDayAs: now) }.map(\.planMealID))
        let next = NextMealPicker.pick(meals: meals, doneIDs: doneToday, weekday: Calendar.current.component(.weekday, from: now), hour: Calendar.current.component(.hour, from: now))
        show("Aujourd'hui : \(next.map { "prochain repas \($0.slot.label)" } ?? (meals.isEmpty ? "pas de plan" : "journée terminée"))\(FreePeriod.status(in: context, now: now).map { " · " + $0.text } ?? "")")
        let shopping = ShoppingList.cycleLines(meals: meals, ingredients: try context.fetch(FetchDescriptor<Ingredient>()), logs: planLogs, checked: [], now: now)
        show("Courses (semaine du \(PlanCycle.start(for: now).formatted(date: .abbreviated, time: .omitted)))")
        for line in shopping where line.toBuy > 0 {
            show("  \(line.food.name) : \(line.buyText)")
            if line.food.packGrams > 0, Double(line.packs) * line.food.packGrams - line.toBuy >= line.food.packGrams {
                problems.append("courses : \(line.food.name) \(line.packs) pots pour \(Int(line.toBuy)) g, un pot de trop")
            }
        }
        return problems
    }

    /// Bilan (as it would read on each day of the backup's week, with only the data of that moment) and Analyse: the numbers and messages
    /// a screen shows, so an absurd one (a « -80 % » on a Saturday, a trend on 2 sessions) fails here instead of being found by eye.
    @MainActor private func screens(_ context: ModelContext, now: Date, show: (String) -> Void) throws -> [String] {
        var problems: [String] = []
        let calendar = WeekReview.calendar
        let finished = try context.fetch(FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.stateRaw == "finished" }))
        let sets = try context.fetch(FetchDescriptor<SetLog>(predicate: #Predicate { $0.kindRaw == "work" }))
        let exerciseList = try context.fetch(FetchDescriptor<Exercise>())
        let byID = Dictionary(exerciseList.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let resolver = LoadResolver(loads: try context.fetch(FetchDescriptor<ExerciseLoad>()), exercises: exerciseList)
        let monday = WeekReview.weekStart(containing: now)
        let moments: [(String, Date)] = [("mer.", 2), ("sam.", 5), ("dim. soir", 6), ("lun. suivant", 7)].map { label, day in
            (label, calendar.date(byAdding: .hour, value: day * 24 + (day == 7 ? 0 : 12), to: monday) ?? monday)
        }
        for (label, moment) in moments {
            let until = finished.filter { $0.startedAt <= moment }
            let ids = Set(until.map(\.id))
            let kept = sets.filter { ids.contains($0.sessionID) }
            func review(_ offset: Int) -> WeekReview {
                WeekReview(start: WeekReview.weekStart(containing: moment.addingTimeInterval(-60), offset: offset), sessions: until, sets: kept, exercises: byID, loads: resolver)
            }
            let week = review(0), before = review(-1)
            let over = week.isOver(now: moment)
            let seriesDelta = WeekReview.change(Double(week.workSets), vs: Double(before.workSets), weekIsOver: over)
            let volumeDelta = WeekReview.change(week.volume, vs: before.volume, weekIsOver: over)
            show("Bilan \(label) : \(week.sessionCount) séance(s) · \(week.workSets) séries\(seriesDelta.map { " (\($0))" } ?? "") · \(Int(week.volume.rounded())) kg\(volumeDelta.map { " (\($0))" } ?? "")")
            if !over, seriesDelta != nil || volumeDelta != nil { problems.append("Bilan \(label) : comparaison affichée alors que la semaine court") }
        }
        let intake = Edition.hasNutrition ? DailyIntake.load(in: context, since: Calendar.current.date(byAdding: .day, value: -540, to: now) ?? now) : [:]
        let points = Insights.points(sessions: finished, sets: sets, loads: resolver, intake: intake)
        let gyms = try context.fetch(FetchDescriptor<Gym>())
        let found = Insights.ranked(Insights.insights(from: points)
            + PositionInsights.insights(sessions: finished, sets: sets, names: Dictionary(exerciseList.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first }))
            + SpeedInsights.insights(sessions: finished, gymNames: Dictionary(gyms.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })))
        for insight in found {
            show("Analyse : \(insight.text) [\(insight.sampleSize) \(insight.unit)]")
            let floor = ["weekday", "slot", "rest"].contains(insight.id) ? Insights.minPerGroup : 3
            if insight.sampleSize < floor { problems.append("Analyse : « \(insight.text) » sur \(insight.sampleSize) seulement") }
        }
        return problems
    }
}
