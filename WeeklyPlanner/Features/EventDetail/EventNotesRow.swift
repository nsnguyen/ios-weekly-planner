import SwiftUI

/// Read-only view-mode row that renders the user's authored event notes.
/// Sits between `EventInviteesRow` and the AI sticky in `PaperEventSheet`.
///
/// Visual recipe: same handwriting-label-on-the-left shape as the
/// editable rows, with the notes body rendered as flowing handwriting
/// underneath. Hairline rule along the bottom edge matches the
/// neighboring rows so the body reads as one connected stack.
struct EventNotesRow: View {
    let notes: String

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notes")
                .font(font.font(at: 13 * size.scale, weight: .regular))
                .foregroundStyle(theme.ink2)

            Text(notes)
                .font(font.font(at: 17 * size.scale, weight: .regular))
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.ink3)
                .frame(height: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Notes: \(notes)")
    }
}
