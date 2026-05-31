# Phase 30 — Week Page Polish

> **Milestone L (v1.1 Polish).** Post-submission. Covers `docs/suggestions.md`
> lines 25, 26, 27, 28, 29, 30 (Weekly view).

## Goal
Make the Hobonichi week spread events-first and less cluttered: drop the
header counts and week label, enlarge the dates, hide the per-day checklist,
soften the empty state, and use horizontal space when a day is event-heavy.

## Why this is needed
Testers found the week page noisy and cramped: redundant "Week NN" and count
lines compete with the dates, the checklist adds weight users didn't want at
the week scale, and busy days run out of room. These tweaks refocus the spread
on events at a glance.

## Prerequisites
- Phase 10 (Week page), Phase 21 (accessibility labels on week rows). *(Shipped.)*

## Files Created / Modified

```
WeeklyPlanner/Features/WeekPage/WeekPageHeader.swift   # MODIFY — remove rightColumn counts (29); drop "Week NN", enlarge date range (30)
WeeklyPlanner/Features/WeekPage/WeekDayRow.swift        # MODIFY — events-only option (26); side/overflow layout (25); empty "none" copy (28); larger day numerals (30)
WeeklyPlanner/Features/WeekPage/WeekEventEntry.swift    # REVIEW — compact event rendering for side/overflow (25)
WeeklyPlanner/Features/WeekPage/WeekTaskEntry.swift     # REVIEW — gated out when checklist hidden (26)
WeeklyPlanner/Features/WeekPage/WeekPageView.swift      # REVIEW — remove bottom date (27)
WeeklyPlanner/Features/WeekPage/WeekPageViewModel.swift # REVIEW — counts no longer surfaced to the header (29)
WeeklyPlannerTests/WeekPage/WeekPageHeaderTests.swift   # MODIFY — no counts, no "Week" string
WeeklyPlannerTests/WeekPage/WeekDayRowTests.swift       # NEW/MODIFY — events-only + "none" empty copy
```

## Visual & Interaction Checklist
- [ ] **(29)** The top-right `"N events"` / `"M tasks left"` lines
      (`WeekPageHeader.rightColumn`) are removed.
- [ ] **(30)** `"Week NN"` (`leftColumn`) is removed; the date range is the
      primary, enlarged title. Day numerals in each row are bigger.
- [ ] **(26)** Per-day rows show events only by default; the checklist/tasks
      block is hidden on the week spread (still available on the Day page).
- [ ] **(25)** A day with many events uses the horizontal space (side column /
      second column / overflow indicator) instead of clipping or unbounded
      vertical growth.
- [ ] **(28)** Empty days read **"none"** rather than a bare "—".
- [ ] **(27)** The date at the bottom of the week page is removed.
- [ ] Today's row keeps its warm-yellow fade and red-ink left column.

## Logic & Data Checklist
- [ ] Hiding the checklist is presentation-only — task data and the Day page's
      task block are untouched.
- [ ] The header no longer reads `eventCount` / `openTaskCount`; if nothing
      else consumes them, prune the now-dead view-model plumbing.
- [ ] Overflow/side layout has a defined rule (e.g., show first N then
      "+K more") — chosen against the mock, not improvised per render.
- [ ] Accessibility labels on week rows updated to match the new content
      (no stale "N events"/"tasks left" in combined labels).

## Tests (TDD)
- [ ] `WeekPageHeaderTests` — asserts no "Week" substring and no count lines.
- [ ] `WeekDayRowTests` — empty day renders "none"; a task-bearing day renders
      no task rows when checklist is hidden; an event-heavy day caps rows and
      shows the overflow affordance.
- [ ] Phase 21 week-page accessibility audit still passes.

## Acceptance Criteria
- Week spread is events-first with the six tweaks visible.
- No task-data regressions; full suite green.
- Screenshot diff vs. `docs/mock/paper-planner.jsx` week spread approved.

## Out of Scope
- Day page polish (Phase 29) and Month grid (Phase 31).
- New week-level capabilities (e.g., drag to reschedule).
- Removing tasks from the data model — they remain on the Day page.

## Risks & Notes
- **(25) and (26) interact:** hiding the checklist frees vertical room, which
  changes how many events fit before overflow. Decide the events-only layout
  and the overflow rule together.
- Confirm with the user whether "events only" is the permanent week default or
  a Preferences toggle. Default: permanent week-page default (Day page still
  shows tasks). Revisit if feedback wants it configurable.
