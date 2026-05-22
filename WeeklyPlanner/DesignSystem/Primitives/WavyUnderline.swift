import SwiftUI

/// `ViewModifier` that paints a hand-drawn sine-wave underline beneath any
/// content (typically a `Text`). The underline tracks the content's measured
/// width so it grows and shrinks with the underlying string and never breaks
/// text wrapping — measurement is performed via a `GeometryReader` placed in
/// the `.background` (it never participates in the parent's layout), and the
/// actual stroke is drawn in a `Canvas` overlay aligned to the bottom edge.
///
/// Defaults match the mock: amplitude 1pt, wavelength 6pt, line width 0.75pt,
/// color `rgba(26,58,122,0.3)` (translucent blue ink). Callers can pass any
/// of `theme.ink`, `theme.blueInk`, a category ink, etc.
///
/// Accessibility: when `accessibilityReduceMotion` is `true` OR the user has
/// requested bold legibility weight, the wavy line is replaced with the
/// platform's plain `.underline(true, color:)` — both signals indicate the
/// reader will benefit from a more legible, less decorative treatment.
struct WavyUnderline: ViewModifier {
    /// Stroke color. Defaults to the translucent blue ink used by the mock's
    /// inline-link decoration.
    let color: Color

    /// Peak-to-baseline distance of the wave in points. 1pt produces the
    /// subtle squiggle in the mock; values above ~2 read as a deliberate
    /// underline rather than a hand-drawn line.
    let amplitude: CGFloat

    /// Horizontal distance between two successive wave peaks. 6pt is the
    /// mock default; smaller values feel busier, larger feel slacker.
    let wavelength: CGFloat

    /// Stroke thickness of the wave path.
    private static let lineWidth: CGFloat = 0.75

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.legibilityWeight) private var legibilityWeight

    func body(content: Content) -> some View {
        if reduceMotion || legibilityWeight == .bold {
            content.underline(true, color: color)
        } else {
            content
                .background(alignment: .bottom) {
                    GeometryReader { proxy in
                        Canvas { context, size in
                            let path = Self.wavePath(width: proxy.size.width,
                                                     amplitude: amplitude,
                                                     wavelength: wavelength,
                                                     height: size.height)
                            context.stroke(path,
                                           with: .color(color),
                                           style: StrokeStyle(lineWidth: Self.lineWidth,
                                                              lineCap: .round,
                                                              lineJoin: .round))
                        }
                        .frame(width: proxy.size.width, height: amplitude * 2 + Self.lineWidth)
                        .offset(y: proxy.size.height)
                        .accessibilityHidden(true)
                    }
                    .frame(height: 0)
                }
        }
    }

    /// Builds a sine-like path that oscillates `amplitude` points above and
    /// below the vertical centerline of a strip `height` tall and `width`
    /// wide. The centerline sits at the top of the strip so callers can
    /// pin the strip flush to the text baseline.
    private static func wavePath(width: CGFloat,
                                 amplitude: CGFloat,
                                 wavelength: CGFloat,
                                 height: CGFloat) -> Path
    {
        var path = Path()
        guard width > 0, wavelength > 0 else { return path }

        let centerY = height / 2
        let step: CGFloat = 1
        var x: CGFloat = 0
        path.move(to: CGPoint(x: 0, y: centerY))
        while x <= width {
            let phase = (x / wavelength) * 2 * .pi
            let y = centerY + sin(phase) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }
        return path
    }
}

extension View {
    /// Paints a hand-drawn wavy line beneath the receiver. See `WavyUnderline`
    /// for accessibility fallbacks and parameter semantics.
    func wavyUnderline(color: Color = .rgba(26, 58, 122, 0.3),
                       amplitude: CGFloat = 1,
                       wavelength: CGFloat = 6) -> some View
    {
        modifier(WavyUnderline(color: color, amplitude: amplitude, wavelength: wavelength))
    }
}

#Preview("WavyUnderline · Cream") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Inline link with wavy underline")
                        .font(.body)
                        .wavyUnderline()

                    Text("Custom ink color")
                        .font(.body)
                        .wavyUnderline(color: PaperTheme.cream.redInk.opacity(0.5))

                    Text("Wider wavelength, taller amplitude")
                        .font(.body)
                        .wavyUnderline(amplitude: 1.5, wavelength: 10)
                }
                .foregroundStyle(PaperTheme.cream.ink)
                .padding(40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.cream)
}

#Preview("WavyUnderline · Kraft") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                Text("Inline link with wavy underline")
                    .font(.body)
                    .foregroundStyle(PaperTheme.kraft.ink)
                    .wavyUnderline(color: PaperTheme.kraft.blueInk.opacity(0.45))
                    .padding(40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.kraft)
}

#Preview("WavyUnderline · Midnight") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                Text("Inline link with wavy underline")
                    .font(.body)
                    .foregroundStyle(PaperTheme.midnight.ink)
                    .wavyUnderline(color: PaperTheme.midnight.blueInk.opacity(0.6))
                    .padding(40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.midnight)
}
