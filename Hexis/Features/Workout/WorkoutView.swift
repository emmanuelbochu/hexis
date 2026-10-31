import SwiftData
import SwiftUI

struct WorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: WorkoutViewModel
    @State private var summarizing = false
    @State private var replacing: WorkoutViewModel.ExerciseGroup?

    init(model: WorkoutViewModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            topBar
            if summarizing {
                SessionEndView(model: model, onEnd: end, onResume: { model.reopen(); summarizing = false })
            } else {
                stats
                list
            }
        }
        .padding(.horizontal, Theme.Spacing.m)
        .screenBackground()
        .overlay(alignment: .bottom) {
            if model.rest.isRunning && !summarizing {
                RestBar(rest: model.rest).padding(Theme.Spacing.m)
            }
        }
        .sheet(item: $replacing) { group in
            ExercisePicker { model.replace(group, with: $0) }
                .appAppearance()
        }
        .onChange(of: model.isAllDone) { _, allDone in
            if allDone {
                model.finish()
                summarizing = true
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Theme.Colors.surface, in: Circle())
            }
            Text("Séance").font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            if !summarizing {
                Button("Terminer") { summarizing = true }
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.onAccent)
                    .padding(.horizontal, Theme.Spacing.m)
                    .frame(height: 40)
                    .background(Theme.Colors.accent, in: Capsule())
            }
        }
    }

    private var stats: some View {
        HStack {
            stat("Durée") {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(duration(context.date.timeIntervalSince(model.session.startedAt)))
                }
            }
            stat("Volume") { Text("\(Int(model.volume.rounded())) kg") }
            stat("Séries") { Text("\(model.workSetsDone)") }
            tiredToggle
        }
    }

    /// « Fatigué » is about the day, not one exercise: loads not started yet are held. A small icon, soft tint when on; the
    /// effect is listed in the adjustments, so no word or sentence takes room here.
    private var tiredToggle: some View {
        Button { model.toggleTired() } label: {
            Image(systemName: Feeling.tired.symbol)
                .font(Theme.Fonts.body)
                .foregroundStyle(model.isTired ? Theme.Colors.accent : Theme.Colors.textSecondary)
                .frame(width: 44, height: 44)
                .background(model.isTired ? Theme.Colors.accentSoft : Color.clear, in: Circle())
        }
        .accessibilityLabel("Fatigué")
        .sensoryFeedback(.selection, trigger: model.isTired)
    }

    private func stat<Content: View>(_ title: String, @ViewBuilder value: () -> Content) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            value().font(Theme.Fonts.headline.monospacedDigit()).foregroundStyle(Theme.Colors.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: Theme.Spacing.m) {
                    ForEach(model.groups) { group in
                        ExerciseCard(model: model, group: group, state: model.cardState(group)) { replacing = group }
                            .id(group.id)
                    }
                }
                .padding(.bottom, 120)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: model.currentIndex) {
                if let group = model.group(containing: model.currentIndex) {
                    withAnimation(.smooth(duration: 0.5)) { proxy.scrollTo(group.id, anchor: .top) }
                }
            }
        }
    }

    private func duration(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds), 0)
        let h = total / 3600, m = total % 3600 / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    private func end() {
        model.finish()
        dismiss()
    }
}
