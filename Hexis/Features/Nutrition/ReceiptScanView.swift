import SwiftData
import SwiftUI

/// Scan a receipt → read it on the phone → Gemini matches it to the plan foods → one tap adds it to the stock.
struct ReceiptScanView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Ingredient.name) private var foods: [Ingredient]
    @Query private var meals: [PlanMeal]
    @Query private var purchases: [PurchaseLog]
    @Query private var aliases: [ReceiptAlias]
    @Query private var memories: [ProductMemory]
    @Query private var offPlan: [OffPlanProduct]
    @Query private var checks: [ShoppingCheck]
    @Query private var logs: [PlanMealLog]
    @Query private var notes: [ShoppingNote]

    private enum Phase { case camera, captured, reading, review([ReceiptReviewLine]), failed(String) }
    @State private var phase = Phase.camera
    @State private var photos: [UIImage] = []
    @State private var extras: [ReceiptExtra] = []
    /// The same ticket was already added on that date: its lines start unticked and its off-plan lines are not counted twice.
    @State private var repeatedOn: Date?

    var body: some View {
        switch phase {
        case .camera:
            ReceiptCamera(onPhoto: { photos.append($0); phase = .captured }, onCancel: { photos.isEmpty ? dismiss() : (phase = .captured) })
                .ignoresSafeArea()
        case .captured:
            VStack(spacing: Theme.Spacing.m) {
                Spacer()
                Image(systemName: "photo.stack").font(.system(size: 48)).foregroundStyle(Theme.Colors.accent)
                Text("\(photos.count) photo\(photos.count > 1 ? "s" : "")")
                    .font(Theme.Fonts.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Button { read() } label: { Label("Lire le ticket", systemImage: "checkmark") }.buttonStyle(PrimaryButtonStyle())
                Button { phase = .camera } label: { Label("Ajouter une photo", systemImage: "camera") }.buttonStyle(SecondaryButtonStyle())
                Button("Annuler") { dismiss() }
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(minHeight: Theme.Layout.minTapHeight)
            }
            .padding(Theme.Spacing.m)
            .screenBackground()
        case .reading:
            VStack(spacing: Theme.Spacing.m) {
                ProgressView().tint(Theme.Colors.accent)
                Text("Lecture du ticket…").font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .screenBackground()
        case .review(let lines):
            ReceiptReviewView(lines: lines, foods: foods, extras: repeatedOn == nil ? extras : [], repeatedOn: repeatedOn) { chosen, corrections, allExtras in
                settleShopping(scanned: Set(chosen.map(\.food.id)))
                ReceiptParser.apply(chosen, in: context)
                if repeatedOn == nil { ReceiptParser.save(allExtras, in: context) }
                OffPlanBook.learn(allExtras, in: context)
                notes.filter(\.checked).forEach(context.delete)
                ReceiptParser.learn(corrections, known: aliases, in: context)
                dismiss()
            }
        case .failed(let message):
            VStack(spacing: Theme.Spacing.m) {
                Image(systemName: "exclamationmark.triangle").font(.system(size: 40)).foregroundStyle(Theme.Colors.accent)
                Text(message).font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textPrimary).multilineTextAlignment(.center)
                Button("Fermer") { dismiss() }.buttonStyle(SecondaryButtonStyle())
            }
            .padding(Theme.Spacing.l)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .screenBackground()
        }
    }

    /// The ticket closes the shopping: what was ticked in store joins the stock, the ticked extras (sponge, water) leave the list.
    private func settleShopping(scanned: Set<UUID>) {
        let ticked = Set(checks.map(\.ingredientID))
        let lines = ShoppingList.cycleLines(meals: meals, ingredients: foods, logs: logs, checked: ticked, purchases: purchases)
        ShoppingList.settleChecked(lines, scanned: scanned)
        checks.forEach(context.delete)
    }

    private func read() {
        phase = .reading
        let known = foods
        let knownAliases = aliases
        let knownProducts = memories
        let knownOffPlan = offPlan
        let pages = photos
        Task {
            do {
                let result = try await ReceiptParser.matches(photos: pages, foods: known, aliases: knownAliases, memories: knownProducts, offPlan: knownOffPlan)
                let lines = ReceiptGuard.review(result.matches, weeklyNeeds: PlanCalculator.weeklyNeeds(meals), recent: purchases)
                let source = result.usedPhoto ? "photo lue par Gemini" : "texte lu par l'iPhone"
                extras = result.extras
                repeatedOn = ReceiptGuard.earlierScan(of: result.matches, recent: purchases)?.date
                phase = lines.isEmpty && result.extras.isEmpty ? .failed("Aucun aliment du plan reconnu sur ce ticket (\(source)).") : .review(lines)
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }
}
