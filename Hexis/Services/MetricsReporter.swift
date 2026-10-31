import Foundation
import MetricKit

/// Receives Apple's crash, hang and launch-time reports (MetricKit, no account needed) and keeps the last few as JSON in
/// Documents/diagnostics, which Tools/weekly_build.py copies from the iPhone.
final class MetricsReporter: NSObject, MXMetricManagerSubscriber {
    static let shared = MetricsReporter()
    private static let keep = 5

    func start() { MXMetricManager.shared.add(self) }

    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads { write(payload.jsonRepresentation(), kind: "metrics") }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads { write(payload.jsonRepresentation(), kind: "diagnostic") }
    }

    private func write(_ json: Data, kind: String) {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let dir = docs.appendingPathComponent("diagnostics", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")
        try? json.write(to: dir.appendingPathComponent("\(stamp)-\(kind).json"), options: .atomic)
        let files = ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        files.dropFirst(Self.keep).forEach { try? FileManager.default.removeItem(at: $0) }
    }
}
