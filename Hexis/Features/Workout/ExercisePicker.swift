import SwiftData
import SwiftUI

/// Searchable list of every exercise of both programs; calls `onPick` then dismisses. The swap is for this session only.
struct ExercisePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var exercises: [Exercise]
    @State private var search = ""
    let onPick: (Exercise) -> Void

    private var filtered: [(name: String, muscleGroup: String, exercise: Exercise?)] {
        let all = ExerciseLibrary.choices(stored: exercises)
        return search.isEmpty ? all : all.filter { $0.name.localizedCaseInsensitiveContains(search) || $0.muscleGroup.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List(filtered, id: \.name) { row in
                Button {
                    if let exercise = row.exercise ?? ExerciseLibrary.exercise(named: row.name, in: context) { onPick(exercise) }
                    dismiss()
                } label: {
                    VStack(alignment: .leading) {
                        Text(row.name).foregroundStyle(Theme.Colors.textPrimary)
                        Text(row.muscleGroup).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
            .font(Theme.Fonts.body)
            .scrollContentBackground(.hidden)
            .screenBackground()
            .searchable(text: $search, prompt: "Exercice ou muscle")
            .navigationTitle("Pour cette séance")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ExercisePicker { _ in }
        .modelContainer(for: Exercise.self, inMemory: true)
        .appAppearance()
}
