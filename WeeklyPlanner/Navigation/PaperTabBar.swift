import SwiftUI

/// Bottom tab bar that lives over the leather book cover. Four `PaperTab`
/// cells laid out evenly with the `theme.bookCover` gradient as background,
/// a dark 0.5pt hairline at the top edge, and a soft drop shadow above.
/// Matches the paper-mode `TabBar` in `docs/mock/overlays.jsx`: no cream
/// bookmark behind the active cell, no dashed stitched seam — those were
/// earlier creative additions that the user removed in favor of the mock's
/// cleaner two-shade chrome look.
struct PaperTabBar: View {
    @Binding var selection: Tab

    @Environment(\.paperTheme) private var theme

    var body: some View {
        ZStack(alignment: .top) {
            theme.bookCover

            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    PaperTab(tab: tab, isActive: selection == tab) {
                        selection = tab
                    }
                }
            }
            .padding(.top, 6)
        }
        .frame(height: 52)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .frame(height: 0.5)
        }
        .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: -4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("PaperTabBar")
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
