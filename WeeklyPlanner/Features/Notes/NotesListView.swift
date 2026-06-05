import SwiftUI

/// The notes list (or its empty state). Delete is exposed as a context
/// menu on each row — same affordance events use.
struct NotesListView: View {
    let notes: [Note]
    let onOpen: (Note) -> Void
    let onDelete: (Note) -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    var body: some View {
        if notes.isEmpty {
            Text("No notes yet — goals, lists, anything.")
                .font(font.font(at: 16 * size.scale, weight: .regular).italic())
                .foregroundStyle(theme.ink2)
                .padding(.vertical, 18)
                .padding(.leading, 18)
                .padding(.trailing, 18)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(notes, id: \.id) { note in
                    NoteRow(note: note) { onOpen(note) }
                        .contextMenu {
                            Button(role: .destructive) {
                                onDelete(note)
                            } label: {
                                Label("Delete note", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }
}
