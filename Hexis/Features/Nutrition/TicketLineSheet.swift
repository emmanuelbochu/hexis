import SwiftData
import SwiftUI

/// Retypes or removes one line of a scanned ticket; the stock follows the plan lines. What the line was is shown above what it becomes.
struct TicketLineSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let line: TicketLine
    let foods: [UUID: Ingredient]
    @State private var grams = 0.0
    @State private var price = 0.0
    @State private var pack = 0.0
    @State private var name = ""
    @State private var category = "Autre"
    @State private var before = ""
    @State private var removing = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Avant") { Text(before).font(Theme.Fonts.body.monospacedDigit()) }
                Section("Après") { Text(after).font(Theme.Fonts.body.monospacedDigit()) }
                switch line {
                case .plan(let log):
                    Section("Quantité comptée (g)") { TextField("0", value: $grams, format: .number).keyboardType(.decimalPad) }
                    if let food = foods[log.ingredientID], food.packGrams > 0 {
                        Section("Poids d'un pot ou paquet (g)") { TextField("0", value: $pack, format: .number).keyboardType(.decimalPad) }
                    }
                case .extra:
                    Section("Nom") { TextField("Nom", text: $name) }
                    Section("Catégorie") {
                        Picker("Catégorie", selection: $category) { ForEach(ExtraTidy.categories, id: \.self) { Text($0).tag($0) } }
                    }
                }
                Section("Prix payé (€)") { TextField("0", value: $price, format: .number).keyboardType(.decimalPad) }
                Section { Button("Supprimer la ligne", role: .destructive) { removing = true } }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("OK") { save() } }
            .alert("Supprimer cette ligne ?", isPresented: $removing) {
                Button("Annuler", role: .cancel) {}
                Button("Supprimer", role: .destructive) { remove() }
            }
        }
        .presentationDetents([.large])
        .onAppear(perform: load)
    }

    private var title: String {
        switch line {
        case .plan(let log): foods[log.ingredientID].map { "\($0.emoji) \($0.name)" } ?? "Ligne"
        case .extra(let extra): extra.label.capitalized
        }
    }

    private var after: String {
        switch line {
        case .plan: "\(QuantityFormatter.weight(grams)) · \(QuantityFormatter.price(price))"
        case .extra: "\(name.capitalized) · \(category) · \(QuantityFormatter.price(price))"
        }
    }

    private func load() {
        switch line {
        case .plan(let log):
            grams = log.grams
            price = log.price
            pack = foods[log.ingredientID]?.packGrams ?? 0
            before = "\(QuantityFormatter.weight(log.grams)) · \(QuantityFormatter.price(log.price))"
        case .extra(let extra):
            name = extra.label
            category = extra.category
            price = extra.price
            before = "\(extra.label.capitalized) · \(extra.category) · \(QuantityFormatter.price(extra.price))"
        }
    }

    private func save() {
        switch line {
        case .plan(let log):
            let food = foods[log.ingredientID]
            ReceiptHistory.correct(log, grams: max(0, grams), price: max(0, price), food: food)
            if let food, pack != food.packGrams, pack >= 0 {
                food.packGrams = pack
                ProductMemoryBook.lockPack(of: food, in: context)
            }
        case .extra(let extra):
            extra.price = max(0, price)
            extra.label = name.trimmingCharacters(in: .whitespaces).isEmpty ? extra.label : name
            extra.category = category
        }
        context.saveReportingFailure()
        dismiss()
    }

    private func remove() {
        switch line {
        case .plan(let log):
            ReceiptHistory.removeStock(of: log, food: foods[log.ingredientID])
            context.delete(log)
        case .extra(let extra): context.delete(extra)
        }
        context.saveReportingFailure()
        dismiss()
    }
}
