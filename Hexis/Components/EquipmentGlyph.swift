import SwiftUI

/// Tiny pictogram of the equipment (machine, cable, dumbbells…), drawn in a 24-unit box.
struct EquipmentGlyph: View {
    let equipment: ExerciseVisual.Equipment

    var body: some View {
        if equipment == .dumbbell {
            Image(systemName: "dumbbell.fill").resizable().scaledToFit().foregroundStyle(Theme.Colors.textPrimary)
        } else {
            Canvas { context, size in
                let s = size.width / 24
                var path = Path()
                func line(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) {
                    path.move(to: CGPoint(x: x1 * s, y: y1 * s))
                    path.addLine(to: CGPoint(x: x2 * s, y: y2 * s))
                }
                func circle(_ x: Double, _ y: Double, _ r: Double) {
                    path.addEllipse(in: CGRect(x: (x - r) * s, y: (y - r) * s, width: 2 * r * s, height: 2 * r * s))
                }
                switch equipment {
                case .cable:
                    circle(12, 5, 3); line(12, 8, 12, 17); line(8, 18, 16, 18); line(8, 18, 8, 21); line(16, 18, 16, 21)
                case .stackMachine:
                    line(5, 3, 5, 21); line(5, 21, 19, 21)
                    for y in stride(from: 6.0, through: 14.0, by: 4.0) { line(8, y, 14, y) }
                    line(14, 17, 21, 12)
                case .plateMachine:
                    circle(8, 12, 5); circle(8, 12, 1.5); line(13, 12, 21, 12); line(21, 8, 21, 16)
                case .smith:
                    line(5, 3, 5, 21); line(19, 3, 19, 21); line(3, 12, 21, 12); line(3, 21, 21, 21)
                case .barbell:
                    line(2, 12, 22, 12); line(6, 6, 6, 18); line(18, 6, 18, 18); line(3, 9, 3, 15); line(21, 9, 21, 15)
                case .bodyweight:
                    circle(12, 12, 7); circle(12, 12, 1.5); line(2, 12, 5, 12); line(19, 12, 22, 12)
                case .dumbbell:
                    break
                }
                context.stroke(path, with: .color(Theme.Colors.textPrimary), style: StrokeStyle(lineWidth: 1.8 * s, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

#Preview {
    let all: [ExerciseVisual.Equipment] = [.cable, .stackMachine, .plateMachine, .smith, .barbell, .bodyweight, .dumbbell]
    HStack { ForEach(all, id: \.self) { EquipmentGlyph(equipment: $0).frame(width: 32, height: 32) } }
        .padding().screenBackground().appAppearance()
}
