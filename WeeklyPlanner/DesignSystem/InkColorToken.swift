import SwiftUI

/// Stable, theme-independent ink color identity for user-styled text
/// (Phase 34 annotations). Stored as the raw String; resolved against the
/// active `PaperTheme` at render time so annotations re-theme correctly.
enum InkColorToken: String, CaseIterable, Codable, Sendable {
    case ink
    case blue
    case red
    case green
    case pencil

    func resolve(in theme: PaperTheme) -> Color {
        switch self {
        case .ink: theme.ink
        case .blue: theme.blueInk
        case .red: theme.redInk
        case .green: theme.greenInk
        case .pencil: theme.pencil
        }
    }
}
