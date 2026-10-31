import Foundation
import Observation

/// A countdown with its Live Activity and end notification: the rest between sets (+/-15 s, skip), or a step of the batch cooking.
@Observable
final class RestTimer {
    enum Kind { case rest, batch }

    private(set) var endDate: Date?
    private var task: Task<Void, Never>?
    /// What comes next (the rest) or what is cooking (the batch step).
    private(set) var next = ""
    private let kind: Kind
    /// The sound at the end (a test counts it).
    private let ring: () -> Void

    var isRunning: Bool { endDate != nil }

    init(kind: Kind = .rest, ring: @escaping () -> Void = { SoundService.restEnded() }) {
        self.kind = kind
        self.ring = ring
    }

    func start(seconds: Int, next: String = "") {
        guard seconds > 0 else { return }
        self.next = next
        schedule(until: Date.now.addingTimeInterval(TimeInterval(seconds)))
    }

    func add(seconds: Int) {
        guard let endDate else { return }
        let target = endDate.addingTimeInterval(TimeInterval(seconds))
        if target <= .now { skip() } else { schedule(until: target) }
    }

    func skip() {
        task?.cancel()
        endDate = nil
        NotificationService.cancelRestEnd(kind)
        RestActivity.end()
    }

    private func schedule(until date: Date) {
        task?.cancel()
        endDate = date
        NotificationService.scheduleRestEnd(at: date, kind: kind, next: next)
        RestActivity.show(until: date, next: next, title: kind == .batch ? "Batch cooking" : nil)
        task = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(date.timeIntervalSinceNow, 0)))
            // The session screen is gone (abandoned, closed): its rest no longer rings.
            guard let self, !Task.isCancelled else { return }
            self.endDate = nil
            // Woken long after the end (app suspended): the notification already rang.
            if date.timeIntervalSinceNow > -3 { self.ring() }
            NotificationService.cancelRestEnd(self.kind)
            RestActivity.end()
        }
    }
}
