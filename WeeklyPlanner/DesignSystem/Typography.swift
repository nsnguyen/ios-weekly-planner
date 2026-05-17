import SwiftUI

/// A single entry in the type ramp. Bundles the size, weight, font kind, and
/// the optional decorations (rotation, tracking, opacity, italic, etc.) that
/// turn a raw size into a styled piece of text.
///
/// Values are sourced verbatim from the design spec (`docs/mock/*.jsx` and
/// `docs/phases/phase-02-design-system.md`). Renderers in Phase 05+ consume
/// these via `View.typography(_:in:)`.
struct TypographyEntry: Hashable {
    let size: CGFloat
    let weight: Font.Weight
    let kind: Kind
    let italic: Bool
    let tracking: CGFloat
    let opacity: Double
    let rotationDegrees: Double
    let uppercase: Bool
    let tabularNumerals: Bool

    enum Kind: Hashable {
        /// Uses the user's selected `PaperFont` family.
        case handwriting
        /// SwiftUI `.system` font.
        case system
        /// A named system font (e.g., `Cochin`, `Cochin-Italic`).
        case named(String)
    }

    init(size: CGFloat,
         weight: Font.Weight = .regular,
         kind: Kind = .handwriting,
         italic: Bool = false,
         tracking: CGFloat = 0,
         opacity: Double = 1.0,
         rotationDegrees: Double = 0,
         uppercase: Bool = false,
         tabularNumerals: Bool = false)
    {
        self.size = size
        self.weight = weight
        self.kind = kind
        self.italic = italic
        self.tracking = tracking
        self.opacity = opacity
        self.rotationDegrees = rotationDegrees
        self.uppercase = uppercase
        self.tabularNumerals = tabularNumerals
    }

    /// Resolves to a SwiftUI `Font` using the active handwriting family.
    /// `family` is ignored for non-handwriting entries.
    func font(in family: PaperFont) -> Font {
        switch kind {
        case .handwriting:
            family.font(at: size, weight: weight)
        case .system:
            Font.system(size: size, weight: weight)
        case let .named(name):
            Font.custom(name, size: size)
        }
    }
}

/// The full type ramp. Each `static let` is a single, named piece of the design.
/// Adding a new entry here is the only way to add a new text style — views
/// must never call `Font.custom` directly.
enum Typography {
    // MARK: - Day-page header

    static let pageWeekdayTitle = TypographyEntry(size: 30, weight: .bold)
    static let pageDateNumber = TypographyEntry(size: 62, weight: .bold, rotationDegrees: -3)
    static let pageMonthCaption = TypographyEntry(size: 12, kind: .named("Cochin-Italic"), italic: true)

    // MARK: - Events list

    static let eventTitle = TypographyEntry(size: 21, weight: .semibold)
    static let eventLocation = TypographyEntry(size: 12, kind: .named("Cochin-Italic"), italic: true)
    static let eventTime = TypographyEntry(size: 13, weight: .semibold, kind: .named("Cochin"), tabularNumerals: true)

    // MARK: - To-do block

    static let taskLabel = TypographyEntry(size: 17, weight: .medium)

    // MARK: - AI sticky

    static let stickyBody = TypographyEntry(size: 13, weight: .semibold)

    // MARK: - Chrome eyebrows

    static let eyebrow = TypographyEntry(size: 10,
                                         weight: .bold,
                                         kind: .system,
                                         tracking: 1.4,
                                         uppercase: true)
    static let weekChromeEyebrow = TypographyEntry(size: 10,
                                                   weight: .bold,
                                                   kind: .system,
                                                   tracking: 1.6,
                                                   opacity: 0.65,
                                                   uppercase: true)

    // MARK: - Date-range pill (top bar)

    static let dateRangePill = TypographyEntry(size: 22, weight: .regular)

    // MARK: - AI search overlay

    static let aiOverlayTitle = TypographyEntry(size: 24, weight: .regular)
    static let aiOverlayInput = TypographyEntry(size: 22, weight: .regular)
    static let aiSuggestion = TypographyEntry(size: 18, weight: .regular)

    // MARK: - Review

    static let reviewTitle = TypographyEntry(size: 28, weight: .bold)
    static let reviewPercent = TypographyEntry(size: 48, weight: .bold, rotationDegrees: -3)
}
