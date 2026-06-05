import SwiftUI

/// One note preview row: bold title line, single faint body line, and a
/// red-ink "goal" tag for goal-kind notes.
struct NoteRow: View {
    let note: Note
    let action: () -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(note.title.isEmpty ? "Untitled" : note.title)
                        .font(font.font(at: 18 * size.scale, weight: .bold))
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)
                    if note.kind == .goal {
                        Text("goal")
                            .font(font.font(at: 12 * size.scale, weight: .regular))
                            .foregroundStyle(theme.redInk)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(theme.redInk.opacity(0.5), lineWidth: 0.5)
                            )
                    }
                }
                if !note.body.isEmpty {
                    Text(note.body)
                        .font(font.font(at: 14 * size.scale, weight: .regular))
                        .foregroundStyle(theme.ink2)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 9)
            .padding(.leading, 18)
            .padding(.trailing, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Rectangle().fill(theme.ruleSoft).frame(height: 0.5)
            }
        }
        .buttonStyle(.plain)
        .accessibleNote(note)
        .accessibilityIdentifier(AccessibilityIDs.notesRow(note.id))
    }
}

#Preview("NoteRow · goal + misc") {
    VStack(spacing: 0) {
        NoteRow(note: Note(title: "Marathon", body: "Sub-4 this year", kind: .goal)) {}
        NoteRow(note: Note(title: "Groceries", body: "milk, eggs, bread", kind: .misc)) {}
    }
    .background(PaperTheme.cream.cream)
    .paperTheme(.cream)
}
