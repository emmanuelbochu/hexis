import SwiftData
import SwiftUI

/// How the sessions really went: order, time per exercise, rests against the plan, where time can be saved.
struct TimeView: View {
    @Environment(\.modelContext) private var context
    /// Everything is read once when the screen opens (no live queries: nothing can loop or refetch while it is shown).
    @State private var loaded: Loaded?

    private struct Loaded {
        var timelines: [SessionTimeline]
        var summary: TimeInsights.Summary?
        var names: [UUID: String]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                if let loaded {
                    if let last = loaded.timelines.first(where: \.isReliable) { lastSession(last, names: loaded.names) }
                    if let summary = loaded.summary { savings(summary, names: loaded.names) } else {
                        card("timer", "Pas encore assez de données", "Il faut 3 séances faites avec l'app (l'heure de chaque série est enregistrée).")
                    }
                } else {
                    ProgressView().tint(Theme.Colors.accent).frame(maxWidth: .infinity)
                }
            }
            .padding(Theme.Spacing.m)
        }
        .screenBackground()
        .onAppear { UsageCounter.hit(.time) }
        .navigationTitle("Temps")
        .navigationBarTitleDisplayMode(.inline)
        .task { if loaded == nil { loaded = load() } }
    }

    private func load() -> Loaded {
        var latest = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.stateRaw == "finished" }, sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        latest.fetchLimit = 8
        let sessions = (try? context.fetch(latest)) ?? []
        let ids = sessions.map(\.id)
        let sets = (try? context.fetch(FetchDescriptor<SetLog>(predicate: #Predicate { ids.contains($0.sessionID) }))) ?? []
        let bySession = Dictionary(grouping: sets, by: \.sessionID)
        let templateIDs = sessions.compactMap(\.templateID)
        let templates = (try? context.fetch(FetchDescriptor<WorkoutTemplate>(predicate: #Predicate { templateIDs.contains($0.id) }))) ?? []
        let timelines = sessions.map { session in
            SessionTimeline(sets: bySession[session.id] ?? [], plan: plan(templates.first { $0.id == session.templateID }))
        }
        let names = Dictionary(
            ((try? context.fetch(FetchDescriptor<Exercise>())) ?? []).map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first }
        )
        return Loaded(timelines: timelines, summary: TimeInsights.summary(timelines), names: names)
    }

    private func plan(_ template: WorkoutTemplate?) -> SessionTimeline.Plan {
        guard let template else { return .init() }
        var plan = SessionTimeline.Plan()
        for block in template.blocks.sorted(by: { $0.order < $1.order }) {
            for item in block.exercises.sorted(by: { $0.order < $1.order }) {
                plan.rest[item.exerciseID] = item.restSeconds
                plan.order.append(item.exerciseID)
                if block.exercises.count > 1 { plan.supersets.insert(item.exerciseID) }
            }
        }
        return plan
    }

    private func lastSession(_ timeline: SessionTimeline, names: [UUID: String]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Dernière séance, dans l'ordre réel").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            ForEach(timeline.entries) { entry in
                HStack {
                    Text("\(entry.order). \(names[entry.exerciseID] ?? "Exercice")")
                        .font(Theme.Fonts.body)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    if entry.movedFromProgram {
                        Image(systemName: "arrow.up.arrow.down").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.accent)
                    }
                    Spacer()
                    Text(detail(entry)).font(Theme.Fonts.caption.monospacedDigit()).foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func detail(_ entry: SessionTimeline.Entry) -> String {
        let minutes = max(1, Int((entry.span / 60).rounded()))
        guard let rest = entry.medianRest else { return "\(minutes) min" }
        return "\(minutes) min · repos \(clock(rest))"
    }

    @ViewBuilder
    private func savings(_ summary: TimeInsights.Summary, names: [UUID: String]) -> some View {
        Text("Où gagner du temps").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
        ForEach(summary.sinks) { sink in
            card(
                "hourglass", "\(names[sink.exerciseID] ?? "Exercice") : +\(clock(Double(sink.extraPerSet))) par série",
                "Repos prévu \(clock(Double(sink.plannedRest))), sur \(sink.sessions) séances."
            )
        }
        if summary.sinks.isEmpty { card("checkmark.circle", "Tes repos respectent le plan", "Sur \(summary.sessions) séances.") }
        if summary.pauseMinutes > 0 {
            card("pause.circle", "\(summary.pauseMinutes) min de pause en moyenne", "Coupures de plus de 8 min, sur \(summary.sessions) séances.")
        }
        if summary.reordered > 0 {
            card("arrow.up.arrow.down", "Ordre changé dans \(summary.reordered) séances sur \(summary.sessions)", "Machine prise ou envie : l'ordre réel est enregistré pour comparer les performances.")
        }
    }

    private func clock(_ seconds: Double) -> String { String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60) }

    private func card(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Image(systemName: symbol).foregroundStyle(Theme.Colors.accent).frame(width: 28)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title).font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textPrimary)
                Text(detail).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

#Preview {
    NavigationStack { TimeView() }
        .modelContainer(for: WorkoutSession.self, inMemory: true)
        .appAppearance()
}
