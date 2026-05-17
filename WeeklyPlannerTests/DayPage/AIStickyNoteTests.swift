import SwiftUI
import UIKit
import XCTest
@testable import WeeklyPlanner

/// Logic-level tests for the AI sticky note. The `folded` toggle is a single
/// `@State` flip on a SwiftUI view — driving it in plain `XCTest` would
/// require a snapshot harness or a SwiftUI testing shim for a one-line state
/// change. We deliberately skip those tests; visual QA + the `#Preview`
/// covers the transition. What's actually worth pinning here is the math in
/// `StickyNoteGenerator.shade(_:percent:)`, which the folded-tab gradient
/// depends on and which lives outside any SwiftUI rendering path.
@MainActor
final class AIStickyNoteTests: XCTestCase {
    /// `shade("#FFE680", percent: 20)` should darken yellow by 20%, leaving
    /// approximately `rgb(204, 184, 102)`. Rounded comparison with ±2 channel
    /// slack absorbs sRGB → UIColor float round-tripping.
    func testShadeHelperReducesBrightness() {
        let shaded = StickyNoteGenerator.shade("#FFE680", percent: 20)
        let (red, green, blue) = Self.channels(of: shaded)
        XCTAssertEqual(red, 204, accuracy: 2)
        XCTAssertEqual(green, 184, accuracy: 2)
        XCTAssertEqual(blue, 102, accuracy: 2)
    }

    /// Shading by 0% must be a no-op — the returned color equals the input
    /// `#FFE680` channel-for-channel.
    func testShadeWithZeroPercentReturnsSameColor() {
        let shaded = StickyNoteGenerator.shade("#FFE680", percent: 0)
        let (red, green, blue) = Self.channels(of: shaded)
        XCTAssertEqual(red, 255, accuracy: 1)
        XCTAssertEqual(green, 230, accuracy: 1)
        XCTAssertEqual(blue, 128, accuracy: 1)
    }

    /// Negative percents must clamp to 0 (no brightening). Spec calls for
    /// `shade` to darken only; a `-5` value falls through to "no change"
    /// rather than producing a lighter color.
    func testShadeWithNegativePercentClampsToOriginal() {
        let shaded = StickyNoteGenerator.shade("#FFE680", percent: -5)
        let (red, green, blue) = Self.channels(of: shaded)
        XCTAssertEqual(red, 255, accuracy: 1)
        XCTAssertEqual(green, 230, accuracy: 1)
        XCTAssertEqual(blue, 128, accuracy: 1)
    }

    // MARK: - Helpers

    /// Extracts 0–255 RGB channels from a SwiftUI `Color` by round-tripping
    /// through `UIColor`. Returns ints since the assertions compare integer
    /// channel values with a small accuracy tolerance.
    private static func channels(of color: Color) -> (red: Int, green: Int, blue: Int) {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Int(round(red * 255)),
                Int(round(green * 255)),
                Int(round(blue * 255)))
    }
}
