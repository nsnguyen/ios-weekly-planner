import SwiftUI

/// Environment keys for the three pieces of design-system context every view
/// reads at render time: the active theme, the handwriting font family, and
/// the text-size step.
///
/// Defaults match a fresh install — Cream + Caveat + Medium — so previews
/// and ad-hoc views Just Work without explicit setup. The root view in
/// `WeeklyPlannerApp` overrides them from `UserSettings`.
extension EnvironmentValues {
    @Entry var paperTheme: PaperTheme = .cream
    @Entry var paperFont: PaperFont = .caveat
    @Entry var paperSize: PaperSize = .m
}

extension View {
    /// Injects a `PaperTheme` into the environment for this subtree.
    func paperTheme(_ theme: PaperTheme) -> some View {
        environment(\.paperTheme, theme)
    }

    /// Injects a `PaperFont` family into the environment for this subtree.
    func paperFont(_ font: PaperFont) -> some View {
        environment(\.paperFont, font)
    }

    /// Injects a `PaperSize` (S / M / L) into the environment for this subtree.
    /// Equivalent to `.handwritingScale(_:)` — handwriting-font elements pick
    /// this up and scale; system-font chrome ignores it.
    func paperSize(_ size: PaperSize) -> some View {
        environment(\.paperSize, size)
    }

    /// Alias for `paperSize(_:)` that matches the design-spec naming.
    func handwritingScale(_ size: PaperSize) -> some View {
        paperSize(size)
    }
}
