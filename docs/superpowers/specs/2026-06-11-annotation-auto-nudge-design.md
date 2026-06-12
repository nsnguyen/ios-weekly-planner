# Annotation Auto-Nudge On Content Growth — Design

**Date:** 2026-06-11
**Status:** Draft (follow-up to 2026-06-10 stack-from-top)
**Area:** Day page free-text annotations

## Problem

Stack-from-top places a note at a fixed overlay position measured at creation.
If content later grows into that band — create a note on an empty day, then
create an event — the event row renders straight through the note (observed
2026-06-11: "1 AM Test" overlapping a "Test" note at the top of Thursday).
The reverse order (events first, note second) already works.

## Desired behavior (confirmed with user)

- **Auto-nudge undragged notes.** When the content column's bottom edge grows
  past a machine-placed note, that note is pushed down to stack below the new
  content, exactly as if it had just been created there.
- **Dragging pins.** The moment the user drags a note anywhere, it is pinned:
  content growth never moves it again. (The machine may move what the machine
  placed; it never moves what the user placed.)
- **Existing notes are pinned.** Notes created before this feature (including
  press-point-era notes) never auto-move. No migration of positions.

## Decisions resolved to defaults (veto at review)

- **Down-nudge only.** Content shrinking (event deleted) does not pull notes
  back up — avoids oscillation and surprise movement; the user can drag or
  recreate. YAGNI until asked for.
- **A note being edited is never nudged** while its editor is open (the commit
  flow owns it); it becomes nudgeable again once committed, on the next
  content-growth event.
- **Nudge animates** with the default SwiftUI animation so the move reads as
  deliberate, not a glitch.

## Approach

### 1. Model: `autoPlaced` flag

`Annotation` gains `var autoPlaced: Bool = false` (SwiftData additive field;
existing rows decode as `false` = pinned, which is exactly the migration we
want). Creation via the stacking gesture sets `autoPlaced = true`;
`moveAnnotation` (drag commit) sets it `false`. Pinned = `!autoPlaced`.

### 2. Trigger: content-bottom growth

`DayPageView` already measures `contentBottomY` (pt, keyboard-independent).
An `.onChange(of: contentBottomY)` hook calls the view model when the value
**grows** (old < new), passing the current `annotationLayerSize` and
`noteHeights` — the same inputs the creation gesture uses. Keyboard-driven
layer-height changes don't touch `contentBottomY`, so they can't trigger it.

### 3. Reflow: reuse the stacking math

`DayPageViewModel.nudgeAutoPlacedNotes(contentBottom:layerSize:noteHeights:)`:

- Colliding = `autoPlaced && id != editingID && noteTop < contentBottom`
  where `noteTop = unitY × layerHeight`.
- Process colliding notes in current-`unitY` order (top-down). For each, set
  `unitY` via the existing pure `DayPageLayout.stackedAnnotationUnit`, with
  `annotationBottoms` = bottoms of all *other* notes that are pinned, already
  processed, or non-colliding — so nudged notes restack in order below the
  content and below each other, never overlapping anything.
- Persist via a dedicated nudge update that does NOT touch `autoPlaced`
  (`moveAnnotation` clears the flag because it means user drag — a nudge must
  not pin the note it just moved). x is untouched (already column-pinned).

The pure ordering/selection logic (`which notes collide, in what order, with
what bottoms`) lives in `DayPageLayout` next to `stackedAnnotationUnit`, so it
is unit-testable without SwiftUI.

## Components touched

| File | Change |
|------|--------|
| `Models/Annotation.swift` | `autoPlaced: Bool = false` field |
| `Features/DayPage/DayPageView.swift` | `.onChange(of: contentBottomY)` growth trigger |
| `Features/DayPage/DayPageLayout.swift` (or VM) | pure collision/reflow helper |
| `DayPageViewModel` | `nudgeAutoPlacedNotes`, `autoPlaced` set on create, cleared on drag |
| `WeeklyPlannerTests` | reflow helper unit tests + VM flag-lifecycle tests |
| `WeeklyPlannerUITests/AnnotationsUITests.swift` | note-then-event end-to-end test |

## Edge cases

- **Multiple colliding notes:** restack in their current vertical order below
  the content; spacing via `stackSpacing`; bottom clamp via `bottomHeadroom`
  (page-full overlap accepted, as in creation).
- **Content grows while a note is mid-drag:** the dragged note is skipped if
  it is the editing note; a purely-dragging note commits its position on
  gesture end (drag wins — it pins).
- **Inbox rows / repeating-event expansions** grow the same content column —
  the trigger is content-bottom growth, source-agnostic by construction.

## Testability (TDD)

- Pure helper: no collision → no moves; one collision → lands at
  contentBottom + spacing; multiple → restack in order; pinned/editing
  excluded; clamp at headroom.
- VM: created-by-gesture note has `autoPlaced == true`; dragged note flips to
  `false` and is never nudged afterward.
- UI test: empty day → create note → create event via the add-row → assert the
  note's frame sits below the event row's frame (no overlap).

## Out of scope

- Pulling notes back up when content shrinks.
- Reflowing pinned or pre-existing notes.
- The unit-space keyboard rescale quirk (notes shift slightly when the
  keyboard changes the layer height — pre-existing Phase 34 behavior, separate
  issue if it ever bothers anyone).
