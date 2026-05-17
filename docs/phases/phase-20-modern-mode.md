# Phase 20 — Modern Mode (Alternative Stock-iOS Theme)

## Goal
Implement the alternative "modern" theme — stock iOS look (SF Pro, system colors, segmented Day/2-Day/Week, time-grid layout, modern AI overlay, modern event sheet, modern tab bar). Toggleable in a dev-only Tweaks panel (and shipped as an alternative style toggle, OFF by default for v1.0).

## Why this is needed
The mock explicitly defines a Modern fallback. Even if Paper is the primary product, having a clean stock-iOS pivot is a safety net (and useful for users with handwriting-font dislike).

## Prerequisites
- All paper screens (Phases 05–18) so we can mirror them.
- Phase 16 (Settings) to host the toggle.

## Files Created / Modified

```
WeeklyPlanner/Features/ModernMode/ModernTheme.swift                    # NEW — token set
WeeklyPlanner/Features/ModernMode/ModernShell.swift                    # NEW — root navigation
WeeklyPlanner/Features/ModernMode/Calendar/DayStripView.swift          # NEW — 7 day-pills horizontal
WeeklyPlanner/Features/ModernMode/Calendar/ViewToggle.swift            # NEW — Day | 2 Day | Week segmented
WeeklyPlanner/Features/ModernMode/Calendar/TimeGridView.swift          # NEW — hour rows + event blocks
WeeklyPlanner/Features/ModernMode/Calendar/TimeGridEventBlock.swift    # NEW — single event block
WeeklyPlanner/Features/ModernMode/Calendar/NowLineOverlay.swift        # NEW — red current-time line
WeeklyPlanner/Features/ModernMode/Calendar/AgendaWeekView.swift        # NEW — 7-day agenda
WeeklyPlanner/Features/ModernMode/Calendar/DayTaskStrip.swift          # NEW — horizontal task chips
WeeklyPlanner/Features/ModernMode/Calendar/WeekScreen.swift            # NEW — composes Day/2Day/Week
WeeklyPlanner/Features/ModernMode/Calendar/ColumnHeaders.swift         # NEW — for 2-Day view
WeeklyPlanner/Features/ModernMode/Tasks/TasksScreen.swift              # NEW — Reminders-style screen
WeeklyPlanner/Features/ModernMode/Review/ModernReviewScreen.swift      # NEW
WeeklyPlanner/Features/ModernMode/Overlays/ModernAISearchOverlay.swift # NEW
WeeklyPlanner/Features/ModernMode/Overlays/ModernEventSheet.swift      # NEW
WeeklyPlanner/Features/ModernMode/TabBar/ModernTabBar.swift            # NEW — glass tab bar
WeeklyPlanner/Features/Settings/StyleSection.swift                     # NEW — paper | modern style toggle
WeeklyPlannerTests/ModernMode/ModernThemeTests.swift                   # NEW
WeeklyPlannerTests/ModernMode/TimeGridLayoutTests.swift                # NEW
WeeklyPlannerTests/ModernMode/ModernSnapshotTests.swift                # NEW
```

## Visual & Interaction Checklist

All values from `docs/mock/components.jsx`, `screens.jsx`, `review.jsx`, `overlays.jsx`.

### `ModernTheme`
- [ ] Tokens:
  - `bg` = `#000` (dark) / `#F2F2F7` (light)
  - `card` = `#1C1C1E` / `#FFFFFF`
  - `cardElev` = `#2C2C2E` / `#FFFFFF`
  - `text` / `text2` / `text3` (60%/38% opacity)
  - `sep` (separator)
  - `fill1` / `fill2`
  - `accent` (default `#0A84FF`; user can change in Tweaks)
  - `today` = `accent`
- [ ] Dark mode toggle via `@Environment(\.colorScheme)` or explicit setting.

### Modern Calendar header
- [ ] Padding `60 16 4`. Flex row.
- [ ] Left: `‹ {month}` micro-eyebrow (13pt 600 accent uppercase letter-spacing 0.4) + large title `{Month YYYY}` (28pt 700 letter-spacing -0.6).
- [ ] Right: 36×36 round button bg `fill2` containing sparkles 18pt accent; plus 36×36 `+` icon 20pt accent.

### `DayStripView`
- [ ] 7 day-pills horizontally. Each:
  - Weekday abbreviation 12pt 600 letter-spacing 0.3 uppercase, color `text2` (accent if today).
  - 34×34 circle: filled `accent` if focused-and-not-today, or 1.5pt `accent` border if today, else transparent.
  - Day number inside, 18pt 600.

### `ViewToggle`
- [ ] Segmented Day | 2 Day | Week.
- [ ] Bg `fill2`, radius 9, padding 2, grid 1fr 1fr 1fr gap 2.
- [ ] Active: bg `card`, shadow `0 2 6 rgba(0,0,0,0.08)`, radius 7. Text 13pt 600 `text`.

### `TimeGridView`
- [ ] Hours 7 AM through 9 PM (Array `[7..21]`).
- [ ] Row height 64pt.
- [ ] Left gutter 54pt wide; hour labels 11pt 500 color `text3`, transform translateY -7.
- [ ] Hour row separator 1pt color `sep`.
- [ ] `TimeGridEventBlock`:
  - Absolute positioned based on `start * 64 - 7*64`.
  - Height `(end-start) * 64 - 2`.
  - Background = `category.bg` (light) / `.bgDark` (dark).
  - Border-radius 6. Padding `4 6 4 10`.
  - Leading 3pt accent stripe in `category.dot`.
  - Title 12pt 600 line-height 14 in `category.dot`.
  - Time range subtitle (only if h > 42pt): 11pt color `category.dot` opacity 0.75.
  - Location (only if h > 64pt): 11pt color `category.dot` opacity 0.65.
- [ ] `NowLineOverlay` (only when day includes today):
  - Red `#FF375F` 10×10 circle on left + 1.5pt horizontal line across.
  - Y position = `now.hour * 64 - 7*64`.
  - Live-updates every minute.

### `AgendaWeekView` (Week view)
- [ ] 7 day groups.
- [ ] Each group header (padding `6 4 8`): large day number (22pt 700 accent if today) + uppercase weekday (13pt 600).
- [ ] Group card (`background card, radius 14, overflow hidden`):
  - Event rows: 4pt leading accent stripe + 11pt padding. Title 15pt 600. Time on right.
  - Task rows: 20pt round checkbox border, fill on done. Title 15pt with strikethrough when done. Flag icon if high priority + open.

### `DayTaskStrip`
- [ ] Horizontal scroll of task chips above the Time Grid in Day view.
- [ ] Each chip: rounded 999 with 0.5pt `sep` border, bg `card`, padding `7 12 7 10`, checkbox 16×16 + title 13pt 500.

### `TasksScreen`
- [ ] Top: "Reminders" eyebrow + "Tasks" large title + sparkles button.
- [ ] Progress strip: 44×44 circular progress ring + label `"{done} of {total} done this week"` + subline `"3 high-priority tasks remaining"`.
- [ ] Sections (Overdue, Today, Tomorrow, Later This Week, Completed) — each tinted (red `#FF453A` for overdue, accent for today, etc.).
- [ ] Each task row: 22pt checkbox + title + meta line (category dot + name + reminder + weekday).

### `ModernReviewScreen`
- [ ] Header eyebrow + "Review" large title + sparkles.
- [ ] AI summary card: 16pt 700 in accent eyebrow row + 17pt body with rainbow gradient top border.
- [ ] Time breakdown: stacked bar (10pt tall, rounded 5pt) plus list of category rows with `{h.1f}h`.
- [ ] Insights cards: leading 3pt tinted stripe + title 15pt 600 + body 13pt color `text2`.
- [ ] Streak card: 40pt rounded green-tint emoji bubble + title + subline + 7-pill row.

### `ModernAISearchOverlay`
- [ ] Backdrop bg `rgba(0,0,0,0.92)` (dark) / `rgba(255,255,255,0.95)` (light) with `backdrop-filter blur 40px saturate 180%`.
- [ ] Slide-down animation 0.35s `cubic-bezier(0.2, 0.8, 0.2, 1)`.
- [ ] Input row with **rainbow shimmer border** (animated gradient over 3s).
- [ ] Suggestions list with rounded-square sparkle-icon avatars.
- [ ] Thinking state: 28pt rainbow conic-gradient "orb" + shimmer text + sub-text.
- [ ] Answer card has top 2pt rainbow gradient stripe, system 15pt body, citation chips with category tint.
- [ ] Inbox-card sub-section with Add button.

### `ModernEventSheet`
- [ ] Bottom sheet (radius 20 top), drag handle, `Cancel | Event | Done` toolbar.
- [ ] Title hero card with leading 4pt category stripe, category pill, large title (24pt 700), time line.
- [ ] Location/Travel grouped card.
- [ ] Reminders group with `Alert`, `When I arrive`, `Repeat` rows + iOS-style toggles.
- [ ] Attendees row (if > 1) with chevron.
- [ ] Gmail source card (if `source == .gmail`): brand glyph + uppercase `"FROM GMAIL"` + subject line.
- [ ] AI suggest card with rainbow top stripe and `SUGGESTED` eyebrow.
- [ ] `Delete Event` button in red.

### `ModernTabBar`
- [ ] Bg `rgba(28,28,30,0.78)` (dark) / `rgba(255,255,255,0.78)` (light) with `backdrop-filter blur 28px saturate 180%`.
- [ ] Top border 0.5pt `sep`.
- [ ] Three tabs identical to Paper but with accent color highlighting active tab.

## Logic & Data Checklist

### Style toggle
- [ ] In Settings, **above** Theme section, add `StyleSection`: segmented `Paper | Modern`.
- [ ] Persists as `UserSettings.style`.
- [ ] When `.paper`: render `AppShell` from Phase 15.
- [ ] When `.modern`: render `ModernShell`.

### Modern data binding
- [ ] Same `EventStore`, `TaskStore`, `InboxStore`, `IntelligenceService` — only the views differ.
- [ ] EventKit sync works identically.

### Defaults
- [ ] Default style `.paper` for v1.0 release. Modern is opt-in.

## Tests (TDD)

`ModernThemeTests`
- [ ] `testDarkAndLightTokensSetCorrectly()`.
- [ ] `testAccentDefaultIsSystemBlue()`.

`TimeGridLayoutTests`
- [ ] `testEventAt9to10_5RendersAtCorrectTopAndHeight()`.
- [ ] `testNowLinePositionAtTwoTwelvePM()`.
- [ ] `testMultipleColumnsWithGapsAreEvenlyWidthed()` — 2-Day view.

`ModernSnapshotTests`
- [ ] Snapshot Day view light + dark.
- [ ] Snapshot Week view dark.
- [ ] Snapshot Modern AI overlay thinking state.
- [ ] Snapshot Modern event sheet for `e17` (Sara's birthday).

## Acceptance Criteria
- Toggling style in Settings instantly swaps the whole app between Paper and Modern.
- All Modern screens are visually faithful to `screens.jsx`/`review.jsx`/`overlays.jsx`.
- All bindings (AI, EventKit, Gmail, notifications) work in both modes identically.
- Switching modes preserves week/day/event-open state.

## Out of Scope
- Animated handoff between modes (just an instant swap).
- Modern-mode-only features (no — feature parity).
- Custom Modern theme variants (only system light/dark).

## Risks & Notes
- **Modern AI overlay rainbow shimmer** is heavy — implement via animated gradient on a CALayer-bridged view if SwiftUI stutters.
- **NowLineOverlay** must use `TimelineView(.everyMinute)` not a Timer.
- **Style toggle** is a heavy operation visually; debounce taps to prevent flicker (250ms).
- Many of these views are similar to the Paper ones structurally — refactor common ViewModels into shared types in `Features/Shared/`.
