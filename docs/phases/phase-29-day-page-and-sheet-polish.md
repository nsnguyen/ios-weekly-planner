# Phase 29 — Day Page & Event Sheet Polish

> **Milestone L (v1.1 Polish).** Post-submission. Covers `docs/suggestions.md`
> lines 7, 8, 9, 10 (Day page) and 13, 14, 15, 16 (event / add-event sheet).

## Goal
Tighten the Day page and the event sheet from real-use feedback: more room for
notes, less footer chrome, arrows-only day stepping, and a clearer, more
legible event sheet.

## Why this is needed
These are high-frequency, low-risk touches on the two screens users spend the
most time in. Individually small; together they materially lift perceived
quality.

## Prerequisites
- Phases 06–08 (Day page), 11 (Event sheet), 22 (Event CRUD). *(All shipped.)*

## Files Created / Modified

```
WeeklyPlanner/Features/DayPage/DayPageHeader.swift          # MODIFY — move header up (7); drop "Week NN" under the day-of-week (9)
WeeklyPlanner/Features/DayPage/DayPageView.swift            # MODIFY — top padding/space reclaim (7); PageNumber footer (8)
WeeklyPlanner/Features/DayPage/BookBottomControls.swift     # MODIFY — prev/next as arrows only, no day labels (10)
WeeklyPlanner/Features/DayPage/WeekChevrons.swift           # REVIEW — arrow treatment consistency (10)
WeeklyPlanner/Features/EventDetail/PaperEventSheet+Edit.swift  # MODIFY — create-mode template background opacity (13)
WeeklyPlanner/Features/EventDetail/EventDeleteButton.swift  # MODIFY — "Tear out this page" → "Delete" (14)
WeeklyPlanner/Features/EventDetail/EventHeader.swift        # MODIFY — larger / tinted sheet header, left side (15)
WeeklyPlanner/Features/EventDetail/EventAISticky.swift      # MODIFY — relocate "SUGGESTED" away from default; surface under Ask AI (16)
WeeklyPlanner/Features/EventDetail/EventAISuggestion.swift  # REVIEW — companion to the above (16)
WeeklyPlannerTests/EventDetail/EventDeleteButtonTests.swift # NEW/MODIFY — asserts the "Delete" label
WeeklyPlannerTests/DayPage/DayPageHeaderTests.swift         # MODIFY — no week label; header geometry
```

## Visual & Interaction Checklist
- [ ] **(7)** Day header sits higher; the events/notes area gains vertical
      space. Verify against `docs/mock/paper-planner.jsx` proportions.
- [ ] **(8)** The page-number/date footer (`PageNumber(date:)`, bottom-trailing
      of `DayPageContent`) is removed — the bottom-right date no longer shows.
- [ ] **(9)** The "Week NN" line under the day-of-week in `DayPageHeader` is
      gone; the day-of-week + date remain.
- [ ] **(10)** The bottom previous-day / next-day controls render as arrows
      only (no spelled-out adjacent day names).
- [x] **(13) — CLOSED, not reproduced (2026-06-03).** Investigated: the
      add-event sheet card already renders on opaque `theme.cream` (`#FAF6E9`,
      no alpha) and contains no `RuledLines`; on-device the form background is
      clean (the horizontal lines are intentional per-field dividers, not
      ruled-paper bleed-through). No code change made. Reopen if feedback
      recurs against a specific build.
- [ ] **(14)** The delete control reads **"Delete"** (the confirm alert already
      says "Delete this event?").
- [ ] **(15)** The event sheet header / left side is larger or uses a distinct
      tint so it's clearly separated from the body.
- [ ] **(16)** The "AI suggested" / "SUGGESTED" affordance is removed from its
      current default placement and instead lives under the "Ask AI" path
      (shown on request rather than always-on).

## Logic & Data Checklist
- [ ] Removing the footer date and week label is presentation-only — no data,
      accessibility-label, or layout-anchor regressions (the `PageNumber`
      anchor previously held bottom-trailing space; confirm nothing relied on
      it for layout).
- [ ] Arrows-only nav keeps the same prev/next semantics and a11y labels
      ("Previous day" / "Next day").
- [ ] The "Delete" relabel keeps the existing destructive confirmation flow.
- [ ] Moving "AI suggested" under Ask AI does not break the sticky/ suggestion
      data path — only where/when it surfaces.

## Tests (TDD)
- [ ] `EventDeleteButtonTests` asserts the visible label is "Delete".
- [ ] `DayPageHeaderTests` asserts no "Week" string is rendered and the header
      origin moved up.
- [ ] A sheet test asserts the SUGGESTED block is absent from the default view
      state and present only via the Ask-AI affordance.
- [ ] Accessibility audit UI tests (Phase 21) still pass for Day page + sheet.

## Acceptance Criteria
- All eight tweaks visible and matching the intent above.
- No accessibility regressions; full suite green.
- Screenshot diff vs. the mock approved for the Day page and event sheet.

## Out of Scope
- Week page polish (Phase 30) and Review/AI naming (Phase 32).
- Any new event-sheet capability (recurrence is Phase 35).
- Free-text notes on the page (Phase 34) — "more space for notes" here means
  reclaiming layout space, not the annotation feature.

## Risks & Notes
- **(16) — RESOLVED (2026-06-03).** User chose "add an Ask AI button in the
  sheet": the suggestion stays hidden until the user taps a dashed "✨ Ask AI"
  affordance, which reveals `EventAISticky` inline. Implemented in
  `PaperEventSheet` via `showAISuggestion` (reset per seeded event).
- Each tweak shipped as an atomic commit so any single change can be reverted
  from TestFlight feedback without unwinding the others.

## Outcome (2026-06-03)
Seven tweaks shipped (7, 8, 9, 10, 14, 15, 16) across 6 atomic commits; (13)
closed as not-reproduced. Unit suite 394/0; the Day-page accessibility audit
now passes (tweak 10 fixed a pre-existing hit-target failure). View-mode
sheet tweaks (15/16) verified structurally + by code; recommend an on-device
eyeball on a real existing event before the Phase 41 submission.
