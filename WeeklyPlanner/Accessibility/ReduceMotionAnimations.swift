import SwiftUI

/// Reduce Motion factory variants on the existing `AnimationTokens`.
/// Each `*(reduced:)` factory returns either the full token (when
/// `reduced == false`) or an alternative animation tuned for the
/// `accessibilityReduceMotion` setting.
///
/// Reduced variants per the Phase 21 design:
/// - Page flip: 0.15s easeInOut opacity crossfade (replaces 3D flip)
/// - Sheet slide: 0.15s easeOut fade
/// - Sticky peel: instant (0s linear)
/// - Picker drop: 0.15s easeOut fade (replaces overshoot curve)
/// - AI overlay slide: 0.2s easeOut fade (overlay is larger surface)
extension AnimationTokens {
    static func pageFlip(reduced: Bool) -> Animation {
        reduced ? .easeInOut(duration: 0.15) : Self.pageFlip
    }

    static func sheetSlide(reduced: Bool) -> Animation {
        reduced ? .easeOut(duration: 0.15) : Self.sheetSlide
    }

    static func stickyPeel(reduced: Bool) -> Animation {
        reduced ? .linear(duration: 0) : Self.stickyPeel
    }

    static func pickerDrop(reduced: Bool) -> Animation {
        reduced ? .easeOut(duration: 0.15) : Self.pickerDrop
    }

    /// AI overlay uses the same sheet-slide curve in full mode but a
    /// slightly longer fade in reduced mode (overlay is larger surface).
    static func aiOverlaySlide(reduced: Bool) -> Animation {
        reduced ? .easeOut(duration: 0.20) : Self.sheetSlide
    }
}
