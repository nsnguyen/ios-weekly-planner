import SwiftUI

/// Handwriting-font wrappers + Dynamic Type layout adapter for the
/// Paper view tree.
///
/// **Handwriting cap**: Caveat, Architects Daughter, Kalam, and Indie
/// Flower remain legible up through `.xxxLarge`; past that they become
/// unreadable. Views that render handwriting font text apply
/// `.dynamicTypeSize(...DynamicTypeSize.xxxLarge)` to clamp the user's
/// system Dynamic Type setting within that range.
///
/// **Layout adapter**: time gutter widens at AX2+, side tabs widen at
/// AX2+ (to accommodate the rotated weekday label), tab bar labels
/// truncate at AX3 and hide entirely at AX4+.
enum DynamicTypeSupport {
    /// Handwriting font configured for Dynamic Type scaling. Delegates
    /// to PaperFont's existing `font(at:weight:)` helper.
    static func handwriting(_ font: PaperFont,
                            size: CGFloat,
                            relativeTo style: Font.TextStyle = .body) -> Font {
        font.font(at: size, weight: .regular)
    }
}

/// Tab bar label rendering style chosen per Dynamic Type size.
enum TabBarLabelStyle: String, Hashable, Sendable {
    case full       // icon + full label
    case truncate   // icon + truncated label (single line)
    case iconOnly   // icon only
}

/// Layout values that adapt to the current Dynamic Type size.
enum DynamicTypeLayout {
    /// Day page time gutter (where hour labels render). Widens at AX2+
    /// so the larger numerals don't crowd events.
    static func timeGutterWidth(at size: DynamicTypeSize) -> CGFloat {
        size >= .accessibility2 ? 64 : 48
    }

    /// Side tab rail width. Widens at AX2+ to accommodate the rotated
    /// weekday text at larger sizes without truncation.
    static func sideTabWidth(at size: DynamicTypeSize) -> CGFloat {
        size >= .accessibility2 ? 32 : 22
    }

    /// Tab bar label rendering style. Full labels up through AX2;
    /// truncate at AX3; icon-only at AX4+ where labels would dominate.
    static func tabBarLabelStyle(at size: DynamicTypeSize) -> TabBarLabelStyle {
        switch size {
        case .accessibility4, .accessibility5:
            return .iconOnly
        case .accessibility3:
            return .truncate
        default:
            return .full
        }
    }
}

/// Pure math helpers for RTL-aware UI. Standard SwiftUI mirroring
/// handles HStack/VStack axes automatically; these helpers cover the
/// edge cases — custom gestures, asymmetric rotations.
enum RTLMath {
    /// Inverts deltaX sign when layoutDirection is .rightToLeft. Use
    /// in custom drag gestures (page-flip, swipe-to-dismiss) where
    /// the user's "next" direction differs between LTR and RTL.
    static func adjustDeltaX(_ deltaX: CGFloat, for direction: LayoutDirection) -> CGFloat {
        direction == .rightToLeft ? -deltaX : deltaX
    }

    /// DayPageHeader rotates the giant date number by -3° in LTR.
    /// In RTL the rotation flips sign so the lean reads the same
    /// visual direction relative to the mirrored text flow.
    static func headerRotationDegrees(for direction: LayoutDirection) -> Double {
        direction == .rightToLeft ? 3.0 : -3.0
    }

    /// Side tab rail alignment — leading in LTR, trailing in RTL.
    /// Most call sites get this for free via standard HStack/VStack
    /// mirroring, but explicit Alignment values need this helper.
    static func sideTabAlignment(for direction: LayoutDirection) -> HorizontalAlignment {
        direction == .rightToLeft ? .trailing : .leading
    }
}
