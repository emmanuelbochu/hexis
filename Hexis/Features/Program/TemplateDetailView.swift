import SwiftData
import SwiftUI

/// Read-only content of a session: exercises in order; a superset is one card titled « Superset » with its rest at the end.
struct TemplateDetailView: View {
    let template: WorkoutTemplate
    @Query private var exercises: [Exercise]
    @State private var shown: TemplateExercise?
    @State private var minutes: Int?
    @Environment(\.modelContext) private var context
    /// Sets per muscle over the whole program week, computed once.
    @State private var weekly: [String: Int] = [:]

    private var names: [UUID: Exercise] { Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) }) }
    private var blocks: [TemplateBlock] { template.blocks.sorted { $0.order < $1.order } }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.m) {
                Text("\(TemplateSummary(template, exercises: names).setCount) séries\(minutes.map { " · ~\($0) min" } ?? "")")
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                ForEach(blocks, id: \.order) { block in
                    blockCard(block: block, color: supersetColor(block))
                }
            }
            .padding(Theme.Spacing.m)
        }
        .screenBackground()
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $shown) { item in
            let name = names[item.exerciseID]?.name ?? ""
            ExerciseInfoSheet(name: name, item: item, weeklySets: weekly[names[item.exerciseID]?.muscleGroup ?? ""])
                .appAppearance()
        }
        .task {
            minutes = DurationStats.load(in: context)[template.id]
            let items = ProgramCatalog.week(of: template, in: template.program?.templates ?? [template]).flatMap { $0.blocks.flatMap(\.exercises) }
            weekly = items.reduce(into: [:]) { $0[names[$1.exerciseID]?.muscleGroup ?? "", default: 0] += $1.sets }
        }
    }

    private func isRehab(_ block: TemplateBlock) -> Bool {
        guard let rehab = ProgramCatalog.rehab else { return false }
        return Rehab.slot(of: block.exercises.sorted { $0.order < $1.order }.map { names[$0.exerciseID]?.name ?? "" }, in: rehab) != nil
    }

    /// Same color as in the session: the n-th superset of the template gets the n-th color.
    private func supersetColor(_ block: TemplateBlock) -> Color? {
        guard block.exercises.count > 1, !isRehab(block) else { return nil }
        let rank = blocks.filter { $0.order < block.order && $0.exercises.count > 1 && !isRehab($0) }.count
        return Theme.Colors.superset(rank)
    }

    private func blockCard(block: TemplateBlock, color: Color?) -> some View {
        let items = block.exercises.sorted { $0.order < $1.order }
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if isRehab(block) {
                Label(ProgramCatalog.rehab?.name ?? "Réhab", systemImage: "bandage")
                    .font(Theme.Fonts.caption.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            ForEach(Array(items.enumerated()), id: \.element.order) { i, item in
                if i > 0 { Divider().overlay(Theme.Colors.separator) }
                // In a superset the rest comes after the last exercise only.
                exerciseRow(item, showsRest: color == nil || i == items.count - 1)
            }
        }
        .padding(Theme.Spacing.m)
        .padding(.leading, color == nil ? 0 : Theme.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .supersetBar(color)
    }

    private func clock(_ seconds: Int) -> String { "\(seconds / 60):\(String(format: "%02d", seconds % 60))" }

    private func exerciseRow(_ item: TemplateExercise, showsRest: Bool) -> some View {
        Button { shown = item } label: { exerciseLabel(item, showsRest: showsRest) }
            .buttonStyle(.plain)
    }

    private func exerciseLabel(_ item: TemplateExercise, showsRest: Bool) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            ExerciseThumbnail(name: names[item.exerciseID]?.name ?? "", size: 48)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Text(names[item.exerciseID]?.name ?? "Exercice").font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
                    if names[item.exerciseID]?.isUnilateral == true {
                        Image(systemName: "arrow.left.arrow.right").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                Text("\(item.sets) × \(repsText(item))")
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(details(item, showsRest: showsRest)).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "info.circle").font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textSecondary)
        }
        .contentShape(Rectangle())
    }

    private func repsText(_ item: TemplateExercise) -> String {
        let unit = ProgramCatalog.exercise(named: names[item.exerciseID]?.name ?? "")?.unit ?? ""
        let range = item.repsMin == item.repsMax ? "\(item.repsMin)" : "\(item.repsMin)–\(item.repsMax)"
        return "\(range) \(unit.isEmpty ? "reps" : unit)"
    }

    private func details(_ item: TemplateExercise, showsRest: Bool) -> String {
        var parts = showsRest ? ["Repos \(clock(item.restSeconds))"] : []
        parts.append(EffortScale.target(rir: item.targetRIR))
        if !item.tempo.isEmpty { parts.append("Tempo \(item.tempo)") }
        return parts.joined(separator: " · ")
    }
}
