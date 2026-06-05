import SwiftUI

/// "+ New note" affordance under the header.
struct NewNoteRow: View {
    let action: () -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                Text("New note")
                    .font(font.font(at: 17 * size.scale, weight: .regular))
            }
            .foregroundStyle(theme.blueInk)
            .padding(.vertical, 10)
            .padding(.leading, 18)
            .padding(.trailing, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New note")
        .accessibilityHint("Double tap to write a new note.")
        .accessibilityIdentifier(AccessibilityIDs.notesAddRow)
    }
}

#Preview("NewNoteRow · cream") {
    NewNoteRow {}
        .background(PaperTheme.cream.cream)
        .paperTheme(.cream)
}
