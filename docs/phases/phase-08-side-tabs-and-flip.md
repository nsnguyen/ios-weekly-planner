# Phase 08 — Side Tabs & Page-Flip System

## Goal
Add the column of seven pastel side tabs (M/T/W/T/F/S/S) along the left edge of the book and implement the 3D page-flip transition between days, including swipe gestures and week-crossing.

## Why this is needed
This is the marquee interaction. The 3D flip is what makes the planner feel like a real physical book.

## Prerequisites
- Phases 02 (`AnimationTokens`, `Spacing.sideTabWidth/...`), 03 (`WeekMath`), 04 (real events to flip between), 05 (`BookPage`), 06+07 (DayPageView renders one day).

## Files Created / Modified

```
WeeklyPlanner/Features/DayPage/SideTabs.swift                  # NEW — 22pt-wide column with 7 tabs
WeeklyPlanner/Features/DayPage/SideTab.swift                   # NEW — single rotated-text tab
WeeklyPlanner/Features/DayPage/PageFlipContainer.swift         # NEW — hosts front + back faces during flip
WeeklyPlanner/Features/DayPage/PageFlipController.swift        # NEW — observable state: current, target, direction, isFlipping
WeeklyPlanner/Features/DayPage/PageShadeOverlay.swift          # NEW — 0 → 0.55 → 0 shading gradient
WeeklyPlanner/Features/DayPage/DayPageView.swift               # MODIFY — host SideTabs + PageFlipContainer
WeeklyPlanner/Navigation/HorizontalSwipeGesture.swift          # NEW — encapsulated drag>40pt logic
WeeklyPlannerTests/DayPage/PageFlipControllerTests.swift       # NEW — state machine + week crossing
WeeklyPlannerTests/DayPage/SideTabsTests.swift                 # NEW
WeeklyPlannerTests/DayPage/FlipSnapshotTests.swift             # NEW — captures mid-flip frames
```

## Visual & Interaction Checklist

### `SideTabs`
- [ ] Renders **only** in Day view (Phase 09 will hide it in Week view).
- [ ] Column at the leading edge of the book page area, width 22pt (selected tab = 28pt).
- [ ] Padding-top 30pt (so the first tab starts below the book chrome).
- [ ] Vertical gap 4pt between tabs.
- [ ] z-index 2 (above paper, below sticky note + binding shadow).

### `SideTab` (single tab)
- [ ] Width: 22pt unselected, 28pt selected.
- [ ] Height: 56pt.
- [ ] Background color from the **pastel palette** (one per day index):
  - 0 Mon `#E8D9B7`
  - 1 Tue `#D9C9E3`
  - 2 Wed `#C8DDE6`
  - 3 Thu `#E4D3C2`
  - 4 Fri `#D9E4C6`
  - 5 Sat `#E7C7C7`
  - 6 Sun `#CFD4DC`
- [ ] Border: none. Border radius: `6pt 0 0 6pt` (only on the leading edge).
- [ ] Selected tab `marginLeading: -6` so it visually pokes leftward into the spine.
- [ ] Shadow: `inset -2 0 4 rgba(0,0,0,0.12), 0 1 2 rgba(0,0,0,0.3)`.
- [ ] Inner content: weekday long name (`"Monday"`...) rotated 90° (writing-mode vertical-rl + transform rotate(180°) on web; SwiftUI: `.rotationEffect(.degrees(-90))` + `.fixedSize()`).
- [ ] Text: handwriting 13pt weight 700, color `theme.ink`, letter-spacing 1.5, uppercase.
- [ ] If `weekOffset == 0 && idx == todayWeekday`: small red dot 5×5 at top-right corner (`top: 4, right: 3`).
- [ ] Tap: flips to that day. If same day, no-op. Animation duration `pageFlip` (0.62s).
- [ ] Transition between width 22 ↔ 28: spring `Animation.smooth(duration: 0.18)`.

### `PageFlipContainer`
- [ ] Hosts the current page (back of stack) and during flip the moving "leaf" (top of stack).
- [ ] Perspective `1800` (use `.rotation3DEffect(_, axis: (x:0, y:1, z:0), perspective: 1.0)` with manual scale to approximate).
- [ ] Transform origin: leading edge (`anchor: .leading`).
- [ ] `backfaceVisibility: hidden` simulated via dual sub-views: front face + back face (the back face is mirrored horizontally with `.scaleEffect(x: -1)` or `.rotation3DEffect(.degrees(180), axis: y)`).
- [ ] During the flip:
  - `0% → 50% → 100%` keyframes for `rotateY`: `0° → -90° → -178°` (for "next"), and reverse for "prev".
  - Shadow shifts in parallel: `-8 6 18 0.25α → -22 6 38 0.45α → -4 6 14 0.20α`.
  - A `PageShadeOverlay` animates opacity `0 → 0.55 → 0` (linear gradient 90° transparent→dark).
- [ ] Duration: 0.62s. Curve: `cubic-bezier(0.45, 0.05, 0.55, 0.95)` mapped to `Animation.timingCurve(...)`.

### `PageShadeOverlay`
- [ ] During "next" flip: front face uses `LinearGradient(90°, transparent 30% → rgba(0,0,0,0.18) 100%)`.
- [ ] Back face uses the mirrored gradient (270°).
- [ ] Opacity is animated 0 → 0.55 → 0 across the 0.62s.

### Bottom flip controls (handled in Phase 09 — left a TODO note here)

### Gesture
- [ ] `HorizontalSwipeGesture`:
  - Recognizes `DragGesture(minimumDistance: 0)` on the page area.
  - On end: if `translation.width < -40pt` → `flip(.next)`. If `> 40pt` → `flip(.prev)`.
  - Vertical-only drags are ignored (`|dy| > |dx|` ratio threshold).
  - During the gesture, the page can lean (apply `rotateY` proportional to drag, capped at ~-25°), enhancing the physical feeling. Threshold to commit remains 40pt.

## Logic & Data Checklist

### `PageFlipController` (`@Observable`)
- [ ] State: `current: (week: Int, day: Int)`, `target: (week: Int, day: Int)?`, `direction: FlipDirection?` (`.next | .prev`).
- [ ] `flipDay(direction:)` — computes target with week-crossing:
  - `.next`: if `day == 6` → `(week+1, 0)` else `(week, day+1)`.
  - `.prev`: if `day == 0` → `(week-1, 6)` else `(week, day-1)`.
- [ ] `flipToDay(idx:)` — used by side-tab tap. Direction inferred from `idx > current.day ? .next : .prev`.
- [ ] `commit()` after animation duration — current = target.
- [ ] Guard: ignore inputs while a flip is in progress.

### Wiring
- [ ] `DayPageView` reads `(week, day)` from `PageFlipController`. When controller's `target` is set, render two pages stacked: current at z=1, target at z=1 underneath. The flipping leaf renders the **outgoing** page on its front face and the **incoming** page on its back face.
- [ ] `SideTabs` reads `currentDay` from controller; selected highlight follows.
- [ ] After commit, focusedDay/weekOffset updates propagate to data fetching (Phase 06 view model).

### Edge cases
- [ ] Flipping past `(week +N, day 0)` continues into `+N+1` weeks (no upper bound). The data layer fetches lazily.
- [ ] Flipping past `(-MAX_BACK, day 6)` is allowed; UI shows empty week page if no data.
- [ ] Rapid taps during animation are coalesced (controller ignores them).

## Tests (TDD)

`PageFlipControllerTests`
- [ ] `testFlipNextOnSundayCrossesIntoNextWeek()` — `(0, 6) → (1, 0)`.
- [ ] `testFlipPrevOnMondayCrossesIntoPreviousWeek()` — `(0, 0) → (-1, 6)`.
- [ ] `testFlipDirectionInferredByDayIndex()`.
- [ ] `testCommitMovesCurrentToTarget()`.
- [ ] `testFlipIsNoopWhileAnimating()`.

`SideTabsTests`
- [ ] `testTodayDotShownOnlyForCurrentWeekTodayTab()`.
- [ ] `testTapTabCallsFlipToDay()`.
- [ ] `testPastelColorPerIndex()`.

`FlipSnapshotTests`
- [ ] Snapshots at flip progress 0.0, 0.25, 0.5, 0.75, 1.0 for a Tuesday → Wednesday flip.
- [ ] Verifies both front and back faces and shading.

## Acceptance Criteria
- Swiping left/right flips the page with the full 3D animation.
- Tapping a side tab flips directly to that day, choosing direction by comparing indices.
- Side tabs' selected tab is 28pt wide and offset -6pt to overlap the spine; today's tab has the red dot.
- Crossing week boundaries works in both directions.
- Reduce-motion: replace 3D flip with a 0.15s opacity crossfade. Document accessibility behavior.

## Out of Scope
- Bottom "Last day / Next day" buttons (Phase 09).
- Top bar week chevrons (Phase 09).
- Week-page flipping (Phase 10 — same controller, week granularity).
- Page picker drop-down (Phase 09).

## Risks & Notes
- **SwiftUI's `rotation3DEffect` doesn't support backface-visibility directly.** Workaround: keep both faces, swap which is shown based on progress > 0.5.
- **Spring/timing-curve fidelity**: SwiftUI's `timingCurve` matches CSS cubic-bezier mostly, but `scaleEffect + rotation3DEffect` ordering matters for perspective accuracy. Test on device.
- **iOS 26 keyframes**: use `KeyframeAnimator` for the shadow + shade interpolation — cleaner than chained `withAnimation` calls.
- **Edge swipe**: avoid conflict with iOS system back-edge swipe (which doesn't apply inside the BookPage area, but worth verifying).
