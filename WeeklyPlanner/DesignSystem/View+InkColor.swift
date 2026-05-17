import SwiftUI

extension View {
    /// Applies the handwritten-pen color for the given `Category`, resolved
    /// against the current `PaperTheme` in the environment. Used for event
    /// titles, task labels, and other ink-on-paper text.
    func inkColor(for category: Category) -> some View {
        modifier(InkColorModifier(category: category))
    }

    /// Convenience for content that should render in `theme.blueInk`,
    /// regardless of category (used by AI overlay text).
    func blueInk() -> some View {
        modifier(SemanticInkModifier(role: .blue))
    }
}

private struct InkColorModifier: ViewModifier {
    let category: Category
    @Environment(\.paperTheme) private var theme

    func body(content: Content) -> some View {
        content.foregroundStyle(CategoryPalette.inkColor(category, in: theme))
    }
}

private struct SemanticInkModifier: ViewModifier {
    enum Role { case blue, red, green, primary }
    let role: Role
    @Environment(\.paperTheme) private var theme

    func body(content: Content) -> some View {
        content.foregroundStyle(color)
    }

    private var color: Color {
        switch role {
        case .blue: theme.blueInk
        case .red: theme.redInk
        case .green: theme.greenInk
        case .primary: theme.ink
        }
    }
}
