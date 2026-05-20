import SwiftUI

/// Stylized Google Calendar "31" tile, ~20×20. Hand-rolled SwiftUI rather
/// than the official brand asset — Phase 17 ships this row as "Coming soon",
/// so a recognizable but generic calendar tile is sufficient.
struct GoogleCalLogo: View {
    var size: CGSize = CGSize(width: 20, height: 20)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size.width * 0.18)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: size.width * 0.18)
                        .strokeBorder(Color(red: 0.85, green: 0.85, blue: 0.85), lineWidth: 0.5)
                )

            Text("31")
                .font(.system(size: size.width * 0.55, weight: .semibold))
                .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96)) // Google blue
        }
        .frame(width: size.width, height: size.height)
        .accessibilityLabel("Google Calendar logo")
    }
}

#Preview("GoogleCalLogo") {
    GoogleCalLogo().padding().background(.white)
}
