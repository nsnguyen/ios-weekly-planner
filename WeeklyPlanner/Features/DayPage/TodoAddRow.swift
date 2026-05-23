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

    /// Whether the surrounding `TodoBlock` already shows at least one
    /// task. Drives the label copy: `"add your first to-do"` when the
    /// patch is otherwise empty, `"add a to-do"` when it isn't. The flag
    /// is read-only — the parent always knows the answer cheaply.
    let hasExistingTasks: Bool

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

    /// Faint "+ add a to-do" placeholder row. The leading glyph is a
    /// small dashed-bordered square containing the `+` (matches the
    /// mock — visually rhymes with the `TodoRow` checkbox while reading
    /// as an empty add-affordance, not a completed item).
    private var idleRow: some View {
        Button {
            composer.isComposing = true
        } label: {
            HStack(spacing: 8) {
                dashedSquarePlus
                Text(hasExistingTasks ? "add a to-do" : "add your first to-do")
                    .font(font.font(at: 17 * size.scale, weight: .regular).italic())
                    .foregroundStyle(theme.ink3)
                Spacer(minLength: 0)
            }
            .padding(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 4))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(hasExistingTasks ? "Add a to-do" : "Add your first to-do")
        .accessibilityHint("Opens the inline to-do composer")
    }

    /// 15×15 dashed-bordered rounded square with a centered `+`. The
    /// dashed border matches the mock's "this is where you'd add one"
    /// vocabulary; sizing matches `TodoRow.checkbox` (15×15) so the
    /// glyph aligns with the column of real checkboxes above.
    private var dashedSquarePlus: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(theme.ink3,
                              style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                .frame(width: 15, height: 15)
            Image(systemName: "plus")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(theme.ink3)
        }
    }

    // MARK: - Composing state

    /// Inline `InkTextField` with a leading checkbox glyph so the field
    /// aligns with the `TodoRow`s above. Three commit/exit paths:
    ///
    /// - **Return key**: commits via `commitAndContinue()` and re-focuses
    ///   the field for chain-add (the user is still typing tasks).
    /// - **Tap anywhere on the page outside the to-do block**: external
    ///   code calls `composer.requestBlur()`, the
    ///   `.onChange(of: composer.pendingBlurToken)` handler below fires
    ///   `fieldFocused = false`, the `.onChange(of: fieldFocused)`
    ///   handler then commits-or-exits based on `canCommit`. This is the
    ///   Notes-style "tap outside to lock in" affordance.
    /// - **Programmatic blur** (e.g., a sheet opens): same path via the
    ///   blur handler.
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
        .onChange(of: composer.pendingBlurToken) {
            // External "tap outside" request — relinquish focus, which
            // trips the .onChange(of: fieldFocused) handler below into
            // its commit-or-exit branch.
            fieldFocused = false
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
                    TodoAddRow(composer: idle, hasExistingTasks: false, onCommit: {})
                    TodoAddRow(composer: idle, hasExistingTasks: true, onCommit: {})
                    Divider()
                    TodoAddRow(composer: composing, hasExistingTasks: true, onCommit: {})
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
