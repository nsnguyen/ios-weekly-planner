import SwiftUI

/// Paper-styled replacement for SwiftUI's `Toggle`. Uses a capsule track with a
/// white knob that slides along its long axis. The "on" state is colored with
/// `theme.greenInk` (green = "on" globally across the app), and the "off"
/// state uses the iOS system grey `rgba(120,120,128,0.32)` so the control
/// reads as a familiar switch regardless of the active paper theme.
///
/// Two sizes are offered:
///
/// - `.compact` (track 38×22, knob 18pt) is used inline inside event-detail
///   rows where vertical room is tight.
/// - `.regular` (track 44×26, knob 22pt) is used on settings rows where the
///   toggle is the dominant control in its row.
///
/// The track itself is the tap target. Tapping anywhere on the capsule
/// flips `isOn` with a 0.2s `cubic-bezier(0.3, 0.8, 0.4, 1)` animation —
/// matching the JS mock — that drives both the knob translation and the
/// track color transition. When `accessibilityReduceMotion` is on, the
/// animation collapses to `Animation.linear(duration: 0)` so the state flip
/// happens immediately without any visible glide.
struct PaperToggle: View {
    /// Width preset. `.compact` is for event-detail rows (38×22 track, 18pt
    /// knob); `.regular` is for settings rows (44×26 track, 22pt knob).
    enum Style {
        case compact
        case regular

        /// Track dimensions in points.
        var trackSize: CGSize {
            switch self {
            case .compact:
                CGSize(width: 38, height: 22)
            case .regular:
                CGSize(width: 44, height: 26)
            }
        }

        /// Knob diameter in points.
        var knobDiameter: CGFloat {
            switch self {
            case .compact:
                18
            case .regular:
                22
            }
        }
    }

    @Environment(\.paperTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var isOn: Bool

    /// Size preset. Defaults to `.regular` (settings rows).
    var style: Style = .regular

    /// iOS system grey used for the off-state track. Constant across themes so
    /// the off state always reads as "inactive system control".
    private static let offTrackColor = Color.rgba(120, 120, 128, 0.32)

    /// Slide curve from the JS mock: 0.2s with a slight overshoot-ish ease.
    private var slideAnimation: Animation {
        reduceMotion
            ? .linear(duration: 0)
            : .timingCurve(0.3, 0.8, 0.4, 1, duration: 0.2)
    }

    /// Horizontal offset of the knob's center from the track's center: pinned
    /// to one half-width away from center on either side, with a 2pt inset so
    /// the knob never kisses the track edge.
    private var knobXOffset: CGFloat {
        let inset: CGFloat = 2
        let halfTravel = (style.trackSize.width - style.knobDiameter) / 2 - inset
        return isOn ? halfTravel : -halfTravel
    }

    var body: some View {
        ZStack {
            Capsule()
                .fill(isOn ? theme.greenInk : Self.offTrackColor)
                .frame(width: style.trackSize.width, height: style.trackSize.height)

            Circle()
                .fill(Color.white)
                .frame(width: style.knobDiameter, height: style.knobDiameter)
                .shadow(color: Color.black.opacity(0.15), radius: 1.5, x: 0, y: 1)
                .offset(x: knobXOffset)
        }
        .contentShape(Capsule())
        .onTapGesture {
            withAnimation(slideAnimation) {
                isOn.toggle()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityValue(isOn ? "on" : "off")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("PaperToggle · Cream") {
    PaperTogglePreviewHost()
        .paperTheme(.cream)
}

#Preview("PaperToggle · Kraft") {
    PaperTogglePreviewHost()
        .paperTheme(.kraft)
}

#Preview("PaperToggle · Midnight") {
    PaperTogglePreviewHost()
        .paperTheme(.midnight)
}

/// Internal preview-only host that wires four toggles (compact on/off and
/// regular on/off) to local `@State` so the slide animation can actually be
/// exercised inside the Xcode preview canvas.
private struct PaperTogglePreviewHost: View {
    @State private var compactOn: Bool = true
    @State private var compactOff: Bool = false
    @State private var regularOn: Bool = true
    @State private var regularOff: Bool = false

    var body: some View {
        ZStack {
            BookCover()
            BookPage {
                PaperSurface {
                    VStack(alignment: .leading, spacing: 24) {
                        PaperToggle(isOn: $compactOn, style: .compact)
                        PaperToggle(isOn: $compactOff, style: .compact)
                        PaperToggle(isOn: $regularOn, style: .regular)
                        PaperToggle(isOn: $regularOff, style: .regular)
                    }
                    .padding(40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 60)
        }
    }
}
