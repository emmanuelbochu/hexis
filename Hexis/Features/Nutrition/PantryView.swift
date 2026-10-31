import SwiftData
import SwiftUI

/// What is already at home, and the price of each food.
struct PantryView: View {
    @Query(sort: \Ingredient.name) private var ingredients: [Ingredient]
    @State private var editing: Ingredient?

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.s) {
                ForEach(ingredients) { food in
                    Button { editing = food } label: {
                        HStack {
                            Text("\(food.emoji) \(food.name)")
                                .font(Theme.Fonts.body)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Spacer()
                            VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                                Text("Stock : \(QuantityFormatter.stock(food))")
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Text(food.packPrice > 0 ? priceText(food) : "Prix à saisir")
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                            .font(Theme.Fonts.caption)
                        }
                        .padding(Theme.Spacing.m)
                        .frame(minHeight: Theme.Layout.minTapHeight)
                        .cardStyle()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Theme.Spacing.m)
        }
        .screenBackground()
        .onAppear { UsageCounter.hit(.pantry) }
        .navigationTitle("Placard")
        .sheet(item: $editing) { IngredientEditSheet(ingredient: $0) }
    }

    private func priceText(_ food: Ingredient) -> String {
        food.packGrams > 0
            ? "\(QuantityFormatter.price(food.packPrice)) / \(QuantityFormatter.weight(food.packGrams))"
            : "\(QuantityFormatter.price(food.packPrice)) / kg"
    }
}

struct IngredientEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var ingredient: Ingredient
    @State private var initialPack = 0.0

    var body: some View {
        NavigationStack {
            Form {
                Section("À la maison (g)") {
                    TextField("0", value: $ingredient.stockGrams, format: .number).keyboardType(.decimalPad)
                }
                Section("Poids d'un pot ou paquet (g, 0 = prix au kg)") {
                    TextField("0", value: $ingredient.packGrams, format: .number).keyboardType(.decimalPad)
                }
                Section("Prix d'un pot ou paquet (€, ou du kg)") {
                    TextField("0", value: $ingredient.packPrice, format: .number).keyboardType(.decimalPad)
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("\(ingredient.emoji) \(ingredient.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("OK") { finish() } }
            .onAppear { initialPack = ingredient.packGrams }
        }
        .presentationDetents([.medium])
    }

    /// A pack size changed by hand is kept: the receipts stop re-learning it.
    private func finish() {
        if ingredient.packGrams != initialPack { ProductMemoryBook.lockPack(of: ingredient, in: context) }
        context.saveReportingFailure()
        dismiss()
    }
}
