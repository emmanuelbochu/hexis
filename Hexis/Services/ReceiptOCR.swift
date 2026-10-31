import UIKit
import Vision

/// Reads the text of receipt photos on the device; only this text ever leaves the phone.
nonisolated enum ReceiptOCR {
    static func text(from images: [UIImage]) async -> String {
        await Task.detached(priority: .userInitiated) {
            images.compactMap(\.cgImage).map(pageText).joined(separator: "\n")
        }.value
    }

    private static func pageText(_ image: CGImage) -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["fr-FR"]
        request.usesLanguageCorrection = false
        try? VNImageRequestHandler(cgImage: image).perform([request])
        let boxes = (request.results ?? []).compactMap { obs in
            obs.topCandidates(1).first.map { (text: $0.string, box: obs.boundingBox) }
        }
        return rows(of: boxes).joined(separator: "\n")
    }

    /// Groups recognised fragments into printed rows (label on the left, price on the right).
    static func rows(of boxes: [(text: String, box: CGRect)]) -> [String] {
        var rows: [(y: CGFloat, items: [(text: String, x: CGFloat)])] = []
        for item in boxes.sorted(by: { $0.box.midY > $1.box.midY }) {
            if let i = rows.firstIndex(where: { abs($0.y - item.box.midY) < 0.008 }) {
                rows[i].items.append((item.text, item.box.minX))
            } else {
                rows.append((item.box.midY, [(item.text, item.box.minX)]))
            }
        }
        return rows.map { $0.items.sorted { $0.x < $1.x }.map(\.text).joined(separator: " ") }
    }
}
