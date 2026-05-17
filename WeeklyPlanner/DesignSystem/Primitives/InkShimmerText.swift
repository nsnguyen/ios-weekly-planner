import SwiftUI

/// Text whose foreground is an animated `LinearGradient` of `blueInk →
/// redInk → greenInk → blueInk`, sweeping horizontally across the glyphs.
/// Used for the AI overlay's "Thinking…" affordance.
///
/// The sweep is driven by a `TimelineView(.animation)` whose date stream is
/// reduced modulo `AnimationTokens.aiThinkingShimmerDuration` (2.5s) to
/// produce a normalized `phase` in 0...1. That phase is mapped to a 2-unit
/// horizontal translation of the gradient (`phase * 2 - 1`), so the gradient
/// enters from off-left at `phase = 0`, sits centered over the text near
/// `phase = 0.5`, and exits off-right by `phase = 1`. Looping is automatic
/// because `truncatingRemainder` resets every 2.5 seconds.
///
/// Accessibility: when `accessibilityReduceMotion` is `true`, the
/// `TimelineView` is replaced with a static rendering pinned at `phase = 0.5`
/// — the gradient still tints the text in the brand colors but no longer
/// moves. The static fallback preserves the visual identity without the
/// vestibular cost.
struct InkShimmerText: View {
    @Environment(\.paperTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The text to display.
    let text: String

    var body: some View {
        if reduceMotion {
            Text(text)
                .foregroundStyle(gradient(phase: 0.5))
        } else {
            TimelineView(.animation) { context in
                let elapsed = context.date.timeIntervalSinceReferenceDate
                let cycle = AnimationTokens.aiThinkingShimmerDuration
                let phase = elapsed.truncatingRemainder(dividingBy: cycle) / cycle
                Text(text)
                    .foregroundStyle(gradient(phase: phase))
            }
        }
    }

    /// Builds the four-stop ink gradient and shifts it horizontally by
    /// `phase * 2 - 1` (range -1...1), translating the gradient from
    /// "fully off-left" to "fully off-right" across one cycle.
    private func gradient(phase: Double) -> LinearGradient {
        let shift = phase * 2.0 - 1.0
        return LinearGradient(colors: [
            theme.blueInk,
            theme.redInk,
            theme.greenInk,
            theme.blueInk,
        ],
        startPoint: UnitPoint(x: -1 + shift, y: 0.5),
        endPoint: UnitPoint(x: 1 + shift, y: 0.5))
    }
}

#Preview("InkShimmerText · Cream") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                InkShimmerText(text: "Thinking…")
                    .font(.system(size: 22, weight: .semibold))
                    .padding(40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.cream)
}

#Preview("InkShimmerText · Kraft") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                InkShimmerText(text: "Thinking…")
                    .font(.system(size: 22, weight: .semibold))
                    .padding(40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.kraft)
}

#Preview("InkShimmerText · Midnight") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                InkShimmerText(text: "Thinking…")
                    .font(.system(size: 22, weight: .semibold))
                    .padding(40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.midnight)
}
