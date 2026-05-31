# Phase 34 — Free-Text Annotations

> **Milestone M (v1.1 Features).** Post-submission. Covers `docs/suggestions.md`
> line 6: *"Free text on planner. Ability to use different color and style
> font (bold)."*

## Goal
Let users place free-form text directly on a planner page, choosing ink color
and a basic style (at minimum bold) — handwriting-on-paper, not bound to an
event or task.

## Why this is needed
A paper planner's defining affordance is writing *anywhere* on the page. Today
all text lives in structured rows (events/tasks). Free-text annotations close
the gap between the paper metaphor and the app, and were explicitly requested.

## Prerequisites
- Phase 03 (models/persistence), Phase 05/06 (paper primitives & day page),
  Phase 02 (theme/ink/font tokens). *(Shipped.)*
- Consider sequencing after Phase 33 so the ink text-styling component is shared.

## Files Created / Modified

```
WeeklyPlanner/Models/Annotation.swift                       # NEW — @Model: id, dayKey, text, colorToken, isBold, position (x/y or anchor), created/updated
WeeklyPlanner/Stores/AnnotationStore.swift                  # NEW — AnnotationStoring + SwiftDataAnnotationStore + StubAnnotationStore
WeeklyPlanner/Stores/Environment+Stores.swift               # MODIFY — \.annotationStore key + stub default
WeeklyPlanner/Stores/SwiftDataStack.swift                   # MODIFY — register Annotation
WeeklyPlanner/Features/DayPage/Annotations/AnnotationLayer.swift     # NEW — overlay above the page that renders + positions annotations
WeeklyPlanner/Features/DayPage/Annotations/AnnotationView.swift      # NEW — one editable annotation (tap to edit, drag to move)
WeeklyPlanner/Features/DayPage/Annotations/TextStyleBar.swift        # NEW — color swatches + bold/style toggles
WeeklyPlanner/Features/DayPage/DayPageView.swift            # MODIFY — host AnnotationLayer in the DayPageContent ZStack
WeeklyPlanner/Features/DayPage/DayPageViewModel.swift       # MODIFY — load annotations for (weekOffset, dayIdx)
WeeklyPlanner/DesignSystem/PaperTheme.swift                 # REVIEW — expose the ink color palette used by the swatches
WeeklyPlanner/Resources/Localizable.xcstrings               # MODIFY — strings (placeholder, style labels)
WeeklyPlannerTests/Annotations/AnnotationStoreTests.swift   # NEW — CRUD round-trip
WeeklyPlannerTests/Annotations/AnnotationLayerTests.swift   # NEW — add/position/style logic
WeeklyPlannerUITests/AnnotationsUITests.swift               # NEW — place text, set color+bold, persists
```

## Visual & Interaction Checklist
- [ ] The user can add a free-text annotation to a day page (e.g., long-press
      empty paper, or a "write" affordance) and type.
- [ ] A style bar offers ink **color** choices (from the theme palette) and at
      least **bold** on/off; chosen style applies live.
- [ ] An annotation can be moved (drag) and re-edited (tap) and deleted.
- [ ] Annotations render in the handwriting font/ink and respect theme + size.
- [ ] Annotations persist per day across relaunch and page flips, and only
      appear on their own day.
- [ ] The annotation gesture does **not** reintroduce a page-flip conflict
      (respect the Phase 27/28 flip-gesture lessons — see Risks).

## Logic & Data Checklist
- [ ] `Annotation` is keyed by `dayKey` (same scheme the day page uses) so it
      loads with the correct `(weekOffset, dayIdx)` cell.
- [ ] CRUD flows through `AnnotationStoring`; previews/tests use the stub.
- [ ] Color is stored as a stable token/name, not a raw platform color, so it
      re-themes correctly if the palette changes.
- [ ] Position model is defined explicitly (absolute point vs. relative anchor);
      pick relative-to-page so it survives rotation/Dynamic Type. Decide in
      `writing-plans`.
- [ ] Editing/moving an annotation must set the flip-suppression contract the
      same disciplined way Phase 28 establishes (gesture-state-derived; auto-
      reset) so it can never lock navigation.

## Tests (TDD)
- [ ] `AnnotationStoreTests` — round-trip incl. color token + bold flag.
- [ ] `AnnotationLayerTests` — add returns an annotation on the right day;
      style changes persist; delete removes it.
- [ ] `AnnotationsUITests` — place, style, relaunch, assert presence + style.
- [ ] Accessibility: annotations are reachable/labeled (VoiceOver reads text).

## Acceptance Criteria
- Free text can be placed, colored, bolded, moved, edited, deleted, and
  persists per day.
- No navigation lock-ups from the new gestures; full suite green.
- Screenshot of an annotated page approved.

## Out of Scope
- Freehand drawing / PencilKit ink strokes (text only).
- Rich text beyond color + bold (italic/underline/size optional stretch — keep
  to bold first unless the user wants more).
- Annotations on the Week or Month surfaces (Day page only for v1).

## Risks & Notes
- **Gesture conflict is the main risk.** A drag-to-move annotation lives on the
  same surface as the page-flip swipe and the sticky. Reuse the Phase 28
  pattern: the flip gesture yields only while an annotation drag is genuinely
  in progress, and that state is gesture-derived and self-resetting. Do **not**
  ship this before Phase 27/28.
- Confirm the "add text" entry point with the user (long-press vs. toolbar
  button). Default: long-press empty paper → new annotation at that point.
- Keep the style set minimal (color + bold) for v1; expand only on request.
