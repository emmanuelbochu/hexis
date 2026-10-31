import SwiftData
import SwiftUI

/// The active program, read only. It comes from the bundled `Program.json` (see `ProgramSync`).
struct ProgramView: View {
    @Query(filter: #Predicate<Program> { $0.isActive }) private var programs: [Program]
    @Query private var exercises: [Exercise]
    @Environment(\.modelContext) private var context
    /// Real average duration per template, read once (`DurationStats`).
    @State private var durations: [UUID: Int] = [:]

    private var exerciseByID: [UUID: Exercise] {
        Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
    }

    var body: some View {
        Group {
            if let program = programs.first {
                list(program)
            } else {
                PlaceholderView(
                    systemImage: "list.bullet.rectangle.fill",
                    title: "Aucun programme",
                    subtitle: "Ajoute Program.json au projet et recompile."
                )
            }
        }
        .screenBackground()
    }

    private func list(_ program: Program) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                Text(program.name).font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textSecondary)
                let sorted = program.templates.sorted { $0.order < $1.order }
                let usual = ProgramCatalog.usualWeek(sorted)
                cards(usual)
                if usual.count < sorted.count {
                    // Proposed by itself when the week can only hold 3 sessions (`WeekRotation`).
                    Text("Semaine à 3 séances").font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.top, Theme.Spacing.s)
                    cards(sorted.filter { !usual.contains($0) })
                }
            }
            .padding(Theme.Spacing.m)
        }
        .task { durations = DurationStats.load(in: context) }
    }
}

extension ProgramView {
    private func summary(_ template: WorkoutTemplate) -> TemplateSummary {
        var summary = TemplateSummary(template, exercises: exerciseByID)
        summary.minutes = durations[template.id]
        return summary
    }

    private func cards(_ templates: [WorkoutTemplate]) -> some View {
        ForEach(templates) { template in
            NavigationLink {
                TemplateDetailView(template: template)
            } label: {
                TemplateCard(template: template, summary: summary(template))
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    ProgramView()
        .modelContainer(for: Program.self, inMemory: true)
        .appAppearance()
}
