# Phase 15 — Paper Tab Bar & Navigation Wiring

## Goal
Build the leather-bound bottom tab bar with three tabs — Calendar, Review, Settings — including the **paper "index tab" bookmark** that pops up behind the active tab. Wire the root navigation so tab switching swaps the page surface above it without re-mounting the BookCover.

## Why this is needed
The tab bar is on every screen and gives the app its second signature interaction (the bookmark).

## Prerequisites
- Phases 02, 05, 06, 10, 14 (so Calendar / Review screens exist), 16 (Settings — but we can stub this with a placeholder until then; Settings page lands in Phase 16).

## Files Created / Modified

```
WeeklyPlanner/Navigation/PaperTabBar.swift                # NEW — the bottom bar component
WeeklyPlanner/Navigation/PaperTab.swift                   # NEW — single tab with index-tab bookmark
WeeklyPlanner/Navigation/AppShell.swift                   # NEW — root container that hosts tabs + active screen
WeeklyPlanner/Navigation/TabSelection.swift               # NEW — enum + @Observable selection
WeeklyPlanner/App/RootView.swift                          # MODIFY — replace placeholder with AppShell
WeeklyPlannerTests/Navigation/TabSelectionTests.swift     # NEW
WeeklyPlannerTests/Navigation/PaperTabBarSnapshotTests.swift  # NEW
```

## Visual & Interaction Checklist

### `PaperTabBar`
- [ ] Absolute at bottom of the screen, leading 0, trailing 0.
- [ ] Padding `top: 6, bottom: 26` (26 is the home-indicator safe area).
- [ ] z-index 30.
- [ ] Background `theme.bookCover` — the same leather as the chrome.
- [ ] Top border 0.5pt `rgba(255,255,255,0.06)`.
- [ ] Box shadow `0 -2 14 rgba(0,0,0,0.4), inset 0 1 0 rgba(255,255,255,0.04)`.
- [ ] Flex row justify-space-around align-flex-start.
- [ ] **Stitched seam**: 0.5pt dashed line near top edge — `top: 4, leading: 18, trailing: 18, border-top: 0.5pt dashed rgba(255,255,255,0.08)`.

### `PaperTab` (3 instances)
- [ ] Flex 1, transparent bg, border 0.
- [ ] Padding `top: 8`.
- [ ] Flex column align-center gap 3.
- [ ] **Active state**:
  - Tab label `theme.ink`, icon `theme.ink`.
  - Behind icon+label: a **paper bookmark** popping up from the bar.
- [ ] **Inactive state**:
  - Tab label `theme.chromeMuted`, icon `theme.chromeMuted`.
- [ ] Icon size 22pt. Label 10pt system font weight 700 (active) or 500 (inactive), letter-spacing 0.1.

### Paper bookmark (active only)
- [ ] Positioned absolute at the top of the tab.
- [ ] 52×26.
- [ ] Background `theme.cream` (the page color).
- [ ] Border radius `4pt 4pt 0 0` (rounded only at top).
- [ ] Shadow `0 -1 2 rgba(0,0,0,0.4), inset 1 1 1 rgba(255,255,255,0.5)`.
- [ ] z-index -1 (behind the icon + label).
- [ ] Centered horizontally; offset top `-8pt` (extends above the tab area).
- [ ] Provides the "I'm bookmarked into the book" visual.

### Tab list (in order)
- [ ] **Calendar** — icon `Icons.calendar`, label `"Calendar"`, value `.calendar`.
- [ ] **Review** — icon `Icons.inbox` (per mock; despite "Review" semantic), label `"Review"`, value `.review`.
- [ ] **Settings** — icon `Icons.settings`, label `"Settings"`, value `.settings`.

### Tab switch interaction
- [ ] Tap a tab → updates `TabSelection`. The screen above swaps with a 0.18s cross-fade (no flip animation across tabs).
- [ ] BookCover stays in place; only the inside-the-book content changes.
- [ ] The bookmark animates: when activating a different tab, the new bookmark fades-in over 0.18s while the old one fades out.

### Settings tab behavior
- [ ] Setting **embedded mode** (Phase 16) — Settings is a full screen replacing the calendar/review area.
- [ ] **Not** a modal sheet (mock had a sheet variant but the embedded behavior is preferred).
- [ ] Switching to Settings does not lose the Day page state (focusedDay, weekOffset, openEvent are preserved when switching back).

## Logic & Data Checklist

### `TabSelection`
- [ ] `enum Tab: String { case calendar, review, settings }`.
- [ ] `@Observable final class TabSelection { var current: Tab = .calendar }`.
- [ ] Persisted across launches in `UserSettings.lastTab` (lightweight value, not critical).

### `AppShell`
- [ ] Root container view. Reads `TabSelection`, swaps between `DayPageView`/`WeekPageView`, `PaperReviewView`, `PaperSettingsView`.
- [ ] Provides `BookCover` as the always-present background.
- [ ] Mounts the active screen as a child of the cover.
- [ ] Tab bar sits absolute at the bottom (z=30).
- [ ] Modal overlays (AI Search, Event Detail, Week Picker) layer above tab bar and active screen.

### Lifecycle
- [ ] Switching tabs does not unmount Day/Week page state; use `.id(tab)` carefully — actually we **want** Day/Week to keep state, so DO NOT use `.id` for those views.
- [ ] Switching tabs may trigger `WeekSummaryGenerator.refresh()` (Phase 13) when entering Review.

## Tests (TDD)

`TabSelectionTests`
- [ ] `testDefaultTabIsCalendar()`.
- [ ] `testSwitchingTabPersistsAcrossNewSelectionInstance()`.

`PaperTabBarSnapshotTests`
- [ ] Snapshot with each tab active in cream, kraft, midnight.
- [ ] Snapshot mid-transition between Calendar and Review (bookmark cross-fade).

## Acceptance Criteria
- Tab bar visible at the bottom of every screen, leather-themed.
- Active tab shows the cream bookmark sticking up from the bar.
- Stitched seam dashed line visible at top edge of the bar.
- Tapping Settings opens the embedded Settings page (Phase 16) without sheet animation.
- All tab transitions are 0.18s cross-fades.
- Tabs preserve scroll/focus state.

## Out of Scope
- A "+" centered add button on the tab bar (not in spec; adding events is the AI overlay or modal — defer).
- iPad split view (iPhone only).
- Right-to-left layout (Phase 21).

## Risks & Notes
- **Bookmark z-order**: it must be **behind** the icon, not in front. Use a `ZStack` with the bookmark first, icon second.
- **Safe area**: don't push the bar above the home indicator. Use `.safeAreaInset(edge: .bottom)` so the active screen content paddings adjust.
- **Stitched seam**: rendered as a sub-pixel-aligned `Path` to avoid blurry dashes on 3× screens.
- **Settings tab return-to-calendar**: when entering Settings, remember the previous tab so a sub-screen's "Done" can return there.
