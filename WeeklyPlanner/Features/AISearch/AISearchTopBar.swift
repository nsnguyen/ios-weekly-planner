import SwiftUI

/// Leather chrome bar that sits above the AI search paper sheet. Stacks an
/// uppercase eyebrow over a handwriting title on the left and a
/// `PaperPillButton(.secondary)` "Close" on the right.
///
/// Outer padding (`top: 54, leading: 26, bottom: 10, trailing: 16`) mirrors
/// the `BookTopBar`'s status-bar clearance so the overlay's title sits at
/// the same eye-line as the planner's own header — useful in the
/// crossfade-by-default reduce-motion mode where there is no slide cue.
///
/// The title's `text-shadow` (the `Color.black.opacity(0.4)` `.shadow`
/// modifier) is hand-set to the same `(radius: 1, x: 0, y: 1)` recipe the
/// mock uses, giving the handwriting just enough lift to read on the leather
/// gradient.
struct AISearchTopBar: View {
    /// Invoked when the user taps the trailing Close pill. The host closes
    /// the overlay.
    var onClose: () -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Button(action: onClose) {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Planner")
                        .font(.system(size: 17, weight: .regular))
                }
                .foregroundStyle(theme.chromeText)
                .padding(.vertical, 6)
                .padding(.trailing, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to planner")

            VStack(alignment: .leading, spacing: 0) {
                Text("ASK THE PLANNER")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(theme.chromeText.opacity(0.65))

                Text("Apple Intelligence")
                    .font(font.font(at: 24, weight: .regular))
                    .foregroundStyle(theme.chromeText)
                    .shadow(color: Color.black.opacity(0.4), radius: 1, x: 0, y: 1)
            }

            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: 54, leading: 14, bottom: 10, trailing: 16))
    }
}
