import SwiftData
import SwiftUI

struct SessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let session: WorkoutSession
    let title: String
    @State private var confirmsDelete = false
    @Query private var sets: [SetLog]
    @Query private var exercises: [Exercise]
    @Query private var notes: [SessionNote]
    @Query private var loads: [ExerciseLoad]

    init(session: WorkoutSession, title: String) {
        self.session = session
        self.title = title
        let id = session.id
        _notes = Query(filter: #Predicate<SessionNote> { $0.sessionID == id })
        _sets = Query(filter: #Predicate<SetLog> { $0.sessionID == id }, sort: \SetLog.completedAt)
    }

    /// Exercises in the order they were really performed (time of validation), with their logged sets.
    private var groups: [(id: UUID, name: String, sets: [SetLog])] {
        var order: [UUID] = []
        var seen: Set<UUID> = []
        for set in sets where seen.insert(set.exerciseID).inserted { order.append(set.exerciseID) }
        let names = Dictionary(exercises.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let byExercise = Dictionary(grouping: sets, by: \.exerciseID)
        return order.map { id in (id, names[id] ?? "Exercice", byExercise[id] ?? []) }
    }

    var body: some View {
        let summary = SessionSummary(
            sets: sets, startedAt: session.startedAt, endedAt: session.endedAt, loads: LoadResolver(loads: loads, exercises: exercises)
        )
        List {
            Section {
                HStack {
                    stat(summary.durationText, "durée")
                    stat("\(summary.workSets)", "séries")
                    stat(summary.volumeText, "volume")
                }
            }
            .listRowBackground(Theme.Colors.surface)
            if let note = notes.first(where: { $0.exerciseID == nil }), !note.text.isEmpty {
                Section("Note") { noteRow(note) }.listRowBackground(Theme.Colors.surface)
            }
            ForEach(groups, id: \.id) { group in
                Section(group.name) {
                    ForEach(group.sets.indices, id: \.self) { i in row(group.sets[i]) }
                    if let note = notes.first(where: { $0.exerciseID == group.id }) { noteRow(note) }
                }
                .listRowBackground(Theme.Colors.surface)
            }
            Section {
                Button("Supprimer cette séance", role: .destructive) { confirmsDelete = true }
                    .frame(maxWidth: .infinity, minHeight: Theme.Layout.minTapHeight)
            }
            .listRowBackground(Theme.Colors.surface)
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Supprimer cette séance ?", isPresented: $confirmsDelete) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive, action: delete)
        } message: {
            Text("Une sauvegarde est faite juste avant.")
        }
    }

    /// Leaves the screen first so nothing reads the session once it is gone.
    private func delete() {
        let target = session
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            SessionDeleter.delete(target, in: context)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack {
            Text(value).font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.accent)
            Text(label).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func noteRow(_ note: SessionNote) -> some View {
        HStack {
            if note.hasPain { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.Colors.accent) }
            Text(note.text.isEmpty ? "Gêne signalée" : note.text)
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private func row(_ set: SetLog) -> some View {
        var label = "\(set.weight.formatted()) kg × \(set.reps)"
        if let side = set.side { label += side == .left ? " · G" : " · D" }
        return HStack {
            Text(label).font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            if set.kind == .warmup {
                Text("échauff.").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }
}
