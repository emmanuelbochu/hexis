import Charts
import SwiftData
import SwiftUI

/// Records and a weight curve for one exercise.
struct ExerciseProgressView: View {
    let exercise: Exercise
    @Query private var sets: [SetLog]

    init(exercise: Exercise) {
        self.exercise = exercise
        let id = exercise.id
        _sets = Query(filter: #Predicate<SetLog> { $0.exerciseID == id })
    }

    var body: some View {
        let points = PersonalRecords.points(from: sets)
        List {
            if let records = PersonalRecords.records(from: sets) {
                Section("Records") {
                    row("Charge max", "\(records.maxWeight.formatted()) kg")
                    row("Reps max", "\(records.maxReps)")
                    row("Volume max / séance", "\(Int(records.maxVolume)) kg")
                }
                .listRowBackground(Theme.Colors.surface)
                if points.count > 1 {
                    Section("Charge max par séance") {
                        Chart(points) {
                            LineMark(x: .value("Date", $0.date), y: .value("kg", $0.topWeight))
                            PointMark(x: .value("Date", $0.date), y: .value("kg", $0.topWeight))
                        }
                        .foregroundStyle(Theme.Colors.accent)
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 180)
                    }
                    .listRowBackground(Theme.Colors.surface)
                }
                DiagnosisSection(exerciseID: exercise.id)
            } else {
                Text("Pas encore de données.").foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .font(Theme.Fonts.body)
        .scrollContentBackground(.hidden)
        .screenBackground()
        .onAppear { UsageCounter.hit(.exerciseProgress) }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            Text(value).foregroundStyle(Theme.Colors.textPrimary)
        }
    }
}
