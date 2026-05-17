import Foundation

/// Identifies one of the three paper themes by stable raw value.
/// Stored verbatim in `UserSettings.themeKey`.
enum PaperThemeKey: String, CaseIterable, Hashable {
    case cream
    case kraft
    case midnight

    /// Resolves the key to its concrete `PaperTheme` instance.
    var theme: PaperTheme {
        switch self {
        case .cream: PaperTheme.cream
        case .kraft: PaperTheme.kraft
        case .midnight: PaperTheme.midnight
        }
    }
}
