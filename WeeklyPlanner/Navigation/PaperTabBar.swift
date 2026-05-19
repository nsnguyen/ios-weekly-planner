import SwiftUI

/// Bottom tab bar that lives over the leather book cover. Three `PaperTab`
/// cells laid out evenly, with a 0.5pt dashed "stitched seam" line near the
/// top edge and a hairline divider above it. The bar provides its own
/// `theme.bookCover` background even though it sits over `AppShell`'s
/// persistent `BookCover` — explicit paint keeps the gradient aligned with
/// the chrome on every screen and lets future tab-bar background tweaks
/// (e.g. a brighter "active book" hue) land in one place.
struct PaperTabBar: View {
    @Binding var selection: Tab

    @Environment(\.paperTheme) private var theme

    var body: some View {
        ZStack(alignment: .top) {
            theme.bookCover

            stitchedSeam
                .padding(.horizontal, 18)
                .padding(.top, 4)

            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    PaperTab(tab: tab, isActive: selection == tab) {
                        selection = tab
                    }
                }
            }
        }
        .frame(height: 70)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 0.5)
        }
        .shadow(color: .black.opacity(0.4), radius: 14, x: 0, y: -2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("PaperTabBar")
    }

    /// Dashed stitched-seam line near the top. Renders as a path so the
    /// 0.5pt dashes stay crisp on 3× displays.
    private var stitchedSeam: some View {
        GeometryReader { proxy in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0.5))
                path.addLine(to: CGPoint(x: proxy.size.width, y: 0.5))
            }
            .stroke(Color.white.opacity(0.08),
                    style: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
        }
        .frame(height: 1)
    }
}

#Preview("PaperTabBar · cream") {
    PaperTabBarPreviewHost()
        .paperTheme(.cream)
}

#Preview("PaperTabBar · midnight") {
    PaperTabBarPreviewHost()
        .paperTheme(.midnight)
}

private struct PaperTabBarPreviewHost: View {
    @State private var tab: Tab = .calendar
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            PaperTabBar(selection: $tab)
        }
        .background(Color.black)
    }
}
