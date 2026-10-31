import SwiftData
import SwiftUI

/// The running session, presented above the whole app (not from inside a pager page, where a page redraw closed it right away).
/// The view model is built once here: building it reads the history, which must not happen on every redraw.
struct ActiveWorkoutView: View {
    let session: WorkoutSession
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var templates: [WorkoutTemplate]
    @State private var model: WorkoutViewModel?

    var body: some View {
        Group {
            if let model {
                WorkoutView(model: model)
            } else {
                VStack(spacing: Theme.Spacing.m) {
                    ProgressView().tint(Theme.Colors.accent)
                    Button("Fermer") { dismiss() }
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .screenBackground()
            }
        }
        .appAppearance()
        .task(id: templates.count) {
            guard model == nil, let template = templates.first(where: { $0.id == session.templateID }) else { return }
            model = WorkoutViewModel(session: session, template: template, context: context)
        }
    }
}
