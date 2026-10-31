import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<WorkoutSession> { $0.stateRaw == "finished" }, sort: \WorkoutSession.startedAt, order: .reverse)
    private var sessions: [WorkoutSession]
    @Query private var gyms: [Gym]
    @Query private var templates: [WorkoutTemplate]
    @State private var gymFilter: UUID?
    @State private var journey: Journey?

    private var shown: [WorkoutSession] {
        gymFilter.map { id in sessions.filter { $0.gymID == id } } ?? sessions
    }

    var body: some View {
        VStack(spacing: 0) {
            PageActionRow(title: "Historique") {
                if Edition.hasGymPicker, gyms.count > 1 {
                    Menu {
                        Button("Toutes") { gymFilter = nil }
                        ForEach(gyms) { gym in Button(gym.name) { gymFilter = gym.id } }
                    } label: { Label("Salle", systemImage: "line.3.horizontal.decrease.circle").frame(width: 44, height: 44) }
                }
                NavigationLink { InsightsView() } label: { Label("Analyse", systemImage: "sparkles").frame(width: 44, height: 44) }
            }
            if sessions.isEmpty {
                PlaceholderView(
                    systemImage: "clock.arrow.circlepath",
                    title: "Historique",
                    subtitle: "Tes séances passées apparaîtront ici."
                )
            } else {
                list
            }
        }
        .screenBackground()
        .task(id: sessions.count) { journey = await Journey.load(in: context) }
    }

    /// The progress card, then the sessions as one grouped list (a lazy stack: the history can be long).
    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Spacing.m) {
                if let journey { JourneyCard(journey: journey) }
                Text("Séances").font(Theme.Fonts.section).foregroundStyle(Theme.Colors.textPrimary).padding(.top, Theme.Spacing.s)
                LazyVStack(spacing: 0) {
                    ForEach(Array(shown.enumerated()), id: \.element.id) { index, session in
                        if index > 0 { Divider().overlay(Theme.Colors.separator).padding(.leading, Theme.Spacing.m) }
                        row(session)
                    }
                }
                .cardStyle()
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.bottom, Theme.Spacing.m)
        }
    }

    private func row(_ session: WorkoutSession) -> some View {
        NavigationLink {
            SessionDetailView(session: session, title: title(session))
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title(session)).font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
                    Text(subtitle(session)).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(.horizontal, Theme.Spacing.m)
            .frame(minHeight: Theme.Layout.minTapHeight + Theme.Spacing.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func title(_ session: WorkoutSession) -> String {
        templates.first { $0.id == session.templateID }?.name ?? "Séance"
    }

    private func subtitle(_ session: WorkoutSession) -> String {
        let gym = gyms.first { $0.id == session.gymID }?.name
        let date = session.startedAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        return [date, gym].compactMap { $0 }.joined(separator: " · ")
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: WorkoutSession.self, inMemory: true)
        .appAppearance()
}
