import SwiftUI

/// What the receipt contained, matched to the plan. Odd lines start unticked; one button adds the ticked ones to the stock.
/// A line is fixed in place: tap the food to pick another one or send the line out of the plan, tap the quantity to retype it
/// (count, weight of a unit, price). Lines outside the plan are listed too: tap one to say what it is.
struct ReceiptReviewView: View {
    @State var lines: [ReceiptReviewLine]
    @State private var extras: [ReceiptExtra]
    let foods: [Ingredient]
    var repeatedOn: Date?
    @State private var editing: UUID?
    @State private var editingExtra: UUID?
    /// The ticked lines, the printed labels moved to another food (nil: out of the plan) to learn from, and every line
    /// outside the plan (kept for the spending, explained ones remembered).
    let onConfirm: ([ReceiptMatch], [(label: String, food: Ingredient?)], [ReceiptExtra]) -> Void

    init(lines: [ReceiptReviewLine], foods: [Ingredient], extras: [ReceiptExtra] = [], repeatedOn: Date? = nil, onConfirm: @escaping ([ReceiptMatch], [(label: String, food: Ingredient?)], [ReceiptExtra]) -> Void) {
        _lines = State(initialValue: lines)
        _extras = State(initialValue: extras)
        self.foods = foods
        self.repeatedOn = repeatedOn
        self.onConfirm = onConfirm
    }

    private var chosen: [ReceiptMatch] { lines.filter(\.isSelected).map(\.match) }
    private var total: Double { chosen.reduce(0) { $0 + $1.price } + extras.reduce(0) { $0 + $1.price } }

    private var corrections: [(label: String, food: Ingredient?)] {
        let toFood = lines.filter { $0.isSelected }.flatMap { line -> [(label: String, food: Ingredient?)] in
            let moved = line.match.food.id != line.originalFoodID ? [line.match.label] : []
            return (moved + line.corrections).filter { !$0.isEmpty }.map { ($0, line.match.food) }
        }
        return toFood + extras.filter { $0.edited == false && !$0.printed.isEmpty && movedOutIDs.contains($0.id) }.map { ($0.printed, nil) }
    }

    /// Extras that came from a plan line sent out of the plan by hand.
    @State private var movedOutIDs: Set<UUID> = []

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            ScrollView {
                VStack(spacing: Theme.Spacing.s) {
                    if let repeatedOn {
                        Label("Ticket déjà ajouté le \(repeatedOn.formatted(.dateTime.day().month(.wide))) : ses lignes sont décochées.", systemImage: "doc.on.doc")
                            .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.accent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach($lines) { $line in
                        ReceiptReviewRow(line: $line, foods: foods, onEdit: { editing = line.id }, onPick: { change(line.id, to: $0) }, onMoveOut: { moveOut(line.id) })
                    }
                    if !extras.isEmpty { extrasSection }
                }
            }
            Button { onConfirm(chosen, corrections, extras) } label: {
                Label("Ajouter au stock · \(QuantityFormatter.price(total))", systemImage: "checkmark")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(chosen.isEmpty && extras.isEmpty)
        }
        .padding(Theme.Spacing.m)
        .screenBackground()
        .sensoryFeedback(.selection, trigger: chosen.count)
        .sheet(item: Binding(get: { editing.map(Pick.init) }, set: { editing = $0?.id })) { pick in
            if let index = lines.firstIndex(where: { $0.id == pick.id }) { ReceiptLineSheet(line: $lines[index]).appAppearance() }
        }
        .sheet(item: Binding(get: { editingExtra.map(Pick.init) }, set: { editingExtra = $0?.id })) { pick in
            if let index = extras.firstIndex(where: { $0.id == pick.id }) { ReceiptExtraSheet(extra: $extras[index]).appAppearance() }
        }
    }

    private struct Pick: Identifiable { let id: UUID }

    private var extrasSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Hors plan · dépenses").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            ForEach(extras) { extra in
                Button { editingExtra = extra.id } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(extra.label.capitalized).font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textPrimary)
                            Text(extra.edited ? "\(extra.category) · retenu pour la prochaine fois" : extra.category)
                                .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                        }
                        Spacer()
                        Text(QuantityFormatter.price(extra.price)).font(Theme.Fonts.caption.monospacedDigit()).foregroundStyle(Theme.Colors.accent).underline(pattern: .dot)
                    }
                    .padding(.horizontal, Theme.Spacing.m)
                    .frame(minHeight: Theme.Layout.minTapHeight)
                    .cardStyle()
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The line is not a food of the plan (a mackerel read as tuna): it leaves the stock, counts in the spending, and the
    /// printed label is remembered as « not in the plan ».
    private func moveOut(_ id: UUID) {
        guard let index = lines.firstIndex(where: { $0.id == id }) else { return }
        let line = lines.remove(at: index)
        let extra = ReceiptExtra(label: line.match.label, category: "Épicerie", price: line.match.price, printed: line.match.label)
        movedOutIDs.insert(extra.id)
        extras.append(extra)
    }

    /// Re-assigns a line to another food (merging with a line already on it); the app remembers it for the next scans.
    private func change(_ id: UUID, to food: Ingredient) {
        guard let index = lines.firstIndex(where: { $0.id == id }), lines[index].match.food.id != food.id else { return }
        var moved = lines[index]
        moved.match.food = food
        moved.warning = nil
        moved.isSelected = true
        if let other = lines.firstIndex(where: { $0.id == food.id }) {
            lines[other].match.grams += moved.match.grams
            lines[other].match.price += moved.match.price
            lines[other].match.units = ReceiptMatch.sum(lines[other].match.units, moved.match.units)
            lines[other].isSelected = true
            lines[other].corrections.append(moved.match.label)
            lines.remove(at: index)
        } else {
            lines[index] = moved
        }
    }
}
