import Foundation

/// Picks which workout to propose: the one after the last one done, in program order (no fixed days).
enum TemplatePicker {
    static func pick(from templates: [(id: UUID, order: Int)], lastDone: UUID?) -> UUID? {
        let ordered = templates.sorted { $0.order < $1.order }
        guard let last = lastDone, let index = ordered.firstIndex(where: { $0.id == last }) else { return ordered.first?.id }
        return ordered[(index + 1) % ordered.count].id
    }
}
