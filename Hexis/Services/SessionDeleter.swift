import Foundation
import SwiftData

/// Removes one finished session with everything that hangs off it, after a snapshot so nothing is lost for good.
enum SessionDeleter {
    static func delete(_ session: WorkoutSession, in context: ModelContext) {
        AutoBackup.save(from: context)
        let id = session.id
        try? context.delete(model: SetLog.self, where: #Predicate { $0.sessionID == id })
        try? context.delete(model: SessionNote.self, where: #Predicate { $0.sessionID == id })
        try? context.delete(model: ExerciseFeeling.self, where: #Predicate { $0.sessionID == id })
        try? context.delete(model: CarryNote.self, where: #Predicate { $0.sessionID == id })
        // A reminder first shown in this session goes back to "not shown yet".
        for note in (try? context.fetch(FetchDescriptor<CarryNote>(predicate: #Predicate { $0.carrySessionID == id }))) ?? [] {
            note.carrySessionID = nil
        }
        context.delete(session)
        context.saveReportingFailure()
    }
}
