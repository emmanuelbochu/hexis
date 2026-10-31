import SwiftData
import SwiftUI

/// One line of encouragement that fades in when it is ready, and takes no room when there is none.
struct CheerLine: View {
    let alignment: TextAlignment
    let load: @MainActor (ModelContext) async -> String?
    @Environment(\.modelContext) private var context
    @State private var text: String?

    var body: some View {
        VStack(spacing: 0) {
            if let text {
                Text(text)
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(alignment)
                    .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
                    .transition(.opacity)
            }
        }
        .task {
            let line = await load(context)
            withAnimation(.easeOut(duration: 0.4)) { text = line }
        }
    }
}

#Preview {
    CheerLine(alignment: .center) { _ in "Développé couché à 82,5 kg, ça n'était jamais arrivé." }
        .padding()
        .screenBackground()
        .appAppearance()
}
