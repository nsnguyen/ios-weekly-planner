# Event Sheet: Edit Affordance — Design

> Approved 2026-05-22. Tightly-scoped follow-up to Phase 22 (Manual
> Event CRUD). Lives on `milestone-j-completeness`.

## Goal

Make event editing discoverable: add a visible "Edit" affordance to
the read-only event sheet's header, with promote-to-edit and
revert-to-view happening inside the same sheet.

## Why this is needed

Phase 22 shipped edit-via-long-press on event rows (context menu →
"Edit"). The view-mode sheet itself exposes no Edit affordance — just
the close X. Users can't discover the long-press shortcut without
being told. The on-device test session surfaced this gap.

## Behavior

### Entry points

- **Long-press** an event row → context menu → "Edit" → sheet opens
  directly in `.edit(id)`. (Existing; unchanged.)
- **Tap** an event row → sheet opens in `.view(id)`. (Existing.)
- **NEW: Tap "Edit"** in the view-mode sheet's header → sheet
  promotes to `.edit(id)` IN PLACE, same sheet, no remount.

### Behavior matrix

| Entry | Save | Cancel (clean) | Cancel (dirty) |
|-------|------|----------------|----------------|
| `.create(at:)` | Dismiss sheet | Dismiss sheet | Discard alert → Dismiss |
| `.edit(id)` (long-press shortcut) | Revert to `.view(id)` | Revert to `.view(id)` | Discard alert → Revert |
| `.view(id)` → Edit tap → `.edit(id)` | Revert to `.view(id)` | Revert to `.view(id)` | Discard alert → Revert |

Rule: `.edit` always reverts to view (whether entered directly or
promoted); `.create` always dismisses (no view to revert to).

## Architecture

### `PaperEventSheet` — mutable mode state

Replace:

```swift
let mode: SheetMode
```

with:

```swift
let initialMode: SheetMode
@State private var currentMode: SheetMode?    // seeded from initialMode in .task(id:)
```

All existing dispatchers (`.task(id:)`, `cardContent`, the `.alert`
block) read `currentMode` instead of `mode`. The view's Edit button
mutates `currentMode`; Save/Cancel handlers mutate it back.

Two new helpers on `PaperEventSheet`:

```swift
private func promoteToEdit() {
    guard case let .view(id) = currentMode else { return }
    currentMode = .edit(id)
    viewModel?.beginEditing()
}

private func revertToView() {
    guard let id = currentMode?.existingEventID else { return }
    viewModel?.cancelEditing()
    currentMode = .view(id)
}
```

The Save / Cancel closures inside the existing `cardContent` switch:

- For `.edit` (whether long-press shortcut or promoted): Save calls
  `await viewModel.save()` then `revertToView()` (don't dismiss); Cancel
  (dirty) raises the existing discard alert which calls `revertToView`;
  Cancel (clean) calls `revertToView` directly.
- For `.create`: unchanged (Save dismisses, Cancel dismisses or shows
  discard).

### `EventHeader` — optional Edit callback

Add:

```swift
var onEdit: (() -> Void)?
```

When non-nil, render a handwriting "Edit" link in the trailing edge
of the header, left of the existing close X:

```
┌────────────────────────────────────┐
│ ○ ○ ○                              │
│                                    │
│ • FAMILY            Edit   ✕       │
│                                    │
│ Sara's birthday                    │
│ Saturday · 8 PM – 11 PM            │
└────────────────────────────────────┘
```

The link uses `font.font(at: 15 * size.scale, weight: .bold)` in
`theme.blueInk`, italic underlined. Tappable hit area inset -8 like
the existing close button.

Accessibility: label "Edit event", trait `.isButton`, identifier
`paperEventSheet.edit`.

### `EventNotesRow` / other view-mode rows — no changes

The promote-to-edit happens at the sheet level; rows below the
header don't care about mode.

## Files touched

| Path | Change |
|------|--------|
| `WeeklyPlanner/Features/EventDetail/PaperEventSheet.swift` | `mode` → `initialMode` + `currentMode` state; `promoteToEdit`, `revertToView`; rewire Save/Cancel closures in `cardContent` |
| `WeeklyPlanner/Features/EventDetail/EventHeader.swift` | Add optional `onEdit` parameter + Edit link rendering |
| `WeeklyPlannerTests/EventDetail/PaperEventSheetEditTests.swift` | +2 VM-contract tests for the revert-to-view flow |

Call-site update: `DayPageContent` already constructs the sheet via
`PaperEventSheet(mode: .view(id), …)` etc. — rename the parameter to
`initialMode:`.

## Tests

Two new tests in `PaperEventSheetEditTests`:

```swift
func testEdit_saveCommitsThenLeavesViewModelInViewableState() async throws {
    // upsert event → vm.load() → vm.beginEditing() → mutate composer
    // → vm.save() → assert vm.composer == nil, vm.event has the new
    // title, vm.event is still loaded (not dismissed).
}

func testEdit_cancelEditingClearsComposerWithoutTouchingEvent() async throws {
    // upsert event → vm.load() → vm.beginEditing() → mutate composer
    // → vm.cancelEditing() → assert vm.composer == nil, vm.event is
    // unchanged.
}
```

These pin the VM contract that the same-sheet promote/revert pattern
relies on. The visual swap (view → edit → view inside one sheet) is
verified by manual dogfood; UITest already exercises create end-to-end.

## Out of scope

- `.create` → revert-to-view after save (would need to look up the
  newly-saved event ID and re-fetch). Keep create → dismiss for now;
  track for a future polish pass.
- Animated cross-fade between view and edit modes inside the card.
  SwiftUI gets a basic `.transition(.opacity)` on the if/else swap
  for free; visual tuning after the data plumbing lands.
- Updating the long-press menu to remove the "Edit" item now that
  the view-mode Edit link is discoverable. Both entry points stay —
  long-press is a power-user shortcut.

## Risks

- **`@State private var currentMode: SheetMode?` initialization
  timing.** Must be seeded in `.task(id: initialMode)` not in
  property initialization (because `initialMode` isn't known at the
  property's `= nil` evaluation time). Existing `.task(id: mode)`
  block already runs on appearance — refactor it to read
  `initialMode` and set `currentMode` first, then dispatch on
  `currentMode`.
- **`SheetMode.existingEventID` is optional** (`.create` has none).
  `revertToView()` must guard with `if case let .view(id) = …` /
  `.edit(id)` to filter out `.create`. The behavior matrix already
  notes `.create` never reverts.
- **Sheet remount on initial mode change.** If the caller passes a
  new `initialMode` value while the sheet is open (e.g., long-press
  on a different row), the existing `.task(id: mode)` re-runs and
  re-seeds. With the refactor, `.task(id: initialMode)` re-seeds
  `currentMode = initialMode` — which is the right behavior. No
  regression.
