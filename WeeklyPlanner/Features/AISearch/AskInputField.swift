import SwiftUI

/// The handwritten input row at the top of the AI search paper sheet. A
/// small `"ASK"` eyebrow with a sparkle icon sits above an underlined
/// `TextField` rendered in the user's handwriting font; a trailing mic
/// button hints at voice input (wired in Phase 13 — for now it is a static
/// affordance).
///
/// Layout matches the spec exactly:
/// - Eyebrow row: 9pt bold tracked `"ASK"` with a 10pt sparkles symbol,
///   both in `ink3`.
/// - Input row: handwriting 22pt `TextField` whose tint matches `blueInk`
///   so the caret reads as a hand-dipped pen, with a 44×44 mic button on
///   the trailing edge (well above Apple's HIG minimum even though the
///   visible icon is only 16pt).
/// - Underline: a 1pt `ink3` rectangle sitting 4pt below the row, mimicking
///   the way handwritten input is captured on lined paper.
///
/// Focus is granted 250ms after appear so the slide-in animation finishes
/// before the keyboard rises — opening both at once stutters on the
/// simulator and reads as nervy on device.
///
/// The `onSubmit` callback fires on the keyboard's `.search` button. The
/// caller is responsible for forwarding the typed `text` to its view model.
struct AskInputField: View {
    /// Two-way binding to the typed query. Owned by the parent view model so
    /// the input reflects programmatic updates (e.g. a suggestion tap
    /// populating the field).
    @Binding var text: String

    /// Invoked when the user submits the field via the search key on the
    /// keyboard. Empty submissions are forwarded verbatim — the caller
    /// decides whether to ignore them.
    var onSubmit: () -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    /// Focus state for the underlying `TextField`. Driven to `true` 250ms
    /// after the view appears so the keyboard rises gracefully behind the
    /// overlay's slide-in.
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.ink3)

                Text("ASK")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(theme.ink3)
            }

            HStack(alignment: .center, spacing: 0) {
                TextField("What's on Friday afternoon?", text: $text)
                    .font(font.font(at: 22, weight: .regular))
                    .foregroundStyle(theme.blueInk)
                    .tint(theme.blueInk)
                    .focused($focused)
                    .submitLabel(.search)
                    .onSubmit(onSubmit)
                    .disabled(false)

                Spacer(minLength: 0)

                Button {
                    // Voice input is wired in Phase 13. For Phase 12 the
                    // button is intentionally inert — the visible icon is
                    // the only affordance we can ship without speech
                    // permissions.
                } label: {
                    Image(systemName: "mic")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.ink3)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }

            Rectangle()
                .fill(theme.ink3)
                .frame(height: 1)
                .padding(.bottom, 4)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                focused = true
            }
        }
    }
}
