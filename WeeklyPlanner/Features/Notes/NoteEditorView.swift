import SwiftUI

/// Which note the editor is showing.
enum NoteEditorMode: Equatable {
    case new
    case existing(UUID)
}

/// Create/edit a note: ink title field, kind chips, ruled-paper body.
/// Back and Done both commit (auto-save semantics); an all-empty new
/// draft is discarded by `NotesViewModel.create`.
struct NoteEditorView: View {
    let mode: NoteEditorMode
    let viewModel: NotesViewModel
    let onClose: () -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    @State private var title = ""
    @State private var bodyText = ""
    @State private var kind: NoteKind = .misc
    @FocusState private var titleFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                InkTextField("Title", text: $title, variant: .title, focus: $titleFocused)
                    .padding(.trailing, 18)
                    .padding(.bottom, 10)

                kindPicker

                TextEditor(text: $bodyText)
                    .font(font.font(at: 17 * size.scale, weight: .regular))
                    .foregroundStyle(theme.ink)
                    .tint(theme.blueInk)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 180)
                    .padding(.trailing, 14)
                    .accessibilityLabel("Note body")
                    .accessibilityIdentifier(AccessibilityIDs.notesEditorBody)

                if case .existing = mode {
                    deleteButton
                }
            }
            .padding(.leading, 32)
            .padding(.bottom, 92)
        }
        .scrollDismissesKeyboard(.interactively)
        .task { await hydrate() }
    }

    private var header: some View {
        HStack {
            Button {
                Task { await commit() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Notes")
                        .font(font.font(at: 16 * size.scale, weight: .regular))
                }
                .foregroundStyle(theme.blueInk)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to notes")
            .accessibilityIdentifier(AccessibilityIDs.notesEditorBack)

            Spacer()

            Button {
                Task { await commit() }
            } label: {
                Text("Done")
                    .font(font.font(at: 16 * size.scale, weight: .bold))
                    .foregroundStyle(theme.blueInk)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityIDs.notesEditorDone)
        }
        .padding(.top, 14)
        .padding(.trailing, 18)
        .padding(.bottom, 10)
    }

    private var kindPicker: some View {
        HStack(spacing: 10) {
            kindChip(.misc, label: "Note")
            kindChip(.goal, label: "Goal")
            Spacer(minLength: 0)
        }
        .padding(.bottom, 10)
        .padding(.trailing, 18)
    }

    private func kindChip(_ value: NoteKind, label: String) -> some View {
        Button { kind = value } label: {
            Text(label)
                .font(font.font(at: 14 * size.scale, weight: kind == value ? .bold : .regular))
                .foregroundStyle(kind == value ? theme.redInk : theme.ink2)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(kind == value ? theme.redInk : theme.ink3,
                                      lineWidth: kind == value ? 1 : 0.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(kind == value ? [.isButton, .isSelected] : .isButton)
    }

    private var deleteButton: some View {
        Button {
            Task {
                if case let .existing(id) = mode {
                    await viewModel.delete(id: id)
                }
                onClose()
            }
        } label: {
            Text("Delete note")
                .font(font.font(at: 15 * size.scale, weight: .regular))
                .foregroundStyle(theme.redInk)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
        .accessibilityIdentifier(AccessibilityIDs.notesEditorDelete)
    }

    private func hydrate() async {
        switch mode {
        case .new:
            titleFocused = true
        case let .existing(id):
            if let note = viewModel.notes.first(where: { $0.id == id }) {
                title = note.title
                bodyText = note.body
                kind = note.kind
            }
        }
    }

    private func commit() async {
        switch mode {
        case .new:
            await viewModel.create(title: title, body: bodyText, kind: kind)
        case let .existing(id):
            await viewModel.update(id: id, title: title, body: bodyText, kind: kind)
        }
        onClose()
    }
}
