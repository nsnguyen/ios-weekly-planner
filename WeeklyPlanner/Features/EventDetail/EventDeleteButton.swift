import SwiftUI

/// "Delete" button at the bottom of the Paper Event Detail sheet. Full-width,
/// transparent background, dashed `redInk` border, and `redInk` handwriting
/// label.
///
/// The button itself only fires `action` — confirmation handling is the
/// caller's responsibility (`PaperEventSheet` shows the destructive alert
/// before calling `viewModel.delete()`).
struct EventDeleteButton: View {
    /// Visible button copy. Phase 29 (14): plain "Delete" — the prior "Tear
    /// out this page" read as cute-but-unclear in TestFlight feedback; the
    /// confirm alert already says "Delete this event?". Exposed as a static so
    /// it's unit-testable without view introspection.
    static let label = "Delete"

    /// Invoked on tap. Wires to a confirmation alert in the sheet root.
    var action: () -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        Button(action: action) {
            Text(Self.label)
                .font(font.font(at: 17, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(theme.redInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dashedBorder(color: theme.redInk, dash: [4, 3], lineWidth: 0.5, cornerRadius: 4)
        .accessibilityLabel("Delete event")
        .accessibilityHint("Double tap to confirm deletion")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(AccessibilityIDs.eventSheetDelete)
    }
}

// MARK: - Previews

#Preview("EventDeleteButton · Cream") {
    ZStack {
        BookCover()
        EventDeleteButton(action: {})
            .padding(.horizontal, 18)
            .background(PaperTheme.cream.cream)
            .padding(40)
    }
    .paperTheme(.cream)
}
