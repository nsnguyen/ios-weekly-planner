import SwiftUI

/// Phase 16 lands the full settings page. Phase 15 ships this placeholder so
/// the Settings tab on the new paper tab bar has a destination that still
/// reads as part of the book — same `BookPage` + `PaperSurface` chrome as
/// every other paper screen, with a centered handwritten "Settings" label
/// and a Cochin sub-line announcing the Phase 16 wait.
struct PaperSettingsView: View {
    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        BookPage {
            PaperSurface {
                ZStack(alignment: .top) {
                    PaperGrain()
                    RuledLines()
                    RedMarginLine()
                    HolePunches()

                    VStack(spacing: 8) {
                        Spacer(minLength: 0)
                        Text("Settings")
                            .font(font.font(at: 36, weight: .bold))
                            .foregroundStyle(theme.ink)
                            .rotationEffect(.degrees(-2))
                        Text("Theme, font, and connections arrive in Phase 16.")
                            .font(.custom("Cochin-Italic", size: 14))
                            .foregroundStyle(theme.ink2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}

#Preview("PaperSettingsView · cream") {
    PaperSettingsView()
        .paperTheme(.cream)
}
