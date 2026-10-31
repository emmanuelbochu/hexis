import SwiftData
import SwiftUI

/// Week shopping list: needs minus what is at home, ticked in store. Resets by itself each cycle.
struct ShoppingView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Ingredient.name) private var ingredients: [Ingredient]
    @Query private var meals: [PlanMeal]
    @Query private var checks: [ShoppingCheck]
    @Query private var logs: [PlanMealLog]
    @Query private var extras: [ExtraPurchase]
    @Query private var purchases: [PurchaseLog]
    @State private var habits: [UsualExtras.Habit] = []
    @State private var editing: Ingredient?
    @State private var scanning = false
    @State private var adding = false
    /// Read again when the app comes back and at Friday's flip: an open screen switches to next week's list by itself.
    @State private var now = Date.now
    @Environment(\.scenePhase) private var scenePhase

    private var cycle: Date { PlanCycle.start(for: now) }
    private var current: [ShoppingCheck] { checks.filter { Calendar.current.isDate($0.cycleStart, inSameDayAs: cycle) } }
    /// A cycle that is mostly school holiday: the list is still shown (what the plan would need), but tracking is paused.
    private var onHoliday: Bool { FreePeriod.isHolidayCycle(cycle) }
    private var lines: [ShoppingLine] {
        ShoppingList.cycleLines(meals: meals, ingredients: ingredients, logs: logs, checked: Set(current.map(\.ingredientID)), purchases: purchases, now: now)
    }

    var body: some View {
        VStack(spacing: 0) {
            PageActionRow {
                Button { adding = true } label: { Label("Ajouter pour cette semaine", systemImage: "plus").frame(width: 44, height: 44) }
                Button { scanning = true } label: { Label("Scanner le ticket", systemImage: "doc.text.viewfinder").frame(width: 44, height: 44) }
                NavigationLink { PantryView() } label: { Label("Placard", systemImage: "archivebox.fill").frame(width: 44, height: 44) }
            }
            content
        }
        .screenBackground()
        .fullScreenCover(isPresented: $scanning) { ReceiptScanView().appAppearance() }
        .sheet(item: $editing) { IngredientEditSheet(ingredient: $0) }
        .sheet(isPresented: $adding) { ShoppingNoteSheet(cycle: cycle).appAppearance() }
        .task {
            pruneOldChecks()
            ShoppingNotes.prune(before: cycle, in: context)
        }
        .task(id: extras.count) { habits = UsualExtras.due(extras) }
        .task(id: now) {
            guard let flip = PlanCycle.nextListReady(after: now) else { return }
            try? await Task.sleep(for: .seconds(max(flip.timeIntervalSinceNow, 0) + 1))
            if !Task.isCancelled { now = .now }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { now = .now } }
        .task(id: lines.filter { $0.toBuy == 0 }.map(\.id)) { dropCoveredChecks() }
    }

    private var content: some View {
        ScrollView {
            let all = lines // once per render: it walks the whole plan
            let toBuy = all.filter { $0.toBuy > 0 && !$0.isBakery }
            let bakery = all.filter { $0.toBuy > 0 && $0.isBakery }
            let atHome = all.filter { $0.toBuy == 0 }
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                if onHoliday {
                    Label("Vacances : liste indicative, le suivi du stock est en pause", systemImage: "beach.umbrella.fill")
                        .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                }
                ShoppingSummaryCard(lines: toBuy)
                ShoppingNotesSection(cycle: cycle)
                SpendingCard()
                ForEach(ShoppingList.categoryOrder.filter { $0 != ShoppingList.bakery }, id: \.self) { category in
                    section(category, toBuy.filter { $0.food.category == category })
                }
                section("Boulangerie, après les courses", bakery)
                if !habits.isEmpty { habitsSection }
                section("Déjà à la maison", atHome)
            }
            .padding(Theme.Spacing.m)
        }
    }

    /// Off-plan foods bought again and again that are due by their own rhythm.
    private var habitsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("D'habitude aussi").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            ForEach(habits) { habit in
                HStack {
                    Text(habit.label.capitalized).font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    Text("≈ " + QuantityFormatter.price(habit.price)).font(Theme.Fonts.caption.monospacedDigit()).foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    @ViewBuilder
    private func section(_ title: String, _ items: [ShoppingLine]) -> some View {
        if !items.isEmpty {
            Text(title)
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            ForEach(items) { line in
                ShoppingRowView(line: line) { toggle(line) }
                    .contextMenu {
                        if line.toBuy > 0 {
                            Button("Déjà à la maison", systemImage: "house") { haveAlready(line) }
                        }
                        Button("Prix et stock", systemImage: "pencil") { editing = line.food }
                    }
            }
        }
    }

    /// The item is at home after all (not on the ticket, or bought elsewhere): it leaves the list for « Déjà à la maison ».
    private func haveAlready(_ line: ShoppingLine) {
        line.food.stockGrams = ShoppingList.coveredStock(line)
        if let check = current.first(where: { $0.ingredientID == line.id }) { context.delete(check) }
        context.saveReportingFailure()
    }

    private func toggle(_ line: ShoppingLine) {
        if let check = current.first(where: { $0.ingredientID == line.id }) {
            context.delete(check)
        } else {
            context.insert(ShoppingCheck(ingredientID: line.id, cycleStart: cycle))
        }
    }

    /// An item stops being ticked once the stock covers it (bought, or no longer needed), so it starts unticked when it is needed again.
    private func dropCoveredChecks() {
        let toBuy = Set(lines.filter { $0.toBuy > 0 }.map(\.id))
        for check in current where !toBuy.contains(check.ingredientID) { context.delete(check) }
        context.saveReportingFailure()
    }

    private func pruneOldChecks() {
        for check in checks where check.cycleStart < cycle && !Calendar.current.isDate(check.cycleStart, inSameDayAs: cycle) {
            context.delete(check)
        }
    }
}

#Preview {
    ShoppingView()
        .modelContainer(for: PlanMeal.self, inMemory: true)
        .appAppearance()
}
