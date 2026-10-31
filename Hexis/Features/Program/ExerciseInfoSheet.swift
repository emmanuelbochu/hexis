import SwiftData
import SwiftUI
import UIKit

/// Short summary of an exercise of the program: picture, prescription, key points, weekly sets of its muscle against the target.
struct ExerciseInfoSheet: View {
    let name: String
    let item: TemplateExercise
    /// Sets the whole program gives this exercise's muscle each week.
    let weeklySets: Int?

    private var spec: ProgramSpec.Exercise? { ProgramCatalog.exercise(named: name) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                picture
                Text(name).font(Theme.Fonts.title).foregroundStyle(Theme.Colors.textPrimary)
                if let muscle = spec.map({ $0.target.isEmpty ? $0.muscleGroup : $0.target }), !muscle.isEmpty {
                    Text(muscle).font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.accent)
                }
                Text(prescription).font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textPrimary)
                if !item.tempo.isEmpty {
                    Text("Tempo : retour (étirement) – pause – effort, en secondes.")
                        .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                }
                if let points = spec?.points, !points.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        ForEach(points, id: \.self) { point in
                            Label { Text(Self.labeled(point)) } icon: { Image(systemName: "circle.fill").font(.system(size: 6)) }
                                .font(Theme.Fonts.body)
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .labelStyle(.titleAndIcon)
                        }
                    }
                    .padding(Theme.Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                }
                if let volume { Text(volume).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary) }
            }
            .padding(Theme.Spacing.m)
        }
        .screenBackground()
        .onAppear { UsageCounter.hit(.exerciseSheet) }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder private var picture: some View {
        if let image = ExerciseImage.assetNames(for: name).lazy.compactMap({ UIImage(named: $0) }).first {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        } else {
            ExerciseThumbnail(name: name, size: 120).frame(maxWidth: .infinity)
        }
    }

    private var prescription: String {
        let unit = spec?.unit ?? ""
        let range = item.repsMin == item.repsMax ? "\(item.repsMin)" : "\(item.repsMin)–\(item.repsMax)"
        var parts = ["\(item.sets) × \(range) \(unit.isEmpty ? "reps" : unit)", "Repos \(item.restSeconds / 60):\(String(format: "%02d", item.restSeconds % 60))", EffortScale.target(rir: item.targetRIR)]
        if !item.tempo.isEmpty { parts.append("Tempo \(item.tempo)") }
        return parts.joined(separator: " · ")
    }

    /// "Réglage : banc à 45°" → "Réglage" in bold, so the setup, the movement and the why are found at a glance.
    static func labeled(_ point: String) -> AttributedString {
        guard let colon = point.range(of: " : "), point.distance(from: point.startIndex, to: colon.lowerBound) <= 20 else {
            return AttributedString(point)
        }
        var label = AttributedString(String(point[..<colon.lowerBound]))
        label.font = Theme.Fonts.body.bold()
        return label + AttributedString(String(point[colon.lowerBound...]))
    }

    private var volume: String? {
        guard let muscle = spec?.muscleGroup, let sets = weeklySets, let target = ProgramCatalog.weeklyTargets[muscle] else { return nil }
        let priority = ProgramCatalog.isPriority(muscle: muscle) ? " (priorité)" : ""
        return "\(muscle) : \(sets) séries par semaine · cible \(target.lowerBound)–\(target.upperBound)\(priority)"
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        ExerciseInfoSheet(name: "Neck extension", item: TemplateExercise(order: 0, exerciseID: UUID(), sets: 3, repsMin: 15, repsMax: 20), weeklySets: 9).appAppearance()
    }
}
