import SwiftUI

/// Dashed "+ add a task" row pinned at the bottom of `TodoBlock`.
/// Two visual states driven by `composer.isComposing`:
///
/// 1. **Idle** — dashed-border row, faint "+ add a task" placeholder.
///    Tap → switches to composing.
/// 2. **Composing** — inline `InkTextField` with autofocus; Return
///    commits via `onCommit`; blur with empty title exits.
///
/// The composer state is owned by `DayPageViewModel`, not by this row,
/// so flipping pages keeps any in-progress draft alive while the user
/// reorients to a different day. The row reads `composer.isComposing`
/// to pick its visual state and writes back on tap/blur.
struct TodoAddRow: View {
    @Bindable var composer: TaskComposerState

    /// Invoked when the user presses Return on the inline field with a
    /// non-empty title. Wired to `DayPageViewModel.addTask()`.
    let onCommit: () async -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    @FocusState private var fieldFocused: Bool

    var body: some View {
        Group {
            if composer.isComposing {
                composingRow
            } else {
                idleRow
            }
        }
        .accessibilityIdentifier("daypage.todo.addRow")
    }

    // MARK: - Idle state

    /// Dashed-border row showing the faint "+ add a task" placeholder.
    /// Whole row is a `Button` so VoiceOver advertises the affordance.
    private var idleRow: some View {
        Button {
            composer.isComposing = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(theme.ink3)
                Text("add a task")
                    .font(font.font(at: 17 * size.scale, weight: .regular).italic())
                    .foregroundStyle(theme.ink3)
                Spacer(minLength: 0)
            }
            .padding(EdgeInsets(top: 6, leading: 4, bottom: 6, trailing: 4))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add a task")
        .accessibilityHint("Opens the inline task composer")
    }

    // MARK: - Composing state

    /// Inline `InkTextField` with a leading checkbox glyph so the field
    /// aligns with the `TodoRow`s above. Pressing Return commits;
    /// pressing Return with an empty title or blurring exits composing.
    private var composingRow: some View {
        HStack(spacing: 8) {
            checkboxGlyph
            InkTextField("new task…",
                         text: $composer.title,
                         variant: .body,
                         focus: $fieldFocused)
                .onSubmit {
                    Task { await commitAndContinue() }
                }
            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
        .task {
            // Autofocus on first appearance. Re-fires on every entry into
            // composing because composingRow remounts (Group branch swap).
            fieldFocused = true
        }
        .onChange(of: fieldFocused) { _, newValue in
            if newValue == false {
                // Field blurred. Commit if non-empty; exit otherwise.
                Task {
                    if composer.canCommit {
                        await onCommit()
                    } else {
                        composer.exit()
                    }
                }
            }
        }
    }

    /// Hollow ink checkbox stand-in so the composing row aligns to the
    /// 15×15 checkbox column of `TodoRow`s above. Drawn as a stroked
    /// rounded rectangle in the same `theme.ink` color.
    private var checkboxGlyph: some View {
        RoundedRectangle(cornerRadius: 1)
            .strokeBorder(theme.ink3, lineWidth: 1.4)
            .frame(width: 15, height: 15)
    }

    /// Commit the current draft, then keep the field focused for the
    /// next entry. `addTask()` calls `composer.reset()` (clears title,
    /// keeps `isComposing == true`); we re-set `fieldFocused = true`
    /// in case `onSubmit` blurred the field.
    private func commitAndContinue() async {
        guard composer.canCommit else {
            composer.exit()
            return
        }
        await onCommit()
        fieldFocused = true
    }
}

// MARK: - Previews

#Preview("TodoAddRow · Idle / Composing") {
    let idle = TaskComposerState(forDay: Date())
    let composing = TaskComposerState(forDay: Date())
    composing.isComposing = true

    return ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                VStack(alignment: .leading, spacing: 6) {
                    TodoAddRow(composer: idle, onCommit: {})
                    Divider()
                    TodoAddRow(composer: composing, onCommit: {})
                }
                .padding(.top, 40)
                .padding(.leading, 44)
                .padding(.trailing, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.cream)
}
