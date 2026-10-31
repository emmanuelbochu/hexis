import SwiftData
import SwiftUI

/// Sunday batch cooking, one step at a time: validate, next. Every other step unfolds with a tap; the screen stays on.
struct BatchCookingView: View {
    @Query(sort: \BatchStep.order) private var steps: [BatchStep]
    @Query private var meals: [PlanMeal]
    @Query private var ingredients: [Ingredient]
    @Query private var flatStocks: [FlatStock]
    @State private var cancelling = false

    private var current: BatchStep? { steps.first { !$0.isDone() } }
    private var doneCount: Int { steps.filter { $0.isDone() }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                ProgressView(value: steps.isEmpty ? 0 : Double(doneCount) / Double(steps.count))
                    .tint(Theme.Colors.accent)
                BatchRunningTimers(steps: steps, current: current)
                if let current {
                    BatchStepCard(step: current, index: doneCount + 1, total: steps.count, previous: steps.last { $0.isDone() })
                        .id(current.id)
                } else {
                    BatchFinishedCard(steps: steps)
                    let carry = CarryList.lines(meals: meals, ingredients: ingredients, steps: steps, flat: FlatStockBook.grams(flatStocks, foods: ingredients))
                    if !carry.isEmpty { CarryCard(lines: carry) }
                }
                group("Ensuite", steps.filter { !$0.isDone() && $0.id != current?.id }, done: false)
                group("Fait", steps.filter { $0.isDone() }, done: true)
                if doneCount > 0 || !BatchTimers.shared.items.isEmpty {
                    Button("Annuler le batch cooking") { cancelling = true }
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: Theme.Layout.minTapHeight)
                }
            }
            .padding(Theme.Spacing.m)
        }
        .screenBackground()
        .navigationTitle("Batch cooking")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: doneCount)
        .alert("Annuler le batch cooking ?", isPresented: $cancelling) {
            Button("Non", role: .cancel) {}
            Button("Annuler le batch", role: .destructive) {
                BatchTimers.shared.stopAll()
                steps.forEach { $0.completedAt = nil }
            }
        } message: {
            Text("Les étapes repartent de zéro et les minuteurs s'arrêtent.")
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    @ViewBuilder
    private func group(_ title: String, _ items: [BatchStep], done: Bool) -> some View {
        if !items.isEmpty {
            Text(title)
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            ForEach(items) { BatchStepRow(step: $0, done: done) }
        }
    }
}

private struct BatchFinishedCard: View {
    let steps: [BatchStep]

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 48)).foregroundStyle(Theme.Colors.accent)
            Text("Batch terminé").font(Theme.Fonts.title).foregroundStyle(Theme.Colors.textPrimary)
            Button("Recommencer") {
                steps.forEach { $0.completedAt = nil }
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}

#Preview {
    NavigationStack { BatchCookingView() }
        .modelContainer(for: BatchStep.self, inMemory: true)
        .appAppearance()
}
