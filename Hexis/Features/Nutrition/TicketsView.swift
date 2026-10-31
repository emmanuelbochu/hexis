import SwiftData
import SwiftUI

/// The scanned receipts, newest first, with what the app counted on each line and its price; a line is retyped by tapping it.
struct TicketsView: View {
    @Query(sort: \PurchaseLog.date, order: .reverse) private var purchases: [PurchaseLog]
    @Query(sort: \ExtraPurchase.date, order: .reverse) private var extras: [ExtraPurchase]
    @Query private var foods: [Ingredient]
    @State private var editing: TicketLine?
    @State private var deleting: ReceiptTicket?
    @Environment(\.modelContext) private var context

    var body: some View {
        let byID = Dictionary(foods.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                let tickets = ReceiptHistory.tickets(purchases: purchases, extras: extras)
                if tickets.isEmpty {
                    Text("Aucun ticket scanné").font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textSecondary)
                }
                ForEach(tickets) { ticket in
                    Text(ticket.date.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute()))
                        .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                    VStack(spacing: Theme.Spacing.s) {
                        ForEach(ticket.purchases) { log in
                            let food = byID[log.ingredientID]
                            line("\(food?.emoji ?? "") \(food?.name ?? "Aliment retiré")", QuantityFormatter.weight(log.grams), log.price) { editing = .plan(log) }
                        }
                        ForEach(ticket.extras) { extra in
                            line(extra.label.capitalized, "hors plan", extra.price) { editing = .extra(extra) }
                        }
                        Button("Supprimer le ticket", systemImage: "trash", role: .destructive) { deleting = ticket }
                            .font(Theme.Fonts.caption)
                            .frame(maxWidth: .infinity, minHeight: Theme.Layout.minTapHeight, alignment: .leading)
                        HStack {
                            Text("Total").font(Theme.Fonts.headline)
                            Spacer()
                            Text(QuantityFormatter.price(ticket.total)).font(Theme.Fonts.headline.monospacedDigit()).foregroundStyle(Theme.Colors.accent)
                        }
                    }
                    .padding(Theme.Spacing.m)
                    .cardStyle()
                }
            }
            .padding(Theme.Spacing.m)
        }
        .screenBackground()
        .navigationTitle("Tickets")
        .alert("Supprimer ce ticket ?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) {
                if let deleting { ReceiptHistory.remove(deleting, foods: byID, in: context) }
                context.saveReportingFailure()
            }
        } message: {
            Text("Le stock et les dépenses reviennent comme avant ce ticket.")
        }
        .sheet(item: $editing) { TicketLineSheet(line: $0, foods: byID).appAppearance() }
    }

    private func line(_ title: String, _ detail: String, _ price: Double, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(title).font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textPrimary)
                    Text(detail).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                Text(QuantityFormatter.price(price)).font(Theme.Fonts.body.monospacedDigit()).foregroundStyle(Theme.Colors.textPrimary)
            }
            .frame(minHeight: Theme.Layout.minTapHeight)
        }
        .buttonStyle(.plain)
    }
}

/// A line of a ticket, plan food or not.
enum TicketLine: Identifiable {
    case plan(PurchaseLog)
    case extra(ExtraPurchase)

    var id: PersistentIdentifier {
        switch self {
        case .plan(let log): log.persistentModelID
        case .extra(let extra): extra.persistentModelID
        }
    }
}

#Preview {
    NavigationStack { TicketsView() }
        .modelContainer(for: [PurchaseLog.self, ExtraPurchase.self, Ingredient.self], inMemory: true)
        .appAppearance()
}
