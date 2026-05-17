import SwiftUI

/// Folded 22×22 state of the AI sticky note. Renders as a tiny corner-folded
/// paper tab with a sparkles glyph — the visual shorthand for "an AI note is
/// hiding here, tap to reveal it".
///
/// The folded shape is achieved with a single 225° linear gradient: the bulk
/// of the tab paints the paper color, a thin black band suggests the fold's
/// shadow line, and the underside fades to a darker shade of the paper. Tilt
/// is rotated 6° further than the expanded note so the fold reads as a
/// distinct gesture rather than a static rotated square.
///
/// Tap delivery is the `onTap` closure — the caller owns the
/// fold-to-expanded state machine.
struct AIStickyTab: View {
    /// Paper color of the underlying sticky note. Matches the expanded
    /// state's background so the fold reads as the same piece of paper.
    let noteColor: Color

    /// Hex form of `noteColor` so we can derive a darker "underside" shade
    /// via `StickyNoteGenerator.shade(_:percent:)` without a `Color -> hex`
    /// round-trip.
    let noteColorHex: String

    /// Rotation of the expanded sticky in degrees. The tab is rendered at
    /// `tilt - 6°` so the fold motion reads as a small additional twist.
    let tilt: Double

    /// Invoked when the tab is tapped — caller flips back to the expanded
    /// sticky.
    var onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            ZStack {
                LinearGradient(stops: [
                    .init(color: noteColor, location: 0.0),
                    .init(color: noteColor, location: 0.55),
                    .init(color: Color.black.opacity(0.18), location: 0.56),
                    .init(color: StickyNoteGenerator.shade(noteColorHex, percent: 20),
                          location: 1.0),
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading)

                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.black.opacity(0.6))
            }
            .frame(width: 22, height: 22)
            .clipShape(RoundedRectangle(cornerRadius: 1))
            .shadow(color: Color.black.opacity(0.25), radius: 1.5, x: 0, y: 1)
            .rotationEffect(.degrees(tilt - 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show AI note")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Previews

#Preview("AIStickyTab · Three colors") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                HStack(spacing: 32) {
                    AIStickyTab(noteColor: Color(hex: "#FFE680"),
                                noteColorHex: "#FFE680",
                                tilt: 4) {}
                    AIStickyTab(noteColor: Color(hex: "#C9F0E0"),
                                noteColorHex: "#C9F0E0",
                                tilt: -3) {}
                    AIStickyTab(noteColor: Color(hex: "#FFCCC9"),
                                noteColorHex: "#FFCCC9",
                                tilt: 5) {}
                }
                .padding(40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.cream)
}
