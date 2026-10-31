import Foundation
import SwiftData

@Model
final class WorkoutTemplate {
    @Attribute(.unique) var id: UUID
    var name: String
    /// Calendar weekday, 1 = Sunday ... 7 = Saturday. Nil = not scheduled.
    var weekday: Int?
    var order: Int
    var program: Program?
    @Relationship(deleteRule: .cascade, inverse: \TemplateBlock.template)
    var blocks: [TemplateBlock] = []

    init(id: UUID = UUID(), name: String, weekday: Int? = nil, order: Int = 0) {
        self.id = id
        self.name = name
        self.weekday = weekday
        self.order = order
    }
}
