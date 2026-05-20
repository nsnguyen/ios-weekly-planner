import SwiftUI

/// Layout constants for the paper book chrome and page surface. Values from
/// `docs/mock/paper-planner.jsx`. Use everywhere layout numbers would
/// otherwise be inlined into views.
enum Spacing {
    // MARK: - Page surface

    /// Page inset against the book-spine background. Spine sits on the leading edge,
    /// so leading is larger than trailing.
    static let pageInset = EdgeInsets(top: 0, leading: 26, bottom: 0, trailing: 18)

    /// Where the soft-red vertical margin line starts (from the page leading edge).
    static let redMarginLeading: CGFloat = 32

    /// Hole-punch dot geometry.
    static let holePunchLeading: CGFloat = 8
    static let holePunchSize: CGFloat = 12

    // MARK: - Book chrome

    /// Inner page (paper). Rounded only on the trailing side; the leading edge
    /// is bound into the book spine.
    static let bookPageCornerRadius = RectangleCornerRadii(topLeading: 2,
                                                           bottomLeading: 2,
                                                           bottomTrailing: 12,
                                                           topTrailing: 12)

    /// Outer book hull, slightly larger radius than the page itself.
    static let bookOuterCornerRadius = RectangleCornerRadii(topLeading: 4,
                                                            bottomLeading: 4,
                                                            bottomTrailing: 14,
                                                            topTrailing: 14)

    /// Top padding above the book chrome, clearing the status bar + dynamic island.
    static let bookTopBarTopPadding: CGFloat = 54

    // MARK: - Tab bar

    static let tabBarHeight: CGFloat = 76
    static let tabBarBottomSafeArea: CGFloat = 26

    // MARK: - Page flip

    /// 3D perspective for the `rotation3DEffect` page-flip transition.
    /// Larger value = less foreshortening.
    static let pageFlipPerspective: CGFloat = 1800

    /// Width of the stacked-paper stripe pattern on the page's trailing edge.
    static let pageEdgeStripeWidth: CGFloat = 6

    // MARK: - Side tabs (M/T/W/T/F/S/S)

    static let sideTabWidth: CGFloat = 22
    static let sideTabSelectedWidth: CGFloat = 28
    static let sideTabHeight: CGFloat = 56
    /// Horizontal offset applied to the selected side tab so it pokes out
    /// (rightward into the outer leather margin, since the day tabs sit on
    /// the right side of the page binder-tab style).
    static let sideTabSelectedOffset: CGFloat = 6
}
