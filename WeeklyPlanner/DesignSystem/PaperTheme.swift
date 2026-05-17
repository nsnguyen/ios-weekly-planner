import SwiftUI

/// Every color a paper view ever reads. Three concrete instances — `.cream`,
/// `.kraft`, `.midnight` — are declared at the bottom of this file with the
/// exact hex values from `docs/mock/paper-theme.jsx`.
///
/// Views never instantiate a `PaperTheme` directly. They read it from
/// `@Environment(\.paperTheme)`, which is injected at the root by
/// `WeeklyPlannerApp` (driven by `UserSettings.themeKey`).
struct PaperTheme: Equatable, Hashable {
    let key: PaperThemeKey
    let displayName: String
    let tag: String

    // MARK: Paper surface

    let cream: Color
    let creamHi: Color
    let creamLo: Color
    let rule: Color
    let ruleSoft: Color
    let redLine: Color

    // MARK: Ink

    let ink: Color
    let ink2: Color
    let ink3: Color
    let blueInk: Color
    let redInk: Color
    let greenInk: Color
    let pencil: Color

    // MARK: Book chrome

    /// Book cover gradient endpoints. Render via `bookCover` below.
    let bookCoverStart: Color
    let bookCoverEnd: Color
    let bookSpine: Color
    let chromeText: Color
    let chromeMuted: Color

    // MARK: Page edges

    /// Two stripe shades for the repeating page-edge pattern at 180°.
    /// Renderer is a primitive in Phase 05.
    let edgeStripeLight: Color
    let edgeStripeDark: Color
    let holePunch: Color

    // MARK: Settings preview

    let paletteHero: Color
    let paletteAccent: Color

    /// Book cover gradient: 160° from `bookCoverStart` to `bookCoverEnd`.
    var bookCover: LinearGradient {
        let points = CSSGradientAngle.unitPoints(degrees: 160)
        return LinearGradient(colors: [bookCoverStart, bookCoverEnd],
                              startPoint: points.start,
                              endPoint: points.end)
    }
}

// MARK: - CSS angle → SwiftUI UnitPoint helper

/// Converts a CSS gradient angle (0° = "to top", clockwise) to a pair of
/// `UnitPoint`s suitable for `LinearGradient(startPoint:endPoint:)`.
enum CSSGradientAngle {
    static func unitPoints(degrees: Double) -> (start: UnitPoint, end: UnitPoint) {
        let radians = degrees * .pi / 180.0
        let dx = sin(radians)
        let dy = -cos(radians)
        return (start: UnitPoint(x: 0.5 - dx / 2.0, y: 0.5 - dy / 2.0),
                end: UnitPoint(x: 0.5 + dx / 2.0, y: 0.5 + dy / 2.0))
    }
}

// MARK: - Theme instances

extension PaperTheme {
    /// Default theme. "Vintage notebook" — light cream pages, leather cover.
    static let cream = PaperTheme(key: .cream,
                                  displayName: "Cream",
                                  tag: "Vintage notebook",
                                  cream: Color(hex: "#FAF6E9"),
                                  creamHi: Color(hex: "#FCF9EE"),
                                  creamLo: Color(hex: "#F1EAD2"),
                                  rule: .rgba(139, 121, 80, 0.18),
                                  ruleSoft: .rgba(139, 121, 80, 0.08),
                                  redLine: .rgba(192, 72, 72, 0.55),
                                  ink: Color(hex: "#1A1A2A"),
                                  ink2: .rgba(26, 26, 42, 0.62),
                                  ink3: .rgba(26, 26, 42, 0.34),
                                  blueInk: Color(hex: "#1A3A7A"),
                                  redInk: Color(hex: "#9C2A2A"),
                                  greenInk: Color(hex: "#2C5A2C"),
                                  pencil: Color(hex: "#3A3A55"),
                                  bookCoverStart: Color(hex: "#2C2418"),
                                  bookCoverEnd: Color(hex: "#1A1410"),
                                  bookSpine: Color(hex: "#0F0A06"),
                                  chromeText: Color(hex: "#E8D9B7"),
                                  chromeMuted: .rgba(232, 217, 183, 0.65),
                                  edgeStripeLight: Color(hex: "#EFE5C9"),
                                  edgeStripeDark: Color(hex: "#E2D6B3"),
                                  holePunch: Color(hex: "#E8E0CB"),
                                  paletteHero: Color(hex: "#FAF6E9"),
                                  paletteAccent: Color(hex: "#1A1410"))

    /// "Warm tan paper" — kraft-paper feel with deep brown ink and binding.
    static let kraft = PaperTheme(key: .kraft,
                                  displayName: "Kraft",
                                  tag: "Warm tan paper",
                                  cream: Color(hex: "#E6D2A8"),
                                  creamHi: Color(hex: "#EDD8B0"),
                                  creamLo: Color(hex: "#D4BA85"),
                                  rule: .rgba(58, 30, 12, 0.20),
                                  ruleSoft: .rgba(58, 30, 12, 0.10),
                                  redLine: .rgba(160, 48, 32, 0.50),
                                  ink: Color(hex: "#3A2418"),
                                  ink2: .rgba(58, 36, 24, 0.62),
                                  ink3: .rgba(58, 36, 24, 0.36),
                                  blueInk: Color(hex: "#23467A"),
                                  redInk: Color(hex: "#A03020"),
                                  greenInk: Color(hex: "#3A5A20"),
                                  pencil: Color(hex: "#3A2418"),
                                  bookCoverStart: Color(hex: "#3A2010"),
                                  bookCoverEnd: Color(hex: "#20120A"),
                                  bookSpine: Color(hex: "#150C06"),
                                  chromeText: Color(hex: "#F3E5C0"),
                                  chromeMuted: .rgba(243, 229, 192, 0.65),
                                  edgeStripeLight: Color(hex: "#D4BA85"),
                                  edgeStripeDark: Color(hex: "#BFA66E"),
                                  holePunch: Color(hex: "#C8AE7D"),
                                  paletteHero: Color(hex: "#E6D2A8"),
                                  paletteAccent: Color(hex: "#3A2010"))

    /// "For night use" — dark navy pages, bright light-blue ink for contrast.
    static let midnight = PaperTheme(key: .midnight,
                                     displayName: "Midnight",
                                     tag: "For night use",
                                     cream: Color(hex: "#1E1F2D"),
                                     creamHi: Color(hex: "#252638"),
                                     creamLo: Color(hex: "#181826"),
                                     rule: .rgba(220, 220, 240, 0.13),
                                     ruleSoft: .rgba(220, 220, 240, 0.06),
                                     redLine: .rgba(240, 128, 128, 0.40),
                                     ink: Color(hex: "#EAE6D9"),
                                     ink2: .rgba(234, 230, 217, 0.65),
                                     ink3: .rgba(234, 230, 217, 0.36),
                                     blueInk: Color(hex: "#7DB0F2"),
                                     redInk: Color(hex: "#F08080"),
                                     greenInk: Color(hex: "#88D680"),
                                     pencil: Color(hex: "#EAE6D9"),
                                     bookCoverStart: Color(hex: "#0A0814"),
                                     bookCoverEnd: Color(hex: "#04040C"),
                                     bookSpine: Color(hex: "#000004"),
                                     chromeText: Color(hex: "#B0B0C2"),
                                     chromeMuted: .rgba(176, 176, 194, 0.60),
                                     edgeStripeLight: Color(hex: "#2A2B40"),
                                     edgeStripeDark: Color(hex: "#1F2030"),
                                     holePunch: Color(hex: "#2A2A38"),
                                     paletteHero: Color(hex: "#1E1F2D"),
                                     paletteAccent: Color(hex: "#7DB0F2"))
}
