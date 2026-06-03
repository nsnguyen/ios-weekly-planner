import SwiftUI

/// Single 22×22 chevron button used twice in the top bar — once flanking the
/// `DateRangePill` on each side — to step the visible week backward or
/// forward. The composite `BookTopBar` (Group Q) places two instances side
/// by side; this primitive is direction-agnostic and owns only the visual
/// chrome plus the tap handler.
///
/// The background is fully transparent and the icon sits at 0.7 opacity so
/// the chevrons read as a quiet secondary control. Color comes from
/// `theme.chromeText` so the icon retains contrast against the leather
/// cover in every theme.
struct WeekChevronButton: View {
    /// Direction the chevron points. Determines both the SF Symbol used and
    /// the VoiceOver label exposed to assistive tech.
    enum Direction {
        case prev
        case next

        fileprivate var systemName: String {
            switch self {
            case .prev: "chevron.left"
            case .next: "chevron.right"
            }
        }

        fileprivate var accessibilityLabel: String {
            switch self {
            case .prev: "Previous week"
            case .next: "Next week"
            }
        }
    }

    /// Direction this instance represents. The composite top bar instantiates
    /// one `.prev` and one `.next` button.
    let direction: Direction

    /// Invoked on tap. The parent advances or rewinds `weekOffset` according
    /// to the chevron's direction.
    var action: () -> Void

    @Environment(\.paperTheme) private var theme

    var body: some View {
        Button(action: action) {
            Image(systemName: direction.systemName)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(theme.chromeText)
                .frame(width: 22, height: 22)
                .opacity(0.7)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(direction.accessibilityLabel)
        .accessibilityIdentifier(direction == .prev
            ? AccessibilityIDs.weekChevronPrev
            : AccessibilityIDs.weekChevronNext)
    }
}

// MARK: - Previews

#Preview("WeekChevronButton · both directions") {
    ZStack {
        BookCover()
        HStack(spacing: 16) {
            WeekChevronButton(direction: .prev) {}
            WeekChevronButton(direction: .next) {}
        }
        .padding(40)
    }
    .paperTheme(.cream)
}

#Preview("WeekChevronButton · midnight") {
    ZStack {
        BookCover()
        HStack(spacing: 16) {
            WeekChevronButton(direction: .prev) {}
            WeekChevronButton(direction: .next) {}
        }
        .padding(40)
    }
    .paperTheme(.midnight)
}
