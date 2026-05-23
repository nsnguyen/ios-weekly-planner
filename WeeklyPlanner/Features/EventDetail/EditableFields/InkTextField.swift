import SwiftUI

/// Handwriting-styled `TextField` atom used by every editable field in
/// the event composer (Phase 22) and the task composer (Phase 23). No
/// border, ink-blue caret, italic placeholder in `theme.ink2`, and a
/// focus-state underline beneath the baseline — wavy ink by default,
/// solid 1pt rectangle when Reduce Motion is on.
///
/// Two preset sizes:
///   - `.title` — 22pt, used for the event title in the composer header.
///   - `.body` — 17pt, used for body fields (location, task title, …).
///
/// Focus state is local by default. Pass `focus: $someFocusState`
/// (a `FocusState.Binding<Bool>`) to let a parent drive focus — e.g.,
/// to auto-focus the title field when a create sheet opens.
///
/// Callers are responsible for adding `.accessibilityIdentifier(...)`
/// when the field needs to be reachable from UITests.
struct InkTextField: View {
    enum Variant { case title, body }

    @Binding var text: String
    let placeholder: String
    let variant: Variant

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Optional external focus binding. When supplied, the parent owns
    /// the focus state — useful for "open sheet → focus title" UX. When
    /// `nil`, the field uses its own local `@FocusState`.
    private let externalFocus: FocusState<Bool>.Binding?

    @FocusState private var localFocus: Bool

    init(_ placeholder: String,
         text: Binding<String>,
         variant: Variant = .body,
         focus: FocusState<Bool>.Binding? = nil)
    {
        self.placeholder = placeholder
        self._text = text
        self.variant = variant
        self.externalFocus = focus
    }

    var body: some View {
        let basePoint: CGFloat = variant == .title ? 22 : 17
        let scaledPoint = basePoint * size.scale
        let weight: Font.Weight = variant == .title ? .bold : .regular

        return TextField(
            "",
            text: $text,
            prompt: Text(placeholder)
                .font(font.font(at: scaledPoint, weight: weight).italic())
                .foregroundStyle(theme.ink2)
        )
        .font(font.font(at: scaledPoint, weight: weight))
        .foregroundStyle(theme.ink)
        .tint(theme.blueInk)
        .textFieldStyle(.plain)
        .focused(resolvedFocus)
        .overlay(alignment: .bottom) {
            if isFocused {
                focusUnderline
                    .offset(y: 4)
                    .allowsHitTesting(false)
            }
        }
    }

    /// The binding `TextField.focused` should resolve to: external if
    /// provided, otherwise the local FocusState.
    private var resolvedFocus: FocusState<Bool>.Binding {
        externalFocus ?? $localFocus
    }

    /// True iff the resolved focus source reports focus. Used by the
    /// underline overlay.
    private var isFocused: Bool {
        externalFocus?.wrappedValue ?? localFocus
    }

    /// Underline drawn beneath the field when focused. Defaults to the
    /// project's wavy-ink style; falls back to a flat 1pt rectangle when
    /// the user has Reduce Motion on (or Bold Text, which `WavyUnderline`
    /// short-circuits via the same path), because `WavyUnderline`'s static
    /// fallback calls `.underline()` on its content — and our content is
    /// `Color.clear` with no text, so the affordance would silently
    /// disappear for accessibility users.
    @ViewBuilder
    private var focusUnderline: some View {
        if reduceMotion {
            Rectangle()
                .fill(theme.blueInk.opacity(0.6))
                .frame(height: 1)
        } else {
            Color.clear
                .frame(height: 0)
                .wavyUnderline(color: theme.blueInk.opacity(0.6),
                               amplitude: 1,
                               wavelength: 6)
        }
    }
}
