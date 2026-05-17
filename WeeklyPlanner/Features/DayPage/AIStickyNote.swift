import SwiftUI

/// Peelable AI sticky note rendered top-right of the Day page. Has two
/// visual states — `expanded` (full 104pt-wide paper rectangle with masking
/// tape on top) and `folded` (a 22×22 corner tab). Tapping anywhere on the
/// note toggles between the two with a `stickyPeel` spring overshoot.
///
/// The note is driven entirely by an `AIInsight` value passed in; the
/// caller (`DayPageView`) is responsible for fetching the insight via
/// `StickyNoteGenerator.insight(forWeekOffset:dayIdx:in:)` and only
/// instantiating this view when an insight exists. There is no "empty
/// sticky" — if no insight, the corner is left blank.
///
/// `folded` state is intentionally view-local. Page flips remount the
/// view, which resets it to expanded — matching the mock behaviour and
/// avoiding any persistence of an ephemeral UI affordance.
struct AIStickyNote: View {
    /// The insight to render. Text, paper color, and tilt all come from
    /// this single value.
    let insight: AIInsight

    @State private var folded: Bool = false

    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if folded {
                AIStickyTab(noteColor: Color(hex: insight.colorHex),
                            noteColorHex: insight.colorHex,
                            tilt: insight.tiltDegrees)
                {
                    folded = false
                }
            } else {
                expandedBody
            }
        }
        .animation(AnimationTokens.stickyPeel, value: folded)
    }

    // MARK: - Subviews

    /// Full sticky paper: tinted background, masking-tape strip overhanging
    /// the top edge, eyebrow row, handwriting body, and the bottom-right
    /// peel hint triangle. Whole view is tappable to fold.
    private var expandedBody: some View {
        Button {
            folded = true
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                eyebrow
                    .padding(.bottom, 3)

                Text(insight.text)
                    .font(font.font(at: 13 * size.scale, weight: .semibold))
                    .foregroundStyle(Color(hex: "#3A2A1A"))
                    .lineSpacing(1.15)
                    .multilineTextAlignment(.leading)
            }
            .frame(width: 104, alignment: .leading)
            .padding(EdgeInsets(top: 8, leading: 9, bottom: 10, trailing: 9))
            .background(RoundedRectangle(cornerRadius: 1)
                .fill(Color(hex: insight.colorHex)))
            .overlay(alignment: .bottomTrailing) {
                StickyPeelCorner()
            }
            .overlay(alignment: .top) {
                MaskingTape(width: .compact)
                    .offset(y: -5)
            }
            .shadow(color: Color.black.opacity(0.22), radius: 4, x: 0, y: 3)
            .shadow(color: Color.black.opacity(0.12), radius: 1, x: 0, y: 1)
            .rotationEffect(.degrees(insight.tiltDegrees), anchor: .topTrailing)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("AI note: \(insight.text)")
        .accessibilityHint("Double tap to fold")
        .accessibilityAddTraits(.isButton)
    }

    /// "AI" eyebrow caption rendered in tiny system-font caps with a tracked
    /// sparkles glyph, styled to read as a translucent label on the paper
    /// rather than a heading.
    private var eyebrow: some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkles")
                .font(.system(size: 9))
                .foregroundStyle(Color.black.opacity(0.4))
            Text("AI")
                .font(.system(size: 8, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Color.black.opacity(0.4))
        }
    }
}

// MARK: - Peel corner hint

/// 12×12 bottom-right triangle that hints at a folded paper corner. Uses the
/// same 135° "transparent → black 0.18" gradient as `PageCurl`, just in a
/// smaller box and without the rounded outer corner — the sticky's own
/// corner is already nearly square (radius 1).
private struct StickyPeelCorner: View {
    var body: some View {
        let points = CSSGradientAngle.unitPoints(degrees: 135)
        let gradient = LinearGradient(stops: [
            .init(color: .clear, location: 0.0),
            .init(color: .clear, location: 0.5),
            .init(color: Color.black.opacity(0.08), location: 0.5),
            .init(color: Color.black.opacity(0.18), location: 1.0),
        ],
        startPoint: points.start,
        endPoint: points.end)

        gradient
            .frame(width: 12, height: 12)
            .clipShape(PeelTriangle())
            .allowsHitTesting(false)
    }
}

/// Right-triangle with vertices at top-leading, bottom-leading, and
/// bottom-trailing. Named distinctly from `CurlTriangle` (the page-level
/// peel) so a future shared `Triangle` shape doesn't collide.
private struct PeelTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Previews

#Preview("AIStickyNote · Two expanded + one folded") {
    let yellow = AIInsight(dayKey: "0:5",
                           text: "Don't forget Sara's gift!",
                           colorHex: "#FFE680",
                           tiltDegrees: 4)
    let mint = AIInsight(dayKey: "0:4",
                         text: "Pitch deck — one more pass.",
                         colorHex: "#C9F0E0",
                         tiltDegrees: -3)

    return ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                HStack(alignment: .top, spacing: 36) {
                    AIStickyNote(insight: yellow)
                    AIStickyNote(insight: mint)
                    AIStickyTab(noteColor: Color(hex: "#FFCCC9"),
                                noteColorHex: "#FFCCC9",
                                tilt: 5) {}
                }
                .padding(.top, 40)
                .padding(.leading, 44)
                .padding(.trailing, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.cream)
}
