# Phase 09 — Top Bar & Week Picker

## Goal
Implement the leather-chrome top bar (week eyebrow, date-range pill, week chevrons, Apple Intelligence button, Day/Week segmented toggle, Today pill) **and** the drop-down week picker (5-month mini grid with red-circle today marker and blue-tint selected week).

## Why this is needed
This is the primary global navigation. Until now Phase 06–08 has been one isolated day. This phase ties everything together: week stepping, view switching, jump-to-today, week picking, AI access.

## Prerequisites
- Phases 02, 03 (`WeekMath`), 05 (`PaperPillButton`), 08 (`PageFlipController`).

## Files Created / Modified

```
WeeklyPlanner/Features/DayPage/BookTopBar.swift                # NEW — leather chrome top bar
WeeklyPlanner/Features/DayPage/BookBottomControls.swift        # NEW — "Last/Next day" + swipe hint
WeeklyPlanner/Features/DayPage/DayWeekToggle.swift             # NEW — segmented Day | Week
WeeklyPlanner/Features/DayPage/TodayPill.swift                 # NEW — chrome-style Today button
WeeklyPlanner/Features/DayPage/WeekChevrons.swift              # NEW — pair of small ‹ › buttons
WeeklyPlanner/Features/DayPage/DateRangePill.swift             # NEW — dashed-underline date range
WeeklyPlanner/Features/DayPage/AIButton.swift                  # NEW — 34×34 sparkles button (top-right)
WeeklyPlanner/Features/WeekPicker/WeekPickerSheet.swift        # NEW — drop-down sheet
WeeklyPlanner/Features/WeekPicker/MonthGridView.swift          # NEW — month section
WeeklyPlanner/Features/WeekPicker/WeekRowView.swift            # NEW — row with W## + 7 day cells
WeeklyPlanner/Features/WeekPicker/WeekPickerViewModel.swift    # NEW — month math + scroll-to-selected
WeeklyPlannerTests/Features/BookTopBarTests.swift              # NEW
WeeklyPlannerTests/Features/WeekPickerViewModelTests.swift     # NEW
WeeklyPlannerTests/Features/WeekPickerSnapshotTests.swift      # NEW
```

## Visual & Interaction Checklist

### `BookTopBar`
- [ ] Outer padding `54pt top, 16pt trailing, 8pt bottom, 26pt leading` (matches mock).
- [ ] Color: `theme.chromeText` (`#E8D9B7` in Cream).
- [ ] Two rows:

**Row 1** (baseline-aligned flex row, justify-space-between):
- [ ] Left cluster:
  - Eyebrow `"THE PLANNER · WEEK {n}"` — system 10pt weight 700, letter-spacing 1.6, opacity 0.65, uppercase.
  - Below it (`marginTop: -1`):
    - `WeekChevrons` left (`‹`) — 22×22 button, opacity 0.7.
    - `DateRangePill` (e.g., `"May 11 – 17"`).
    - `WeekChevrons` right (`›`).
- [ ] Right cluster:
  - `AIButton` — 34×34 rounded 999, 1pt translucent border (`rgba(255,255,255,0.12)`), bg `rgba(255,255,255,0.06)`, sparkles icon 16pt in `accent` color, marginLeading 8pt.

**Row 2** (marginTop 6pt, flex row gap 6pt):
- [ ] `DayWeekToggle` — 62×24, rounded 7, padding 2pt, gap 2pt, border `0.5pt rgba(255,255,255,0.08)`, bg `rgba(0,0,0,0.3)`.
  - Each segment: padding `3 12`, rounded 5pt. Active: bg `theme.chromeText`, text `theme.bookSpine` (or `#1A1410`). Inactive: bg transparent, text `theme.chromeText`. Font system 11pt weight 600.
- [ ] `TodayPill` — appears only when `weekOffset != 0`. 0.5pt border `chromeMuted`, bg `rgba(255,255,255,0.06)`, color `chromeText`, padding `3 9`, system 11pt weight 500, rounded 5pt.

### `WeekChevrons` (single chevron variant — used as two instances)
- [ ] 22×22 button, opacity 0.7, transparent bg.
- [ ] SVG path: `chevL`/`chevR` (14pt) in `chromeText`.
- [ ] Behavior:
  - In Day view: shifts `weekOffset` by ±1 **without** triggering the page-flip animation (instant set, focusedDay unchanged).
  - In Week view: triggers a week-page flip via `PageFlipController.flipWeek(direction:)`.

### `DateRangePill`
- [ ] Button. No background. Padding `2 4`. Border radius 4pt.
- [ ] Label content (baseline-aligned flex, gap 4):
  - Handwriting 22pt, weight 400, color `#FAF6E9` (always cream — not theme-dependent for the title!).
  - Text shadow `0 1 2 rgba(0,0,0,0.4)`.
  - Bottom border: 0.5pt dashed `rgba(250,246,233,0.35)`.
  - Padding-bottom 1pt to attach the dashed line.
- [ ] Trailing 9×9 SVG chevron (down) at opacity 0.55, stroke `chromeText`.
- [ ] Tap → opens `WeekPickerSheet`.
- [ ] When the picker is open: chevron rotates 180° animated 0.18s.

### `AIButton`
- [ ] 34×34, rounded 999, border 1pt `chromeMuted`, bg `rgba(255,255,255,0.06)`, sparkles 16pt in `accent`.
- [ ] Tap → opens `PaperAISearch` overlay (Phase 12 implements the overlay; this button just sets a Boolean state).

### `BookBottomControls`
- [ ] Padding `8pt 26pt 14pt`. Flex row justify-space-between.
- [ ] Left button: chevL 15pt + label `"Last day"` (or `"Last week"` if Week view). System 12pt weight 500, color `chromeText`.
- [ ] Center hint: `"swipe ‹ ›"` — system 10pt, opacity 0.4, letter-spacing 1, uppercase.
- [ ] Right button: label `"Next day"`/`"Next week"` + chevR.
- [ ] Tap behavior calls `PageFlipController.flipDay(.next/.prev)` (or `.flipWeek` in Week view).

### `WeekPickerSheet`
- [ ] Overlay over the BookCover (z=50). Backdrop (z=40): `rgba(15,10,6,0.55)` with `backdrop-filter: blur(2px)`.
- [ ] Sheet rect: `leading: 12, trailing: 12, top: 100, bottom: 16`.
- [ ] Background: linear gradient (160°, `#FCF9EE` → `#F1EAD2`).
- [ ] Border radius 12.
- [ ] Shadow: `0 16 40 rgba(0,0,0,0.55), 0 2 6 rgba(0,0,0,0.25)`.
- [ ] Animation: opacity backdrop 0.2s fade; sheet `pickerDrop` 0.32s translateY(-14) opacity 0 → translateY(0) opacity 1.

**Header** (padding `14 16 10`, flex row, border-bottom 0.5pt `theme.rule`, gap 10):
- [ ] Left: eyebrow `"JUMP TO WEEK"` (system 9pt weight 700 letter-spacing 1.6 uppercase color `ink2`), title `"Pick a date"` (handwriting 22pt color `ink`).
- [ ] Right: two `PaperPillButton`s:
  - `"Today"` (primary, blueInk) — taps `onPick(0)`.
  - `"Close"` (secondary).

**Day-of-week column header** (sticky, padding `8 14 6`, grid `28pt + 7 equal`):
- [ ] Empty 28pt column (will align with W## label).
- [ ] 7 letters `"M T W T F S S"` — center-aligned, system 10pt weight 700, letter-spacing 1, color `ink3`.
- [ ] Background `rgba(250,246,233,0.85)` (cream-ish) with bottom border 0.5pt `ruleSoft`.

**Scroll body**:
- [ ] Padding `8 14 14`.
- [ ] For each of 5 months (focusYear/focusMonth ± 2):
  - Month header: handwriting 18pt weight 700, `ink`, padding `4 2 4`, with a 0.5pt rule that extends to the right of the title.
  - Week rows (`WeekRowView` below).

**`WeekRowView`** (button, grid `28pt + 7 equal`, gap 3, padding `3pt vertical`):
- [ ] Width 100%, border 0, cursor pointer, text-align left.
- [ ] Selected row: background `rgba(26,58,122,0.12)`, radius 4pt.
- [ ] **W## label** (28pt): system 9pt weight 700, color `blueInk` if selected else `ink3`, center, align-self center. Text `"W{20 + offset}"`.
- [ ] **7 day cells**: each text-aligned center, padding `5pt vertical`, position relative.
  - If `isToday`: red filled circle 24pt, color `redInk`, behind the day number (Z-stacked).
  - Day number: handwriting 17pt, weight 500 (or 700 if today), color `#FFFFFF` if today, else `ink` if in-month, else `ink3` if out-of-month.
- [ ] If row contains today but isn't selected: 3pt-wide red vertical bar on the leading edge (`leading: 2, top: 50%, height: 28, radius 2, color: redInk, opacity 0.7`).
- [ ] Tap: `onPick(offset)`.

**Footer**:
- [ ] Centered italic handwriting 13pt color `ink3`: `"Tap any week to flip there."`.

### Auto-scroll behavior
- [ ] On open, scroll the selected week into view, offset 80pt from top of scroll view (so it sits below the day-of-week header).

## Logic & Data Checklist

### `BookTopBar` state
- [ ] Reads `weekOffset`, `meta` (range + week number) from `PageFlipController` / `WeekMath`.
- [ ] `paperView` (Day | Week) from `SettingsStore.paperView` (or a local `@State` initialized from settings — Phase 25 will fully wire).
- [ ] Has callbacks: `onOpenAI()`, `onOpenPicker()`, `onJumpToday()`, `onPrevWeek()`, `onNextWeek()`, `onChangePaperView(_:)`.

### Chevron behavior split
- [ ] In Day view: chevrons set week offset directly (no flip animation).
- [ ] In Week view: chevrons call `PageFlipController.flipWeek(direction:)` which uses the same 3D flip animation at week granularity.

### `WeekPickerViewModel`
- [ ] `focusMonthDate(for weekOffset:) -> Date` — Monday of week 0 + `7*offset`.
- [ ] `months(around focusDate:) -> [Month]` — focusMonth ± 2.
- [ ] `weeks(in year:month:) -> [Week]` — returns all weeks that contain at least one day in this month (handles leading/trailing days of adjacent months); each week carries `offset` relative to base.
- [ ] `sameDay(_ a: Date, _ b: Date) -> Bool`.

### Today pill
- [ ] Visible only when `weekOffset != 0 || focusedDay != todayWeekday`.
- [ ] Tap: `weekOffset = 0`, `focusedDay = WeekMath.todayIndex`. No animation (instant jump).

## Tests (TDD)

`BookTopBarTests`
- [ ] `testEyebrowFormatsWeekNumber()`.
- [ ] `testTodayPillHiddenOnCurrentWeekTodayDay()`.
- [ ] `testTodayPillVisibleAfterFlipping()`.
- [ ] `testDayWeekToggleSwitchesActiveSegment()`.
- [ ] `testChevronAdvancesWeekOffset()`.

`WeekPickerViewModelTests`
- [ ] `testFiveMonthsCenteredOnFocus()`.
- [ ] `testWeeksInMonthMay2026Contains6Or5Weeks()` — verify against calendar.
- [ ] `testWeekOffsetMappingForMay11_2026_IsZero()`.
- [ ] `testTodayDetectedOnMay16_2026()`.

`WeekPickerSnapshotTests`
- [ ] Snapshot with week 0 selected.
- [ ] Snapshot with week +2 selected (different scroll position).
- [ ] Snapshot in midnight theme.

## Acceptance Criteria
- Side-by-side with the mock, the top bar pixel-matches in all three themes.
- Week chevrons step through weeks correctly with the right animation (instant in Day, flip in Week).
- Picker opens with smooth 0.32s drop animation; selected week auto-scrolls into view.
- Today pill appears/disappears at correct moments.

## Out of Scope
- AI overlay content (Phase 12).
- Week-page rendering (Phase 10).
- Settings sheet (Phase 16).

## Risks & Notes
- **The DateRangePill's color is `#FAF6E9` regardless of theme** because it sits over the dark leather. Don't accidentally swap to `theme.cream` (which is dark in Midnight).
- **DayWeekToggle's inactive text** must be `theme.chromeText`, not `ink`.
- **WeekPicker's "today" red circle** must be drawn behind the day number, not as a background on the cell — otherwise the rotation effect of selecting today is off.
- **Scroll-to-selected** in the picker requires `ScrollViewReader` and a stable ID (`weekOffset`). Auto-anchor only on appear, not on every state change.
