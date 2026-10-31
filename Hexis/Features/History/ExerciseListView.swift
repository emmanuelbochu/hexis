import SwiftData
import SwiftUI

/// Exercises that have logged sets, leading to their records and curve.
struct ExerciseListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var performedIDs: Set<UUID> = []

    private var performed: [Exercise] { exercises.filter { performedIDs.contains($0.id) } }

    var body: some View {
        List(performed) { exercise in
            NavigationLink(exercise.name) { ExerciseProgressView(exercise: exercise) }
                .frame(minHeight: Theme.Layout.minTapHeight)
                .listRowBackground(Theme.Colors.surface)
        }
        .font(Theme.Fonts.body)
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Progrès")
        .task {
            // Only the exercise id of each set is read, once.
            var descriptor = FetchDescriptor<SetLog>(predicate: #Predicate { $0.kindRaw == "work" })
            descriptor.propertiesToFetch = [\.exerciseID]
            performedIDs = Set(((try? context.fetch(descriptor)) ?? []).map(\.exerciseID))
        }
    }
}
