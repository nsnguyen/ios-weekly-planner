import SwiftUI

/// Per-category color tokens. Dot / background / ink colors all flow from here.
///
/// Three of the six ink colors (`personal`, `focus`, `travel`) are deliberately
/// theme-independent — the mock locks them to a single tone across Cream /
/// Kraft / Midnight so events keep their identity when the user swaps themes.
enum CategoryPalette {
    // MARK: Accent ("dot") colors — exact hex from docs/mock/data.jsx

    static func dot(_ category: Category) -> Color {
        switch category {
        case .work: Color(hex: "#0A84FF")
        case .personal: Color(hex: "#BF5AF2")
        case .health: Color(hex: "#30D158")
        case .family: Color(hex: "#FF375F")
        case .focus: Color(hex: "#FF9F0A")
        case .travel: Color(hex: "#64D2FF")
        }
    }

    /// 12%-alpha tint of the dot. Used as light-mode event-block backgrounds.
    static func bgLight(_ category: Category) -> Color {
        dot(category).opacity(0.12)
    }

    /// 22%-alpha tint of the dot. Used as dark-mode event-block backgrounds
    /// and as the slightly heavier hover/selected variant in light mode.
    static func bgDark(_ category: Category) -> Color {
        dot(category).opacity(0.22)
    }

    /// Per-category handwritten-pen color. For three categories this is fixed
    /// (matches the mock); for the other three it follows the active theme.
    static func inkColor(_ category: Category, in theme: PaperTheme) -> Color {
        switch category {
        case .work: theme.blueInk
        case .personal: Color(hex: "#5A2A7A")
        case .health: theme.greenInk
        case .family: theme.redInk
        case .focus: Color(hex: "#8A5A1A")
        case .travel: Color(hex: "#1A6A8A")
        }
    }

    /// User-facing label for the category. Localizable in Phase 21.
    static func displayName(_ category: Category) -> String {
        switch category {
        case .work: "Work"
        case .personal: "Personal"
        case .health: "Health"
        case .family: "Family"
        case .focus: "Focus"
        case .travel: "Travel"
        }
    }
}
