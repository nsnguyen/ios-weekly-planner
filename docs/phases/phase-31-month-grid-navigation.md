# Phase 31 — Month Grid & Week-Picker Navigation

> **Milestone L (v1.1 Polish).** Post-submission. Covers `docs/suggestions.md`
> lines 33, 34, 35, 36 (Monthly view). The "monthly view" is the month grid
> inside the **Week Picker** (`MonthGridView` / `WeekPickerViewModel` /
> `WeekRowView`); there is no standalone month screen.

## Goal
Make the month grid navigable and readable: centered month/year heading,
explicit month/year stepping, an unbounded (or far wider) range, a weekday
column layout, and no week-number noise.

## Why this is needed
The picker is the only way to jump dates, and it's currently boxed in.
`WeekPickerViewModel.buildMonths(around:)` builds exactly `focusMonth ± 2`
(five months), computed once in `init` and never extended — so the user
literally cannot scroll past two months either way (36). The month title is
left-aligned with a trailing rule (34 wants it centered), rows carry ISO week
numbers the user doesn't want (33), and there's no direct way to jump to an
arbitrary month or year (35).

## Prerequisites
- Phase 09 (Top Bar & Week Picker). *(Shipped.)*
- Best landed after Phase 27, which touches week-pick → `setWeek` wiring.

## Files Created / Modified

```
WeeklyPlanner/Features/WeekPicker/WeekPickerViewModel.swift # MODIFY — unbounded/lazy month range (36); jump-to month/year (35)
WeeklyPlanner/Features/WeekPicker/WeekPickerSheet.swift     # MODIFY — month/year stepper header (35); lazy paging on scroll (36)
WeeklyPlanner/Features/WeekPicker/MonthGridView.swift       # MODIFY — center month/year title (34); weekday header row (33)
WeeklyPlanner/Features/WeekPicker/WeekRowView.swift         # MODIFY — remove the ISO week-number column (33)
WeeklyPlannerTests/WeekPicker/WeekPickerViewModelTests.swift # MODIFY — range extension + jump math
WeeklyPlannerTests/WeekPicker/MonthGridViewTests.swift      # NEW — centered title, no week number, weekday header
```

## Visual & Interaction Checklist
- [ ] **(34)** The "May 2026" month/year title is centered in the section
      header (currently left-aligned with a trailing rule in `MonthGridView`).
- [ ] **(33)** Rows present a weekday-column layout (Mon-first weekday header),
      and the ISO **week number** is removed from each row.
- [ ] **(35)** The picker has explicit month/year navigation controls
      (prev/next month chevrons and/or a year stepper) — not scroll-only.
- [ ] **(36)** The user can navigate well beyond ±2 months in both directions
      (target: effectively unbounded, e.g., lazily extends as you scroll, or a
      generous fixed window such as ±24 months).
- [ ] "Today" still gets its red marker; the selected week still gets its blue
      wash; tapping a week still selects + dismisses.

## Logic & Data Checklist
- [ ] `buildMonths` no longer hard-caps at `±2`. Either build lazily on scroll
      (preferred — extend the `months` array as the user nears either end) or
      build a much wider fixed range. Whichever is chosen, scrolling to an edge
      must reveal more months.
- [ ] A jump-to-month/year action recomputes (or scrolls to) the requested
      month and keeps `selectedWeekOffset` semantics intact.
- [ ] Week offset math (`PickerWeek.offset` relative to today's Monday) stays
      correct at far-out months — verify no integer drift across year
      boundaries and DST.
- [ ] Removing the week number is presentation-only (no offset depends on the
      displayed `weekNumber`).
- [ ] Known prior issue: confirm picker scrolling actually works (a past bug
      report noted broken scroll / misaligned day header) — fix if still present.

## Tests (TDD)
`WeekPickerViewModelTests`
- [ ] `testRangeExtendsBeyondTwoMonths()` — months exist for ±N (N ≫ 2).
- [ ] `testJumpToMonthYear()` — jumping to a specific year/month yields that
      month with correct offsets.
- [ ] `testWeekOffsetCorrectAcrossYearBoundary()`.

`MonthGridViewTests`
- [ ] `testTitleCentered()` / `testNoWeekNumberRendered()` /
      `testWeekdayHeaderPresent()`.

## Acceptance Criteria
- The four tweaks are visible and the picker scrolls/jumps freely.
- Offset math verified across year boundaries; full suite green.
- Screenshot diff vs. `docs/mock/` picker approved.

## Out of Scope
- A standalone month **tab** / full-screen month calendar — not requested;
  the month grid stays inside the picker.
- Drag-to-create or long-press-quick-event from a day cell (the `PickerDay`
  already carries `date` for a future phase, but it's out here).

## Risks & Notes
- **Lazy paging vs fixed-wide window:** lazy is the right long-term answer but
  adds scroll-position bookkeeping; a ±24-month fixed window is a cheap interim
  that satisfies "past 2 months" with far less risk. Recommend starting with
  the wider fixed window and only going lazy if memory/scroll feel demands it —
  decide during `writing-plans`.
- "Mon to Friday per month" (33) is read as *weekday columns, Monday-first*,
  not "hide the weekend." Confirm with the user if ambiguous; do **not** drop
  Saturday/Sunday data.
