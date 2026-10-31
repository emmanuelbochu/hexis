import SwiftData
import SwiftUI

/// What the app learned from the user's data: regularity, deload, session length and cross-checked trends.
struct InsightsView: View {
    @Query(filter: #Predicate<WorkoutSession> { $0.stateRaw == "finished" }) private var sessions: [WorkoutSession]
    @Query(filter: #Predicate<SetLog> { $0.kindRaw == "work" }) private var sets: [SetLog]
    @Query private var exercises: [Exercise]
    @Query private var loads: [ExerciseLoad]
    @Query private var foods: [FoodEntry]
    @Environment(\.modelContext) private var context
    @Query private var gyms: [Gym]
    @State private var insights: [Insights.Insight] = []
    @State private var showsAll = false
    private static let visibleCount = 4

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                TrainingStatusSection()
                link("Bilan de la semaine", "calendar") { WeekReviewView() }
                link("Progrès par exercice", "chart.line.uptrend.xyaxis") { ExerciseListView() }
                link("Temps de séance", "timer") { TimeView() }
                Text("Ce que je remarque")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                if insights.isEmpty {
                    card("sparkles", "Pas encore assez de données", Edition.hasNutrition
                        ? "Il faut quelques séances par modèle pour croiser jour, heure, repos et alimentation."
                        : "Il faut quelques séances de chaque modèle pour croiser jour, heure et repos.")
                }
                ForEach(showsAll ? insights : Array(insights.prefix(Self.visibleCount))) { insight in
                    card(insight.symbol, insight.text, "Tendance sur \(insight.sampleSize) \(insight.unit).")
                }
                if insights.count > Self.visibleCount {
                    Button(showsAll ? "Moins" : "Voir les \(insights.count - Self.visibleCount) autres") { showsAll.toggle() }
                        .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: Theme.Layout.minTapHeight)
                }
            }
            .padding(Theme.Spacing.m)
        }
        .screenBackground()
        .onAppear { UsageCounter.hit(.analyse) }
        .navigationTitle("Analyse")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: sessions.count + foods.count) {
            let resolver = LoadResolver(loads: loads, exercises: exercises)
            // Only the original app has food and Health data to cross with the sessions.
            let intake = Edition.hasNutrition ? DailyIntake.load(in: context, since: Calendar.current.date(byAdding: .day, value: -540, to: .now) ?? .now) : [:]
            let points = Insights.points(sessions: sessions, sets: sets, loads: resolver, intake: intake)
            let since = Calendar.current.date(byAdding: .day, value: -90, to: .now) ?? .now
            let weights = Edition.usesHealth ? await HealthService.weights(since: since) : []
            let steps = Edition.usesHealth ? await HealthService.dailySteps(since: since) : []
            if Edition.usesHealth { await HealthService.authorize() }
            insights = Insights.ranked(Insights.insights(from: points)
                + (Edition.usesHealth ? BodyInsights.insights(points: points, steps: steps, weights: weights, intake: intake) : [])
                + PositionInsights.insights(sessions: sessions, sets: sets, names: Dictionary(exercises.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first }))
                + SpeedInsights.insights(sessions: sessions, gymNames: Dictionary(gyms.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })))
        }
    }

    private func link<Destination: View>(_ title: String, _ symbol: String, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: symbol).foregroundStyle(Theme.Colors.accent).frame(width: 28)
                Text(title).font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(Theme.Spacing.m)
            .frame(minHeight: Theme.Layout.minTapHeight)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private func card(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Image(systemName: symbol).foregroundStyle(Theme.Colors.accent).frame(width: 28)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title).font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textPrimary)
                Text(detail).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

#Preview {
    NavigationStack { InsightsView() }
        .modelContainer(for: WorkoutSession.self, inMemory: true)
        .appAppearance()
}
