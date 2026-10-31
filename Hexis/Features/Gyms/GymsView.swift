import CoreLocation
import SwiftData
import SwiftUI

struct GymsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Gym.name) private var gyms: [Gym]
    @State private var newName = ""
    @State private var location = LocationService()
    @State private var message: String?

    var body: some View {
        List {
            Section("Salles") {
                ForEach(gyms) { gym in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(gym.name)
                            statusLine(for: gym)
                        }
                        Spacer()
                        Menu {
                            Button("Chercher sur la carte", systemImage: "magnifyingglass") {
                                Task { await search(gym) }
                            }
                            Button("Définir ici (GPS)", systemImage: "location.fill") {
                                Task { await setLocation(of: gym) }
                            }
                        } label: {
                            Image(systemName: "location.fill")
                                .foregroundStyle(gym.latitude == nil ? Theme.Colors.textSecondary : Theme.Colors.accent)
                                .frame(width: 44, height: 44)
                        }
                    }
                }
                .onDelete { offsets in
                    offsets.map { gyms[$0] }.forEach(context.delete)
                    context.saveReportingFailure()
                }
            }
            Section {
                HStack {
                    TextField("Nouvelle salle", text: $newName)
                    Button("Ajouter", action: add)
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .font(Theme.Fonts.body)
        .scrollContentBackground(.hidden)
        .screenBackground()
        .onAppear { UsageCounter.hit(.gyms) }
        .navigationTitle("Salles")
        .alert("Position", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    private func statusLine(for gym: Gym) -> some View {
        let issue = GymSetup.issue(for: gym.setupItem, among: gyms.map(\.setupItem))
        let saved = GymDefaults.places[gym.name]?.address ?? "Position enregistrée"
        return Text(issue?.message ?? saved)
            .font(Theme.Fonts.caption)
            .foregroundStyle(issue == nil ? Theme.Colors.textSecondary : Theme.Colors.accent)
    }

    private func setLocation(of gym: Gym) async {
        guard let here = await location.currentLocation() else {
            message = location.isDenied
                ? "Localisation refusée : autorise-la pour Hexis dans Réglages iOS › Confidentialité › Service de localisation."
                : "Position indisponible. Réessaie à l'entrée de la salle, avec un meilleur signal."
            return
        }
        guard here.horizontalAccuracy >= 0, here.horizontalAccuracy <= GymSetup.maxAccuracy else {
            message = "Position trop imprécise (±\(Int(here.horizontalAccuracy)) m). Réessaie à l'entrée de la salle."
            return
        }
        gym.latitude = here.coordinate.latitude
        gym.longitude = here.coordinate.longitude
        context.saveReportingFailure()
    }

    private func search(_ gym: Gym) async {
        guard let coordinate = await GymGeocoder.coordinate(forGymNamed: gym.name) else {
            message = "Salle introuvable sur la carte (réseau ou nom). Utilise « Définir ici (GPS) » sur place."
            return
        }
        gym.latitude = coordinate.latitude
        gym.longitude = coordinate.longitude
        context.saveReportingFailure()
    }

    private func add() {
        context.insert(Gym(name: newName.trimmingCharacters(in: .whitespaces)))
        context.saveReportingFailure()
        newName = ""
    }
}

#Preview {
    NavigationStack { GymsView() }
        .modelContainer(for: Gym.self, inMemory: true)
        .appAppearance()
}
