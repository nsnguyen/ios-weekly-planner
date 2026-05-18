import SwiftUI

/// Date-range label that doubles as the tap target for opening the week
/// picker. Renders the range string (e.g., `"May 11 – 17"`) in the active
/// handwriting font over an explicit cream tone, with a 0.5pt dashed
/// underline drawn beneath it, followed by a small chevron that rotates 180°
/// when the picker is open.
///
/// The title text color is intentionally hard-coded to `#FAF6E9` rather than
/// `theme.cream` — the pill sits over the dark leather book cover in every
/// theme, including Midnight (where `theme.cream` is dark navy and would be
/// invisible against the cover). Only the chevron derives from the theme via
/// `theme.chromeText` for the small color shift between themes.
///
/// The button itself is intentionally low-chrome: no background, 2pt vertical
/// / 4pt horizontal padding, and a 4pt corner radius for the hit shape.
struct DateRangePill: View {
    /// Pre-formatted range string supplied by the caller (e.g.,
    /// `"May 11 – 17"`). The pill performs no formatting — the parent owns
    /// localization and the long-dash separator.
    let rangeText: String

    /// Chevron rotation in degrees. Pass `0` when the picker is closed and
    /// `180` when open; the change is animated with a 0.18s ease-out curve.
    var chevronRotation: Double

    /// Invoked when the user taps the pill — typically toggles the week
    /// picker overlay open / closed.
    var action: () -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    /// Cream color used for the range text, fixed across themes because the
    /// pill always renders over the dark leather book cover.
    private static let titleColor: Color = .init(hex: "#FAF6E9")

    /// Translucent cream used by the dashed underline beneath the title.
    private static let underlineColor: Color = .init(red: 250 / 255,
                                                     green: 246 / 255,
                                                     blue: 233 / 255).opacity(0.35)

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(rangeText)
                    .font(font.font(at: 22, weight: .regular))
                    .foregroundStyle(Self.titleColor)
                    .shadow(color: Color.black.opacity(0.4), radius: 1, x: 0, y: 1)
                    .padding(.bottom, 1)
                    .overlay(alignment: .bottom) {
                        Canvas { context, size in
                            var path = Path()
                            let y = size.height / 2
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: size.width, y: y))
                            let strokeStyle = StrokeStyle(lineWidth: 0.5, dash: [4, 3])
                            context.stroke(path,
                                           with: .color(Self.underlineColor),
                                           style: strokeStyle)
                        }
                        .frame(height: 0.5)
                    }

                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(theme.chromeText)
                    .opacity(0.55)
                    .rotationEffect(.degrees(chevronRotation))
                    .animation(.easeOut(duration: 0.18), value: chevronRotation)
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .contentShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Jump to week")
        .accessibilityValue(rangeText)
    }
}

// MARK: - Previews

#Preview("DateRangePill · closed + open") {
    ZStack {
        BookCover()
        VStack(spacing: 24) {
            DateRangePill(rangeText: "May 11 – 17", chevronRotation: 0) {}
            DateRangePill(rangeText: "May 11 – 17", chevronRotation: 180) {}
        }
        .padding(40)
    }
    .paperTheme(.cream)
}

#Preview("DateRangePill · midnight") {
    ZStack {
        BookCover()
        DateRangePill(rangeText: "May 11 – 17", chevronRotation: 0) {}
            .padding(40)
    }
    .paperTheme(.midnight)
}
