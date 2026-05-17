# Phase 10 — Paper Week Page (Hobonichi-Style)

## Goal
Render the seven-day "Hobonichi" week page: 7 rows each with weekday tag + giant date number + events column + tasks column + week sticky note. Wire week-flip animations (reusing Phase 08's flip system at week granularity).

## Why this is needed
The Day/Week toggle on the top bar must do something. The Week page is the bird's-eye view that complements the Day page.

## Prerequisites
- Phase 02, 03 (`WeekMath`, models), 05 (`BookPage`), 06 (`EventEntryRow` styles for tiny rows), 08 (page-flip system).

## Files Created / Modified

```
WeeklyPlanner/Features/WeekPage/WeekPageView.swift             # NEW — full week layout
WeeklyPlanner/Features/WeekPage/WeekPageHeader.swift           # NEW — "Week N" + range + counts
WeeklyPlanner/Features/WeekPage/WeekDayRow.swift               # NEW — single row per weekday
WeeklyPlanner/Features/WeekPage/WeekEventEntry.swift           # NEW — compact event row inside a WeekDayRow
WeeklyPlanner/Features/WeekPage/WeekTaskEntry.swift            # NEW — compact task chip
WeeklyPlanner/Features/WeekPage/WeekStickyNote.swift           # NEW — bottom-right sticky note
WeeklyPlanner/Features/WeekPage/WeekPageViewModel.swift        # NEW — fetch events + tasks for full week
WeeklyPlannerTests/Features/WeekPageViewModelTests.swift       # NEW
WeeklyPlannerTests/Features/WeekPageSnapshotTests.swift        # NEW
```

## Visual & Interaction Checklist

### Page wrapper
- [ ] `BookPage` from Phase 05. No side tabs in week view (those are only for Day).
- [ ] Content padding `2 18 14 44` (top, trailing, bottom, leading).

### `WeekPageHeader`
- [ ] Padding `14 18 4 44`.
- [ ] Flex row, baseline-aligned, justify-space-between.
- [ ] Left:
  - Title `"Week {weekNumber}"` — handwriting 26pt weight 700, color `ink`, line-height 1.
  - Subtitle `"{range}, {year}"` — Cochin italic 12pt, `ink2`, marginTop 2.
- [ ] Right:
  - Two lines, right-aligned, handwriting 15pt italic, `ink2`, line-height 1.1:
    - `"{N} events"`
    - `"{M} tasks left"` (open tasks only)
- [ ] Below header (`margin: 6 18 0 44`): a 2pt gradient line — `linear-gradient(90deg, ink, ink 60%, transparent)` opacity 0.45.

### `WeekDayRow` (one per day)
- [ ] Flex row, align stretch.
- [ ] Min height 56pt.
- [ ] Border-bottom: 0.5pt `theme.rule` (except for last row).
- [ ] Padding `6pt vertical`.

#### Today highlight
- [ ] If row's day is today:
  - Background: linear gradient(90°, `rgba(255,230,128,0.4)` → `rgba(255,230,128,0)`).
  - Radius 4pt.
  - Margin -4pt horizontal (extends slightly beyond the row's edges).
  - Padding 4pt added back horizontally.

#### Left column (52pt wide)
- [ ] Weekday short label uppercase (e.g., `"MON"`) — system 9pt weight 700, letter-spacing 1.4, color `redInk` if today else `ink2`.
- [ ] Date number — handwriting 28pt weight 700, line-height 0.9, color `redInk` if today else `ink`, marginTop 1.

#### Right column (flex 1)
- [ ] If no events and no tasks: handwriting 16pt italic em-dash `"—"` in `ink3`.
- [ ] Otherwise stack of `WeekEventEntry` + `WeekTaskEntry`.

### `WeekEventEntry`
- [ ] Compact one-line event display.
- [ ] Cursor pointer (tap → open event sheet, Phase 11).
- [ ] Layout: flex row baseline-aligned, gap 5, margin-bottom 1.
- [ ] **Time** (36pt fixed-width): Cochin 10pt, color `ink2`, tabular nums. Formatted without space (e.g., `"9AM"`, `"1:30PM"`).
- [ ] **Title** (flex 1, ellipsis): handwriting 15pt, color = category ink, single-line, ellipsis. Includes inline `GmailGlyph(size: 8)` after title if `source == .gmail`.
- [ ] **Trailing dot**: 6×6 category dot at 0.75 opacity.

### `WeekTaskEntry`
- [ ] Tappable row to toggle done.
- [ ] Layout: flex row align center, gap 6, marginTop 1.
- [ ] Checkbox 11×11, border 1.3pt `ink`, fill white, with check svg if done (blueInk).
- [ ] Title: handwriting 14pt, ellipsis, color `ink2` (or `ink3` if done with strikethrough redInk).
- [ ] Priority bang `"!"` if high + open.

### `WeekStickyNote`
- [ ] Absolute positioned `bottom: 14, trailing: 14`.
- [ ] 120pt wide. Padding `9 10 11`. Background `#FFE680` (default yellow). Tilt `-3°`.
- [ ] Shadow `0 3 8 rgba(0,0,0,0.22), 0 1 2 rgba(0,0,0,0.12)`.
- [ ] Masking tape 36×10 (wider variant) at top-center, color `rgba(180,140,70,0.45)`.
- [ ] Eyebrow row (system 8pt weight 700 letter-spacing 1.2 color `rgba(0,0,0,0.4)`, marginBottom 3, flex gap 3):
  - **If current week and inbox > 0**: `GmailGlyph(9)` + `"INBOX"`.
  - **Else**: `Icon.sparkles(9, rgba(0,0,0,0.5))` + `"WEEK · AI"`.
- [ ] Body: handwriting 13pt weight 600, color `#3A2A1A`, line-height 1.18.
- [ ] Content varies by `weekOffset`:
  - `0`: if inbox > 0 → `"{N} new from Gmail — review ↘"`, else `"Busiest Sat night — order Uber."`.
  - `1`: `"NYC trip Fri-Sun. Pack Tue night."`.
  - `2`: `"Memorial Day Mon — quiet week."`.
  - `-1`: `"Concert was the highlight!"`.
  - Otherwise: omitted.
- [ ] Tap → opens AI overlay pre-seeded with `"Summarize this week"` (Phase 12 wires this).

### Page-flip in Week view
- [ ] `PageFlipController.flipWeek(direction:)` triggers the same 3D flip, but the leaf shows a `WeekPageView` of the outgoing week on the front and the incoming week on the back.
- [ ] Swipe gesture in Week view triggers `flipWeek`.

## Logic & Data Checklist

### `WeekPageViewModel`
- [ ] Inputs: `weekOffset: Int`.
- [ ] Outputs:
  - `days: [WeekDay]` (always 7).
  - `eventsByDay: [Int: [Event]]` — per weekdayIdx.
  - `tasksByDay: [Int: [TaskItem]]`.
  - `eventCount`, `openTaskCount` (for header).
  - `inboxCount` (for sticky text).
- [ ] Refreshes when stores emit.

### Wiring
- [ ] The Day/Week toggle in `BookTopBar` (Phase 09) flips between `DayPageView` and `WeekPageView`. No animation between the two; instant swap by re-binding the page view (the flip system is for next/prev navigation within the chosen mode).
- [ ] Both views share the `BookCover` + `BookTopBar` + `BookBottomControls`. Only the inside-the-book content swaps.

## Tests (TDD)

`WeekPageViewModelTests`
- [ ] `testEventsGroupedByDayIndexForWeekZero()` — verify Saturday has 3 events from seed.
- [ ] `testTaskCountExcludesDone()`.
- [ ] `testInboxCountForCurrentWeek()`.

`WeekPageSnapshotTests`
- [ ] Snapshot of week 0 — multi-event rows, today highlight on Saturday row, sticky note shows `"Busiest Sat night — order Uber."` (no pending inbox in seed) or `"3 new from Gmail — review ↘"` if seed has inbox.
- [ ] Snapshot of week +1 — NYC sticky note, empty days visible.
- [ ] Snapshot in midnight theme.

## Acceptance Criteria
- Week page shows 7 rows correctly populated from seed and EventKit.
- Today row is highlighted with the yellow gradient.
- Event titles ellipsize when long; time + dot remain visible.
- Tap on an event opens the event sheet (Phase 11).
- Sticky text matches the week-offset map.

## Out of Scope
- Tasks-only "Reminders" screen (not in spec; Tasks live in Day view + Week view rows).
- Direct editing from week view (tap opens detail).
- Inline event creation.

## Risks & Notes
- **52pt left column width** is the minimum to fit `"WED"` + a 28pt date number. Verify with longest weekday short.
- **Title ellipsis with mixed handwriting fonts**: `Text(...).lineLimit(1).truncationMode(.tail)` works for Caveat; Indie Flower has wider glyphs — test "Sara's birthday" (long) fits on the row.
- **The yellow today-row background must NOT extend under the left column**'s date number; otherwise contrast drops. Verify by visual diff.
