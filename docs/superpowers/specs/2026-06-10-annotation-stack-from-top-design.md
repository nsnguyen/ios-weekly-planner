# Annotation Stack-From-Top Placement — Design

**Date:** 2026-06-10
**Status:** Approved (approach A — measured geometry)
**Area:** Day page free-text annotations (follow-up to 2026-06-07 column alignment)

## Problem

A long-press note lands at the vertical position of the finger. On a sparse or
empty day this strands the note mid-page (e.g. a lone "Test" note floating in
the middle of an otherwise empty Wednesday), which looks broken on ruled paper.
The user wants new notes to read like writing on a notepad: start at the top,
continue downward.

## Desired behavior (confirmed with user)

- **Always stack from top.** The press position is ignored entirely (both axes
  now — x was already ignored since the column-alignment fix). A new note lands
  one line below the lowest existing content on the page.
- **"Lowest existing content" = below everything:** the content column (header →
  events list → inbox block) or the lowest existing annotation — whichever is
  lower. On an empty day the content column is just the header, so the first
  note lands on the first free line below "Wednesday / 10 Jun".
- **Drag stays free.** Stacking decides only the initial placement; notes remain
  freely repositionable afterward (existing `moveGesture` unchanged).
- **Existing notes keep their saved positions.** No migration.
- **Non-participants:** the AI sticky note (decorative top-right overlay) does
  not count as content; the bottom to-do patch / EventAddRow live in a
  `safeAreaInset` outside the annotation layer's coordinate space and cannot
  participate anyway.

```
Empty day:                       Day with events + a note:
 ┌ header ─────────────┐          ┌ header ─────────────┐
 │ Wednesday   10      │          │ Wednesday   10      │
 ├─────────────────────┤          ├ events ─────────────┤
 │ [new note]   ← here │          │ 9:00 standup        │
 │                     │          │ 11:00 review        │
 │        (not here,   │          ├─────────────────────┤
 │         where the   │          │ [note A]            │
 │         finger was) │          │ [new note]   ← here │
 └─────────────────────┘          └─────────────────────┘
```

## Approach (A — measure real geometry)

Chosen over (B) estimating heights from model data and (C) fixed line slots:
note heights vary with wrapped text and the events block with row count, and on
ruled paper even a few points of overlap reads as broken. Real frames make
overlap impossible. The page already uses `onGeometryChange` twice for exactly
this kind of measurement.

### 1. Named coordinate space on the layer node

The padded content frame in `DayPageView.body` (the node that already feeds
`annotationLayerSize` via `onGeometryChange`, `DayPageView.swift:156-172`) gains
`.coordinateSpace(name: "annotationLayer")`. Both measurements below resolve
frames in this space, so no manual padding math is needed and the values are
directly comparable to `annotationLayerSize`.

### 2. Two measurements into view state

- **Content bottom.** The `content(...)` VStack (header / events / inbox,
  `DayPageView.swift:455`) reports `frame(in: .named(...)).maxY` →
  `@State contentBottomY: CGFloat`. The VStack hugs its children, so its bottom
  is the header's bottom on an empty day and the events/inbox bottom otherwise —
  no per-row measurement needed. (The outer `minHeight` stretch happens on the
  parent frame node, not the VStack, so the VStack's own frame stays natural.)
- **Annotation heights.** Each `AnnotationView` in `AnnotationLayer` reports its
  rendered **height** into a `@Binding var noteHeights: [UUID: CGFloat]` owned by
  `DayPageView` (entry removed on disappear). At press time the gesture computes
  each note's bottom as `layerHeight × unitY + height` from the live model.
  Heights rather than frames on purpose: height is pure layout (wrapped text,
  bold, paper-size scaling all measured), independent of the `.offset` render
  transform, and reading `unitY` live means a note dragged a moment ago can
  never contribute a stale bottom.

### 3. Pure stacking function in `DayPageLayout`

```swift
static let stackSpacing: CGFloat = 12      // gap below the anchor; tune visually
static let bottomHeadroom: CGFloat = 60    // keep at least this much page below a new note

static func stackedAnnotationUnit(contentBottom: CGFloat,
                                  annotationBottoms: some Collection<CGFloat>,
                                  layerSize: CGSize) -> CGPoint
```

- anchor = `max(contentBottom, annotationBottoms.max() ?? 0)`
- y = `min(anchor + stackSpacing, layerSize.height - bottomHeadroom)`
- returns `Annotation.clampUnit(CGPoint(x: pageMargin / width, y: y / height))`
  (same NaN/zero-size safety net as today).

`stackSpacing` starts at 12 pt — a visual gap, not a snap; the paper's ruled
lines are 28 pt apart (`RuledLines.lineSpacing`) and true line-snapping stays
out of scope. Tune against screenshots during implementation.

The existing `annotationCreationUnit(pressY:layerSize:)` is **deleted** — the
creation gesture is its only caller and press Y is no longer an input.

### 4. Gesture swap

`annotationCreationGesture.onEnded` (`DayPageView.swift:333-352`) calls the new
function with the measured state instead of `drag.startLocation.y`, and its
guard extends to `contentBottomY > 0` (alongside the existing nonzero
`annotationLayerSize` check) so a press can never stack against an unmeasured
content column. Everything downstream — `addAnnotation(atUnit:)`, empty-text
draft, open-editor-on-create — is untouched.

## Components touched

| File | Change |
|------|--------|
| `Features/DayPage/DayPageLayout.swift` | `stackedAnnotationUnit` + constants; delete `annotationCreationUnit` |
| `Features/DayPage/DayPageView.swift` | named coordinate space; `contentBottomY` state; gesture uses stacking function |
| `Features/DayPage/Annotations/AnnotationLayer.swift` | per-annotation height reporting |
| `WeeklyPlannerTests/Annotations/DayPageLayoutTests.swift` | replace press-Y tests with stacking tests |

## Edge cases

- **Layer not yet measured:** the gesture guards on zero `annotationLayerSize`
  (existing) and zero `contentBottomY` (new) — a press during the pre-layout
  window is dropped rather than mis-stacked.
- **Full page:** the anchor clamps to `height − bottomHeadroom`; notes may
  overlap down there, accepted as "the page is full" (the page already scrolls).
- **Delete/drag a note:** the bottoms dict updates from geometry automatically;
  the next note stacks against the new reality.

## Testability (TDD — tests first)

`DayPageLayoutTests` additions (RED before implementation):

- Empty page: y = contentBottom + `stackSpacing`; x · width = `pageMargin`.
- Note below content: stacks below the note, not the content.
- Note dragged above content bottom: content bottom wins (max, not last).
- Anchor near page bottom: y clamps to `height − bottomHeadroom`.
- Degenerate layer size: no NaN (clampUnit path).

`AnnotationsUITests` addition: on an empty day, long-press mid-page → the
created note's frame sits in the top quarter of the page.

## Verification

- New unit tests pass; existing `DayPageViewModelTests` / annotation tests stay
  green (`addAnnotation(atUnit:)` stores what it's handed — unchanged).
- Full `WeeklyPlannerTests` suite green.
- Manual: long-press an empty day → note on the first line under the header;
  add two more → they stack in order; drag one to the bottom → next note stacks
  below it; day with events → first note lands under the events list.

## Out of scope

- Snapping notes to the 28 pt ruled lines (placement is measured, not gridded).
- Reflowing or migrating existing saved notes.
- Reordering semantics for the stack (notes are still free-floating objects).
- Counting the AI sticky note as content.
