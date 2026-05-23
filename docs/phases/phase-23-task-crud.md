# Phase 23 — Manual Task CRUD

## Goal
Let the user add new tasks to a day's `TodoBlock` via an inline "+ add a task" row, edit priority + due date via a mini paper popover, and delete via swipe or popover.

## Why this is needed
The to-do block is currently toggle-only. Without inline add/edit/delete, users have no way to put a task into the planner from inside the app — they can only check off seeded ones.

## Prerequisites
- Phase 07 (`TodoBlock`, `TodoRow`), Phase 19 (notification rescheduling on `.taskStoreDidChange`), Phase 21 (accessibility), Phase 22 (`InkTextField` shared atom).

## Files Created / Modified

```
WeeklyPlanner/Features/DayPage/TaskComposerState.swift           # NEW
WeeklyPlanner/Features/DayPage/TaskMiniPopover.swift             # NEW
WeeklyPlanner/Features/DayPage/TodoBlock.swift                   # MODIFY — addRow, composer integration
WeeklyPlanner/Features/DayPage/TodoRow.swift                     # MODIFY — swipeActions + contextMenu
WeeklyPlanner/Features/DayPage/EmptyDayState.swift               # MODIFY — Add-task CTA
WeeklyPlanner/Features/DayPage/DayPageViewModel.swift            # MODIFY — addTask, updateTask, deleteTask
WeeklyPlanner/Stores/TaskStore.swift                             # MODIFY — +upsert, +delete
WeeklyPlanner/Stores/Environment+Stores.swift                    # MODIFY — Stub conformance
WeeklyPlannerTests/DayPage/TaskComposerStateTests.swift          # NEW
WeeklyPlannerTests/DayPage/TodoBlockCRUDTests.swift              # NEW
WeeklyPlannerTests/Stores/TaskStoreUpsertDeleteTests.swift       # NEW
WeeklyPlannerUITests/TaskCreateFlowUITests.swift                 # NEW
```

## Visual & Interaction Checklist

### `TodoBlock` add row (idle state)
- [ ] Pinned at the bottom of the existing `VStack`, after the last `TodoRow`.
- [ ] Dashed border row (0.5pt dashed in `theme.ink3`), padding `8 12` vertical, leading-aligned.
- [ ] Leading "+" ink-stroke glyph (12×12 `Canvas`-drawn) in `theme.ink3`.
- [ ] Placeholder text `"add a task"` in handwriting font, 17pt, `theme.ink3`, italic.
- [ ] Tap → switches to composing state (instant, no animation).
- [ ] Hidden when `EmptyDayState` is showing AND user hasn't tapped the Add-task CTA there yet.

### `TodoBlock` add row (composing state)
- [ ] Inline `InkTextField` (from Phase 22) with autofocus on appear.
- [ ] Same handwriting 17pt; placeholder `"new task…"`.
- [ ] Return commits non-empty title → `composer.build()` → `viewModel.addTask(...)` → `composer.reset()` → field stays focused for next entry.
- [ ] Empty Return / blur → exits composing without saving.
- [ ] A tiny `theme.blueInk` checkbox glyph appears to the left during composing (matches `TodoRow` layout so the field doesn't jump on commit).

### `TodoRow` swipe + long-press
- [ ] `.swipeActions(edge: .trailing)`:
  - [ ] `"Delete"` (destructive role) → `viewModel.deleteTask(id:)` after a 200ms strikethrough+fade animation.
- [ ] `.swipeActions(edge: .leading)`:
  - [ ] `"Priority"` → cycles low → medium → high → low. Spring animation on the priority bang glyph.
- [ ] `.contextMenu`:
  - [ ] Renders `TaskMiniPopover` anchored to the row via `.popover()`.

### `TaskMiniPopover`
- [ ] ~220×180 paper card (`PaperSurface` background, rounded 4pt, tilt -1°, shadow `0 4 12 rgba(0,0,0,0.18)`).
- [ ] Header: handwriting "Edit task", 13pt, `theme.ink2`.
- [ ] Priority row: 3 ink dots (gray / yellow / red — sized 18pt, gap 12pt); selected gets a 1.5pt ink ring.
- [ ] Due row: 3 chips ("Today" / "Tomorrow" / "Pick…"). Active chip ink-blue text + underline. `Pick…` reveals a graphical `DatePicker` below the row.
- [ ] Delete row: handwriting "Delete" in `theme.redInk` with `WavyUnderline` underneath.
- [ ] Footer: handwriting "Done" in `theme.blueInk`, trailing-aligned, dismisses popover.
- [ ] Tapping a priority/due option commits immediately (no separate Save button) → `viewModel.updateTask(id:, mutation:)`.

### `EmptyDayState` evolution
- [ ] Below the existing empty hint text, add `"+ add a task"` link (handwriting 17pt, `theme.blueInk`, underline).
- [ ] Tap → `composer.isComposing = true` AND `TodoBlock` renders an embedded composer even though `tasks.isEmpty`.

## Logic & Data Checklist

### `TaskComposerState`
- [ ] `@MainActor @Observable`.
- [ ] `var title: String = ""`, `var isComposing: Bool = false`, `var priority: Priority = .medium`, `var due: Date`.
- [ ] `func build(forDay date: Date) -> TaskItem` — uses current `priority`, sets `due` to date, generates new `UUID`.
- [ ] `func reset()` — clears title, leaves `isComposing` true so user can chain entries.
- [ ] `func exit()` — clears all, sets `isComposing = false`.

### `TaskStoring` protocol
- [ ] New: `func upsert(_ task: TaskItem) async throws`.
- [ ] New: `func delete(id: UUID) async throws`.
- [ ] Both must post `.taskStoreDidChange` on success (so `NotificationReschedulingObserver` from Phase 19 reschedules).
- [ ] `SwiftDataTaskStore`: implement both. Delete uses `context.delete(_:)` + `save()`; upsert uses `FetchDescriptor` by id then either modify or insert.
- [ ] `StubTaskStore`: in-memory implementation, mirrors `.taskStoreDidChange` post.

### `DayPageViewModel`
- [ ] New: `func addTask(_ task: TaskItem) async` — calls `taskStore.upsert`, then `refresh()`.
- [ ] New: `func updateTask(id: UUID, mutation: (inout TaskItem) -> Void) async` — fetch by id, mutate, upsert.
- [ ] New: `func deleteTask(id: UUID) async` — calls `taskStore.delete`, refreshes.
- [ ] Existing `toggleTask` unchanged.

### Default values for `+ add a task`
- [ ] `priority = .medium`.
- [ ] `due = <currentDayPageDate>` (the day the user is viewing).
- [ ] `reminderTime = nil`.
- [ ] `locationReminder = nil`.

## Tests (TDD)

`TaskComposerStateTests`
- [ ] `testCanCommit_falseWhenTitleEmpty`.
- [ ] `testBuild_usesProvidedDay_and_currentPriority`.
- [ ] `testReset_clearsTitleKeepsComposing`.
- [ ] `testExit_clearsAll`.

`TodoBlockCRUDTests`
- [ ] `testAddRowComposes_andReturnCommitsTask`.
- [ ] `testAddRowEmptyReturn_discards`.
- [ ] `testSwipeDelete_callsStoreDelete`.
- [ ] `testLongPress_opensMiniPopover_andPriorityChangeCallsUpsert`.
- [ ] `testMiniPopover_dueChip_Tomorrow_setsDueToNextDay`.

`TaskStoreUpsertDeleteTests`
- [ ] `testUpsert_newTask_persists_and_postsChange`.
- [ ] `testUpsert_existingTask_replacesFields`.
- [ ] `testDelete_removesAndPostsChange`.
- [ ] `testDelete_unknownID_throwsNotFound`.

`TaskCreateFlowUITests`
- [ ] `testInlineAddTask_endToEnd` — tap add-row, type "Prep slides", Return; assert row appears.

## Acceptance Criteria
- Tap dashed row → inline text field with caret on screen in <300ms.
- Type + Return commits the task; refresh shows it sorted by priority.
- Empty title + Return / blur → no row created.
- Swipe left → Delete; tap Delete → row animates out with strikethrough fade.
- Long-press → mini popover opens; changing priority reflects in the bang glyph after dismissing.
- All accessibility audit UI tests still green.

## Out of Scope
- Multi-line task notes.
- Recurring tasks.
- Task → event conversion.
- Drag-to-reorder.

## Risks & Notes
- **`@FocusState` + autofocus timing** in SwiftUI 17 races insertion. Use `.task { focused = true }` not `.onAppear`.
- **Swipe-actions vs horizontal page-flip gesture.** `HorizontalSwipeGesture` lives at `PaperSurface` level; trailing swipe on `swipeActions` row should consume the horizontal drag first. Verify on-device — Phase 08 had a similar pattern collision.
- **Popover positioning** near screen bottom — SwiftUI's `.popover()` auto-flips; prefer that over a manual ZStack overlay.
- **`Priority` enum identity** — Phase 21 retrospective notes `Category.social` doesn't exist; double-check `Priority.low/.medium/.high` slugs against `Models/Priority.swift` before writing tests.
