import SwiftData
import SwiftUI

/// Weekly review: volume, effort, muscles trained, records and plateaus.
struct WeekReviewView: View {
    @Environment(\.modelContext) private var context
    @State private var offset = 0
    @State private var data: Snapshot?

    /// Everything shown, computed once per week shown (never in `body`: a full history froze the app).
    private struct Snapshot {
        var week: WeekReview
        var previous: WeekReview
        var weeklyTarget: Int
        var isDeload: Bool
        var findings: [(name: String, message: String)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                if let data {
                    weekPicker(data.week)
                    if data.week.sessionCount == 0 {
                        PlaceholderView(systemImage: "calendar", title: "Semaine vide", subtitle: "Aucune séance terminée cette semaine.")
                            .frame(height: 260)
                    } else {
                        tiles(data.week, previous: data.previous, target: data.weeklyTarget)
                        muscleCheck(data.week, isDeload: data.isDeload)
                        if !data.week.records.isEmpty { records(data.week) }
                    }
                    BodyCard(weekEnd: data.week.end)
                    attention(data.findings)
                }
            }
            .padding(Theme.Spacing.m)
        }
        .screenBackground()
        .onAppear { UsageCounter.hit(.weekReview) }
        .navigationTitle("Bilan")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: offset) { load() }
    }

    /// The history, read once: moving between weeks only recomputes the week shown.
    private struct Source {
        var sessions: [WorkoutSession]
        var sets: [SetLog]
        var byID: [UUID: Exercise]
        var resolver: LoadResolver
        var cycle: TrainingCycle
        var weeklyTarget: Int
        var findings: [(name: String, message: String)]
    }

    @State private var source: Source?

    private func makeSource() -> Source {
        let finished = (try? context.fetch(FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.stateRaw == "finished" }))) ?? []
        let sets = (try? context.fetch(FetchDescriptor<SetLog>(predicate: #Predicate { $0.kindRaw == "work" }))) ?? []
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let loads = (try? context.fetch(FetchDescriptor<ExerciseLoad>())) ?? []
        let deloads = (try? context.fetch(FetchDescriptor<DeloadWeek>())) ?? []
        let programs = (try? context.fetch(FetchDescriptor<Program>(predicate: #Predicate { $0.isActive }))) ?? []
        let feelings = (try? context.fetch(FetchDescriptor<ExerciseFeeling>())) ?? []
        let byID = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let cycle = TrainingCycle(deloadStarts: deloads.map(\.start))
        let findings = StagnationDetector.findings(sets: sets.filter { !HistorySeed.isImported($0.sessionID) }, feelings: feelings, cycle: cycle)
            .map { (name: byID[$0.exerciseID]?.name ?? "Exercice", message: $0.message) }
        return Source(
            sessions: finished, sets: sets, byID: byID, resolver: LoadResolver(loads: loads, exercises: exercises), cycle: cycle,
            weeklyTarget: programs.first.map { ProgramCatalog.usualWeek($0.templates).count } ?? 4, findings: findings
        )
    }

    private func load() {
        let src = source ?? makeSource()
        source = src
        func review(_ shift: Int) -> WeekReview {
            WeekReview(
                start: WeekReview.weekStart(containing: .now, offset: offset + shift), sessions: src.sessions, sets: src.sets,
                exercises: src.byID, loads: src.resolver
            )
        }
        let week = review(0)
        data = Snapshot(
            week: week, previous: review(-1), weeklyTarget: src.weeklyTarget,
            isDeload: src.cycle.isDeload(week.start), findings: src.findings
        )
    }

    private func weekPicker(_ week: WeekReview) -> some View {
        HStack {
            Button { offset -= 1 } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
            Spacer()
            Text("\(week.start.formatted(.dateTime.day().month(.abbreviated))) – \(week.end.formatted(.dateTime.day().month(.abbreviated)))")
                .font(Theme.Fonts.headline)
            Spacer()
            Button { offset += 1 } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                .disabled(offset >= 0)
        }
        .foregroundStyle(Theme.Colors.textPrimary)
    }
}

#Preview {
    NavigationStack { WeekReviewView() }
        .modelContainer(for: WorkoutSession.self, inMemory: true)
        .appAppearance()
}
