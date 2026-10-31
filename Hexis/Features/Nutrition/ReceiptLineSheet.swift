import SwiftUI

/// Retypes what a receipt line counts: how many units, what one weighs, what was paid. The AI's reading stays visible above.
struct ReceiptLineSheet: View {
    @Binding var line: ReceiptReviewLine
    @Environment(\.dismiss) private var dismiss
    @State private var units = 1
    @State private var perUnit = 0.0
    @State private var price = 0.0

    private var food: Ingredient { line.match.food }
    /// A food sold by the piece (banana) has no weight to retype: the unit is the piece.
    private var weightEditable: Bool { food.pieceGrams <= 0 || line.match.soldInBoxes }
    private var unitGrams: Double { !weightEditable ? food.pieceGrams : (line.match.soldInBoxes ? perUnit * food.pieceGrams : perUnit) }

    private var preview: ReceiptMatch {
        var match = line.match
        match.set(units: units, unitGrams: unitGrams)
        match.price = price
        return match
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Lu sur le ticket") { summary(line.original) }
                Section("Compté") { summary(preview) }
                Section("Nombre d'unités") { TextField("1", value: $units, format: .number).keyboardType(.numberPad) }
                if weightEditable {
                    Section(line.match.soldInBoxes ? "\(food.pieceLabel.capitalized)s par lot" : "Poids d'une unité (g)") {
                        TextField("0", value: $perUnit, format: .number).keyboardType(.decimalPad)
                    }
                }
                Section("Prix payé (€)") { TextField("0", value: $price, format: .number).keyboardType(.decimalPad) }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("\(food.emoji) \(food.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("OK") { commit() } }
        }
        .presentationDetents([.large])
        .onAppear {
            units = line.match.editableUnits
            perUnit = line.match.soldInBoxes ? line.match.editableUnitGrams / food.pieceGrams : line.match.editableUnitGrams
            price = line.match.price
        }
    }

    private func summary(_ match: ReceiptMatch) -> some View {
        HStack {
            Text(match.quantityText)
            Spacer()
            Text(QuantityFormatter.price(match.price)).foregroundStyle(Theme.Colors.textSecondary)
        }
        .font(Theme.Fonts.body.monospacedDigit())
    }

    private func commit() {
        line.match = preview
        line.warning = nil
        line.isSelected = true
        dismiss()
    }
}
