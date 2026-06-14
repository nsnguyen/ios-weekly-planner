# Annotation Compact-Reorder Stack — Design

**Date:** 2026-06-13
**Status:** Draft (follow-up to 2026-06-12 vertical-only, supersedes 2026-06-11 auto-nudge)
**Area:** Day page free-text annotations

## Problem

Vertical-only movement (shipped 2026-06-12) lets a note be dragged to any height
and left there. A user dragging a note down — or a note left where content used
to be — produces large empty gaps (observed 2026-06-13: "1 AM Baby making" with
two notes floating far below it, big bands of blank paper between). The down-only
auto-nudge (2026-06-11) only pushes notes *down* on content growth; it never
pulls them up to close a gap. Notes should read as a tidy, gapless ordered list.

## Desired behavior (confirmed with user)

- **Reorder + re-pack.** Dragging a note up/down drops it into a new position in
  the list; on release the whole stack re-packs tight (no gaps), so the drag
  changes the notes' *order* — like rearranging to-do rows.
- **Always gapless, below the content.** Notes form one tight stack directly
  below the day's content (events / to-dos / inbox), closing the gap under the
  last content row too. Reordering happens among notes only; notes never move
  above or interleave with events.
- **No more free placement / pinning.** A drag no longer pins a note at an
  arbitrary height — it only reorders. The stack is always compacted.

## Approach

One rule: **notes always pack gaplessly below the content, in their current
vertical order.** Vertical position (`unitY`) doubles as the order key
(sort ascending) — no schema change. The down-only growth nudge becomes a
special case of bidirectional compaction.

### 1. Core: one pure function

`DayPageLayout.compactedStack(notes:contentBottom:layerSize:)`:

- Input: every note as `(id, unitY, height)`, plus `contentBottom` (pt) and
  `layerSize`.
- Sort notes by `unitY` ascending — that *is* the list order.
- Walk a cursor from `contentBottom`: each note's top = `cursor + stackSpacing`,
  clamped to `layerSize.height - bottomHeadroom`; then `cursor = top + height`.
- Return each note's new `unitY` (id-keyed).

Properties: **bidirectional** (closes gaps above *and* below — no down-only
guard), **all notes** (no `autoPlaced` filter), **idempotent** (a settled stack
returns identical positions, so the caller writes nothing). Pure values in,
placements out — unit-testable without SwiftUI, next to `stackedAnnotationUnit`.
This **replaces** `nudgesForContentGrowth`.

### 2. Drag = reorder

`AnnotationView.moveGesture.onEnded` keeps the vertical-only drop math
(`verticalDragUnit`, X on the margin) and writes the drop-`unitY` to the live
model in the same no-flash-back transaction as today (the note sits at the drop
spot, not its pre-drag spot). It then **signals** a compaction — it does not run
it, because the anchor inputs (`contentBottom`, `layerSize`, `noteHeights`) live
in `DayPageView`, which owns the measurements. The dropped note now sorts into
its new slot by `unitY`, the stack re-packs, and the change **animates** (the
"snap into order"). The old `moveAnnotation` pin path (write one note's
position + clear `autoPlaced`) is retired — drag persistence flows through
compaction, which writes every note's final slot.

### 3. Trigger: one VM method, several call sites

`DayPageViewModel.compactNotes(contentBottom:layerSize:noteHeights:editingID:)`
computes `compactedStack`, animates the changed notes to their new `unitY`, and
upserts **only** the notes whose `unitY` changed (idempotent → settled pages
write nothing). Called on:

- **annotations load / appear** — fixes pre-existing gappy days (the screenshot);
- **`contentBottomY` change, either direction** — replaces the growth-only guard
  in `DayPageView`'s `.onChange`;
- **drag release** — `AnnotationView` writes the drop-`unitY` and bumps a
  compaction-request token the VM publishes; `DayPageView` observes the token and
  runs the reorder with its measured anchors;
- **delete** and **after a text commit** — close the freed slot / settle a new note.

While a note is being edited, compaction is **deferred** (the edited note's
editor must not be yanked) and runs when editing ends (`editingID → nil`).

## Components touched

| File | Change |
|------|--------|
| `Features/DayPage/DayPageLayout.swift` | add pure `compactedStack`; remove `nudgesForContentGrowth` + `AnnotationNudge` |
| `Features/DayPage/DayPageViewModel.swift` | add `compactNotes` + a published compaction-request token; remove `nudgeAutoPlacedNotes` and `moveAnnotation` |
| `Features/DayPage/DayPageView.swift` | `.onChange(of: contentBottomY)` fires both directions → `compactNotes`; also compact on appear, on the compaction token, and on edit-end |
| `Features/DayPage/Annotations/AnnotationView.swift` | `onEnded` writes drop-`unitY` then bumps the VM compaction token |
| `WeeklyPlannerTests/Annotations/DayPageLayoutTests.swift` | replace nudge tests with `compactedStack` tests |
| `WeeklyPlannerTests/Annotations/AnnotationLayerTests.swift` | adjust any `nudgeAutoPlacedNotes` / pin expectations |

## Edge cases

- **Reorder mid-list:** dropping note C between A and B gives C a `unitY` between
  theirs → sort yields A, C, B → packs A, C, B. Exact-tie `unitY` broken stably
  (dragged note keeps its dropped side).
- **Drag above the content:** a note dropped up in the event area gets the
  smallest `unitY` → sorts first → packs at `contentBottom + stackSpacing` (it
  becomes the first note, never above the content).
- **Page full:** notes past `height - bottomHeadroom` pile at the clamp (overlap
  accepted there, exactly as creation/auto-nudge do today).
- **Degenerate layer (0×0):** guarded at the call site (`width/height > 0`);
  `clampUnit` is the NaN/inf net, as in `stackedAnnotationUnit`.
- **Keyboard-shrunk layer during a content change:** inherited residual from
  auto-nudge, but milder now — compaction also runs on appear and is
  bidirectional, so a mis-placed note self-heals on the next appear/drag instead
  of waiting for a growth event.

## Testability (TDD)

- **Pure `compactedStack`:** two notes already tight → no change (idempotent);
  a gap below content → both pull up to `contentBottom + stackSpacing`,
  `+ height + stackSpacing`; order follows `unitY` (pass notes out of order,
  assert sorted packing); a note dropped between two others reorders; full page
  clamps at headroom; settled stack re-run emits no diffs.
- **VM `compactNotes`:** persists only changed notes; excludes/defers the editing
  note; a dragged note ends below/above its neighbor per drop position.
- **Throwaway on-sim driver:** create two notes, drag the lower one above the
  upper, assert their vertical order swapped and the second sits exactly
  `stackSpacing`-below the first (no gap). Removed after it passes.

## Out of scope

- VoiceOver reading order — the VM array stays creation-ordered; only the
  visual `unitY` order changes (minor a11y nuance, separate issue).
- Interleaving notes with events / to-dos in one shared order.
- Snapping notes to the ruled-paper line rhythm (placement stays measured, as
  `stackSpacing` already is).
- Removing the now-vestigial `autoPlaced` field (kept to avoid a SwiftData
  migration; YAGNI until a model cleanup pass).
