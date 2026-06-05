import SwiftUI

/// The Notes tab page: standard paper-book chrome hosting the notes list,
/// which swaps to the editor in place (no sheet).
struct PaperNotesView: View {
    @Environment(\.noteStore) private var noteStore
    @Environment(\.paperTheme) private var theme

    @State private var viewModel: NotesViewModel?
    @State private var editing: NoteEditorMode?

    var body: some View {
        BookPage {
            PaperSurface {
                ZStack(alignment: .topLeading) {
                    PaperGrain()
                    RuledLines()
                    RedMarginLine()
                    HolePunches()

                    if let viewModel {
                        if let editing {
                            NoteEditorView(mode: editing, viewModel: viewModel) {
                                self.editing = nil
                            }
                        } else {
                            list(viewModel)
                        }
                    } else {
                        ProgressView().padding(.top, 60)
                    }
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = NotesViewModel(store: noteStore)
            }
            await viewModel?.load()
        }
    }

    private func list(_ vm: NotesViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                NotesHeader()
                NewNoteRow { editing = .new }
                NotesListView(notes: vm.notes,
                              onOpen: { editing = .existing($0.id) },
                              onDelete: { note in
                                  Task { await vm.delete(id: note.id) }
                              })
            }
            .padding(.leading, 32) // clear the red margin
            .padding(.bottom, 92)  // PaperTabBar clearance
        }
    }
}

#Preview("PaperNotesView · stub store") {
    PaperNotesView()
        .environment(\.noteStore, StubNoteStore())
        .paperTheme(.cream)
}
