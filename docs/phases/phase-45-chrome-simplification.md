# Phase 45 — Chrome & Navigation Simplification

> **Milestone P — Feedback Round 2** · items #57, #74, #75, #76
> Triage: `docs/superpowers/specs/2026-07-07-feedback-round-2-roadmap-design.md`
> Implementation plan: `docs/superpowers/plans/2026-07-07-phase-45-chrome-simplification.md`

## Goal

The Review tab is removed entirely; empty week-page days show nothing
instead of "none"; the week-picker's duplicated month/year header is
deduplicated; and getting free text onto the day page is fast (no 450 ms
hold).

## Prerequisites

- None hard. Recommended **first** in Milestone P (smallest phase; deleting
  Review before Phase 44's typography sweep removes one surface).

## Decisions (from triage)

- **#74:** Review feature code is **deleted**, not flag-hidden (decision 8).
  Git history preserves it. The orphaned `Streak` model is deleted with it
  (it was never populated).
- **#75:** reverses round-1 item #28 ("—" → "none"); blank wins — noted so
  it isn't "fixed" back.
- **#76:** of the two stacked "July 2026" labels in the week picker, the
  **per-month section header is removed** and the sticky nav-bar title
  (which tracks scrolling and sits beside the steppers) stays.
- **#57:** long-press-to-create drops 0.45 s → 0.2 s and the editor focuses
  immediately; tap stays reserved for edit/commit (a bare tap creating
  notes would misfire constantly).

## Files

- Modify: `WeeklyPlanner/Navigation/TabSelection.swift` (drop `.review`;
  unknown-raw fallback), `PaperTab.swift` (icon/label/preview),
  `AppShell.swift` (routing case)
- Delete: `WeeklyPlanner/Features/Review/` (8 files),
  `WeeklyPlanner/Models/Streak.swift`,
  `WeeklyPlannerTests/Features/Review/ReviewViewModelTests.swift`
- Modify: `WeeklyPlanner/Stores/SwiftDataStack.swift` (unregister `Streak`),
  `WeeklyPlanner/DesignSystem/Typography.swift` (drop `reviewTitle`/`reviewPercent`)
- Modify: `WeeklyPlanner/Features/WeekPage/WeekDayRow.swift` (blank empty days)
- Modify: `WeeklyPlanner/Features/WeekPicker/MonthGridView.swift` (drop header)
- Modify: `WeeklyPlanner/Features/DayPage/DayPageView.swift` (0.2 s create),
  `Annotations/AnnotationView.swift` (if focus tuning needed)
- Tests: `TabSelectionTests`/`TabSelectionNotesTests`, `WeekDayRowTests`,
  `MonthGridViewTests`, `TypographyTests`, `AccessibilityAuditUITests`
  (delete review case), `AnnotationsUITests` (timing).

## Visual & Interaction Checklist

- [ ] Tab bar shows exactly **Calendar · Notes · Settings** (#74).
- [ ] A week-page day with no entries shows blank space — no "none", row
  height unchanged (#75).
- [ ] Week picker shows the month/year **once** (nav bar); scrolling months
  still updates it; no per-month title above each grid (#76).
- [ ] Pressing on empty day-page paper creates a free-text note noticeably
  faster (0.2 s), keyboard up immediately; existing notes still tap-to-edit
  and drag-to-move exactly as before (#57).

## Logic & Data Checklist

- [ ] `UserSettings.lastTabRaw == "review"` (persisted from an old build)
  falls back to `.calendar` without crashing.
- [ ] `Streak` removed from the SwiftData schema (was always empty — no
  data-loss migration needed; verify a store with an existing Streak table
  still opens).
- [ ] No dangling references: `PaperReviewView`, `ReviewViewModel`,
  `Streak`, `reviewTitle`, `reviewPercent`, `tabbar.tab.review` all grep to
  zero in `WeeklyPlanner/`.

## Tests (TDD)

Updated: `TabSelectionNotesTests` (allCases = 3), `TabSelectionTests`
(persist a non-review tab + legacy-raw fallback test), `WeekDayRowTests`
(blank instead of "none"), `MonthGridViewTests` (header gone),
`TypographyTests` (review tokens gone), `AnnotationsUITests` (create still
works at the shorter press).
New: none beyond the fallback test — this phase deletes more than it adds.

## Acceptance Criteria

- Checklists pass; full unit suite green; `SmokeUITests`,
  `AnnotationsUITests`, `AccessibilityAuditUITests` (minus deleted case),
  week-picker UI suites green.
- Grep proof of zero review references.

## Out of Scope

- Any replacement for Review's stats (if users miss it, that's a future
  phase; Ask-the-Planner's summarizeWeek tool still exists).
- `WeekSummary`/`WeekSummaryGenerator` — shared with the Intelligence layer;
  they stay.
- Tap-to-create annotations (deliberately rejected — misfire risk).

## Risks & Notes

- `Tab` raw values persist in `UserSettings.lastTabRaw` — the fallback path
  is the one real bug risk; it gets a dedicated unit test.
- Removing a `@Model` (`Streak`) from the schema: SwiftData tolerates
  unknown legacy tables, but verify on a simulator carrying pre-phase data
  (the store must open and other models must load).
- Phase 44 touches the same `PaperSettingsView`/paper stack — if 44 lands
  first, its `PaperBackground` sweep will have included `PaperReviewView`;
  deleting Review afterward is still trivial. Preferred order stays 45 → 44.
