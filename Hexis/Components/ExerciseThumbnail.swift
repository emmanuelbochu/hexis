import SwiftUI
import UIKit

/// Exercise picture: the muscle worked on a body (front or back) plus a badge for the equipment (cable, machine, smith…).
/// An exercise picture asset (`ExerciseImage.assetNames`), when present, replaces the drawn body.
struct ExerciseThumbnail: View {
    let name: String
    var size: CGFloat = 44

    private var visual: ExerciseVisual { .guess(name: name) }

    var body: some View {
        let picture = ExerciseImage.assetNames(for: name).lazy.compactMap { UIImage(named: $0) }.first
        Group {
            if let image = picture {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                BodyFigure(muscle: visual.muscle, back: visual.showsBack).padding(size * 0.08)
            }
        }
        .frame(width: size, height: size)
        .background(Theme.Colors.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).stroke(Theme.Colors.border, lineWidth: 1))
        .overlay(alignment: .bottomTrailing) {
            if picture == nil { badge }
        }
        .padding(.trailing, picture == nil ? size * 0.1 : 0)
        .accessibilityHidden(true)
    }

    private var badge: some View {
        Group {
            EquipmentGlyph(equipment: visual.equipment)
                .padding(size * 0.08)
                .frame(width: size * 0.46, height: size * 0.46)
                .background(Theme.Colors.surface, in: Circle())
                .overlay(Circle().stroke(Theme.Colors.accent.opacity(0.6), lineWidth: 1))
                .offset(x: size * 0.1, y: size * 0.1)
        }
    }
}

#Preview {
    HStack {
        ExerciseThumbnail(name: "Développé pectoraux convergent")
        ExerciseThumbnail(name: "Extension triceps corde", size: 72)
        ExerciseThumbnail(name: "Fente bulgare Smith", size: 72)
    }
    .padding().screenBackground().appAppearance()
}
