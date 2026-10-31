import Foundation

/// Pure stats of a finished (or running) session, computed from its logged sets.
struct SessionSummary: Equatable {
    var workSets: Int
    var volume: Double
    var exercises: Int
    var duration: TimeInterval
    var averageRPE: Double?

    init(sets: [SetLog], startedAt: Date, endedAt: Date?, loads: LoadResolver? = nil) {
        let work = sets.filter { $0.kind == .work }
        workSets = work.filter { $0.side != .left }.count
        volume = work.reduce(0) { $0 + (loads?.effective($1) ?? $1.weight) * Double($1.reps) }
        exercises = Set(work.map(\.exerciseID)).count
        let efforts = work.compactMap { $0.rir.map { Double(10 - $0) } }
        averageRPE = efforts.isEmpty ? nil : efforts.reduce(0, +) / Double(efforts.count)
        duration = (endedAt ?? .now).timeIntervalSince(startedAt)
    }

    var durationText: String {
        let minutes = Int(duration / 60)
        return minutes >= 60 ? "\(minutes / 60) h \(String(format: "%02d", minutes % 60))" : "\(minutes) min"
    }

    var volumeText: String { "\(Int(volume.rounded())) kg" }
}
