import SwiftUI

/// The root scene the user lands on when the app launches. Composes the full
/// paper book chrome — `BookCover` underneath, `BookPage` inset to clear the
/// status bar / Dynamic Island on top and reserve room for the eventual tab
/// bar on the bottom, with `PaperSurface` + grain + ruled lines + red margin +
/// hole punches + page-number footer layered inside.
///
/// Phase 06 will replace the centered "Phase 05 ready" placeholder with the
/// real Day Page content. Until then the placeholder text doubles as the
/// `SmokeUITests.testAppLaunches` smoke marker.
///
/// The view picks up its colors from `@Environment(\.paperTheme)`, whose
/// default is `.cream` — no explicit theme override here; settings rewiring
/// arrives in Phase 19.
struct RootView: View {
    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var paperFont

    var body: some View {
        ZStack {
            BookCover()

            BookPage {
                PaperSurface {
                    ZStack {
                        PaperGrain()
                        RuledLines()
                        RedMarginLine()
                        HolePunches()

                        Text("Phase 05 — Paper book chrome ready")
                            .font(Typography.eventTitle.font(in: paperFont))
                            .foregroundStyle(theme.ink)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        PageNumber(date: Date())
                            .frame(maxWidth: .infinity,
                                   maxHeight: .infinity,
                                   alignment: .bottomTrailing)
                    }
                }
            }
            .padding(.top, Spacing.bookTopBarTopPadding)
            .padding(.bottom, Spacing.tabBarHeight + Spacing.tabBarBottomSafeArea)
        }
    }
}

#Preview {
    RootView()
}
