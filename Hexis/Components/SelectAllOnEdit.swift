import UIKit

/// Tapping a number field (kg, reps) selects its whole value, so typing replaces it. One global observer:
/// a per-field subscription ran every field's handler on each tap (dozens of `selectAll` calls, keyboard freeze).
enum SelectAllOnEdit {
    private static var installed = false

    static func install() {
        guard !installed else { return }
        installed = true
        NotificationCenter.default.addObserver(forName: UITextField.textDidBeginEditingNotification, object: nil, queue: .main) { note in
            guard let field = note.object as? UITextField, field.keyboardType == .decimalPad || field.keyboardType == .numberPad else { return }
            DispatchQueue.main.async { if field.isFirstResponder { field.selectAll(nil) } }
        }
    }
}
