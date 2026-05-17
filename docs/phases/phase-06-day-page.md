# Phase 06 — Paper Day Page (Static Layout + Events + Inbox)

## Goal
Render the Day page exactly as in `paper-planner.jsx` — header (weekday + giant rotated date number + Today chip), events list (time gutter + handwritten title + location + category dot + Gmail glyph), and the from-inbox suggestions block. Static for now: no flip, no tabs, no sticky note, no to-do block (those come in 07–08).

## Why this is needed
This is the most viewed screen. Pixel parity here defines the whole product feel.

## Prerequisites
- Phases 02 (typography, theme), 03 (Event model, week math), 04 (real EventKit-backed `EventStore`), 05 (primitives).

## Files Created / Modified

```
WeeklyPlanner/Features/DayPage/DayPageView.swift             # NEW — the visible page
WeeklyPlanner/Features/DayPage/DayPageHeader.swift           # NEW — weekday + giant date + Today chip
WeeklyPlanner/Features/DayPage/EventEntryRow.swift           # NEW — time gutter + title + dot + Gmail glyph
WeeklyPlanner/Features/DayPage/EventEntryList.swift          # NEW — vertical list of events for the day
WeeklyPlanner/Features/DayPage/InboxSuggestionRow.swift      # NEW — italic gmail-found event
WeeklyPlanner/Features/DayPage/InboxBlock.swift              # NEW — "FROM INBOX" section beneath events
WeeklyPlanner/Features/DayPage/EmptyDayState.swift           # NEW — "Nothing scheduled. A free page." string
WeeklyPlanner/Features/DayPage/DayPageViewModel.swift        # NEW — load + observe events/inbox for (weekOffset, dayIdx)
WeeklyPlanner/Features/DayPage/GmailGlyph.swift              # NEW — small multi-fill SVG path → SwiftUI
WeeklyPlanner/Features/DayPage/TodayChip.swift               # NEW — dashed-border red pill
WeeklyPlannerTests/DayPage/DayPageViewModelTests.swift       # NEW
WeeklyPlannerTests/DayPage/EventEntryRowTests.swift          # NEW (logic-level)
WeeklyPlannerTests/DayPage/DayPageSnapshotTests.swift        # NEW (snapshot all three themes, two days)
```

## Visual & Interaction Checklist

### Page wrapper
- [ ] Uses `BookPage` from Phase 05 (so the paper, holes, margin, ruled lines, edge stripes are present).
- [ ] Content area padding: `top: 18, leading: 44, trailing: 18, bottom: 18` — leading 44 to clear the red margin.
- [ ] Font color defaults to `theme.ink`. Body font `"Cochin", "Georgia", serif`.

### `DayPageHeader`
- [ ] Two-column flex row, baseline-aligned.
- [ ] **Left column**:
  - Line 1: weekday name (e.g., `"Saturday"`). Handwriting font, 30pt, weight 700, line height 1.0, letter-spacing -0.5.
  - Line 2: `"{date} {monthShort} · Week {weekNumber}"` — Cochin italic 12pt, color `theme.ink2`, margin-top 2pt.
- [ ] **Right column** (`flex-shrink: 0`):
  - Giant date number (e.g., `"16"`) — handwriting font, 62pt, weight 700, line-height 0.85, letter-spacing -2.
  - Color: if today → `theme.redInk`; else → `theme.ink`.
  - Opacity 0.85.
  - Rotation -3° via `.rotationEffect(.degrees(-3))`.
- [ ] If today's page: render `TodayChip` underneath the header row.

### `TodayChip`
- [ ] Inline-flex pill, dashed 0.5pt border in `theme.redInk`. Background `rgba(156,42,42,0.1)` (i.e., `redInk` 10% alpha).
- [ ] Padding `2 × 9`. Border radius 3pt.
- [ ] Content: 5×5 red dot + uppercase text `"TODAY · 2:12 PM"` (replace `2:12 PM` with real `Date.now` formatted `h:mm a` lowercased pm → `"PM"`).
- [ ] Text: system 10pt, weight 700, letter-spacing 1.0, color `redInk`.
- [ ] Updates every minute via `TimelineView(.everyMinute)` so the time stays current while page is visible.
- [ ] Only present when the page being shown is **today** (today = current week + `weekdayIndex == today's weekday`).

### `EventEntryRow`
- [ ] Two-column flex row, baseline-aligned, padding `5pt vertical, 0 horizontal`.
- [ ] **Time gutter** (width 48pt, `flex-shrink: 0`):
  - Cochin font 13pt, weight 600, color `theme.ink2`.
  - Tabular numerals (`Font.feature(.tabularNumbers)`).
  - Formatted from `event.start`: `"9 AM"`, `"1:30 PM"`, `"7:30 PM"`. No leading zero on the hour. Minutes shown only if non-zero.
- [ ] **Title** (handwriting font, 21pt, weight 600, line-height 1.1, letter-spacing 0.1):
  - Color = `Category.inkColor(in: theme)` (per category mapping in Phase 02).
  - Followed by 9×9 category dot (`Circle().fill(category.dot)` opacity 0.7, marginLeft 6, vertical-align middle).
  - If `event.source == .gmail`, render `GmailGlyph(size: 10)` after the dot.
- [ ] **Location subtitle** (only if `event.location != nil`):
  - Below the title row.
  - Paragraph indent `paddingLeading: 56` (aligns under the title, not the time).
  - Cochin italic 12pt, color `theme.ink2`.
  - Prefix `"↳ "` (U+21B3 + space).
  - `marginTop: -2` — overlap slightly with the title row baseline (matches mock).
- [ ] Whole row is a button → `onTapEvent(event.id)` (handled in Phase 11 wiring).

### `EventEntryList`
- [ ] Vertical stack of `EventEntryRow`s, sorted ascending by `event.start`.
- [ ] Spacing 0 (rows have intrinsic 5pt padding).
- [ ] Wrapped in a `LazyVStack` for performance.

### `InboxBlock`
- [ ] Appears when `inbox.count > 0`.
- [ ] Padded above: `marginTop 6, paddingTop 6, borderTop 0.5pt dashed theme.ink3`.
- [ ] Eyebrow row (system 8pt, weight 700, letter-spacing 1.4, color `theme.ink3`, `marginBottom 4`):
  - `GmailGlyph(size: 9)` + space + `"FROM INBOX"`.
- [ ] Followed by a vertical stack of `InboxSuggestionRow`s.

### `InboxSuggestionRow`
- [ ] Row at 0.78 opacity (italicized look).
- [ ] Time gutter — width 48, Cochin 12pt weight 600, color `theme.ink3`.
- [ ] Title block:
  - Handwriting 17pt italic, color `theme.ink2`, line-height 1.1.
  - 7×7 category dot suffix at 0.5 opacity.
  - "via {fromName}" subtitle in Cochin 10pt italic, color `theme.ink3`, marginTop 1.
- [ ] Two action buttons (right-aligned, paddingTop 2, gap 5):
  - **Add to calendar**: 18×18 with 1pt `theme.greenInk` border. Inside: small `+` icon (10×10) stroked in green.
  - **Dismiss**: 18×18 with 1pt `theme.ink3` border. Inside: small `×` icon (9×9) stroked.
- [ ] Tap actions: Add → calls `InboxStore.accept(id:)` → creates an `Event` from the suggestion. Dismiss → `InboxStore.dismiss(id:)`. Animations: row fades + collapses with `Animation.smooth(duration: 0.25)`.

### `EmptyDayState`
- [ ] Shown when no events AND no inbox suggestions.
- [ ] Handwriting font 20pt, italic, color `theme.ink3`, marginTop 20pt.
- [ ] Text: `"Nothing scheduled. A free page."`.

### `GmailGlyph`
- [ ] Custom SwiftUI `Shape`s replicating the multi-color "M" glyph from `paper-planner.jsx` `GmailIcon`.
- [ ] Composed of 6 sub-paths in their respective colors: white envelope back, red sides, accent fills.
- [ ] Sizes used: 9, 10, 11, 16.

## Logic & Data Checklist

### `DayPageViewModel` (`@Observable` or `ObservableObject`)
- [ ] Inputs: `weekOffset: Int`, `dayIdx: Int`.
- [ ] Pulls events via `EventStore.observe(weekOffset:).filter { event.weekdayIndex == dayIdx }`.
- [ ] Pulls inbox via `InboxStore.pending(weekOffset:).filter { suggestion.weekdayIndex == dayIdx }`.
- [ ] Exposes `events: [Event]` (sorted by start), `inbox: [InboxSuggestion]`.
- [ ] Exposes `isToday: Bool` derived from `WeekMath.todayIndex`.
- [ ] Refreshes when `EventStore` emits.
- [ ] Provides `accept(suggestionID:)`, `dismiss(suggestionID:)`.

### Plumbing
- [ ] `EventStore`, `InboxStore`, `SettingsStore` injected via `@Environment`.
- [ ] Layout values come from `Spacing` (Phase 02).
- [ ] No magic numbers in views — everything from `Spacing` or `Typography`.

### Empty/error states
- [ ] If `EventKit` permission is denied: show the events list anyway from local SwiftData (might be empty in production builds). Settings will surface the permission warning (Phase 17).
- [ ] If the `EventStore` async fetch fails: render `EmptyDayState` with a small "Couldn't load events" subline in `theme.ink3`.

## Tests (TDD)

`DayPageViewModelTests`
- [ ] `testEventsForWeekZeroSaturdayMay16ReturnsThreeEvents()` — Sara's birthday + family brunch + deep work in the seed (verify against `data.jsx` events e15..e19).
- [ ] `testEventsSortedByStart()`.
- [ ] `testIsTodayTrueForCurrentWeekSaturday()`.
- [ ] `testAcceptSuggestionRemovesItFromInbox()`.

`EventEntryRowTests`
- [ ] `testTimeFormatting()` — 9.0 → `"9 AM"`, 13.5 → `"1:30 PM"`, 12.0 → `"12 PM"`, 0.0 → `"12 AM"`, 7.75 → `"7:45 AM"`.
- [ ] `testInkColorForWorkInMidnightTheme()`.

`DayPageSnapshotTests`
- [ ] Snapshot of Saturday May 16 (today) — has Today chip, three events including Sara's birthday + family brunch + deep work.
- [ ] Snapshot of Friday May 15 — events including Pitch deck and Dinner with Mei (both Gmail-sourced).
- [ ] Snapshot of Sunday May 17 (empty? no — it has events from `data.jsx`. Pick Wednesday May 13 or Tuesday's empty day if any).
- [ ] Snapshot under cream + kraft + midnight.

## Acceptance Criteria
- Day page renders all events for the focused day in correct typography, color, layout.
- Today chip shows live time, updates every minute.
- Gmail-sourced events show the multi-color M glyph.
- Inbox suggestions appear under events when present.
- Side-by-side visual diff vs. `docs/mock/Weekly Planner.html` shows no layout discrepancies > 1pt.
- Snapshot tests pass for all three themes.

## Out of Scope
- To-do block (Phase 07).
- AI sticky note (Phase 07).
- Side tabs / page flip (Phase 08).
- Top bar / week nav (Phase 09).
- Event detail sheet on tap (Phase 11).

## Risks & Notes
- **Time gutter width = 48pt** — must fit `"11:45 AM"` without wrapping. Verify with longest event time in seed data.
- **Mixed-case smart fonts**: Caveat handles lowercase well; Architects Daughter has unusual ascenders. Test all 4 fonts before claiming pixel parity.
- **Tabular numerals** matter for the time gutter so events line up vertically. Use `.monospacedDigit()`.
- **Inbox row's icon button hit area** is only 18×18 — bump effective hit area via `.contentShape(Rectangle().inset(by: -8))` to satisfy 44pt minimum.
