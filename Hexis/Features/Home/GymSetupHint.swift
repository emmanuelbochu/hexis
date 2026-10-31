import SwiftUI

/// Tells when the GPS detection of gyms is not set up (or ambiguous).
struct GymSetupHint: View {
    let gyms: [Gym]

    var body: some View {
        let items = gyms.map(\.setupItem)
        if let issue = items.lazy.compactMap({ GymSetup.issue(for: $0, among: items) }).first {
            NavigationLink {
                GymsView()
            } label: {
                Label(issue.message, systemImage: "location.slash")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.accent)
                    .multilineTextAlignment(.leading)
            }
        }
    }
}

#Preview {
    GymSetupHint(gyms: [])
        .appAppearance()
}
