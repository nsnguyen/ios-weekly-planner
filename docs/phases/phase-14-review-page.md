# Phase 14 — Paper Review Page

## Goal
Build the end-of-week reflection page — `"Week N · In review"` title, completion-percent (rotated -3°), AI summary in blue ink, dotted-line time-spent bar chart, "Notes from AI" colored star bullets, and a streaks panel with 7-day pill row + emoji.

## Why this is needed
Review is the second tab and the AI's other big surface (after the AI search overlay). It's what turns a calendar into a planner with retrospect.

## Prerequisites
- Phases 02, 03 (`Streak` model, `Event/Task` data), 05 (`BookPage`, `WavyUnderline`), 13 (`WeekSummaryGenerator`).

## Files Created / Modified

```
WeeklyPlanner/Features/Review/PaperReviewView.swift              # NEW — root
WeeklyPlanner/Features/Review/ReviewHeader.swift                 # NEW — title + completion %
WeeklyPlanner/Features/Review/ReviewSummaryBlock.swift           # NEW — AI summary in blue ink
WeeklyPlanner/Features/Review/TimeSpentBarChart.swift            # NEW — dotted lines + per-category bars
WeeklyPlanner/Features/Review/CategoryTimeRow.swift              # NEW — single bar row
WeeklyPlanner/Features/Review/AINotesList.swift                  # NEW — colored ★ bullets
WeeklyPlanner/Features/Review/StreaksBlock.swift                 # NEW — emoji + label + 7-day pills
WeeklyPlanner/Features/Review/ReviewViewModel.swift              # NEW — aggregate stats
WeeklyPlannerTests/Features/ReviewViewModelTests.swift           # NEW
WeeklyPlannerTests/Features/PaperReviewSnapshotTests.swift       # NEW
```

## Visual & Interaction Checklist

### Layout chrome
- [ ] Top: BookCover + chrome bar (padding `54 18 10 26`, color `chromeText`):
  - Left: eyebrow `"THE PLANNER"` (11pt weight 700 letter-spacing 1.6 opacity 0.7 uppercase) + title `"Review"` (handwriting 26pt color `#FAF6E9` textShadow `0 1 2 rgba(0,0,0,0.4)`).
  - Right: AI button (34×34, 1pt translucent border, sparkles 17pt accent) — same component as Phase 09.
- [ ] Inside: `BookPage` (Phase 05) with red margin + 3 holes + edge stripes + binding shadow.
- [ ] Scrollable content area: `inset: 0 14 0 44`, padding `14pt top/bottom`.

### `ReviewHeader`
- [ ] Flex row align-flex-start justify-space-between gap 10.
- [ ] Left:
  - Title `"Week {N} · In review"` — handwriting 28pt weight 700 line-height 1 letter-spacing -0.5 color `ink`.
  - Subtitle range — Cochin italic 12pt color `ink2` marginTop 3 — `"11 – 17 May 2026"`.
- [ ] Right:
  - Completion percent — handwriting 48pt weight 700 line-height 0.9 color `ink`, opacity 0.85, rotation -3°, text-align right.
  - Format: `"{round(donePct * 100)}%"`.
- [ ] Divider line below (height 2pt, marginTop 8): `linear-gradient(90deg, ink, ink 50%, transparent)` opacity 0.45.

### `ReviewSummaryBlock`
- [ ] MarginTop 12.
- [ ] Eyebrow `"AI SUMMARY"` (system 9pt weight 700 letter-spacing 1.4 uppercase color `ink3`, with sparkles 10pt prefix), marginBottom 4.
- [ ] Body: handwriting 18pt line-height 1.25 letter-spacing 0.1 color `blueInk`.
- [ ] Content: dynamic — comes from `WeekSummaryGenerator` (Phase 13). Default fallback (used when AI unavailable):  
  `"A balanced week. You wrapped up {done} of {total} tasks, kept Wednesday's run, and still owe Sara her gift."`

### `TimeSpentBarChart`
- [ ] MarginTop 18.
- [ ] Section header `"Time spent"` handwriting 20pt weight 700 color `ink`, **wavy underline** in `rgba(26,26,42,0.25)`, marginBottom 8.
- [ ] `CategoryTimeRow` per category, sorted by hours desc.

### `CategoryTimeRow`
- [ ] Flex row align-center gap 10, padding `4pt vertical`.
- [ ] Left label (width 64): handwriting 16pt color `ink` — category display name.
- [ ] Middle bar track (flex 1, height 14, position relative):
  - Bottom border: 1pt **dotted** in `ink3` (the "graph line").
  - Fill: absolute leading 0, top 1, bottom 1, width = `(hours / maxHours) * 100%`, background `category.dot` opacity 0.55, radius 1pt.
- [ ] Right value: Cochin 12pt color `ink2` tabular-nums width 30 text-align right — `"{hours.1f}h"`.

### `AINotesList`
- [ ] MarginTop 18.
- [ ] Section header `"Notes from AI"` handwriting 20pt weight 700 color `ink` **wavy underline** marginBottom 8.
- [ ] List of bullets (from `WeekSummary.bullets`):
  - Default seed bullets (Phase 13 will populate dynamically):
    1. `"Health is up 40% this week. Keep it."` — ink `greenInk`.
    2. `"Friday afternoon — nothing booked. Block focus."` — ink `redInk`.
    3. `"Sara's gift still on the list. Today!"` — ink `redInk`.
- [ ] Each bullet: flex row gap 8 padding `3pt vertical`, leading `★` handwriting 18pt in bullet's ink color, body handwriting 16pt line-height 1.25 same ink.

### `StreaksBlock`
- [ ] MarginTop 18 paddingBottom 10.
- [ ] Section header `"Streaks"` handwriting 20pt weight 700 **wavy underline** marginBottom 8.
- [ ] Flex row align-center gap 10:
  - Emoji 24pt (e.g., `🏃`).
  - Middle (flex 1):
    - Title handwriting 17pt color `ink` — `"{streakName} · {N} weeks"`.
    - Pill row marginTop 4 flex gap 3:
      - Seven cells; each 1pt flex 1 height 5pt radius 2pt.
      - Background `greenInk` if `last7Days[i]`, else `rgba(0,0,0,0.08)`.
  - Trailing 🔥 18pt.

### Page corner curl
- [ ] 28×28 gradient corner-curl bottom-right.

## Logic & Data Checklist

### `ReviewViewModel`
- [ ] Inputs: `weekOffset: Int` (default 0; can be navigated via top chevrons in future — out of scope v1.0).
- [ ] Aggregates:
  - `timeByCategory: [Category: Double]` — sum of `event.durationHours` for events in week.
  - `maxHours: Double`.
  - `tasksDone`, `tasksTotal`, `completionPercent`.
  - `summary: WeekSummary` — from `WeekSummaryGenerator` (Phase 13) with on-disk cache keyed by `weekOffset`.
  - `streaks: [Streak]` — from `StreakStore`.
- [ ] If summary unavailable (AI off / fetching), display the fallback string above.
- [ ] Refresh trigger: on appear and on `EventStore` change.

### Streak detection
- [ ] v1.0: maintain a single hardcoded `Streak` for "Morning run" (matches mock) tracked by detecting events with category `.health` titled `"Morning run"` recurring weekly. Future: user-defined habits.

### AI button
- [ ] Tap → opens the AI overlay (Phase 12) pre-seeded with the query `"Summarize my week so far"`.

## Tests (TDD)

`ReviewViewModelTests`
- [ ] `testTimeByCategorySumsCorrectly()` — seed week 0, expect health ≈ 2.0h (run + yoga + run again — verify), work ≈ X, etc.
- [ ] `testCompletionPercentMatchesSeed()` — 4 done / 9 total in seed = 44%.
- [ ] `testStreakDetectsMorningRunOver4Weeks()`.

`PaperReviewSnapshotTests`
- [ ] Snapshot week 0 review in cream + kraft + midnight.
- [ ] Snapshot with AI summary unavailable (offline fallback).

## Acceptance Criteria
- The page renders all sections in correct order, fonts, and colors.
- Completion percent matches the data, rotated -3°.
- Time-spent bars are accurate to 0.1h.
- "Notes from AI" bullets honor ink color per insight.
- Streak row reflects real data.
- Tapping AI button opens overlay with seeded query.

## Out of Scope
- Editing past data from this page.
- Switching weeks within Review (v1.0 always shows current week).
- Export/share PDF (defer to v1.1).

## Risks & Notes
- **Dotted lines** in SwiftUI: use `Path.stroke(.init(lineWidth: 1, dash: [2, 2]))`. Verify dot rhythm matches mock at 3× scale.
- **AI summary caching** prevents the page from regenerating on every appear; invalidate cache when events change.
- **Snapshot test fragility**: AI summary text varies. For tests, force the fallback string via a `forceFallback: true` flag.
