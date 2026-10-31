import Foundation
import Observation

/// The batch cooking's countdowns: one per step, several at once (rice while the chicken cooks). They outlive the screen and the
/// app: the end date is kept, each has its own notification, and a reopened app takes them up where they are. The Dynamic Island
/// shows the soonest one.
@MainActor
@Observable
final class BatchTimers {
    static let shared = BatchTimers()
    static let key = "batchTimers"

    struct Item: Codable, Identifiable, Equatable {
        var title: String
        var end: Date
        var id: String { title }
    }

    private(set) var items: [Item] = []
    @ObservationIgnored private var tasks: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private let defaults: UserDefaults
    /// The sound at the end (a test counts it).
    @ObservationIgnored private let ring: () -> Void

    init(defaults: UserDefaults = .standard, now: Date = .now, ring: @escaping () -> Void = { SoundService.timerEnded() }) {
        self.defaults = defaults
        self.ring = ring
        let saved = (defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode([Item].self, from: $0) }) ?? []
        items = saved.filter { $0.end > now }
        items.forEach(watch)
        if items.count != saved.count { save() }
        NotificationService.purgeBatchEnds(keeping: Set(items.map(\.title)))
        refreshActivity()
    }

    func end(of title: String) -> Date? { items.first { $0.title == title }?.end }

    /// Starts (or restarts) the step's countdown; the others keep running.
    func start(title: String, seconds: Int, now: Date = .now) {
        guard seconds > 0 else { return }
        let item = Item(title: title, end: now.addingTimeInterval(TimeInterval(seconds)))
        items.removeAll { $0.title == title }
        items.append(item)
        items.sort { $0.end < $1.end }
        NotificationService.scheduleBatchEnd(at: item.end, title: title)
        watch(item)
        save()
        refreshActivity()
    }

    func stop(_ title: String) {
        tasks[title]?.cancel()
        tasks[title] = nil
        items.removeAll { $0.title == title }
        NotificationService.cancelBatchEnd(title: title)
        save()
        refreshActivity()
    }

    /// Cancels the whole batch: every countdown and every waiting notification.
    func stopAll() {
        items.map(\.title).forEach(stop)
        NotificationService.purgeBatchEnds(keeping: [])
    }

    private func watch(_ item: Item) {
        tasks[item.title]?.cancel()
        tasks[item.title] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(item.end.timeIntervalSinceNow, 0)))
            guard let self, !Task.isCancelled else { return }
            self.items.removeAll { $0.title == item.title }
            self.tasks[item.title] = nil
            // Woken long after the end (app suspended): the notification already rang.
            if item.end.timeIntervalSinceNow > -3 { self.ring() }
            self.save()
            self.refreshActivity()
        }
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(items), forKey: Self.key)
    }

    private func refreshActivity() {
        if let soonest = items.first {
            RestActivity.show(until: soonest.end, next: soonest.title, title: "Batch cooking")
        } else {
            RestActivity.end()
        }
    }
}
