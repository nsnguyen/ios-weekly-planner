import SwiftUI

/// One tab in the seven-tab pastel column that runs down the right edge of
/// the Day page, binder-tab style. The tab paints a per-weekday pastel
/// rectangle, rounded only on its trailing (outer) edge so it reads as a
/// binder tab clipped onto the right side of the page, with the 3-letter
/// weekday acronym running top-to-bottom across the tab.
///
/// Selection state changes two things: the width grows from
/// `Spacing.sideTabWidth` (22pt) to `Spacing.sideTabSelectedWidth` (28pt) and
/// the whole tab nudges rightward by `Spacing.sideTabSelectedOffset` (+6pt)
/// so it pokes further into the outer leather margin. A small red dot in
/// the top-leading (inner, near the page) corner marks the tab that
/// represents today.
///
/// Colors come from `pastel(forIdx:)` — these are spec values from the mock
/// rather than theme tokens, so they're hard-coded on purpose. Ink color and
/// the today-dot color do come from `@Environment(\.paperTheme)`.
struct SideTab: View {
    /// Monday-based weekday index, `0...6`. Drives both the pastel background
    /// and the rotated weekday label.
    let idx: Int

    /// 3-letter weekday acronym (`"Mon"`, `"Tue"`, ...). Uppercased and
    /// rotated +90° when rendered so it reads top-to-bottom on the tab.
    let weekdayShort: String

    /// Full weekday name (`"Monday"`, `"Tuesday"`, ...) used for
    /// accessibility only — the visible label is `weekdayShort`.
    let weekdayLong: String

    /// `true` when this tab is the currently focused day. Selected tabs are
    /// wider and offset rightward.
    let isSelected: Bool

    /// `true` when this tab represents the real-world today (i.e., the page
    /// you'd jump to via the Today chip). Adds the small red dot overlay.
    let isToday: Bool

    /// Invoked when the user taps the tab. The parent decides whether to flip
    /// pages, no-op (same day), or refuse mid-flip.
    var onTap: () -> Void

    @Environment(\.paperTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            Self.tabShape
                .fill(Self.pastel(forIdx: idx))
                .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
                .overlay {
                    SideTabLabel(text: weekdayShort.uppercased(),
                                 layout: Self.labelLayout)
                }
                .overlay(alignment: .topLeading) {
                    if isToday {
                        Circle()
                            .fill(theme.redInk)
                            .frame(width: 5, height: 5)
                            .padding(.top, 4)
                            .padding(.leading, 3)
                    }
                }
            .frame(width: isSelected ? Spacing.sideTabSelectedWidth : Spacing.sideTabWidth,
                   height: Spacing.sideTabHeight)
            .offset(x: isSelected ? Spacing.sideTabSelectedOffset : 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(weekdayLong)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .animation(.smooth(duration: 0.18), value: isSelected)
    }

    /// Tab silhouette: rounded only on the trailing edge so the leading
    /// (inner) edge butts flat against the side of the page area.
    private static var tabShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(cornerRadii: RectangleCornerRadii(topLeading: 0,
                                                                 bottomLeading: 0,
                                                                 bottomTrailing: 6,
                                                                 topTrailing: 6))
    }
}

struct SideTabLabelLayout: Hashable {
    let fontSize: CGFloat
    let tracking: CGFloat
    let verticalInset: CGFloat
    let lineBoxHeight: CGFloat
    let minimumScaleFactor: CGFloat

    var trackLength: CGFloat {
        Spacing.sideTabHeight - (verticalInset * 2)
    }
}

private struct SideTabLabel: View {
    let text: String
    let layout: SideTabLabelLayout

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        Text(text)
            .font(font.font(at: layout.fontSize, weight: .bold))
            .tracking(layout.tracking)
            .foregroundStyle(theme.ink)
            .lineLimit(1)
            .minimumScaleFactor(layout.minimumScaleFactor)
            .allowsTightening(true)
            .frame(width: layout.trackLength, height: layout.lineBoxHeight)
            .rotationEffect(.degrees(90))
            .frame(width: Spacing.sideTabWidth, height: Spacing.sideTabHeight)
    }
}

extension SideTab {
    nonisolated static let labelLayout = SideTabLabelLayout(fontSize: 13,
                                                            tracking: 1.5,
                                                            verticalInset: 2,
                                                            lineBoxHeight: Spacing.sideTabWidth,
                                                            minimumScaleFactor: 0.42)

    /// Pastel color for a given Monday-based weekday index. Out-of-range
    /// indices fall back to Monday's color so callers don't need to clamp.
    ///
    /// These hex values come directly from `docs/mock/paper-planner.jsx`'s
    /// `TAB_COLORS` array and are intentionally not part of `PaperTheme` —
    /// they're a fixed weekday-coding palette, not a theme decision.
    static func pastel(forIdx idx: Int) -> Color {
        switch idx {
        case 0: Color(hex: "#E8D9B7")
        case 1: Color(hex: "#D9C9E3")
        case 2: Color(hex: "#C8DDE6")
        case 3: Color(hex: "#E4D3C2")
        case 4: Color(hex: "#D9E4C6")
        case 5: Color(hex: "#E7C7C7")
        case 6: Color(hex: "#CFD4DC")
        default: Color(hex: "#E8D9B7")
        }
    }
}

// MARK: - Previews

#Preview("SideTab · All seven, Friday selected") {
    let longNames = ["Monday", "Tuesday", "Wednesday", "Thursday",
                     "Friday", "Saturday", "Sunday"]
    let shortNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    return ZStack {
        BookCover()
        VStack(spacing: 4) {
            ForEach(0 ..< 7, id: \.self) { idx in
                SideTab(idx: idx,
                        weekdayShort: shortNames[idx],
                        weekdayLong: longNames[idx],
                        isSelected: idx == 4,
                        isToday: idx == 4) {}
            }
        }
        .padding(40)
    }
    .paperTheme(.cream)
}
