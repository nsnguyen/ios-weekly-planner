import SwiftUI

/// Multi-line notes editor for `EditableEventContent`. Renders like the
/// other composer rows — leading handwriting label, trailing inline
/// `TextEditor` — but with a soft min-height so the user has visible
/// room to write without needing to scroll the sheet just to see two
/// lines. The editor grows as content does.
///
/// Style:
///   - Same 15pt handwriting label as `LocationField` / `PaperDateTimeRow`.
///   - `TextEditor` content uses handwriting at 17pt × size.scale.
///   - Faint italic placeholder ("Add notes…") rendered as a ZStack
///     under the editor so it disappears as soon as the user types.
///   - Hairline `theme.ink3` rule along the bottom edge to match
///     neighboring composer rows.
struct NotesField: View {
    @Binding var text: String

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("Notes")
                .font(font.font(at: 15 * size.scale, weight: .regular))
                .foregroundStyle(theme.ink2)
                .frame(width: 72, alignment: .leading)
                .padding(.top, 8)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Add notes…")
                        .font(font.font(at: 17 * size.scale, weight: .regular).italic())
                        .foregroundStyle(theme.ink2)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $text)
                    .font(font.font(at: 17 * size.scale, weight: .regular))
                    .foregroundStyle(theme.ink)
                    .tint(theme.blueInk)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80)
                    .focused($focused)
            }
        }
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.ink3)
                .frame(height: 0.5)
        }
        .accessibilityIdentifier("paperEventSheet.notes")
    }
}
