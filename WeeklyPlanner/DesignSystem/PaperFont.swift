import SwiftUI

/// The handwriting font families that ship with the app. Users pick one in
/// Settings; it is then injected via `@Environment(\.paperFont)` and used
/// everywhere `Typography` returns a `.font(in:weight:)`.
///
/// Caveat ships four weights as separate static instances (sliced from the
/// upstream variable font). Kalam ships Light / Regular / Bold. Architects
/// Daughter, Indie Flower, Patrick Hand, Shadows Into Light, Gochi Hand and
/// Nanum Pen Script are single-weight families — the requested `weight` is
/// silently ignored (a heavier `LegibilityWeight` maps back to regular).
enum PaperFont: String, CaseIterable, Hashable, Codable {
    case caveat
    case architects
    case kalam
    case indie
    case patrick
    case shadows
    case gochi
    case nanum

    /// Human-readable label shown in Settings.
    var displayName: String {
        switch self {
        case .caveat: "Caveat"
        case .architects: "Architects"
        case .kalam: "Kalam"
        case .indie: "Indie"
        case .patrick: "Patrick Hand"
        case .shadows: "Shadows"
        case .gochi: "Gochi Hand"
        case .nanum: "Nanum Pen"
        }
    }

    /// System font used if the custom font fails to register at runtime.
    /// `Cochin` is the closest serif-with-personality font on iOS.
    var fallbackPostScriptName: String {
        switch self {
        case .caveat: "Cochin"
        case .architects, .kalam, .indie,
             .patrick, .shadows, .gochi, .nanum: "Caveat-Regular"
        }
    }

    /// Returns a SwiftUI `Font` for this family at the requested size + weight.
    /// Falls back through the family chain via SwiftUI's built-in font matching.
    func font(at size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(postScriptName(for: weight), size: size)
    }

    /// Resolves the bundled PostScript name for a given `Font.Weight`.
    /// Internal so it can be unit-tested without forcing a runtime `UIFont` lookup.
    func postScriptName(for weight: Font.Weight) -> String {
        switch self {
        case .caveat: caveatName(for: weight)
        case .architects: "ArchitectsDaughter-Regular"
        case .kalam: kalamName(for: weight)
        case .indie: "IndieFlower-Regular"
        case .patrick: "PatrickHand-Regular"
        case .shadows: "ShadowsIntoLight"
        case .gochi: "GochiHand-Regular"
        case .nanum: "NanumPen-Regular"
        }
    }

    // MARK: - Per-family weight mapping

    /// Returns the appropriate font weight for the current `LegibilityWeight`
    /// setting. When the user enables Bold Text in iOS Settings, this swaps to
    /// a heavier weight where the font family supports it; otherwise returns
    /// the regular weight.
    ///
    /// - Caveat: Regular → SemiBold
    /// - Kalam: Regular → Bold (family ships Light / Regular / Bold)
    /// - Architects Daughter: Regular (single-weight family; no change)
    /// - Indie Flower: Regular (single-weight family; no change)
    func weightFor(legibility: LegibilityWeight) -> Font.Weight {
        guard legibility == .bold else { return .regular }
        switch self {
        case .caveat:     return .semibold
        case .kalam:      return .bold
        case .architects, .indie,
             .patrick, .shadows, .gochi, .nanum:
            return .regular
        }
    }

    private func caveatName(for weight: Font.Weight) -> String {
        switch weight {
        case .medium: "Caveat-Medium"
        case .semibold: "Caveat-SemiBold"
        case .bold, .heavy, .black: "Caveat-Bold"
        default: "Caveat-Regular"
        }
    }

    private func kalamName(for weight: Font.Weight) -> String {
        switch weight {
        case .ultraLight, .thin, .light: "Kalam-Light"
        case .bold, .heavy, .black: "Kalam-Bold"
        default: "Kalam-Regular"
        }
    }
}
