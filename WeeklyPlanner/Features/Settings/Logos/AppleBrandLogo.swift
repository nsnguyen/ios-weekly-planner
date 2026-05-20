import SwiftUI

/// Apple logo silhouette, ~18×22. Renders via `Image(systemName: "apple.logo")`
/// at the theme's ink color. The SF Symbol is permitted for first-party Apple
/// product references (Apple HIG section "Apple logo").
struct AppleBrandLogo: View {
    var size: CGSize = CGSize(width: 18, height: 22)

    @Environment(\.paperTheme) private var theme

    var body: some View {
        Image(systemName: "apple.logo")
            .resizable()
            .scaledToFit()
            .frame(width: size.width, height: size.height)
            .foregroundStyle(theme.ink)
            .accessibilityLabel("Apple logo")
    }
}

#Preview("AppleBrandLogo") {
    AppleBrandLogo().padding().background(PaperTheme.cream.cream).paperTheme(.cream)
}
