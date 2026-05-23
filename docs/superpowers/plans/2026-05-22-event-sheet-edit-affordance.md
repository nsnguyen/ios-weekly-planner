# Event Sheet Edit Affordance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a discoverable "Edit" link to the view-mode event sheet's header that promotes the sheet to `.edit` mode in place, with Save/Cancel reverting to view in the same sheet (no dismiss).

**Architecture:** Replace `PaperEventSheet.mode` (immutable `let`) with `initialMode: SheetMode` + `@State currentMode: SheetMode?`. All dispatchers (`.task(id:)`, `cardContent`, alerts) read `currentMode`. View-header Edit button → mutates `currentMode = .edit(id)` + `viewModel.beginEditing()`. Save/Cancel in `.edit` mutate back to `.view(id)` instead of dismissing. `.create` mode is unchanged (still dismisses on Save).

**Tech Stack:** Swift 6, SwiftUI (iOS 26+), `@Observable`, existing `EventDetailViewModel` and `EventComposerState` from Phase 22.

**Spec:** `docs/superpowers/specs/2026-05-22-event-sheet-edit-affordance.md` · **Branch:** `milestone-j-completeness` (at `95317c2`).

---

## File Structure

| Path | Responsibility |
|------|----------------|
| `WeeklyPlanner/Features/EventDetail/EventHeader.swift` | Optional `onEdit` callback + "Edit" link rendering |
| `WeeklyPlanner/Features/EventDetail/PaperEventSheet.swift` | Mutable `currentMode` state; `promoteToEdit()` + `revertToView()` helpers; Save/Cancel handlers branch on mode |
| `WeeklyPlannerTests/EventDetail/PaperEventSheetEditTests.swift` | +2 VM-contract tests for the revert-to-view flow |

Call-site: `WeeklyPlanner/Features/DayPage/DayPageView.swift` already constructs `PaperEventSheet(mode: …)` in three places. The parameter rename `mode:` → `initialMode:` ripples here; no behavior change at the call sites.

---

## Conventions

- Tests:
  ```bash
  xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
    -only-testing:WeeklyPlannerTests/<ClassName> \
    CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -20
  ```
- Run `xcodegen generate` only when adding new files (no new files in this plan, so skip).
- Each task ends with a commit on `milestone-j-completeness`.
- Trust `xcodebuild` over SourceKit indexer diagnostics (stale-index pattern has been constant throughout Phases 22/23).

---

## Task 1: `EventHeader` — optional Edit link

**Files:**
- Modify: `WeeklyPlanner/Features/EventDetail/EventHeader.swift`

**Why:** Add the visible affordance first; the sheet wiring (Task 2) will consume it.

- [ ] **Step 1: Read the current file to find the exact insertion points**

```bash
cat WeeklyPlanner/Features/EventDetail/EventHeader.swift
```

The current struct is:

```swift
struct EventHeader: View {
    let event: Event
    var onClose: () -> Void
    // body: HStack { leftColumn; Spacer; closeButton } padding (top:38, leading:44, bottom:14, trailing:18)
}
```

- [ ] **Step 2: Add the `onEdit` property + initializer + Edit link rendering**

Open `WeeklyPlanner/Features/EventDetail/EventHeader.swift` and apply two edits:

**Edit A** — change the property declarations + add init. Replace:

```swift
    /// The event being displayed. Drives every text and color decision in
    /// the header.
    let event: Event

    /// Invoked when the user taps the `×` close affordance. The sheet root
    /// uses this to set `isOpen = false`.
    var onClose: () -> Void
```

with:

```swift
    /// The event being displayed. Drives every text and color decision in
    /// the header.
    let event: Event

    /// Invoked when the user taps the `×` close affordance. The sheet root
    /// uses this to set `isOpen = false`.
    var onClose: () -> Void

    /// Optional callback for promoting the sheet from `.view` to `.edit`.
    /// When non-nil, the header renders an "Edit" link in the trailing
    /// edge left of the close `×`. Nil in `.edit`/`.create` modes and in
    /// previews/tests that don't need the affordance.
    var onEdit: (() -> Void)?

    init(event: Event,
         onClose: @escaping () -> Void,
         onEdit: (() -> Void)? = nil)
    {
        self.event = event
        self.onClose = onClose
        self.onEdit = onEdit
    }
```

**Edit B** — change the body to render the Edit link before the close button. Replace the existing `body`:

```swift
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            leftColumn
                .accessibilityElement(children: .combine)
                .accessibilityLabel(AccessibilityFormatters.eventLabel(event))
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            closeButton
        }
        .padding(EdgeInsets(top: 38, leading: 44, bottom: 14, trailing: 18))
    }
```

with:

```swift
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            leftColumn
                .accessibilityElement(children: .combine)
                .accessibilityLabel(AccessibilityFormatters.eventLabel(event))
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            if let onEdit {
                editButton(onEdit: onEdit)
                    .padding(.trailing, 6)
            }
            closeButton
        }
        .padding(EdgeInsets(top: 38, leading: 44, bottom: 14, trailing: 18))
    }
```

**Edit C** — append the `editButton` private method after the existing `closeButton`. After this block:

```swift
    /// Small `×` glyph in `ink2`. `.contentShape(...)` extends the hit area
    /// 8pt in every direction so the tap target is the standard 32pt-ish
    /// square even though the glyph itself is only 14pt.
    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.ink2)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle().inset(by: -8))
        .accessibilityLabel("Close")
    }
```

insert:

```swift
    /// "Edit" link rendered in the trailing edge of the header when
    /// `onEdit` is supplied. Handwriting, bold, blue ink, underlined —
    /// matches the design system's link affordance.
    private func editButton(onEdit: @escaping () -> Void) -> some View {
        Button(action: onEdit) {
            Text("Edit")
                .font(font.font(at: 15, weight: .bold))
                .underline()
                .foregroundStyle(theme.blueInk)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle().inset(by: -8))
        .accessibilityLabel("Edit event")
        .accessibilityHint("Switches the sheet to edit mode")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("paperEventSheet.edit")
    }
```

- [ ] **Step 3: Build to confirm no regressions**

```bash
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`. (No call sites have changed yet — `onEdit` defaults to `nil`, so the existing two call sites in `PaperEventSheet.swift` and the preview still type-check.)

- [ ] **Step 4: Run the full unit-test suite to confirm no regressions**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -5
```

Expected: TEST SUCCEEDED, 327 tests pass.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Features/EventDetail/EventHeader.swift
git commit -m "feat(edit-affordance): EventHeader — optional Edit link in trailing edge

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: `PaperEventSheet` — `currentMode` state + promote/revert wiring

**Files:**
- Modify: `WeeklyPlanner/Features/EventDetail/PaperEventSheet.swift`
- Modify: `WeeklyPlanner/Features/DayPage/DayPageView.swift` (call-site rename only)

**Why:** Replace the immutable `mode: SheetMode` property with a mutable internal `@State currentMode`, then wire Edit → promote, Save/Cancel in `.edit` → revert.

- [ ] **Step 1: Modify `PaperEventSheet.swift` — replace `mode` with `initialMode` + `currentMode`**

Open `WeeklyPlanner/Features/EventDetail/PaperEventSheet.swift`. Apply the following edits.

**Edit A** — the property declaration. Find:

```swift
    /// Mode-driven entry. `existingEventID` returns the id for view/edit;
    /// in create mode the sheet generates an id once the composer is built.
    let mode: SheetMode
```

Replace with:

```swift
    /// Initial mode for the sheet. Seeded into `currentMode` on appear
    /// via the `.task(id:)` block. The view never reads `initialMode`
    /// directly after seed — it reads `currentMode`, which can flip
    /// (`.view` ↔ `.edit`) inside the same sheet via the Edit link.
    let initialMode: SheetMode

    /// Mutable mode the sheet actually renders. `nil` before the first
    /// `.task(id:)` fires; SwiftUI treats `nil` as "not ready yet" and
    /// the dispatcher returns a placeholder.
    @State private var currentMode: SheetMode?
```

**Edit B** — the `.task(id:)` block. Find the existing block (it currently dispatches on `mode`):

```swift
        .task(id: mode) {
            switch mode {
            case .view(let id), .edit(let id):
                if viewModel == nil || viewModel?.eventID != id {
                    let generator = intelligenceService.map {
                        EventSuggestionGenerator(intelligence: $0)
                    }
                    viewModel = EventDetailViewModel(eventID: id,
                                                     eventStore: eventStore,
                                                     suggestionGenerator: generator)
                }
                await viewModel?.load()
                await viewModel?.refreshAISuggestion()
                if case .edit = mode { viewModel?.beginEditing() }
            case .create(let date):
                if viewModel == nil {
                    viewModel = EventDetailViewModel(eventID: UUID(),
                                                     eventStore: eventStore)
                }
                viewModel?.beginCreating(at: date,
                                         calendar: WeekMath.mondayCalendar())
            }
        }
```

Replace with:

```swift
        .task(id: initialMode) {
            // Seed currentMode from the caller's initial intent. Re-seed
            // whenever initialMode changes (e.g., a different event id
            // arrives while the sheet is already on screen).
            currentMode = initialMode
            switch initialMode {
            case .view(let id), .edit(let id):
                if viewModel == nil || viewModel?.eventID != id {
                    let generator = intelligenceService.map {
                        EventSuggestionGenerator(intelligence: $0)
                    }
                    viewModel = EventDetailViewModel(eventID: id,
                                                     eventStore: eventStore,
                                                     suggestionGenerator: generator)
                }
                await viewModel?.load()
                await viewModel?.refreshAISuggestion()
                if case .edit = initialMode { viewModel?.beginEditing() }
            case .create(let date):
                if viewModel == nil {
                    viewModel = EventDetailViewModel(eventID: UUID(),
                                                     eventStore: eventStore)
                }
                viewModel?.beginCreating(at: date,
                                         calendar: WeekMath.mondayCalendar())
            }
        }
```

**Edit C** — the `cardContent` dispatcher. Find the existing definition:

```swift
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch mode {
            case .view:
                EventHeader(event: viewModel?.event ?? Self.placeholderEvent,
                            onClose: { isOpen = false })
                if let event = viewModel?.event, let viewModel {
                    bodyRows(event: event, viewModel: viewModel)
                        .padding(.horizontal, 18)
                } else {
                    Spacer().frame(height: 200)
                }
            case .edit, .create:
                if let viewModel, let composer = viewModel.composer {
                    EditableEventContent(composer: composer,
                                         canSave: composer.canSave,
                                         isCreate: { if case .create = mode { true } else { false } }(),
                                         showsDelete: { if case .edit = mode { true } else { false } }(),
                                         onSave: { await viewModel.save(); if viewModel.composer == nil { isOpen = false } },
                                         onCancel: {
                                             if viewModel.composerIsDirty {
                                                 showCancelConfirm = true
                                             } else {
                                                 viewModel.cancelEditing()
                                                 isOpen = false
                                             }
                                         },
                                         onDelete: { showDeleteConfirm = true })
                } else {
                    Spacer().frame(height: 200)
                }
            }
        }
    }
```

Replace with:

```swift
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch currentMode {
            case .view, .none:
                EventHeader(event: viewModel?.event ?? Self.placeholderEvent,
                            onClose: { isOpen = false },
                            onEdit: viewModel?.event == nil ? nil : { promoteToEdit() })
                if let event = viewModel?.event, let viewModel {
                    bodyRows(event: event, viewModel: viewModel)
                        .padding(.horizontal, 18)
                } else {
                    Spacer().frame(height: 200)
                }
            case .edit, .create:
                if let viewModel, let composer = viewModel.composer {
                    let isCreate: Bool = { if case .create = currentMode { return true } else { return false } }()
                    let isEdit: Bool = { if case .edit = currentMode { return true } else { return false } }()
                    EditableEventContent(composer: composer,
                                         canSave: composer.canSave,
                                         isCreate: isCreate,
                                         showsDelete: isEdit,
                                         onSave: {
                                             await viewModel.save()
                                             // After save: .edit reverts to view in place;
                                             // .create dismisses the sheet entirely (no
                                             // view to revert to).
                                             if isEdit {
                                                 if let id = currentMode?.existingEventID {
                                                     currentMode = .view(id)
                                                 }
                                             } else if viewModel.composer == nil {
                                                 isOpen = false
                                             }
                                         },
                                         onCancel: {
                                             if viewModel.composerIsDirty {
                                                 showCancelConfirm = true
                                             } else if isEdit {
                                                 // Clean cancel from edit → revert to view.
                                                 revertToView()
                                             } else {
                                                 // Clean cancel from create → dismiss.
                                                 viewModel.cancelEditing()
                                                 isOpen = false
                                             }
                                         },
                                         onDelete: { showDeleteConfirm = true })
                } else {
                    Spacer().frame(height: 200)
                }
            }
        }
    }
```

**Edit D** — the discard alert handler. Find:

```swift
        .alert("Discard changes?", isPresented: $showCancelConfirm) {
            Button("Discard", role: .destructive) {
                viewModel?.cancelEditing()
                isOpen = false
            }
            Button("Keep editing", role: .cancel) {}
        }
```

Replace with:

```swift
        .alert("Discard changes?", isPresented: $showCancelConfirm) {
            Button("Discard", role: .destructive) {
                // Dirty cancel: .edit reverts to view; .create dismisses.
                if case .edit = currentMode {
                    revertToView()
                } else {
                    viewModel?.cancelEditing()
                    isOpen = false
                }
            }
            Button("Keep editing", role: .cancel) {}
        }
```

**Edit E** — add the two helper methods. Find the existing `.alert("Delete this event?"...)` block (above the new "Discard changes?" alert). Just BEFORE the closing brace of the `var body: some View` — actually, the helpers belong outside `body` as instance methods. Find the LAST `}` before the `// MARK: - Drag-to-dismiss` section (if it exists) or before any nested struct. The safe place is right before `private var dragGesture: some Gesture`. Insert:

```swift
    // MARK: - Mode promotion

    /// View → Edit promotion. Called from the view-mode header's Edit
    /// link. Seeds the composer from the loaded event and flips
    /// `currentMode` so `cardContent` dispatches to the editable variant.
    /// No-op if the event hasn't loaded yet or we're already in `.edit`.
    private func promoteToEdit() {
        guard case let .view(id) = currentMode else { return }
        viewModel?.beginEditing()
        currentMode = .edit(id)
    }

    /// Edit → View revert. Called from Save (after `viewModel.save()`
    /// completes) and from clean / discard-confirmed Cancel. Clears any
    /// composer state and flips `currentMode` back. No-op if not in
    /// `.edit` (e.g., the user already dismissed).
    private func revertToView() {
        guard case let .edit(id) = currentMode else { return }
        viewModel?.cancelEditing()
        currentMode = .view(id)
    }
```

- [ ] **Step 2: Rename call-site parameter — `mode:` → `initialMode:` in `DayPageView.swift`**

Open `WeeklyPlanner/Features/DayPage/DayPageView.swift`. Find the three `PaperEventSheet(mode: …)` call sites (currently around lines 149, 154, 159 for `.view`, `.create`, `.edit` respectively). Use sed-style search-replace, or apply three targeted edits:

```swift
            if let id = openEventID {
                PaperEventSheet(mode: .view(id),
                                isOpen: ...)
            }
            if let anchor = creatingEventAt {
                PaperEventSheet(mode: .create(at: anchor),
                                isOpen: ...)
            }
            if let id = editingEventID {
                PaperEventSheet(mode: .edit(id),
                                isOpen: ...)
            }
```

Replace each `mode:` with `initialMode:`. Also update `WeekPageView.swift` and the `#Preview` inside `PaperEventSheet.swift` (the `PaperEventSheetPreviewHost` calls `PaperEventSheet(mode: .view(eventID), ...)` — change to `initialMode:`).

Easiest: `grep -rn "PaperEventSheet(mode:" WeeklyPlanner/` to find them all, then `sed -i '' 's/PaperEventSheet(mode:/PaperEventSheet(initialMode:/g' <each file>`.

- [ ] **Step 3: Build to confirm**

```bash
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Run the full unit-test suite**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -5
```

Expected: 327 tests pass.

- [ ] **Step 5: Run the UITest to confirm create-flow still works (the test exercises `PaperEventSheet(initialMode: .create(at:))` indirectly via the AddEventLink)**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerUITests/EventCreateFlowUITests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -10
```

Expected: TEST SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add WeeklyPlanner/Features/EventDetail/PaperEventSheet.swift \
       WeeklyPlanner/Features/DayPage/DayPageView.swift \
       WeeklyPlanner/Features/WeekPage/WeekPageView.swift
git commit -m "feat(edit-affordance): PaperEventSheet promote-to-edit + revert-to-view

Replace immutable 'mode: SheetMode' property with 'initialMode:' +
internal '@State currentMode'. View-mode header's Edit link calls
promoteToEdit() (flips currentMode to .edit + viewModel.beginEditing).
Save/Cancel in .edit call revertToView() instead of dismissing.
.create unchanged (still dismisses on save). Call-site parameter
rename: mode: → initialMode: across DayPageView, WeekPageView, and
the PaperEventSheet preview.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: VM-contract tests for the revert flow

**Files:**
- Modify: `WeeklyPlannerTests/EventDetail/PaperEventSheetEditTests.swift`

**Why:** The same-sheet promote/revert pattern relies on `EventDetailViewModel` clearing `composer` on save and `event` staying loaded. Pin those invariants.

- [ ] **Step 1: Append two new tests inside the existing `PaperEventSheetEditTests` class**

Open `WeeklyPlannerTests/EventDetail/PaperEventSheetEditTests.swift`. After the last existing test method (currently `testCanSave_falseWhenTitleEmptyOrTimesInvalid`), inside the class brace, add:

```swift
    func testEdit_saveCommitsThenLeavesViewModelInViewableState() async throws {
        let event = Event(title: "Lunch",
                          start: Date(timeIntervalSince1970: 1_780_000_000),
                          end: Date(timeIntervalSince1970: 1_780_003_600),
                          category: .personal)
        try await eventStore.upsert(event)

        let vm = EventDetailViewModel(eventID: event.id, eventStore: eventStore)
        await vm.load()
        vm.beginEditing()
        vm.composer?.title = "Lunch with Jamie"
        await vm.save()

        // The sheet's revertToView() will call cancelEditing() only on
        // the cancel/discard paths — Save itself clears the composer via
        // the VM. Either way, after save: composer is nil AND event is
        // still loaded with the new title, so the sheet can render the
        // view-mode body without re-fetching.
        XCTAssertNil(vm.composer)
        XCTAssertEqual(vm.event?.title, "Lunch with Jamie")
    }

    func testEdit_cancelEditingClearsComposerWithoutTouchingEvent() async throws {
        let event = Event(title: "Lunch",
                          start: Date(timeIntervalSince1970: 1_780_000_000),
                          end: Date(timeIntervalSince1970: 1_780_003_600),
                          category: .personal)
        try await eventStore.upsert(event)

        let vm = EventDetailViewModel(eventID: event.id, eventStore: eventStore)
        await vm.load()
        vm.beginEditing()
        vm.composer?.title = "Renamed in memory only"

        vm.cancelEditing()

        // After cancel: composer cleared (so the sheet flips to view
        // mode), event still carries the ORIGINAL title (because cancel
        // doesn't touch the store).
        XCTAssertNil(vm.composer)
        XCTAssertEqual(vm.event?.title, "Lunch")
    }
```

- [ ] **Step 2: Run the tests**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/PaperEventSheetEditTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -10
```

Expected: `Executed 5 tests, with 0 failures` (3 existing + 2 new).

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlannerTests/EventDetail/PaperEventSheetEditTests.swift
git commit -m "test(edit-affordance): PaperEventSheetEditTests — revert-flow VM contract

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Dogfood + manual sweep

**Files:** none (manual verification)

- [ ] **Step 1: Rebuild + install + launch**

```bash
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -derivedDataPath build/ \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/WeeklyPlanner.app
xcrun simctl launch booted com.weeklyplanner.WeeklyPlanner
```

- [ ] **Step 2: Manual sweep**

1. Tap an event row → view-mode sheet opens.
2. Verify "Edit" link appears in the top-right next to the close X.
3. Tap Edit → sheet flips to editable mode (Save/Cancel header replaces Edit/X).
4. Change the title → tap Save → sheet flips BACK to view mode showing the new title (no dismiss).
5. Tap Edit again → change the title → tap Cancel → "Discard changes?" alert appears → tap Discard → sheet flips back to view mode with the ORIGINAL title.
6. Tap Edit → tap Cancel with no changes → sheet flips back to view mode (no alert).
7. Use the bottom-right "+ add an event" link to create a fresh event → fill title → tap Save → sheet DISMISSES (no revert; .create still dismisses).
8. Long-press an event row → tap "Edit" in the menu → sheet opens directly in edit mode → tap Save → sheet flips to view mode (revert, NOT dismiss). This is the behavior change for the long-press path.

- [ ] **Step 3: If any step fails, document in this plan as a deviation and fix.**

---

## Self-Review

**Spec coverage** against `docs/superpowers/specs/2026-05-22-event-sheet-edit-affordance.md`:

| Spec item | Implemented in |
|-----------|----------------|
| `EventHeader.onEdit` optional callback | Task 1 |
| Edit link visible in trailing edge of view-mode header | Task 1 |
| Edit link accessibility (label/hint/trait/id `paperEventSheet.edit`) | Task 1 |
| `PaperEventSheet.initialMode` + `@State currentMode` | Task 2 |
| `.task(id: initialMode)` re-seed | Task 2 |
| `cardContent` dispatch on `currentMode` | Task 2 |
| `promoteToEdit()` helper | Task 2 |
| `revertToView()` helper | Task 2 |
| Save in `.edit` reverts to view (no dismiss) | Task 2 |
| Cancel (clean) in `.edit` reverts to view | Task 2 |
| Cancel (dirty) in `.edit` → discard alert → revert to view | Task 2 |
| `.create` Save/Cancel unchanged (dismisses) | Task 2 (preserved) |
| Long-press `.edit` Save also reverts to view (per behavior matrix) | Task 2 (`isEdit` covers both entry points) |
| Call-site rename `mode:` → `initialMode:` | Task 2 |
| VM-contract tests for save-then-viewable + cancel-then-viewable | Task 3 |
| Manual sweep checklist | Task 4 |

**Placeholder scan:** No TBD/TODO/FIXME. Every code step has the actual code to paste.

**Type consistency:**
- `SheetMode.existingEventID: UUID?` (existing) used by `revertToView` via `if case .edit(let id)` pattern matching — no rename needed. ✓
- `currentMode: SheetMode?` — `.none` handled in `cardContent` switch's `.view, .none:` branch as a "default to view" so the placeholder render happens before `.task(id:)` fires. ✓
- `EventHeader(event:onClose:onEdit:)` — three-arg init; existing two-arg call sites work because `onEdit` defaults to `nil`. ✓
- `viewModel?.event` checked non-nil before passing `{ promoteToEdit() }` so the Edit button can't fire on an unloaded view (the `onEdit` is `nil` when no event is loaded). ✓

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-05-22-event-sheet-edit-affordance.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — fresh subagent per task + two-stage review. The pattern that ran Phases 22 + 23 cleanly.

**2. Inline Execution** — execute tasks in this same session via executing-plans. Faster for a 3-task scope.

**Which approach?**
