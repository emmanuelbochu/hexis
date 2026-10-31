import SwiftData
import SwiftUI

/// Card: title, notes and the table of sets of one exercise.
struct ExerciseCard: View {
    let model: WorkoutViewModel
    let group: WorkoutViewModel.ExerciseGroup
    var state: WorkoutViewModel.CardState = .upcoming
    let onReplace: () -> Void
    @State private var gaugeRow: GaugeRow?
    @State private var expanded = false

    private struct GaugeRow: Identifiable {
        let index: Int
        var id: Int { index }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            header
            summary
            if expanded { details.onAppear { UsageCounter.hit(.exerciseDetails) } }
            GymNoteLine(exerciseID: group.exerciseID, gymID: model.session.gymID, sessionID: model.session.id, showsSetting: expanded)
            if model.lastFeeling(group.exerciseID) == .pain {
                Label("Gêne la dernière fois", systemImage: Feeling.pain.symbol)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.accent)
            }
            sets
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .supersetBar(model.supersetIndex(group).map(Theme.Colors.superset))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(Theme.Colors.accent, lineWidth: 1.5)
                .opacity(state == .active ? 0.9 : 0)
        }
        .opacity(opacity)
        .animation(.smooth(duration: 0.35), value: state)
        .animation(.snappy, value: model.done)
        .sensoryFeedback(.success, trigger: model.records(group).count)
        .onChange(of: model.records(group).count) { old, new in if new > old { SoundService.play(.record) } }
        .sheet(item: $gaugeRow) { row in
            Group {
                if Edition.isElle {
                    SimpleEffortSheet(suggested: model.suggestedRPE(row.index)) { model.setRPE(row.index, $0) }
                } else {
                    EffortGaugeSheet(rpe: model.suggestedRPE(row.index)) { model.setRPE(row.index, $0) }
                }
            }
            .appAppearance()
        }
    }

    @ViewBuilder private var sets: some View {
            let medals = model.records(group)
            columnTitles
            ForEach(visibleRows, id: \.self) { i in
                SetRow(
                    label: model.rowLabel(i), isWarmup: model.steps[i].warmupPercent != nil,
                    previous: model.previousText(i),
                    weight: Binding(get: { model.values[i]?.weight ?? 0 }, set: { model.setWeight(i, $0) }),
                    reps: Binding(get: { model.values[i]?.reps ?? 0 }, set: { model.setReps(i, $0) }),
                    rpe: model.values[i]?.rpe, targetRPE: 10 - model.steps[i].targetRIR,
                    isDone: model.done.contains(i), isCurrent: model.currentIndex == i, record: medals[i],
                    onEffort: { gaugeRow = GaugeRow(index: i) }, onToggle: { model.toggle(i) }
                )
            }
    }

    /// The active exercise is fully lit; its partner and the rest are toned down, finished ones the most.
    private var opacity: Double {
        switch state {
        case .active: 1
        case .partner: 0.85
        case .upcoming: 0.7
        case .finished: 0.4
        }
    }

    /// Folded: sets × reps and effort, a dot when the app changed something. Tap to unfold.
    private var summary: some View {
        Button { withAnimation(.snappy) { expanded.toggle() } } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Text(model.subtitle(group)).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                if model.isAdjusted(group) {
                    Image(systemName: "wand.and.stars").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.accent)
                }
                Spacer()
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .frame(minHeight: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ForEach(model.details(group), id: \.self) { line in
                Text(line).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var visibleRows: [Int] { model.visibleRows(group) }

    private var header: some View {
        HStack(spacing: Theme.Spacing.s) {
            ExerciseThumbnail(name: group.name)
            Text(group.name)
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.accent)
                .lineLimit(2)
                .onTapGesture { withAnimation(.snappy) { expanded.toggle() } }
            if model.hasPain(group.exerciseID) {
                Image(systemName: Feeling.pain.symbol).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.accent)
            }
            if !model.records(group).isEmpty {
                Image(systemName: "medal.fill").font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.record)
                    .transition(.scale.combined(with: .opacity))
            }
            Spacer()
            ExerciseNotesView(sessionID: model.session.id, exerciseID: group.exerciseID, gymID: model.session.gymID)
                .id(group.exerciseID)
            Menu {
                Button(model.hasPain(group.exerciseID) ? "Retirer la gêne" : "Signaler une gêne", systemImage: Feeling.pain.symbol) {
                    model.togglePain(group.exerciseID)
                }
                Button("Remplacer l'exercice", systemImage: "arrow.triangle.2.circlepath", action: onReplace)
                Menu("Poids saisi", systemImage: "scalemass") {
                    let current = model.loadProfile(group.exerciseID, name: group.name)
                    ForEach(LoadProfile.presets, id: \.title) { preset in
                        Toggle(preset.title, isOn: Binding(
                            get: { current == preset.profile },
                            set: { _ in model.setLoad(preset.profile, for: group.exerciseID) }
                        ))
                    }
                }
                if model.hasPendingWarmups(group) {
                    Button("Passer l'échauffement", systemImage: "forward.end") { model.skipWarmups(of: group) }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 44, height: Theme.Layout.minTapHeight)
                    .contentShape(Rectangle())
            }
        }
    }

    private var columnTitles: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text("SÉRIE").frame(width: SetRow.Column.label)
            Text("PRÉCÉD.").frame(maxWidth: .infinity)
            Text("KG").frame(width: SetRow.Column.kg)
            Text(model.repsTitle(group)).frame(width: SetRow.Column.reps)
            Text(Edition.isElle ? "Reste" : "RPE").frame(width: SetRow.Column.effort)
            Image(systemName: "checkmark").frame(width: SetRow.Column.check)
        }
        .font(.system(size: 11, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .foregroundStyle(Theme.Colors.textSecondary)
        .padding(.horizontal, Theme.Spacing.s)
    }
}
