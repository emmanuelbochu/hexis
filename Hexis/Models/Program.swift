import Foundation
import SwiftData

@Model
final class Program {
    @Attribute(.unique) var id: UUID
    var name: String
    var isActive: Bool
    @Relationship(deleteRule: .cascade, inverse: \WorkoutTemplate.program)
    var templates: [WorkoutTemplate] = []

    init(id: UUID = UUID(), name: String, isActive: Bool = false) {
        self.id = id
        self.name = name
        self.isActive = isActive
    }
}
