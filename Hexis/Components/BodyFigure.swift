import SwiftUI

/// Simple front or back silhouette with one muscle lit in the accent colour.
struct BodyFigure: View {
    let muscle: ExerciseVisual.Muscle
    var back = false

    var body: some View {
        Canvas { context, size in
            let s = size.width / 100
            func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ r: Double) -> Path {
                Path(roundedRect: CGRect(x: x * s, y: y * s, width: w * s, height: h * s), cornerRadius: r * s)
            }
            func dot(_ x: Double, _ y: Double, _ r: Double) -> Path {
                Path(ellipseIn: CGRect(x: (x - r) * s,      y: (y - r) * s, width: 2 * r * s, height: 2 * r * s))
            }
            let silhouette = GraphicsContext.Shading.color(Theme.Colors.textSecondary.opacity(0.4))
            let lit = GraphicsContext.Shading.color(Theme.Colors.accent)
            for path in [dot(50, 11, 7), rect(45, 17, 10, 7, 3), rect(32, 22, 36, 36, 10), rect(20, 24, 11, 38, 5.5),
                         rect(69, 24, 11, 38, 5.5), rect(35, 56, 14, 40, 6), rect(51, 56, 14, 40, 6)] {
                context.fill(path, with: silhouette)
            }
            for path in Self.paths(for: muscle, rect: rect, dot: dot) { context.fill(path, with: lit) }
        }
        .accessibilityHidden(true)
    }

    private static func paths(
        for muscle: ExerciseVisual.Muscle,
        rect: (Double, Double, Double, Double, Double) -> Path,
        dot: (Double, Double, Double) -> Path
    ) -> [Path] {
        switch muscle {
        case .chest: [rect(35, 27, 14, 12, 5), rect(51, 27, 14, 12, 5)]
        case .shoulders, .rearDelts: [dot(29, 28, 6.5), dot(71, 28, 6.5)]
        case .traps: [rect(38, 22, 24, 11, 5)]
        case .lats: [rect(34, 33, 15, 20, 6), rect(51, 33, 15, 20, 6)]
        case .biceps, .triceps: [rect(20, 34, 11, 17, 5), rect(69, 34, 11, 17, 5)]
        case .abs: [rect(41, 40, 18, 18, 5)]
        case .quads: [rect(35, 58, 14, 22, 6), rect(51, 58, 14, 22, 6)]
        case .hamstrings: [rect(35, 66, 14, 17, 6), rect(51, 66, 14, 17, 6)]
        case .glutes: [rect(35, 55, 14, 12, 6), rect(51, 55, 14, 12, 6)]
        case .calves: [rect(36, 80, 12, 14, 5), rect(52, 80, 12, 14, 5)]
        case .neck: [rect(44, 15, 12, 10, 4)]
        }
    }
}

#Preview {
    HStack {
        BodyFigure(muscle: .chest).frame(width: 80, height: 80)
        BodyFigure(muscle: .lats, back: true).frame(width: 80, height: 80)
        BodyFigure(muscle: .quads).frame(width: 80, height: 80)
    }
    .padding().screenBackground().appAppearance()
}
