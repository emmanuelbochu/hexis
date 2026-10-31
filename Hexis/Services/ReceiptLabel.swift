import Foundation

/// Normalised receipt lines, so the same printed line is recognised on the next ticket.
enum ReceiptLabel {
    /// Lower-case words without digits or accents: stable enough to recognise the same printed line next time.
    static func normalize(_ label: String) -> String {
        label.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .init(identifier: "fr_FR"))
            .split { !$0.isLetter }.filter { $0.count > 1 }.joined(separator: " ")
    }
}
