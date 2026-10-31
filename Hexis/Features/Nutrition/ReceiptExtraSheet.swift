import SwiftUI

/// A line outside the plan: say what it is in your own words, the AI names it and the app remembers it for the next ticket.
struct ReceiptExtraSheet: View {
    @Binding var extra: ReceiptExtra
    @Environment(\.dismiss) private var dismiss
    @State private var said = ""
    @State private var price = 0.0
    @State private var working = false

    var body: some View {
        NavigationStack {
            Form {
                if !extra.printed.isEmpty { Section("Sur le ticket") { Text(extra.printed).foregroundStyle(Theme.Colors.textSecondary) } }
                Section("Actuellement") { LabeledContent(extra.label.capitalized, value: extra.category) }
                Section("C'est quoi ?") { TextField("Gel douche, 2 packs d'eau…", text: $said, axis: .vertical) }
                Section("Prix payé (€)") { TextField("0", value: $price, format: .number).keyboardType(.decimalPad) }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Hors plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button(working ? "…" : "OK") { commit() }.disabled(working) }
        }
        .presentationDetents([.medium])
        .onAppear { price = extra.price }
    }

    private func commit() {
        working = true
        Task {
            extra.price = max(0, price)
            if !said.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let tidy = await ExtraTidy.tidy(printed: extra.printed, said: said, current: extra.label)
                extra.label = tidy.name
                extra.category = tidy.category
                extra.edited = !extra.printed.isEmpty
            }
            dismiss()
        }
    }
}
