import SwiftUI

/// Small inline glyph rendered after an event title when the event originated
/// from a Gmail message (`event.source == .gmail`).
///
/// **v1 — simplified envelope + red M.** The mock's `GmailIcon` in
/// `docs/mock/icons.jsx` is a multi-fill SVG with six sub-paths (white outer
/// envelope, two red side trapezoids, and inner "M" peaks in different reds).
/// Porting the polychrome version pixel-perfectly is a Phase 22 polish item;
/// at 9–11pt the difference is invisible to the eye, so v1 ships a clean
/// readable approximation:
///
/// - A white rounded rectangle envelope with a hair-line gray outline.
/// - A red "M" stroke drawn from bottom-leading up to a peak at (0.30, 0.20),
///   over to the valley at (0.50, 0.50), up to a peak at (0.70, 0.20), then
///   down to bottom-trailing.
///
/// These are the only two hardcoded hex colors in the day-page feature
/// (`#FFFFFF` envelope, `#EA4335` Gmail red); the colors are part of the
/// Gmail brand identity, not the paper theme, so they intentionally bypass
/// `@Environment(\.paperTheme)`.
struct GmailGlyph: View {
    /// Side length of the square glyph in points. Caller picks based on
    /// surrounding type — 10pt for inline event-row use, 9pt for the
    /// "FROM INBOX" eyebrow, 16pt for larger contexts.
    let size: CGFloat

    init(size: CGFloat = 10) {
        self.size = size
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(Color(hex: "#FFFFFF"))
                .overlay(RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .stroke(Color(hex: "#D0D0D0"), lineWidth: 0.5))

            GmailMShape()
                .stroke(Color(hex: "#EA4335"),
                        style: StrokeStyle(lineWidth: max(1, size * 0.12),
                                           lineCap: .round,
                                           lineJoin: .round))
                .padding(size * 0.18)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The red "M" pen-stroke drawn inside the envelope. Coordinates are
/// expressed as fractions of the bounding `rect` so the same shape scales
/// cleanly between 9pt and 16pt without manual tweaking.
private struct GmailMShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let x = rect.minX
        let y = rect.minY

        path.move(to: CGPoint(x: x, y: y + h))
        path.addLine(to: CGPoint(x: x + w * 0.30, y: y + h * 0.20))
        path.addLine(to: CGPoint(x: x + w * 0.50, y: y + h * 0.50))
        path.addLine(to: CGPoint(x: x + w * 0.70, y: y + h * 0.20))
        path.addLine(to: CGPoint(x: x + w, y: y + h))
        return path
    }
}

// MARK: - Previews

#Preview("GmailGlyph · Sizes") {
    HStack(spacing: 16) {
        GmailGlyph(size: 9)
        GmailGlyph(size: 10)
        GmailGlyph(size: 11)
        GmailGlyph(size: 16)
    }
    .padding(40)
    .background(Color(hex: "#FAF6E9"))
}
