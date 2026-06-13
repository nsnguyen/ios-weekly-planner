# Annotation Vertical-Only, Left-Locked Movement — Design

**Date:** 2026-06-12
**Status:** Draft (follow-up to 2026-06-11 auto-nudge)
**Area:** Day page free-text annotations

## Problem

Day-page notes (`Annotation`s) can currently be dragged freely in 2D — the
long-press *creation* gesture already places them flush at the left margin and
stacked top-down, but `AnnotationView.moveGesture` then lets the user drop a
note at any X/Y. Free horizontal placement breaks the notepad metaphor: notes
should read as an ordered, left-aligned list, not scattered sticky notes.

## Desired behavior (confirmed with user)

- **Vertical-only movement.** An existing note can be dragged up or down to
  reorder it; it can never move horizontally.
- **All notes align to the left side.** Every note renders flush at the page's
  leading margin (`DayPageLayout.pageMargin`, 44pt — the red rule line where
  events and to-dos begin). This includes notes dragged off to the right under
  the old free-2D behavior: they **snap back to the column** the moment this
  ships, with no migration and no user action.
- **Creation is unchanged.** Long-press to create a note already places it at
  the margin, stacked below existing content. Untouched.

## Approach

Make the **left margin the single source of truth** for a note's horizontal
position. Stored `unitX` stops driving the rendered X, so a note's column
position no longer depends on whatever X happens to be persisted. Drag is
reduced to a vertical translation.

### 1. Render: lock X to the margin (snaps all notes left)

`AnnotationLayer` positions each note with
`.offset(x: geo.size.width * annotation.unitX, y: …)`. Replace the X term with
the constant margin:

```swift
.offset(x: DayPageLayout.pageMargin,
        y: geo.size.height * annotation.unitY)
```

For a freshly-created note this is identical (`width × (pageMargin/width) ==
pageMargin`); for an old right-dragged note it pulls the leading edge to the
column. This single line is what makes *all* notes — new, old, or
previously-dragged — align left, without touching stored data.

### 2. Live drag: vertical-only finger tracking

`moveGesture`'s `dragOffset` updater currently feeds the full translation into
`.offset(dragOffset)`, so the note drifts sideways under the finger. Constrain
it to the Y component:

```swift
.updating($dragOffset) { value, state, _ in
    state = CGSize(width: 0, height: value.translation.height)
}
```

### 3. Drag commit: pin X to the margin, move only Y

The `onEnded` handler commits the new position. Route its math through a new
**pure** helper in `DayPageLayout` (next to `stackedAnnotationUnit` /
`nudgesForContentGrowth`, matching the "plain values in, unit out —
unit-testable without SwiftUI" pattern):

```swift
/// Unit-space destination for a vertical-only note drag: the leading
/// edge stays locked to the page margin, only the top's Y moves by the
/// drag translation. `Annotation.clampUnit` keeps it on the page and is
/// the NaN/inf safety net for a degenerate (zero) layer size.
static func verticalDragUnit(currentUnitY: Double,
                             translationHeight: CGFloat,
                             layerSize: CGSize) -> CGPoint {
    Annotation.clampUnit(CGPoint(
        x: pageMargin / layerSize.width,
        y: currentUnitY + Double(translationHeight / layerSize.height)))
}
```

`onEnded` then commits `verticalDragUnit(...)` to the live model and persists
via `viewModel.moveAnnotation`, exactly as today — same live-commit-in-one-
transaction trick that prevents the flash-back, same `autoPlaced`-clearing pin
behavior (a vertical drag is still a deliberate placement, so it still resists
auto-nudge). The only difference is X always lands on the margin.

## Components touched

| File | Change |
|------|--------|
| `Features/DayPage/DayPageLayout.swift` | new pure `verticalDragUnit(...)` helper |
| `Features/DayPage/Annotations/AnnotationView.swift` | `dragOffset` → Y-only; `onEnded` → `verticalDragUnit` (X pinned) |
| `Features/DayPage/Annotations/AnnotationLayer.swift` | render X at `DayPageLayout.pageMargin` (ignore stored `unitX`) |
| `WeeklyPlannerTests` | `verticalDragUnit` unit tests |
| `WeeklyPlannerUITests/AnnotationsUITests.swift` | (if low-risk) vertical-drag keeps X, moves Y |

## Untouched (verified against current source)

- **Auto-nudge** (`nudgesForContentGrowth`) is already Y-only — the X axis is
  never computed there.
- **Creation** (`stackedAnnotationUnit`) already returns `x = pageMargin/width`.
- **Pin-on-drag**: `moveAnnotation` still clears `autoPlaced`, so a
  hand-positioned note still resists content-growth auto-nudge.
- **SwiftData schema**: `unitX` stays on the model; it simply becomes
  display-irrelevant. No migration.

## Decisions resolved to defaults (veto at review)

- **No data migration.** Render ignores stored `unitX`, so old off-left values
  are harmless; any note that is dragged re-normalizes its own `unitX` to the
  margin on commit. Rewriting every row's `unitX` on load would add write
  churn on every refresh for zero additional visible benefit. YAGNI.
- **"Left side" = `pageMargin` (44pt), not screen edge.** The note column
  aligns with events/to-dos at the red rule line, consistent with how new
  notes are already created and with `DayPageLayout.pageMargin`'s doc comment.
- **A vertical drag still pins** (clears `autoPlaced`). Reordering a note by
  hand is a deliberate placement; it should not be re-stacked by auto-nudge.

## Edge cases

- **Old right-dragged note:** stored `unitX` ≈ 0.5; render forces `x =
  pageMargin`, so it appears in the column immediately. Stored value stays
  stale (display-irrelevant) until a drag normalizes it.
- **Degenerate layer size (width/height 0):** `onEnded` already guards
  `layerSize.width > 0 && layerSize.height > 0`; `verticalDragUnit` additionally
  leans on `Annotation.clampUnit` as the NaN/inf net, matching
  `stackedAnnotationUnit`.
- **Clamp at page edges:** dragging a note above the top or below the bottom
  clamps `unitY` into [0, 1] via `clampUnit`, unchanged from today.

## Testability (TDD)

- **Pure helper `verticalDragUnit`:** X always equals `pageMargin/width`
  regardless of input or starting `unitX`; Y moves by `translationHeight/height`;
  upward and downward translations both clamp at the page edges; a zero-size
  layer returns a clamped, finite point (no NaN/inf).
- **UI (only if it proves low-flake):** create a note, drag it down, assert its
  frame's `minX` is unchanged (column-locked) and its `minY` increased. Given
  the documented XCUI accessibility-frame inflation, assert *relative* movement
  (Δ), not absolute coordinates; skip rather than ship a flaky test.

## Out of scope

- Migrating / rewriting stored `unitX` for existing rows.
- Horizontal reordering, indentation, or multi-column layouts.
- Any change to creation placement, auto-nudge, or the commit/delete lifecycle.
