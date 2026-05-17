import SwiftUI

/// `ViewModifier` that strokes a rounded-rect dashed border around the
/// receiver. Used by category chips, the "Today" pill, event-detail toggles,
/// and any other small element that wants the paper-stitch look without the
/// weight of a solid border.
///
/// Defaults follow the mock: 0.5pt stroke, dash pattern `[4, 3]`, pill-shaped
/// (cornerRadius 999). Callers override `cornerRadius` for square chips
/// (e.g., `cornerRadius: 6` for a small button) and override `dash` for a
/// denser stitch.
///
/// The modifier is purely an overlay — it never changes the receiver's size,
/// background, or layout. Callers are responsible for adding their own
/// `.padding(...)` so the dashed border doesn't crash against the content.
struct DashedBorder: ViewModifier {
    /// Stroke color.
    let color: Color

    /// Dash pattern in the format `[on, off, on, off, ...]`. Two values are
    /// usually enough; `[4, 3]` means 4pt of stroke followed by a 3pt gap.
    let dash: [CGFloat]

    /// Stroke thickness.
    let lineWidth: CGFloat

    /// Corner radius for the rounded rectangle. `999` produces a pill shape;
    /// smaller values produce a chip or rounded button outline.
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: lineWidth, dash: dash))
                    .foregroundStyle(color)
            }
    }
}

extension View {
    /// Strokes a dashed rounded-rect border around the receiver. See
    /// `DashedBorder` for parameter semantics.
    func dashedBorder(color: Color,
                      dash: [CGFloat] = [4, 3],
                      lineWidth: CGFloat = 0.5,
                      cornerRadius: CGFloat = 999) -> some View
    {
        modifier(DashedBorder(color: color,
                              dash: dash,
                              lineWidth: lineWidth,
                              cornerRadius: cornerRadius))
    }
}

#Preview("DashedBorder · Cream") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                VStack(alignment: .leading, spacing: 16) {
                    Text("WORK")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.4)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .foregroundStyle(PaperTheme.cream.ink)
                        .dashedBorder(color: PaperTheme.cream.ink3)

                    Text("TODAY")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.4)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .foregroundStyle(PaperTheme.cream.blueInk)
                        .dashedBorder(color: PaperTheme.cream.blueInk.opacity(0.6))

                    Text("Square chip")
                        .font(.system(size: 12))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .foregroundStyle(PaperTheme.cream.ink)
                        .dashedBorder(color: PaperTheme.cream.ink3, cornerRadius: 6)
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

#Preview("DashedBorder · Kraft") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                Text("WORK")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.4)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .foregroundStyle(PaperTheme.kraft.ink)
                    .dashedBorder(color: PaperTheme.kraft.ink3)
                    .padding(40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.kraft)
}

#Preview("DashedBorder · Midnight") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                Text("WORK")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.4)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .foregroundStyle(PaperTheme.midnight.ink)
                    .dashedBorder(color: PaperTheme.midnight.ink3)
                    .padding(40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.midnight)
}
