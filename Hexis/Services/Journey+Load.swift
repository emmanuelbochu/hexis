import Foundation
import SwiftData

extension Journey {
    /// Reads the history once and builds the card; call it from a `.task`, never from `body`.
    @MainActor static func load(in context: ModelContext, now: Date = .now) async -> Journey? {
        let finished = (try? context.fetch(FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.stateRaw == "finished" }))) ?? []
        guard let first = finished.map(\.startedAt).min() else { return nil }
        let sets = (try? context.fetch(FetchDescriptor<SetLog>(predicate: #Predicate { $0.kindRaw == "work" }))) ?? []
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let program = (try? context.fetch(FetchDescriptor<Program>(predicate: #Predicate { $0.isActive })))?.first
        let rehab = Set(ProgramCatalog.rehabExercises.map { $0.name.lowercased() })
        let eligible = Set(exercises.filter { !rehab.contains($0.name.lowercased()) && (ProgramCatalog.exercise(named: $0.name)?.unit ?? "").isEmpty }.map(\.id))
        await HealthService.authorize()
        let weights = await HealthService.weights(since: first.addingTimeInterval(-14 * 86_400))
        return make(
            sets: sets, sessionDates: finished.map(\.startedAt), names: Dictionary(exercises.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a }),
            eligible: eligible, weights: weights, weeklyTarget: program.map { ProgramCatalog.usualWeek($0.templates).count } ?? 4, now: now
        )
    }
}
