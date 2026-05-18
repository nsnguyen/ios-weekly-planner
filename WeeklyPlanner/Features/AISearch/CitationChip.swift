import SwiftUI

/// A yellow dashed-border chip surfacing one `AICitation` (a referenced
/// event) below an answer body. Layout: a 6×6 category-colored dot on the
/// leading edge, a two-line stack of the event title (handwritten) over a
/// short weekday-and-time line (system).
///
/// Visual recipe (verbatim from `phase-12-ai-search-overlay.md`):
/// - Background: `rgba(255, 230, 128, 0.4)` — translucent legal-pad yellow.
/// - Border: 0.5pt dashed `ink3`, 2pt corner radius.
/// - Inner padding: 4 vertical, 8 horizontal.
///
/// The background hex / dash pattern are intentionally hard-coded — they
/// are the literal design tokens for citation chips, not theme-derived
/// values, so the chip reads the same against every paper theme.
///
/// Tap routing is the caller's responsibility — Phase 12's overlay closes
/// itself first, then signals the host to open the matching event detail
/// sheet 100ms later (so the slide-down and the slide-up don't collide).
struct CitationChip: View {
    /// The citation rendered by this chip. `id` is forwarded back through
    /// `onTap` so the caller knows which event to open.
    let citation: AICitation

    /// Invoked synchronously on the main actor when the user taps the chip.
    var onTap: () -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 6) {
                Circle()
                    .fill(CategoryPalette.dot(citation.category))
                    .frame(width: 6, height: 6)

                VStack(alignment: .leading, spacing: 0) {
                    Text(citation.title)
                        .font(font.font(at: 15, weight: .regular))
                        .foregroundStyle(theme.ink)
                        .lineSpacing(1.0)

                    Text("\(citation.weekdayLong) \(citation.timeShort)")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(theme.ink3)
                }
            }
            .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
            .background(Color.rgba(255, 230, 128, 0.4))
            .overlay {
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(theme.ink3,
                                  style: StrokeStyle(lineWidth: 0.5, dash: [3, 2]))
            }
            .cornerRadius(2)
        }
        .buttonStyle(.plain)
    }
}
