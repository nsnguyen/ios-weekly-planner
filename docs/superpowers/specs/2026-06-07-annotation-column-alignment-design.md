# Annotation Column Alignment — Design

**Date:** 2026-06-07
**Status:** Approved (approach A)
**Area:** Day page free-text annotations (Phase 34 follow-up)

## Problem

Long-pressing the day page creates a free-text annotation (the intended Phase 34
behavior — confirmed correct by the user). But the note lands in the wrong place:
it renders far to the left of the press point, often out in the page's left margin
instead of in line with the events.

## Root cause

The mis-placement is **not** a padding/coordinate-space bug — the creation
gesture's `.local` space and the annotation overlay are the same node, so the unit
math round-trips correctly. The cause is the **render anchor**:

- `AnnotationLayer` positions each note with
  `.position(x: width·unitX, y: height·unitY)` (`AnnotationLayer.swift:27`), and
  `.position` centers the view on that point.
- The note's display frame is a **220 pt wide, leading-aligned** box
  (`AnnotationView.swift:65`).

So a 220 pt box gets *centered* on the press point P, and the (typically short)
text renders at the box's leading edge — roughly **110 pt left of P**, frequently
drifting into the left margin.

```
Current — 220 pt box centered on press point P:
 margin(44)
 │ events / red-line column
 │   ┌───────────── 220 pt box, centered on P ──────────────┐
[Test                                                        ]
 └ "Test" renders at P − 110, out in the margin
```

## Desired behavior

New notes created by long-press start at the **event column** — the same left edge
(the 44 pt page margin) where events, the red margin line, and to-dos all begin —
at the vertical position where the user pressed. Notes remain freely draggable
afterward (drag behavior is unchanged).

```
Fixed — note top-left anchored at (column, pressY):
 margin(44)
 │ [Test            ]   ← leading edge at the column, on the line pressed
```

## Approach (A — re-anchor to top-leading)

Chosen over the lower-risk "keep center anchor, only fix creation" because it
removes the underlying 110 pt center surprise rather than papering over it, and it
avoids hard-coupling the creation gesture to the 220 pt box width.

### 1. Re-anchor the annotation layer to top-leading

In `AnnotationLayer`, change each note's placement so `unitX`/`unitY` mean the
note's **top-left corner** instead of its center:

- Replace `.position(x: width·unitX, y: height·unitY)` with a top-leading
  `.offset(x: width·unitX, y: height·unitY)`. The hosting `ZStack` is already
  `alignment: .topLeading`, so each note lays out at the origin and the offset
  shifts its top-left to the unit-scaled point.

Drag is unaffected — `moveGesture` is translation-based (`unit += translation /
layerSize`), so it composes with the new anchor identically. `dragOffset` continues
to apply on top during an in-progress drag.

**Trade-off (accepted):** any note created before this change has its stored unit
re-interpreted from "center" to "top-left," so it shifts once (right ~110 pt, down
~half its height). Negligible — the feature is one day old and notes are
user-repositionable.

### 2. Column-align new notes on creation

In `DayPageView.annotationCreationGesture`, compute the creation unit as:

- `unitX = pageMargin / annotationLayerSize.width` — the event column (constant;
  the horizontal press position is intentionally ignored, so every new note lines
  up in the same column).
- `unitY = drag.startLocation.y / annotationLayerSize.height` — where the user
  pressed vertically (so the note starts on the line under the finger).
- Pass the result through `Annotation.clampUnit` for safety, then
  `viewModel.addAnnotation(atUnit:)`.

### 3. Name the page-margin constant

Lift the repeated literal `44` (the page's `.padding(.leading, 44)` and the new
creation math) into a single named constant so the note column and the page margin
cannot drift apart. Scope the constant to the day-page layout (e.g. a small
`private let`/`enum` in `DayPageView.swift`); only the two sites we touch need to
adopt it now.

## Components touched

| File | Change |
|------|--------|
| `Features/DayPage/Annotations/AnnotationLayer.swift` | `.position` → top-leading `.offset` |
| `Features/DayPage/DayPageView.swift` | column-aligned creation unit; named page-margin constant |

## Testability

The placement math currently lives inline in a SwiftUI `Gesture` closure, which is
hard to unit-test. Extract a small pure helper — `annotationCreationUnit(pressY:
layerSize:pageMargin:)` returning the clamped column-aligned unit — so the
alignment can be asserted directly:

- `unitX · width == pageMargin` (text leading lands on the column).
- `unitY · height == pressY` (vertical position preserved).
- Degenerate `layerSize` (zero width/height) is handled without NaN.

Write this test first (RED) per the project's TDD workflow, then implement.

## Verification

- New unit test for `annotationCreationUnit` passes.
- Existing `AnnotationLayerTests` / `DayPageViewModelTests` stay green (the VM's
  `addAnnotation(atUnit:)` is unchanged — it stores the unit it's handed).
- `AnnotationsUITests` re-run; adjust only if an assertion depended on the old
  center anchor (they assert appearance/editability, not exact pixel x, so changes
  should be minimal or none).
- Manual: long-press several spots on the day page — each note's leading edge lands
  on the event column at the pressed line, and notes still drag freely.

## Out of scope

- The "Add Event" sheet (long-press → annotation is the confirmed, desired
  behavior; event creation stays on the existing "add your first event" row).
- Snapping notes to ruled lines, or constraining drag to the column.
