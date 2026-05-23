# Phase 23 — Manual Task CRUD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user add tasks via an inline "+ add a task" row inside `TodoBlock`, edit priority + due date via a mini paper popover (long-press), and delete via swipe or popover. Auto-refresh the Day page on `.taskStoreDidChange` so adds/edits/deletes appear immediately.

**Architecture:** A new `TaskComposerState` (`@Observable`) carries the draft. `TodoBlock` flips from "renders only when tasks exist" to "renders when tasks exist OR composer is active," embedding a new `TodoAddRow` atom at the bottom. `TodoRow` gains `.swipeActions(.trailing)` for delete and `.contextMenu` (long-press) that opens a `TaskMiniPopover` for priority + due + delete. `EmptyDayState` adds an "Add a task" CTA that flips the composer on. `DayPageContent` listens to `.taskStoreDidChange` and refreshes — mirroring Phase 22's `.eventStoreDidChange` observer.

**Tech Stack:** Swift 6, SwiftUI (iOS 26+), SwiftData, `@Observable`, `@Bindable`, `@FocusState`, the existing `InkTextField` atom from Phase 22, and the existing `TaskStoring` protocol — which ALREADY exposes `upsert(_:)` and `delete(id:)` (no protocol changes required).

**Spec:** `docs/phases/phase-23-task-crud.md` · **Branch:** `milestone-j-completeness` (already on it, Phase 22 landed at `142310d`).

**Critical API note from the codebase survey** (override the phase doc where needed):
- `Priority` cases are `.low`, `.med`, `.high` — **not `.medium`**. Phase doc says "low/med/high" in some prose; tests must use `.med`.
- `TaskStoring.upsert(_:)` and `TaskStoring.delete(id:)` ALREADY exist (verified at `WeeklyPlanner/Stores/TaskStore.swift:8,10`). They post `.taskStoreDidChange` on success. The phase doc's "Store API surface" requirement is a no-op.
- `SwiftDataTaskStore` and `StubTaskStore` both already implement those methods (verified at `TaskStore.swift:35-56,66-71` and `Environment+Stores.swift:139-141`).
- `TodoBlock` currently early-returns `EmptyView()` when `tasks.isEmpty` (`TodoBlock.swift:31-33`); we replace that gate with a "tasks OR composer active" condition.
- `EventEntryList` accepted an `onEdit` callback in Phase 22 Task 10; `TodoRow` and `TodoBlock` predate that, so we wire long-press in this phase.

---

## File Structure

### New files

| Path | Responsibility |
|------|----------------|
| `WeeklyPlanner/Features/DayPage/TaskComposerState.swift` | `@Observable` draft state — title, isComposing, priority, due, focus binding |
| `WeeklyPlanner/Features/DayPage/TodoAddRow.swift` | Dashed "+ add a task" row — two visual states (idle / composing inline field) |
| `WeeklyPlanner/Features/DayPage/TaskMiniPopover.swift` | Long-press editor — priority swatches, due chips, Delete button |
| `WeeklyPlannerTests/DayPage/TaskComposerStateTests.swift` | Composer state unit tests |
| `WeeklyPlannerTests/DayPage/TodoBlockCRUDTests.swift` | VM-contract tests for addTask/updateTask/deleteTask |
| `WeeklyPlannerUITests/TaskCreateFlowUITests.swift` | End-to-end add-task UITest |

### Modified files

| Path | Why |
|------|-----|
| `WeeklyPlanner/Features/DayPage/TodoBlock.swift` | Flip gate from "tasks.isEmpty" to "tasks.isEmpty && !composer.isComposing"; embed `TodoAddRow`; accept `composer` + `onAddTask` + `onEditTask` + `onDeleteTask` parameters |
| `WeeklyPlanner/Features/DayPage/TodoRow.swift` | Wrap in `.swipeActions(.trailing)` for delete; wrap in `.contextMenu` to open `TaskMiniPopover` |
| `WeeklyPlanner/Features/DayPage/EmptyDayState.swift` | Optional `"Add a task"` CTA below the main caption; tap → flips composer on |
| `WeeklyPlanner/Features/DayPage/DayPageViewModel.swift` | New methods: `addTask(_:)`, `updateTask(id:mutation:)`, `deleteTask(id:)`; expose a `taskComposer: TaskComposerState` instance |
| `WeeklyPlanner/Features/DayPage/DayPageView.swift` | Pass `composer` + the three callbacks to `TodoBlock`; pass CTA callback to `EmptyDayState`; add `.onReceive(.taskStoreDidChange)` to refresh |
| `WeeklyPlanner/Features/WeekPage/WeekPageView.swift` | Same `.onReceive(.taskStoreDidChange)` observer added (matches Phase 22 auto-refresh pattern) |
| `WeeklyPlannerTests/DayPage/DayPageViewModelTests.swift` (if exists) | Append VM tests for the new mutation methods — or create the file if missing |

---

## Conventions for this plan

- Tests run via:
  ```bash
  xcodebuild test \
    -project WeeklyPlanner.xcodeproj \
    -scheme WeeklyPlanner \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
    -only-testing:WeeklyPlannerTests/<ClassName> \
    CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -25
  ```
- New `.swift` files under `WeeklyPlanner/` or `WeeklyPlannerTests/` may require `xcodegen generate` before the next build (per Phase 22 experience — XcodeGen tracks files explicitly).
- Each task ends with `git add <files> && git commit -m "feat(phase-23): ..."` on `milestone-j-completeness`.
- SourceKit emits stale "Cannot find type" / "No exact matches" diagnostics throughout — trust `xcodebuild`, not the editor's indexer.

---

## Task 1: `TaskComposerState` — `@Observable` draft

**Files:**
- Create: `WeeklyPlanner/Features/DayPage/TaskComposerState.swift`
- Test: `WeeklyPlannerTests/DayPage/TaskComposerStateTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `WeeklyPlannerTests/DayPage/TaskComposerStateTests.swift`:

```swift
import Foundation
import XCTest
@testable import WeeklyPlanner

@MainActor
final class TaskComposerStateTests: XCTestCase {
    func testDefaults() {
        let day = Date(timeIntervalSince1970: 1_780_000_000)
        let state = TaskComposerState(forDay: day)
        XCTAssertEqual(state.title, "")
        XCTAssertFalse(state.isComposing)
        XCTAssertEqual(state.priority, .med)
        XCTAssertEqual(state.due, day)
        XCTAssertFalse(state.canCommit)
    }

    func testCanCommit_falseWhenTitleEmptyOrWhitespace() {
        let state = TaskComposerState(forDay: Date())
        XCTAssertFalse(state.canCommit)
        state.title = "   "
        XCTAssertFalse(state.canCommit)
        state.title = "Prep slides"
        XCTAssertTrue(state.canCommit)
    }

    func testBuild_usesDayAndCurrentPriority_trimsTitle() {
        let day = Date(timeIntervalSince1970: 1_780_000_000)
        let state = TaskComposerState(forDay: day)
        state.title = "  Prep slides  "
        state.priority = .high
        let task = state.build(category: .work)
        XCTAssertEqual(task.title, "Prep slides")
        XCTAssertEqual(task.priority, .high)
        XCTAssertEqual(task.due, day)
        XCTAssertEqual(task.category, .work)
        XCTAssertFalse(task.done)
    }

    func testReset_clearsTitleKeepsComposing() {
        let state = TaskComposerState(forDay: Date())
        state.isComposing = true
        state.title = "Prep slides"
        state.reset()
        XCTAssertEqual(state.title, "")
        XCTAssertTrue(state.isComposing, "reset should keep composing so user can chain adds")
    }

    func testExit_clearsAndStopsComposing() {
        let state = TaskComposerState(forDay: Date())
        state.isComposing = true
        state.title = "Prep slides"
        state.priority = .high
        state.exit()
        XCTAssertEqual(state.title, "")
        XCTAssertFalse(state.isComposing)
        XCTAssertEqual(state.priority, .med, "exit should reset priority to the default")
    }

    func testSetDay_updatesDueDate() {
        let firstDay = Date(timeIntervalSince1970: 1_780_000_000)
        let nextDay = firstDay.addingTimeInterval(86_400)
        let state = TaskComposerState(forDay: firstDay)
        state.setDay(nextDay)
        XCTAssertEqual(state.due, nextDay)
    }
}
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/TaskComposerStateTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -20
```

Expected: BUILD FAILED, "Cannot find 'TaskComposerState'".

- [ ] **Step 3: Create `TaskComposerState`**

Create `WeeklyPlanner/Features/DayPage/TaskComposerState.swift`:

```swift
import Foundation
import Observation

/// Editable draft for a new `TaskItem`. Held by `DayPageViewModel` and
/// bound to the inline `+ add a task` row in `TodoBlock`. Two-way bound
/// via `@Bindable` so `TextField` two-way bindings work.
///
/// The composer exposes only the fields the inline row + mini popover
/// expose to the user: title, priority, due. `category` is supplied by
/// the caller at `build(category:)` time (defaults to `.personal` from
/// the view-model layer).
@MainActor
@Observable
final class TaskComposerState {
    var title: String = ""
    var isComposing: Bool = false
    var priority: Priority = .med
    var due: Date

    init(forDay date: Date) {
        self.due = date
    }

    var canCommit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Build a fresh `TaskItem` from the current draft. Caller supplies
    /// the `category` (typically `.personal` until the UI exposes a
    /// picker). Trims whitespace from the title; `done` always starts
    /// false; reminders are nil — the popover doesn't manage reminders
    /// in v1.
    func build(category: Category = .personal) -> TaskItem {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return TaskItem(title: trimmed,
                         due: due,
                         done: false,
                         priority: priority,
                         category: category)
    }

    /// Clear the title; KEEP `isComposing == true` so the user can chain
    /// add-task entries by tapping Return repeatedly.
    func reset() {
        title = ""
    }

    /// Clear everything and exit composing. Used when the user blurs the
    /// field with an empty title, taps Cancel, or the popover dismisses.
    func exit() {
        title = ""
        priority = .med
        isComposing = false
    }

    /// Update the anchor day. Called when the composer is mounted on a
    /// new Day page (e.g., user flipped to a different day with the
    /// composer open).
    func setDay(_ date: Date) {
        due = date
    }
}
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
xcodegen generate 2>&1 | tail -3
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/TaskComposerStateTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -20
```

Expected: TEST SUCCEEDED, 6 tests passed.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Features/DayPage/TaskComposerState.swift \
       WeeklyPlannerTests/DayPage/TaskComposerStateTests.swift
git commit -m "feat(phase-23): TaskComposerState — draft + validation + build

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: `DayPageViewModel` — composer + addTask/updateTask/deleteTask

**Files:**
- Modify: `WeeklyPlanner/Features/DayPage/DayPageViewModel.swift`
- Test: `WeeklyPlannerTests/DayPage/TodoBlockCRUDTests.swift` (new — covers the VM contract)

- [ ] **Step 1: Write the failing tests**

Create `WeeklyPlannerTests/DayPage/TodoBlockCRUDTests.swift`:

```swift
import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

/// VM-contract tests for the task-CRUD methods added by Phase 23.
/// Named `TodoBlockCRUDTests` (per phase doc) even though the assertions
/// target `DayPageViewModel` directly — the view contract is the same.
@MainActor
final class TodoBlockCRUDTests: XCTestCase {
    private var container: ModelContainer!
    private var taskStore: SwiftDataTaskStore!
    private var eventStore: SwiftDataEventStore!
    private var inboxStore: SwiftDataInboxStore!
    private var calendar: Calendar!
    private var today: Date!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        taskStore = SwiftDataTaskStore(context: container.mainContext)
        eventStore = SwiftDataEventStore(context: container.mainContext)
        inboxStore = SwiftDataInboxStore(context: container.mainContext)
        calendar = WeekMath.mondayCalendar()
        today = Date(timeIntervalSince1970: 1_780_000_000)
    }

    override func tearDown() async throws {
        taskStore = nil; eventStore = nil; inboxStore = nil
        calendar = nil; today = nil; container = nil
        try await super.tearDown()
    }

    private func makeViewModel() -> DayPageViewModel {
        DayPageViewModel(weekOffset: 0,
                          dayIdx: WeekMath.todayIndex(in: WeekMath.weekDays(forOffset: 0,
                                                                            today: today),
                                                       for: today) ?? 0,
                          eventStore: eventStore,
                          inboxStore: inboxStore,
                          taskStore: taskStore,
                          clock: { self.today })
    }

    func testAddTask_persistsAndAppearsInList() async throws {
        let vm = makeViewModel()
        await vm.refresh()
        XCTAssertEqual(vm.tasks.count, 0)

        vm.taskComposer.title = "Prep slides"
        vm.taskComposer.priority = .high
        await vm.addTask()

        await vm.refresh()
        XCTAssertEqual(vm.tasks.count, 1)
        XCTAssertEqual(vm.tasks.first?.title, "Prep slides")
        XCTAssertEqual(vm.tasks.first?.priority, .high)
    }

    func testAddTask_emptyTitle_isNoOp() async throws {
        let vm = makeViewModel()
        vm.taskComposer.title = "   "
        await vm.addTask()
        await vm.refresh()
        XCTAssertEqual(vm.tasks.count, 0)
    }

    func testAddTask_resetsTitleKeepsComposing() async throws {
        let vm = makeViewModel()
        vm.taskComposer.isComposing = true
        vm.taskComposer.title = "Prep slides"
        await vm.addTask()
        XCTAssertEqual(vm.taskComposer.title, "")
        XCTAssertTrue(vm.taskComposer.isComposing)
    }

    func testDeleteTask_removesRow() async throws {
        let task = TaskItem(title: "Prep slides",
                            due: today,
                            priority: .med,
                            category: .personal)
        try await taskStore.upsert(task)

        let vm = makeViewModel()
        await vm.refresh()
        XCTAssertEqual(vm.tasks.count, 1)

        await vm.deleteTask(id: task.id)
        await vm.refresh()
        XCTAssertEqual(vm.tasks.count, 0)
    }

    func testUpdateTask_changesPriority() async throws {
        let task = TaskItem(title: "Prep slides",
                            due: today,
                            priority: .low,
                            category: .personal)
        try await taskStore.upsert(task)

        let vm = makeViewModel()
        await vm.refresh()

        await vm.updateTask(id: task.id) { $0.priority = .high }
        await vm.refresh()
        XCTAssertEqual(vm.tasks.first?.priority, .high)
    }

    func testUpdateTask_changesDueDate() async throws {
        let task = TaskItem(title: "Prep slides",
                            due: today,
                            priority: .med,
                            category: .personal)
        try await taskStore.upsert(task)

        let vm = makeViewModel()
        await vm.refresh()

        let tomorrow = today.addingTimeInterval(86_400)
        await vm.updateTask(id: task.id) { $0.due = tomorrow }
        await vm.refresh()
        // The task moved to a different day; this day-vm should no
        // longer surface it.
        XCTAssertEqual(vm.tasks.count, 0)
    }
}
```

- [ ] **Step 2: Run — verify FAIL with "no member 'taskComposer'" / "addTask" / etc.**

```bash
xcodegen generate 2>&1 | tail -3
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/TodoBlockCRUDTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -25
```

Expected: BUILD FAILED, "no member 'taskComposer'" or "'addTask'".

- [ ] **Step 3: Extend `DayPageViewModel`**

Open `WeeklyPlanner/Features/DayPage/DayPageViewModel.swift`. The existing class is `@MainActor @Observable final class DayPageViewModel` with `events`, `inbox`, `tasks`, `loadError`, stored deps, and methods `refresh()`, `accept`, `dismiss`, `toggleTask`, plus a private `refreshStickyInsightIfNeeded`.

Add a stored property near the other published vars (`var events`, `var inbox`, `var tasks`, `var loadError`):

```swift
    /// Inline-add composer for the to-do block. Reset on every refresh
    /// to the focused day so a flipped page hands the user a fresh row
    /// anchored at the right date.
    var taskComposer: TaskComposerState
```

Initialize it in the `init`. Find the existing init parameter list:

```swift
    init(weekOffset: Int,
         dayIdx: Int,
         eventStore: any EventStoring,
         inboxStore: any InboxStoring,
         taskStore: any TaskStoring,
         stickyGenerator: StickyInsightGenerator? = nil,
         modelContext: ModelContext? = nil,
         clock: @escaping () -> Date = { .init() })
    {
```

At the bottom of the existing `init` body (after `self.clock = clock`), add:

```swift
        // Anchor the composer to this day-vm's date. Re-anchored in
        // refresh() so the composer always points at the focused day
        // even if the system date crosses midnight while the page is open.
        let days = WeekMath.weekDays(forOffset: weekOffset, today: clock())
        let anchor = days.indices.contains(dayIdx) ? days[dayIdx].date : clock()
        self.taskComposer = TaskComposerState(forDay: anchor)
```

Add a date-anchor refresh inside `refresh()`. Find the existing `func refresh() async` body. At the top (after `let calendar = WeekMath.mondayCalendar()` and `let now = clock()`), keep the existing code; AFTER the `await refreshStickyInsightIfNeeded(now: now)` line at the bottom, add:

```swift
        // Re-anchor the composer in case the clock advanced past midnight
        // while the page was visible. The composer's day matches this
        // page's date, not "today".
        let days = WeekMath.weekDays(forOffset: weekOffset, today: now)
        if days.indices.contains(dayIdx) {
            taskComposer.setDay(days[dayIdx].date)
        }
```

Then append three new methods. Place them after the existing `toggleTask(id:)`:

```swift
    /// Commit the composer's current draft. No-op when `canCommit` is
    /// false (empty title). On success, resets the composer's title (so
    /// the user can chain adds) but keeps `isComposing == true`.
    /// Surfaces errors via `loadError`.
    func addTask() async {
        guard taskComposer.canCommit else { return }
        let task = taskComposer.build(category: .personal)
        do {
            try await taskStore.upsert(task)
        } catch {
            loadError = error.localizedDescription
        }
        taskComposer.reset()
        await refresh()
    }

    /// Fetch the task by id, apply the mutation, persist via upsert.
    /// Used by the mini popover for priority / due-date / title edits.
    func updateTask(id: UUID, mutation: (TaskItem) -> Void) async {
        do {
            guard let task = try await taskStore.task(id: id) else { return }
            mutation(task)
            try await taskStore.upsert(task)
        } catch {
            loadError = error.localizedDescription
        }
        await refresh()
    }

    /// Delete the task and refresh.
    func deleteTask(id: UUID) async {
        do {
            try await taskStore.delete(id: id)
        } catch {
            loadError = error.localizedDescription
        }
        await refresh()
    }
```

- [ ] **Step 4: Run the new tests — should PASS now**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/TodoBlockCRUDTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -25
```

Expected: TEST SUCCEEDED, 6 tests passed.

- [ ] **Step 5: Run the full unit-test suite to confirm no regressions**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -10
```

Expected: TEST SUCCEEDED. Baseline was 321 (after Phase 22). New Task 1 (+6) + Task 2 (+6) = 333.

- [ ] **Step 6: Commit**

```bash
git add WeeklyPlanner/Features/DayPage/DayPageViewModel.swift \
       WeeklyPlannerTests/DayPage/TodoBlockCRUDTests.swift
git commit -m "feat(phase-23): DayPageViewModel — taskComposer + addTask/updateTask/deleteTask

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: `TodoAddRow` atom — dashed "+ add a task" row

**Files:**
- Create: `WeeklyPlanner/Features/DayPage/TodoAddRow.swift`

**Why:** Two-state visual atom — idle (dashed border, "+ add a task" placeholder) and composing (inline `InkTextField` with autofocus). Reuses Phase 22's `InkTextField` with an external focus binding so the parent can drive focus.

- [ ] **Step 1: Create the file**

```swift
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
```

- [ ] **Step 2: Verify it compiles**

```bash
xcodegen generate 2>&1 | tail -3
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Features/DayPage/TodoAddRow.swift
git commit -m "feat(phase-23): TodoAddRow — dashed +add a task row with inline composer

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: `TaskMiniPopover` — priority/due/delete editor

**Files:**
- Create: `WeeklyPlanner/Features/DayPage/TaskMiniPopover.swift`

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

/// Floating paper-card popover anchored to a `TodoRow` via SwiftUI's
/// `.popover()` modifier. Lets the user adjust priority (3 ink swatches),
/// due date (Today / Tomorrow / Pick…), or delete the task.
///
/// The popover commits each control change immediately — no Save
/// button. Tapping "Done" dismisses; tapping "Delete" raises a
/// confirmation via the caller's `onDelete` callback.
struct TaskMiniPopover: View {
    let task: TaskItem
    let onPriorityChange: (Priority) -> Void
    let onDueChange: (Date) -> Void
    let onDelete: () -> Void
    let onDismiss: () -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    @State private var pickingDate: Date

    init(task: TaskItem,
         onPriorityChange: @escaping (Priority) -> Void,
         onDueChange: @escaping (Date) -> Void,
         onDelete: @escaping () -> Void,
         onDismiss: @escaping () -> Void)
    {
        self.task = task
        self.onPriorityChange = onPriorityChange
        self.onDueChange = onDueChange
        self.onDelete = onDelete
        self.onDismiss = onDismiss
        _pickingDate = State(initialValue: task.due)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            priorityRow
            dueRow
            Divider().background(theme.ink3)
            deleteRow
            HStack {
                Spacer()
                Button("Done", action: onDismiss)
                    .font(font.font(at: 15 * size.scale, weight: .bold))
                    .foregroundStyle(theme.blueInk)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("daypage.todo.popover.done")
            }
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
        .frame(minWidth: 240)
        .presentationCompactAdaptation(.popover)
    }

    // MARK: - Subviews

    private var header: some View {
        Text("Edit task")
            .font(font.font(at: 13 * size.scale, weight: .regular))
            .foregroundStyle(theme.ink2)
    }

    private var priorityRow: some View {
        HStack(spacing: 12) {
            Text("Priority")
                .font(font.font(at: 15 * size.scale, weight: .regular))
                .foregroundStyle(theme.ink2)
                .frame(width: 72, alignment: .leading)

            HStack(spacing: 14) {
                ForEach(Priority.allCases, id: \.self) { priority in
                    swatch(for: priority)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func swatch(for priority: Priority) -> some View {
        let isSelected = task.priority == priority
        let color: Color = switch priority {
        case .low: theme.ink3
        case .med: Color(.sRGB, red: 0.95, green: 0.78, blue: 0.30, opacity: 1)
        case .high: theme.redInk
        }
        return Button {
            onPriorityChange(priority)
        } label: {
            ZStack {
                Circle().fill(color).frame(width: 18, height: 18)
                if isSelected {
                    Circle()
                        .stroke(theme.ink, lineWidth: 1.5)
                        .frame(width: 26, height: 26)
                }
            }
            .contentShape(Rectangle().inset(by: -6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(priority.rawValue.capitalized) priority")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var dueRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("Due")
                    .font(font.font(at: 15 * size.scale, weight: .regular))
                    .foregroundStyle(theme.ink2)
                    .frame(width: 72, alignment: .leading)

                dueChip(label: "Today", date: startOfDay(Date()))
                dueChip(label: "Tomorrow", date: startOfDay(Date().addingTimeInterval(86_400)))
                dueChip(label: "Pick…", date: nil)
                Spacer(minLength: 0)
            }

            if showsDatePicker {
                DatePicker("",
                           selection: $pickingDate,
                           displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(theme.blueInk)
                    .onChange(of: pickingDate) { _, newValue in
                        onDueChange(newValue)
                    }
            }
        }
    }

    @State private var showsDatePicker: Bool = false

    private func dueChip(label: String, date: Date?) -> some View {
        let isCurrent: Bool = {
            guard let date else { return showsDatePicker }
            return isSameDay(task.due, date)
        }()
        return Button {
            if let date {
                showsDatePicker = false
                onDueChange(date)
            } else {
                showsDatePicker.toggle()
            }
        } label: {
            Text(label)
                .font(font.font(at: 14 * size.scale,
                                weight: isCurrent ? .bold : .regular))
                .foregroundStyle(isCurrent ? theme.blueInk : theme.ink2)
                .underline(isCurrent, color: theme.blueInk)
        }
        .buttonStyle(.plain)
    }

    private var deleteRow: some View {
        Button(action: onDelete) {
            HStack(spacing: 6) {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                Text("Delete task")
                    .font(font.font(at: 15 * size.scale, weight: .regular))
            }
            .foregroundStyle(theme.redInk)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("daypage.todo.popover.delete")
    }

    // MARK: - Helpers

    private func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private func isSameDay(_ a: Date, _ b: Date) -> Bool {
        Calendar.current.isDate(a, inSameDayAs: b)
    }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
xcodegen generate 2>&1 | tail -3
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Features/DayPage/TaskMiniPopover.swift
git commit -m "feat(phase-23): TaskMiniPopover — priority swatches + due chips + delete

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: `TodoRow` — swipe-to-delete + long-press context menu

**Files:**
- Modify: `WeeklyPlanner/Features/DayPage/TodoRow.swift`

- [ ] **Step 1: Modify `TodoRow.swift`**

Open `WeeklyPlanner/Features/DayPage/TodoRow.swift`. Add three new `var` callbacks alongside `onToggle`:

```swift
struct TodoRow: View {
    let task: TaskItem
    var onToggle: () -> Void
    var onDelete: (() -> Void)?
    var onLongPress: (() -> Void)?
```

(Default both new callbacks to `nil` so existing call sites that pass only `onToggle` keep working — `TodoBlock` will be updated in Task 6 to pass the new callbacks.)

Add an `init` matching the new shape (Swift won't synthesize one that preserves the optional defaults if `var`s are reordered, so be explicit):

```swift
    init(task: TaskItem,
         onToggle: @escaping () -> Void,
         onDelete: (() -> Void)? = nil,
         onLongPress: (() -> Void)? = nil)
    {
        self.task = task
        self.onToggle = onToggle
        self.onDelete = onDelete
        self.onLongPress = onLongPress
    }
```

Wrap the existing `Button(action: onToggle) { ... }` body in `.swipeActions` + `.contextMenu`. Replace the current `body` with:

```swift
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                checkbox
                title
                if showsPriorityBang {
                    priorityBang
                }
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle().inset(by: -4))
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .contextMenu {
            if let onLongPress {
                Button {
                    onLongPress()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
```

The `.swipeActions(.trailing)` and `.contextMenu` modifiers tolerate empty content when the callbacks are nil — SwiftUI just doesn't surface the menu/swipe. Previews that omit the new callbacks continue to render unchanged.

- [ ] **Step 2: Run the full unit test suite to confirm no regressions**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -10
```

Expected: TEST SUCCEEDED, all 333 tests pass (no new tests in this task — UI behavior covered by UITest in Task 9).

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Features/DayPage/TodoRow.swift
git commit -m "feat(phase-23): TodoRow — swipe-to-delete + long-press edit menu

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: `TodoBlock` — embed composer + new gate

**Files:**
- Modify: `WeeklyPlanner/Features/DayPage/TodoBlock.swift`

- [ ] **Step 1: Modify `TodoBlock.swift`**

Open `WeeklyPlanner/Features/DayPage/TodoBlock.swift`. Change the struct's stored properties to accept the composer + the three callbacks:

```swift
struct TodoBlock: View {
    let tasks: [TaskItem]
    @Bindable var composer: TaskComposerState
    var onToggle: (UUID) -> Void
    var onAddTask: () async -> Void
    var onDelete: (UUID) -> Void
    var onLongPress: (UUID) -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size
```

Replace the `body` to gate on "tasks OR composer active":

```swift
    var body: some View {
        if tasks.isEmpty && !composer.isComposing {
            EmptyView()
        } else {
            content
        }
    }
```

Update `content` to embed the `TodoAddRow` at the bottom of the rows VStack:

```swift
    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 6)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(sortedTasks, id: \.id) { task in
                    TodoRow(task: task,
                            onToggle: { onToggle(task.id) },
                            onDelete: { onDelete(task.id) },
                            onLongPress: { onLongPress(task.id) })
                        .accessibleTask(task) { onToggle(task.id) }
                        .accessibilityIdentifier(AccessibilityIDs.daypageTodoRow(task.id))
                }
                TodoAddRow(composer: composer, onCommit: onAddTask)
                    .padding(.top, sortedTasks.isEmpty ? 0 : 4)
            }
        }
        .padding(EdgeInsets(top: 10, leading: 12, bottom: 8, trailing: 12))
        .background(RoundedRectangle(cornerRadius: 2)
            .fill(Self.patchBackground))
        .dashedBorder(color: theme.ink3, dash: [4, 3], lineWidth: 0.5, cornerRadius: 2)
    }
```

Update the `#Preview` at the bottom — the existing one passes only `tasks` and `onToggle`. Replace with:

```swift
#Preview("TodoBlock · Three tasks (cream)") {
    let calendar = WeekMath.mondayCalendar()
    var components = DateComponents()
    components.year = 2026
    components.month = 5
    components.day = 16
    let due = calendar.date(from: components) ?? Date()

    let tasks = [
        TaskItem(title: "Water plants", due: due, done: true, priority: .low, category: .personal),
        TaskItem(title: "Buy gift for Sara", due: due, priority: .high, category: .family),
        TaskItem(title: "Confirm dinner reservation",
                 due: due,
                 priority: .med,
                 category: .personal),
    ]

    let composer = TaskComposerState(forDay: due)

    return ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                TodoBlock(tasks: tasks,
                          composer: composer,
                          onToggle: { _ in },
                          onAddTask: {},
                          onDelete: { _ in },
                          onLongPress: { _ in })
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
```

- [ ] **Step 2: Update the only existing call site to `TodoBlock`**

`grep -n "TodoBlock(" WeeklyPlanner` to find call sites. Currently there is exactly one production call in `WeeklyPlanner/Features/DayPage/DayPageView.swift` (~line 221, inside `content(weekDay:weekMeta:)`):

```swift
                if hasTasks {
                    TodoBlock(tasks: viewModel.tasks) { id in
                        Task { await viewModel.toggleTask(id: id) }
                    }
                    .padding(.top, 12)
                }
```

Replace with the new signature:

```swift
                let showsTodoBlock = hasTasks || viewModel.taskComposer.isComposing
                if showsTodoBlock {
                    TodoBlock(tasks: viewModel.tasks,
                              composer: viewModel.taskComposer,
                              onToggle: { id in
                                  Task { await viewModel.toggleTask(id: id) }
                              },
                              onAddTask: {
                                  await viewModel.addTask()
                              },
                              onDelete: { id in
                                  Task { await viewModel.deleteTask(id: id) }
                              },
                              onLongPress: { id in
                                  editingTaskID = id
                              })
                    .padding(.top, 12)
                }
```

Add a new state property near the existing `editingEventID`/`creatingEventAt` declarations in `DayPageContent`:

```swift
    @State private var editingTaskID: UUID?
```

- [ ] **Step 3: Run the full test suite to confirm no regressions**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -10
```

Expected: 333/333 pass.

- [ ] **Step 4: Commit**

```bash
git add WeeklyPlanner/Features/DayPage/TodoBlock.swift \
       WeeklyPlanner/Features/DayPage/DayPageView.swift
git commit -m "feat(phase-23): TodoBlock embeds composer + DayPageView wires callbacks

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Wire `TaskMiniPopover` into `DayPageContent`

**Files:**
- Modify: `WeeklyPlanner/Features/DayPage/DayPageView.swift`

- [ ] **Step 1: Add popover rendering for the edit task**

In `DayPageContent`, find the existing sheet section (which has `.view(id)`, `.edit(id)`, and `.create(at:)` PaperEventSheet blocks from Phase 22 Tasks 7-10). After those blocks, add:

```swift
            if let id = editingTaskID,
               let task = viewModel?.tasks.first(where: { $0.id == id })
            {
                Color.clear
                    .frame(width: 0, height: 0)
                    .popover(isPresented: Binding(get: { editingTaskID != nil },
                                                   set: { if !$0 { editingTaskID = nil } }),
                             attachmentAnchor: .point(.center),
                             arrowEdge: .top)
                    {
                        TaskMiniPopover(task: task,
                                        onPriorityChange: { newPriority in
                                            Task {
                                                await viewModel?.updateTask(id: id) {
                                                    $0.priority = newPriority
                                                }
                                            }
                                        },
                                        onDueChange: { newDue in
                                            Task {
                                                await viewModel?.updateTask(id: id) {
                                                    $0.due = newDue
                                                }
                                            }
                                        },
                                        onDelete: {
                                            Task {
                                                await viewModel?.deleteTask(id: id)
                                                editingTaskID = nil
                                            }
                                        },
                                        onDismiss: { editingTaskID = nil })
                    }
            }
```

This presents the popover from a zero-size invisible anchor — works fine on iPhone (SwiftUI auto-adapts to a sheet on compact size class via `presentationCompactAdaptation(.popover)` inside `TaskMiniPopover.body`).

- [ ] **Step 2: Run the full test suite to confirm no regressions**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -10
```

Expected: 333/333 pass.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Features/DayPage/DayPageView.swift
git commit -m "feat(phase-23): wire TaskMiniPopover into DayPageContent

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Auto-refresh + EmptyDayState CTA

**Files:**
- Modify: `WeeklyPlanner/Features/DayPage/DayPageView.swift`
- Modify: `WeeklyPlanner/Features/WeekPage/WeekPageView.swift`
- Modify: `WeeklyPlanner/Features/DayPage/EmptyDayState.swift`

- [ ] **Step 1: Add `.onReceive(.taskStoreDidChange)` to both pages**

In `DayPageContent.body`, find the existing `.onReceive(NotificationCenter.default.publisher(for: .eventStoreDidChange))` modifier (added in Phase 22's `1f03e69` fix). Right below it, add:

```swift
        .onReceive(NotificationCenter.default.publisher(for: .taskStoreDidChange)) { _ in
            Task { await viewModel?.refresh() }
        }
```

Do the same in `WeeklyPlanner/Features/WeekPage/WeekPageView.swift` — find its existing `.onReceive(.eventStoreDidChange)` and add a sibling for `.taskStoreDidChange` calling `viewModel?.refresh()`.

- [ ] **Step 2: Modify `EmptyDayState` to accept an optional CTA**

Open `WeeklyPlanner/Features/DayPage/EmptyDayState.swift`. Replace the entire file with:

```swift
import SwiftUI

/// Placeholder copy rendered on a Day page when the focused day has neither
/// confirmed events nor pending inbox suggestions. The aesthetic intent is the
/// opposite of an "empty state" alert — there is no icon, no call-to-action,
/// and no muted card. Just a handwritten italic line on the paper that reads
/// like a margin note the user wrote to themselves.
///
/// In Phase 23 the empty state gained an optional `onAddTask` CTA that
/// flips the day-vm's task composer into composing mode. Phase 22's plan
/// kept the row aesthetic; we add a single underlined inline link below
/// the main caption to avoid disturbing the "free page" feel.
struct EmptyDayState: View {
    var onAddTask: (() -> Void)?

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nothing scheduled. A free page.")
                .font(font.font(at: 20 * size.scale, weight: .regular).italic())
                .foregroundStyle(theme.ink3)

            if let onAddTask {
                Button(action: onAddTask) {
                    Text("+ add a task")
                        .font(font.font(at: 17 * size.scale, weight: .regular).italic())
                        .foregroundStyle(theme.blueInk)
                        .underline()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("daypage.empty.addTask")
            }
        }
        .padding(.top, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Previews

#Preview("EmptyDayState · Cream") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                EmptyDayState(onAddTask: {})
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
```

- [ ] **Step 3: Wire the CTA from `DayPageView`**

In `DayPageContent.content(weekDay:weekMeta:)`, find the existing `EmptyDayState()` call (currently no args). Replace with:

```swift
                if !hasEvents, !hasInbox, !hasTasks {
                    EmptyDayState(onAddTask: {
                        viewModel.taskComposer.isComposing = true
                    })
                }
```

Note: this requires `viewModel` to be non-nil at this point, which the surrounding `if let viewModel` block already guarantees.

When the user taps "+ add a task" from the empty state, `composer.isComposing` flips on. But the surrounding `if hasTasks` guard prevents `TodoBlock` from rendering. Update the `showsTodoBlock` calculation from Task 6 — it's already `hasTasks || viewModel.taskComposer.isComposing`, so the block will appear with just the inline composer. Good.

But there's one tighter issue: when `!hasEvents && !hasInbox && !hasTasks && composer.isComposing`, BOTH the `TodoBlock` and the `EmptyDayState` render — overlapping. Add an extra guard to the empty-state branch:

```swift
                if !hasEvents, !hasInbox, !hasTasks, !viewModel.taskComposer.isComposing {
                    EmptyDayState(onAddTask: {
                        viewModel.taskComposer.isComposing = true
                    })
                }
```

So once the user taps the CTA, `EmptyDayState` disappears and `TodoBlock` (with just the add row) takes over.

- [ ] **Step 4: Run the full test suite**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -10
```

Expected: 333/333 pass.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Features/DayPage/DayPageView.swift \
       WeeklyPlanner/Features/WeekPage/WeekPageView.swift \
       WeeklyPlanner/Features/DayPage/EmptyDayState.swift
git commit -m "feat(phase-23): auto-refresh on .taskStoreDidChange + EmptyDayState CTA

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: UITest — inline add-task end-to-end

**Files:**
- Create: `WeeklyPlannerUITests/TaskCreateFlowUITests.swift`

- [ ] **Step 1: Create the UITest**

```swift
import XCTest

/// End-to-end inline add-task flow: launch app → find or open TodoBlock
/// → tap "+ add a task" → type title → Return → verify the row appears.
///
/// Mirrors Phase 22's `EventCreateFlowUITests` discovery pattern; uses
/// the `daypage.todo.addRow` identifier from `TodoAddRow` and falls back
/// to `daypage.empty.addTask` from `EmptyDayState` when the day starts
/// empty.
final class TaskCreateFlowUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testAddTaskInline_endToEnd() throws {
        let app = XCUIApplication()
        app.launch()

        // Open the composer. The Day page may already render a TodoBlock
        // (from seeded tasks) — if so, tap its add row directly. Otherwise
        // tap the empty-state CTA.
        let addRow = app.buttons["daypage.todo.addRow"]
        let emptyCTA = app.buttons["daypage.empty.addTask"]

        let opened: Bool = {
            if addRow.waitForExistence(timeout: 3) {
                addRow.tap()
                return true
            }
            if emptyCTA.waitForExistence(timeout: 3) {
                emptyCTA.tap()
                return true
            }
            return false
        }()
        XCTAssertTrue(opened, "Either the TodoBlock add row or the empty-state CTA should be reachable")

        // Type a unique title so we can find the row deterministically.
        let title = "UITest Prep \(UUID().uuidString.prefix(6))"
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 2)
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText(String(title))
        // Return commits.
        app.keyboards.buttons["return"].tap()

        // The new row carries the title in its accessibility label
        // (via `accessibleTask(...)` from Phase 21). Wait for it.
        let predicate = NSPredicate(format: "label CONTAINS %@", String(title))
        let result = app.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5),
                      "New task title should be visible on the Day page after Return")
    }
}
```

- [ ] **Step 2: Run it**

```bash
xcodegen generate 2>&1 | tail -3
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerUITests/TaskCreateFlowUITests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -30
```

Expected: TEST SUCCEEDED. If the `return` key identifier varies by keyboard locale, fall back to `app.keyboards.buttons.element(boundBy: 0)` or use `field.typeText("\n")` directly. Document any timing tweak.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlannerUITests/TaskCreateFlowUITests.swift
git commit -m "test(phase-23): TaskCreateFlowUITests — end-to-end inline add

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: READMEs + Phase 23 retrospective

**Files:**
- Modify: `README.md`
- Modify: `docs/phases/README.md`

- [ ] **Step 1: Update both READMEs**

In `docs/phases/README.md`, flip Phase 23's row to ✅ in the phase map:

```
| 23 | Manual Task CRUD                                     | J                   | ✅     |
```

Update the "Current state" / "Next up" paragraph (currently `Phase 22 ✅, Phase 23 (Manual Task CRUD) and Phase 24 (AI Sticky v2) pending`) to:

```
**Current state:** Milestones A–I shipped on `main`; Phases 22 + 23 shipped on `milestone-j-completeness`. Phase 20 (Modern Mode) archived at tag `phase-20-archive`.

**Milestone J — Completeness** is in progress: Phase 22 ✅, Phase 23 ✅, Phase 24 (AI Sticky v2) pending. Spec: `docs/superpowers/specs/2026-05-22-functional-completeness-design.md`.

Next up: Phase 24 — AI Sticky v2 (Live & Actionable).
```

Append a Phase 23 retrospective at the bottom (after the Phase 22 retrospective):

```markdown
### Phase 23 — Manual Task CRUD

Shipped inline task add + long-press edit + swipe-to-delete on
`milestone-j-completeness`. `TodoBlock`'s "tasks.isEmpty → EmptyView"
gate flipped to "tasks.isEmpty AND !composer.isComposing → EmptyView"
so the dashed yellow patch appears whenever the user starts composing,
even on an otherwise-empty day. New atoms: `TaskComposerState` (the
`@Observable` draft), `TodoAddRow` (idle ↔ composing dual-state row),
and `TaskMiniPopover` (priority swatches + due chips + delete). The
`EmptyDayState` gained an optional `"+ add a task"` underlined link
that flips the composer on.

**Architecture:**
- `TaskComposerState` exposes `title`, `isComposing`, `priority`, `due`
  with `canCommit`, `build(category:)`, `reset()` (clears title, keeps
  composing for chained entries), `exit()` (clears all, stops composing),
  and `setDay(_:)` for cross-midnight re-anchoring.
- `DayPageViewModel` owns the composer and the three new methods:
  `addTask()`, `updateTask(id:mutation:)`, `deleteTask(id:)`.
- `TaskStoring` protocol already exposed `upsert(_:)` and `delete(id:)`
  (since Phase 03) — the phase doc's "store API growth" requirement was
  a no-op. `.taskStoreDidChange` was likewise already posted by all
  mutations.
- `TodoRow` gained optional `onDelete` and `onLongPress` callbacks
  threaded through `.swipeActions(.trailing)` and `.contextMenu`. The
  context menu offers Edit (opens `TaskMiniPopover`) and Delete.
- `TaskMiniPopover` uses `.presentationCompactAdaptation(.popover)` so
  it renders as a popover on iPad and a sheet on iPhone. Anchored to a
  zero-size hidden host so the position is automatic.
- Auto-refresh on `.taskStoreDidChange` added to both `DayPageContent`
  and the Week page's content view, matching Phase 22's pattern.

**Plan deviations encountered:**

1. **Phase doc said "Priority `low/medium/high`"; the enum is actually
   `Priority.med`** (not `.medium`). Tests use the correct case.

2. **`TaskStoring.upsert` and `.delete` already exist.** Phase doc's
   "Add: func upsert / func delete" requirement is a no-op; both have
   been in the protocol since Phase 03 (verified at
   `WeeklyPlanner/Stores/TaskStore.swift:8,10`). Plan skipped the
   protocol-change task entirely.

3. **`@Bindable` on a struct property** — `TodoAddRow` and `TodoBlock`
   take `@Bindable var composer: TaskComposerState` so `composer.title`
   propagates into `InkTextField`. The standard SwiftUI pattern.

4. **`@FocusState` with external binding** — `TodoAddRow` owns its own
   `@FocusState` and passes it into `InkTextField` via the optional
   `focus:` parameter added in Phase 22. The atom thereby supports
   programmatic focus from the parent. On entering composing mode,
   `.task { fieldFocused = true }` autofocuses.

5. **Blur → commit-or-exit policy.** `TodoAddRow.onChange(of: fieldFocused)`
   commits when the field loses focus with a non-empty title, exits
   otherwise. Mirrors the iOS Reminders blur behavior.

6. **Composer ownership** — held by `DayPageViewModel`, not by the row.
   This means flipping pages keeps any in-progress draft alive (the
   composer re-anchors its date in `refresh()`). If the product team
   prefers "page-flip discards the draft", swap the ownership to
   `@State` on `DayPageContent`.

**Tracked follow-ups (deferred, not blocking):**
- Priority swatches in `TaskMiniPopover` use the same 18pt size as
  Phase 22's `CategorySwatchRow`, exposing the same 34pt-vs-44pt tap
  target gap. Track for the same future a11y polish.
- `TaskMiniPopover` doesn't currently expose a title-edit field. Tap
  the row to toggle done; long-press → mini popover for priority +
  due + delete. Editing the title would require either an inline field
  or a full sheet (à la `PaperEventSheet`). Out of scope per spec; add
  to backlog.
- `addTask()` always uses `category: .personal`. A category picker is
  out of scope for Phase 23 — Phase 03's `Category` enum has 6 cases
  but the to-do block aesthetic doesn't accommodate the swatch row at
  this density.

**Files added/modified:**
- New: `WeeklyPlanner/Features/DayPage/TaskComposerState.swift`
- New: `WeeklyPlanner/Features/DayPage/TodoAddRow.swift`
- New: `WeeklyPlanner/Features/DayPage/TaskMiniPopover.swift`
- New: `WeeklyPlannerTests/DayPage/TaskComposerStateTests.swift`
- New: `WeeklyPlannerTests/DayPage/TodoBlockCRUDTests.swift`
- New: `WeeklyPlannerUITests/TaskCreateFlowUITests.swift`
- Modified: `WeeklyPlanner/Features/DayPage/{TodoBlock,TodoRow,EmptyDayState,DayPageViewModel,DayPageView}.swift`
- Modified: `WeeklyPlanner/Features/WeekPage/WeekPageView.swift`
```

In `README.md`, flip the Milestone J row to track Phase 23 done:

```
| J — Completeness       | 22–24 | ⏳ in progress (Phases 22 + 23 ✅; 24 pending) |
```

- [ ] **Step 2: Commit**

```bash
git add README.md docs/phases/README.md
git commit -m "docs(phase-23): mark ✅ + retrospective

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage check** against `docs/phases/phase-23-task-crud.md`:

| Spec requirement | Implemented in |
|------------------|----------------|
| `TaskComposerState` (`@Observable`, defaults, canCommit, build, reset, exit, setDay) | Task 1 |
| `TodoBlock` flips gate to "tasks OR composer" | Task 6 |
| Dashed "+ add a task" idle row | Task 3 (`TodoAddRow`) |
| Inline composing field with autofocus | Task 3 |
| Return commits non-empty title; empty Return / blur exits | Task 3 + Task 2 (`addTask()` resets-and-continues) |
| `TodoRow` `.swipeActions(.trailing)` Delete | Task 5 |
| `TodoRow` `.contextMenu` opens mini popover | Task 5 + Task 7 |
| `TaskMiniPopover` with priority + due + delete | Task 4 + Task 7 |
| `EmptyDayState` "+ add a task" CTA | Task 8 |
| `TaskStoring.upsert` / `.delete` exist | already exists (Phase 03) |
| `DayPageViewModel.addTask/updateTask/deleteTask` | Task 2 |
| Auto-refresh on `.taskStoreDidChange` | Task 8 (Day + Week pages) |
| Composer.due defaults to current Day page's date | Task 1 (`init(forDay:)`) + Task 2 (`refresh()` re-anchors) |
| New task priority defaults to `.med` | Task 1 (composer default) |
| UITest for inline add | Task 9 |
| Phase 23 ✅ in READMEs | Task 10 |

The spec also mentions "leading swipe → cycles priority low → med → high → low" (`docs/phases/phase-23-task-crud.md:50`). Not in the plan — defer to the retrospective as a tracked follow-up, since it adds complexity (a second swipe action) without a clear product signal. If you want it in v1, add a Task 5b that adds `.swipeActions(edge: .leading)` cycling through priorities and calls `viewModel.updateTask(id:) { $0.priority = next }`.

**Placeholder scan:** No TBD/TODO/FIXME in the plan. Every step has either complete code or an exact command.

**Type consistency:**
- `TaskComposerState.build(category:)` returns `TaskItem` — used in Task 2's `addTask()`. ✓
- `TaskComposerState.canCommit` referenced in Task 2's `addTask()` guard. ✓
- `TaskComposerState.reset()` referenced in Task 2's `addTask()`. ✓
- `TaskComposerState.exit()` referenced in Task 3's blur handler. ✓
- `Priority.med` (not `.medium`) used consistently across Tasks 1, 2, 4. ✓
- `TaskStoring.upsert/delete/task(id:)/toggle(id:)` — all referenced match the existing protocol. ✓
- `DayPageViewModel.taskComposer` referenced in Task 6's `TodoBlock` call and Task 8's `EmptyDayState` callback. ✓
- `editingTaskID: UUID?` introduced in Task 6, consumed in Task 7's popover block. ✓

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-05-22-phase-23-task-crud.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — fresh subagent per task + two-stage review. Phase 22 ran this way cleanly.

**2. Inline Execution** — execute tasks in this same session via executing-plans.

**Which approach?**
