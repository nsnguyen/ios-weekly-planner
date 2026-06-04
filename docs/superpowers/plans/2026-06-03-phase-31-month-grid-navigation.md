# Phase 31 — Month Grid & Week-Picker Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the week picker's month grid navigable and readable: a ±24-month window (was ±2), explicit month/year stepping controls, centered month titles, a Monday-first weekday header per month, and no ISO week-number column.

**Architecture:** `WeekPickerViewModel` stays pure eager math — `buildMonths` widens from `(-2...2)` to `(-24...24)` (49 months, still built once in `init`; ~2k Calendar ops, a few ms). A new `displayedMonthIndex` on the view model backs the nav bar (step/jump API, clamped to the window). The sheet's scroll body becomes a `LazyVStack` (49 eager `MonthGridView`s would be ~6k views) driven by the iOS 17+ `.scrollPosition(id:)`/`.scrollTargetLayout()` binding at month granularity — bidirectional, so the nav title follows manual scrolling and nav buttons scroll the list. The weekday header moves from the sheet (sticky, with a 28pt week-number gutter) into `MonthGridView` (per-month, full-width), because the W## gutter is gone and the spec's file table assigns the header to `MonthGridView`.

**Tech Stack:** SwiftUI (iOS 26), Swift 6 strict concurrency, XCTest (NOT Swift Testing), XcodeGen.

**Decision (made upstream):** ±24-month **fixed window**, not lazy paging. Only revisit if scroll feel/memory demands it.

**Key constraints:**
- Touch ONLY `WeeklyPlanner/Features/WeekPicker/*`, `WeeklyPlannerTests/WeekPicker/*`, plus *additive* lines in `WeeklyPlanner/Accessibility/AccessibilityIDs.swift`. No AppShell/PageFlipController changes.
- `weekpicker.weekrow.<offset>` accessibility identifiers must keep working (UITest `WeekNavigationStabilityUITests.testWeekPickerNavigatesToSelectedWeek` taps row +3).
- Keep: today's red marker, selected week's blue wash, tap-week selects + dismisses.
- Removing the week number is presentation-only: `PickerWeek.weekNumber` stays in the model.
- `.xcodeproj` is gitignored; run `xcodegen generate` after adding `MonthGridViewTests.swift`.

**Test commands** (signing flags exactly as below; device iPhone 17 / iOS 26.5):

```bash
# Full unit suite (skip UITests):
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -only-testing:WeeklyPlannerTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO

# One unit test class:
…same… -only-testing:WeeklyPlannerTests/WeekPickerViewModelTests …flags…

# Picker end-to-end scroll check (idle shortened):
env WP_IDLE_SECONDS=3 xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -only-testing:WeeklyPlannerUITests/WeekNavigationStabilityUITests/testWeekPickerNavigatesToSelectedWeek \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO
```

**Reference dates used by tests** (baseDate = Sat May 16 2026, noon; today's Monday = May 11 2026):
- Window spans **May 2024 … May 2028** (49 months).
- Mon **Mar 1 2027** = May 11 2026 + 294 days = offset **+42** (exact).
- Week containing **Jan 1 2027** (a Friday) starts Mon **Dec 28 2026** = +231 days = offset **+33**.
- Week containing **Jan 1 2026** (a Thursday) starts Mon **Dec 29 2025** = −133 days = offset **−19**.
- US DST transitions inside the window (e.g. Mar 8 2026, Nov 1 2026) are covered by the all-window contiguity sweep.

---

### Task 0: Worktree setup + baseline

**Files:** none (tooling only)

- [ ] **Step 0.1:** `cp /Users/nguyen-mini/Documents/dev/ios-weekly-planner/Secrets.xcconfig ./Secrets.xcconfig` (gitignored; needed by build).
- [ ] **Step 0.2:** `xcodegen generate` — fresh worktree has no `.xcodeproj`.
- [ ] **Step 0.3:** Run the full unit suite (command above). Expected: all tests pass (~387). This is the baseline; record the count.

---

### Task 1: (36) Widen the month window to ±24

**Files:**
- Modify: `WeeklyPlannerTests/WeekPicker/WeekPickerViewModelTests.swift`
- Modify: `WeeklyPlanner/Features/WeekPicker/WeekPickerViewModel.swift`

- [ ] **Step 1.1: Write the failing test + update the stale ±2 test.**

In `WeekPickerViewModelTests.swift`, REPLACE `testFiveMonthsCenteredOnFocus` with the two tests below (the old test pins count == 5 / Mar–Jul and must change with the window):

```swift
    /// Phase 31 (36): the window is ±24 months around the focus month —
    /// 49 months total, symmetric, oldest first.
    func testMonthWindowCenteredOnFocus() {
        let viewModel = WeekPickerViewModel(baseDate: Self.may16_2026(), focusWeekOffset: 0)
        XCTAssertEqual(viewModel.months.count, 49)
        XCTAssertEqual(viewModel.months.first?.month, 5)
        XCTAssertEqual(viewModel.months.first?.year, 2024)
        XCTAssertEqual(viewModel.months.last?.month, 5)
        XCTAssertEqual(viewModel.months.last?.year, 2028)
        // The focus month sits exactly in the middle.
        XCTAssertEqual(viewModel.months[24].month, 5)
        XCTAssertEqual(viewModel.months[24].year, 2026)
    }

    /// Phase 31 (36): regression guard against the old hard ±2 cap — months
    /// well beyond two months out exist in both directions.
    func testRangeExtendsBeyondTwoMonths() {
        let viewModel = WeekPickerViewModel(baseDate: Self.may16_2026(), focusWeekOffset: 0)
        XCTAssertTrue(viewModel.months.contains { $0.year == 2025 && $0.month == 5 },
                      "Expected May 2025 (−12 months) in the window")
        XCTAssertTrue(viewModel.months.contains { $0.year == 2027 && $0.month == 5 },
                      "Expected May 2027 (+12 months) in the window")
    }
```

- [ ] **Step 1.2: Run to verify both fail** (`months.count` is 5, first month is Mar 2026):
`-only-testing:WeeklyPlannerTests/WeekPickerViewModelTests` → Expected: FAIL.
- [ ] **Step 1.3: Implement.** In `WeekPickerViewModel.swift`:
  - Add inside the class:

```swift
    /// Phase 31 (36): months built on either side of the focus month.
    /// ±24 (49 months total) — a generous fixed window chosen over lazy
    /// paging; revisit only if memory or scroll feel demands it.
    static let monthWindowRadius = 24
```

  - In `buildMonths`, replace `(-2 ... 2)` with `(-monthWindowRadius ... monthWindowRadius)`.
  - Update doc comments that say "five months" / "5-element array" / "focus month ± 2" on `PickerMonth`, `months`, the class header, `init`, and `buildMonths` to describe the ±24 window (`2 * monthWindowRadius + 1` months).
- [ ] **Step 1.4: Run the class again.** Expected: PASS (all existing tests too — `testMay2026HasFiveOrSixWeeks` etc. filter by year+month and survive).
- [ ] **Step 1.5: Commit.**

```bash
git add WeeklyPlanner/Features/WeekPicker/WeekPickerViewModel.swift WeeklyPlannerTests/WeekPicker/WeekPickerViewModelTests.swift
git commit -m "feat(week-picker): widen month window from ±2 to ±24 months (Phase 31 #36)"
```

---

### Task 2: (35) Displayed-month tracking + step/jump API on the view model

**Files:**
- Modify: `WeeklyPlannerTests/WeekPicker/WeekPickerViewModelTests.swift`
- Modify: `WeeklyPlanner/Features/WeekPicker/WeekPickerViewModel.swift`

- [ ] **Step 2.1: Write the failing tests.** Append to `WeekPickerViewModelTests`:

```swift
    // MARK: - Phase 31 (35): displayed month + step/jump

    func testDisplayedMonthStartsAtFocusMonth() {
        let viewModel = WeekPickerViewModel(baseDate: Self.may16_2026(), focusWeekOffset: 0)
        XCTAssertEqual(viewModel.displayedMonth?.id, "2026-05")
        // Focus offset +6 → Mon Jun 22, 2026 → June is the focus month.
        let shifted = WeekPickerViewModel(baseDate: Self.may16_2026(), focusWeekOffset: 6)
        XCTAssertEqual(shifted.displayedMonth?.id, "2026-06")
    }

    /// Phase 31 (35): jumping to an arbitrary month/year selects that month
    /// for display, leaves the week *selection* untouched, and the target
    /// month's week offsets are correct (Mon Mar 1 2027 = +42 weeks from
    /// Mon May 11 2026 — exactly 294 days).
    func testJumpToMonthYear() {
        let viewModel = WeekPickerViewModel(baseDate: Self.may16_2026(), focusWeekOffset: 0)
        let target = viewModel.jumpTo(year: 2027, month: 3)
        XCTAssertNotNil(target)
        XCTAssertEqual(viewModel.displayedMonth?.id, "2027-03")
        XCTAssertEqual(viewModel.displayedMonth?.title, "March 2027")
        XCTAssertEqual(viewModel.selectedWeekOffset, 0,
                       "Jumping must not change the selected week")
        let firstWeek = target?.weeks.first
        XCTAssertEqual(firstWeek?.offset, 42)
        XCTAssertEqual(firstWeek?.days.first?.id, "2027-03-01")
    }

    func testJumpOutsideWindowReturnsNil() {
        let viewModel = WeekPickerViewModel(baseDate: Self.may16_2026(), focusWeekOffset: 0)
        XCTAssertNil(viewModel.jumpTo(year: 2030, month: 1))
        XCTAssertEqual(viewModel.displayedMonth?.id, "2026-05",
                       "Failed jump must not move the displayed month")
    }

    func testStepMonthAndYearClampAtWindowEdges() {
        let viewModel = WeekPickerViewModel(baseDate: Self.may16_2026(), focusWeekOffset: 0)
        viewModel.stepMonth(by: 1)
        XCTAssertEqual(viewModel.displayedMonth?.id, "2026-06")
        viewModel.stepMonth(by: 12)
        XCTAssertEqual(viewModel.displayedMonth?.id, "2027-06")
        // Clamp forward: +24 from June 2027 overshoots → lands on May 2028.
        viewModel.stepMonth(by: 24)
        XCTAssertEqual(viewModel.displayedMonth?.id, "2028-05")
        XCTAssertFalse(viewModel.canStepForward)
        XCTAssertTrue(viewModel.canStepBackward)
        // Clamp backward to the window start.
        viewModel.stepMonth(by: -100)
        XCTAssertEqual(viewModel.displayedMonth?.id, "2024-05")
        XCTAssertFalse(viewModel.canStepBackward)
        XCTAssertTrue(viewModel.canStepForward)
    }

    func testSyncDisplayedMonthToScrolledID() {
        let viewModel = WeekPickerViewModel(baseDate: Self.may16_2026(), focusWeekOffset: 0)
        viewModel.syncDisplayedMonth(toID: "2026-11")
        XCTAssertEqual(viewModel.displayedMonth?.id, "2026-11")
        viewModel.syncDisplayedMonth(toID: "not-a-month")
        XCTAssertEqual(viewModel.displayedMonth?.id, "2026-11",
                       "Unknown ids must be ignored")
    }
```

- [ ] **Step 2.2: Run to verify they fail to compile** (no `displayedMonth`/`jumpTo`/`stepMonth`/`canStepForward`/`canStepBackward`/`syncDisplayedMonth`). Expected: build FAIL on the test target.
- [ ] **Step 2.3: Implement.** In `WeekPickerViewModel.swift`:
  - Add stored property after `selectedWeekOffset`:

```swift
    /// Index into `months` of the month the nav bar currently displays.
    /// Starts at the focus month; nav chevrons step it, manual scrolling
    /// syncs it via `syncDisplayedMonth(toID:)`. Phase 31 (35).
    var displayedMonthIndex: Int = 0
```

  - In `init`, after `months = …`, locate the focus month by id (the window is symmetric so the middle is the focus month, but derive it robustly):

```swift
        let calendar = WeekMath.mondayCalendar()
        let todayMonday = Self.mondayOfWeek(containing: baseDate, calendar: calendar)
        let focusMonday = calendar.date(byAdding: .day, value: focusWeekOffset * 7, to: todayMonday) ?? todayMonday
        let comps = calendar.dateComponents([.year, .month], from: focusMonday)
        let focusID = String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
        displayedMonthIndex = months.firstIndex { $0.id == focusID } ?? months.count / 2
```

  - Add the API (new `// MARK: - Phase 31 (35): month/year navigation` section):

```swift
    /// The month the nav bar shows. `nil` only if `months` is empty.
    var displayedMonth: PickerMonth? {
        months.indices.contains(displayedMonthIndex) ? months[displayedMonthIndex] : nil
    }

    /// True when a backward (older) step is possible.
    var canStepBackward: Bool { displayedMonthIndex > 0 }

    /// True when a forward (newer) step is possible.
    var canStepForward: Bool { displayedMonthIndex < months.count - 1 }

    /// Step the displayed month by `delta` months (±1 chevrons, ±12 year
    /// steppers), clamped to the built window.
    func stepMonth(by delta: Int) {
        guard !months.isEmpty else { return }
        displayedMonthIndex = min(max(displayedMonthIndex + delta, 0), months.count - 1)
    }

    /// Jump straight to a month/year. Returns the month on success, `nil`
    /// (and no state change) when the target is outside the built window.
    /// Never touches `selectedWeekOffset` — selection only changes on row tap.
    @discardableResult
    func jumpTo(year: Int, month: Int) -> PickerMonth? {
        guard let idx = months.firstIndex(where: { $0.year == year && $0.month == month }) else {
            return nil
        }
        displayedMonthIndex = idx
        return months[idx]
    }

    /// Keep `displayedMonthIndex` in sync while the user scrolls manually.
    /// Unknown ids (footer overscroll, transient nil) are ignored.
    func syncDisplayedMonth(toID id: String) {
        guard let idx = months.firstIndex(where: { $0.id == id }) else { return }
        displayedMonthIndex = idx
    }
```

- [ ] **Step 2.4: Run the class.** Expected: PASS.
- [ ] **Step 2.5: Commit.**

```bash
git add WeeklyPlanner/Features/WeekPicker/WeekPickerViewModel.swift WeeklyPlannerTests/WeekPicker/WeekPickerViewModelTests.swift
git commit -m "feat(week-picker): displayed-month tracking + step/jump API (Phase 31 #35)"
```

---

### Task 3: Offset integrity across year boundaries and DST (verification tests)

**Files:**
- Modify: `WeeklyPlannerTests/WeekPicker/WeekPickerViewModelTests.swift`

These pin existing math at the new range; they should pass immediately (they are the spec's correctness gate, not TDD-red).

- [ ] **Step 3.1: Add the tests.**

```swift
    // MARK: - Phase 31 (36): offset integrity at far-out months

    /// Hard-coded year-boundary anchors: the week containing Jan 1 2027
    /// starts Mon Dec 28 2026 (+33 weeks from Mon May 11 2026); the week
    /// containing Jan 1 2026 starts Mon Dec 29 2025 (−19 weeks).
    func testWeekOffsetCorrectAcrossYearBoundary() {
        let viewModel = WeekPickerViewModel(baseDate: Self.may16_2026(), focusWeekOffset: 0)

        let jan2027 = viewModel.months.first { $0.year == 2027 && $0.month == 1 }
        XCTAssertNotNil(jan2027)
        let newYearWeek2027 = jan2027?.weeks.first { week in
            week.days.contains { $0.id == "2027-01-01" }
        }
        XCTAssertEqual(newYearWeek2027?.offset, 33)
        XCTAssertEqual(newYearWeek2027?.days.first?.id, "2026-12-28")

        let jan2026 = viewModel.months.first { $0.year == 2026 && $0.month == 1 }
        XCTAssertNotNil(jan2026)
        let newYearWeek2026 = jan2026?.weeks.first { week in
            week.days.contains { $0.id == "2026-01-01" }
        }
        XCTAssertEqual(newYearWeek2026?.offset, -19)
        XCTAssertEqual(newYearWeek2026?.days.first?.id, "2025-12-29")
    }

    /// Sweep the whole ±24-month window: deduped week offsets must form a
    /// gapless contiguous integer range, every week must start on a Monday
    /// and hold exactly 7 days, and offset 0 must start on Mon May 11 2026.
    /// Catches integer drift across year boundaries and DST transitions
    /// (Mar/Nov 2024–2028 all fall inside the window).
    func testWeekOffsetsContiguousAcrossWholeWindow() {
        let viewModel = WeekPickerViewModel(baseDate: Self.may16_2026(), focusWeekOffset: 0)
        let calendar = WeekMath.mondayCalendar()

        var mondayByOffset: [Int: String] = [:]
        for month in viewModel.months {
            for week in month.weeks {
                XCTAssertEqual(week.days.count, 7, "Week \(week.offset) must span 7 days")
                let monday = week.days[0]
                XCTAssertEqual(calendar.component(.weekday, from: monday.date), 2,
                               "Week \(week.offset) must start on a Monday")
                if let existing = mondayByOffset[week.offset] {
                    XCTAssertEqual(existing, monday.id,
                                   "Offset \(week.offset) maps to two different Mondays")
                } else {
                    mondayByOffset[week.offset] = monday.id
                }
            }
        }

        let offsets = mondayByOffset.keys.sorted()
        XCTAssertEqual(mondayByOffset["0" == "" ? 0 : 0], "2026-05-11")
        XCTAssertEqual(offsets.first.map { offsets.last! - $0 + 1 }, offsets.count,
                       "Offsets must be gapless: \(offsets.first!)...\(offsets.last!)")
    }
```

  Note: write the offset-0 assertion plainly as `XCTAssertEqual(mondayByOffset[0], "2026-05-11")` — the line above shows intent.
- [ ] **Step 3.2: Run the class.** Expected: PASS. If any fail → STOP, invoke `superpowers:systematic-debugging` (this would be real drift in `daysBetween / 7`).
- [ ] **Step 3.3: Commit.**

```bash
git add WeeklyPlannerTests/WeekPicker/WeekPickerViewModelTests.swift
git commit -m "test(week-picker): pin offset integrity across year boundaries and DST (Phase 31 #36)"
```

---

### Task 4: (33)(34) Centered title, per-month weekday header, no week-number column

**Files:**
- Create: `WeeklyPlannerTests/WeekPicker/MonthGridViewTests.swift`
- Modify: `WeeklyPlanner/Features/WeekPicker/MonthGridView.swift`
- Modify: `WeeklyPlanner/Features/WeekPicker/WeekRowView.swift`
- Modify: `WeeklyPlanner/Features/WeekPicker/WeekPickerSheet.swift` (delete `dayOfWeekHeader` only — the rest of the sheet changes in Task 5)

**Testing approach (honest note):** the suite has no snapshot/render infrastructure (all existing tests are logic tests). These tests pin *presentation contracts*: small statics/helpers the view bodies actually consume. They guard regressions that flip the constants but cannot detect someone hand-rolling a new label; the screenshot-diff acceptance step covers that.

- [ ] **Step 4.1: Write the failing tests** — create `WeeklyPlannerTests/WeekPicker/MonthGridViewTests.swift`:

```swift
import SwiftUI
import XCTest
@testable import WeeklyPlanner

/// Phase 31 (33)(34) presentation contracts for the month grid. The suite
/// has no snapshot infrastructure, so these pin the constants/helpers the
/// view bodies consume rather than rendered pixels; the screenshot diff vs
/// `docs/mock/` is the visual gate.
@MainActor
final class MonthGridViewTests: XCTestCase {
    private static func may16_2026() -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 16
        components.hour = 12
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }

    /// (34) The "May 2026" title is centered in the section header.
    func testTitleCentered() {
        XCTAssertEqual(MonthGridView.titleAlignment, .center)
    }

    /// (33) Monday-first weekday header, all seven days — weekends stay.
    func testWeekdayHeaderPresent() {
        XCTAssertEqual(MonthGridView.weekdaySymbols,
                       ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"])
    }

    /// (33) The ISO week-number column is gone from rows, the row's
    /// accessibility label no longer leaks the ISO number, and the removal
    /// is presentation-only (`PickerWeek.weekNumber` survives in the model).
    func testNoWeekNumberRendered() {
        XCTAssertFalse(WeekRowView.showsWeekNumberColumn)

        let viewModel = WeekPickerViewModel(baseDate: Self.may16_2026(), focusWeekOffset: 0)
        let currentWeek = viewModel.months
            .flatMap(\.weeks)
            .first { $0.offset == 0 }
        XCTAssertNotNil(currentWeek)
        guard let currentWeek else { return }

        // Presentation-only: the model still carries the ISO number…
        XCTAssertEqual(currentWeek.weekNumber, 20)
        // …but the row's VoiceOver label is date-based, not "Week 20".
        let label = WeekRowView.accessibilityLabel(for: currentWeek)
        XCTAssertEqual(label, "Week of May 11")
        XCTAssertFalse(label.contains("\(currentWeek.weekNumber)"))
    }
}
```

- [ ] **Step 4.2:** `xcodegen generate` (new test file), then run `-only-testing:WeeklyPlannerTests/MonthGridViewTests`. Expected: build FAIL (`titleAlignment`, `weekdaySymbols`, `showsWeekNumberColumn`, `accessibilityLabel(for:)` don't exist).
- [ ] **Step 4.3: Implement `MonthGridView`.** Replace the `header` and add the weekday header + contracts:

```swift
    /// Phase 31 (34) presentation contract — the month title is centered.
    /// Unit-tested in `MonthGridViewTests.testTitleCentered`.
    static let titleAlignment: TextAlignment = .center

    /// Phase 31 (33) presentation contract — Monday-first weekday header,
    /// weekends included. Two letters (vs. the JS mock's single letter)
    /// because the single-letter form repeats T and S and reads as a typo.
    /// Unit-tested in `MonthGridViewTests.testWeekdayHeaderPresent`.
    static let weekdaySymbols = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
```

  New body layout (title, then weekday header, then rows):

```swift
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.vertical, 4)

            weekdayHeader

            ForEach(month.weeks) { week in
                WeekRowView(week: week,
                            isSelected: week.offset == selectedWeekOffset,
                            onPick: onPick)
                    .id(week.id)
            }
        }
        .padding(.bottom, 8)
    }

    /// "May 2026" handwritten title, centered across the full row width
    /// (Phase 31 #34 — was left-aligned with a trailing rule).
    private var header: some View {
        Text(month.title)
            .font(font.font(at: 18, weight: .bold))
            .foregroundStyle(theme.ink)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: frameAlignment)
            .padding(.horizontal, 2)
    }

    /// Maps the testable `TextAlignment` contract onto the frame alignment
    /// the header actually uses.
    private var frameAlignment: Alignment {
        switch Self.titleAlignment {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    /// Seven Monday-first weekday labels above the month's rows (Phase 31
    /// #33). Spacing/padding mirror `WeekRowView`'s day cells exactly so the
    /// columns line up: HStack(spacing: 3) + 14pt horizontal padding.
    private var weekdayHeader: some View {
        HStack(spacing: 3) {
            ForEach(Self.weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(theme.ink3)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(EdgeInsets(top: 2, leading: 14, bottom: 4, trailing: 14))
    }
```

  Update the struct doc comment (mentions title + weekday header now).
- [ ] **Step 4.4: Implement `WeekRowView`.** Remove `weekNumberLabel` and its use; add contracts:

```swift
    /// Phase 31 (33) presentation contract — the leading "W##" ISO
    /// week-number column was removed; rows are seven full-width day cells.
    /// `PickerWeek.weekNumber` stays in the model (the removal is
    /// presentation-only). Unit-tested in
    /// `MonthGridViewTests.testNoWeekNumberRendered`.
    static let showsWeekNumberColumn = false

    /// Date-based VoiceOver label ("Week of May 11") — replaces the old
    /// "Week 21" ISO-number label, which no longer matches anything visible.
    static func accessibilityLabel(for week: PickerWeek) -> String {
        guard let monday = week.days.first?.date else { return "Week" }
        return "Week of \(Self.mondayFormatter.string(from: monday))"
    }

    /// "May 11" style. POSIX-locale so the label doesn't drift across devices.
    private static let mondayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
```

  In `body`: delete `weekNumberLabel` from the HStack (leaving the seven `dayCell`s), delete the `weekNumberLabel` computed property, and change the a11y line to:

```swift
        .accessibilityLabel(Self.accessibilityLabel(for: week))
```

  Keep `.accessibilityIdentifier(AccessibilityIDs.weekpickerWeekRow(week.offset))` EXACTLY as is. Update the struct doc comment (no more `W##` column).
- [ ] **Step 4.5: Trim `WeekPickerSheet`.** Delete the `dayOfWeekHeader` computed property and its call in `sheet` (the per-month header replaces it; its 28pt `Color.clear` gutter existed only to align with the removed W## column). The `// MARK: - Day-of-week header` section goes away entirely.
- [ ] **Step 4.6: Run** `MonthGridViewTests` + `WeekPickerViewModelTests`. Expected: PASS.
- [ ] **Step 4.7: Commit.**

```bash
git add WeeklyPlanner/Features/WeekPicker/ WeeklyPlannerTests/WeekPicker/MonthGridViewTests.swift
git commit -m "feat(week-picker): centered month title, per-month Mon-first weekday header, drop W## column (Phase 31 #33 #34)"
```

---

### Task 5: (35)(36) Month/year nav bar + lazy scroll plumbing in the sheet

**Files:**
- Modify: `WeeklyPlanner/Features/WeekPicker/WeekPickerSheet.swift`
- Modify: `WeeklyPlanner/Accessibility/AccessibilityIDs.swift` (ADDITIVE ONLY)

No new unit tests here (pure SwiftUI wiring over the Task-2 API, which is already tested); verification is Task 6's build + UITest + manual pass.

- [ ] **Step 5.1: Add accessibility identifiers** (append to the `// Week picker` section in `AccessibilityIDs.swift`; do NOT touch existing entries):

```swift
    // Week picker — month/year navigation bar (Phase 31)
    static let weekpickerMonthPrev = "weekpicker.nav.month.prev"
    static let weekpickerMonthNext = "weekpicker.nav.month.next"
    static let weekpickerYearPrev = "weekpicker.nav.year.prev"
    static let weekpickerYearNext = "weekpicker.nav.year.next"
    static let weekpickerNavTitle = "weekpicker.nav.title"
```

- [ ] **Step 5.2: Rework `WeekPickerSheet`.**
  - Add scroll-position state next to `viewModel`:

```swift
    /// Month id (`"yyyy-MM"`) the scroll body is anchored to, bound to
    /// `.scrollPosition(id:)`. Buttons write it (programmatic scroll);
    /// manual scrolling writes it back and `syncDisplayedMonth` keeps the
    /// nav title in step. Phase 31 (35)(36).
    @State private var scrolledMonthID: String?
```

  - `sheet` becomes:

```swift
        VStack(spacing: 0) {
            header
            divider
            monthNavBar
            divider
            scrollBody
        }
```

  - Add the nav bar (new `// MARK: - Month/year navigation` section):

```swift
    /// Explicit month/year navigation (Phase 31 #35): «/» step a year,
    /// ‹/› step a month, the centered label names the displayed month.
    /// Not scroll-only anymore — but scrolling still works and keeps the
    /// label in sync via `scrolledMonthID`.
    private var monthNavBar: some View {
        HStack(spacing: 2) {
            navButton(systemName: "chevron.left.2",
                      id: AccessibilityIDs.weekpickerYearPrev,
                      label: "Previous year",
                      enabled: viewModel.canStepBackward) { step(-12) }
            navButton(systemName: "chevron.left",
                      id: AccessibilityIDs.weekpickerMonthPrev,
                      label: "Previous month",
                      enabled: viewModel.canStepBackward) { step(-1) }

            Text(viewModel.displayedMonth?.title ?? " ")
                .font(font.font(at: 16, weight: .bold))
                .foregroundStyle(theme.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityIdentifier(AccessibilityIDs.weekpickerNavTitle)

            navButton(systemName: "chevron.right",
                      id: AccessibilityIDs.weekpickerMonthNext,
                      label: "Next month",
                      enabled: viewModel.canStepForward) { step(1) }
            navButton(systemName: "chevron.right.2",
                      id: AccessibilityIDs.weekpickerYearNext,
                      label: "Next year",
                      enabled: viewModel.canStepForward) { step(12) }
        }
        .padding(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
        .background(Color(red: 250 / 255, green: 246 / 255, blue: 233 / 255).opacity(0.85))
    }

    /// One chevron button in the nav bar. 32pt square hit target, ink3 when
    /// disabled at a window edge.
    private func navButton(systemName: String,
                           id: String,
                           label: String,
                           enabled: Bool,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(enabled ? theme.ink2 : theme.ink3.opacity(0.4))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityIdentifier(id)
        .accessibilityLabel(label)
    }

    /// Step the displayed month and scroll the grid to it. ±1 from the
    /// chevrons, ±12 from the year steppers; the view model clamps to the
    /// built window.
    private func step(_ deltaMonths: Int) {
        viewModel.stepMonth(by: deltaMonths)
        guard let id = viewModel.displayedMonth?.id else { return }
        if reduceMotion {
            scrolledMonthID = id
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                scrolledMonthID = id
            }
        }
    }
```

  - Replace `scrollBody` (LazyVStack + scrollPosition; the `ScrollViewReader`/`DispatchQueue` hack goes away — `.scrollPosition(id:)` handles both initial position and programmatic scrolls). PRESERVE the big sizing comment's intent: keep `.frame(maxWidth:.infinity, maxHeight:.infinity)` + `.layoutPriority(1)` directly on the `ScrollView` (that's what fixed the historical "scroll gesture dead" bug):

```swift
    /// Vertical scroll containing the ±24-month window. `LazyVStack` keeps
    /// 49 month sections affordable; `.scrollTargetLayout()` +
    /// `.scrollPosition(id:)` give month-granular two-way scroll control
    /// (nav bar ↔ manual scrolling). The `.frame(maxHeight: .infinity)` +
    /// `.layoutPriority(1)` MUST stay directly on the ScrollView — that is
    /// the fix for the historical "picker scroll gesture dead" bug (the
    /// scroll surface otherwise sizes to its content's natural height).
    private var scrollBody: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.months) { month in
                    MonthGridView(month: month,
                                  selectedWeekOffset: viewModel.selectedWeekOffset,
                                  onPick: handlePick)
                }

                footer
            }
            .scrollTargetLayout()
            .padding(.top, 8)
            .padding(.bottom, 14)
        }
        .scrollPosition(id: $scrolledMonthID, anchor: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .layoutPriority(1)
        .onAppear {
            // Re-anchor on the focus month every time the sheet opens
            // (replaces the old ScrollViewReader scrollTo-on-appear).
            scrolledMonthID = viewModel.displayedMonth?.id
        }
        .onChange(of: scrolledMonthID) { _, newID in
            guard let newID else { return }
            viewModel.syncDisplayedMonth(toID: newID)
        }
    }
```

  - Update the sheet's top doc comment ("5-month mini grid" → "±24-month grid with month/year nav").
- [ ] **Step 5.3: Build** (`xcodebuild build` same destination/flags, or just run Task 6's suite). Expected: compiles clean under Swift 6 strict concurrency.
- [ ] **Step 5.4: Commit.**

```bash
git add WeeklyPlanner/Features/WeekPicker/WeekPickerSheet.swift WeeklyPlanner/Accessibility/AccessibilityIDs.swift
git commit -m "feat(week-picker): month/year nav bar + lazy scroll over ±24-month window (Phase 31 #35 #36)"
```

---

### Task 6: Verification (superpowers:verification-before-completion)

- [ ] **Step 6.1:** Full unit suite (command in header). Expected: **all green**, count ≥ baseline + 8 new tests. Record the exact "Executed N tests" line.
- [ ] **Step 6.2:** Picker scroll end-to-end — run `testWeekPickerNavigatesToSelectedWeek` with `WP_IDLE_SECONDS=3` (command in header). This black-box test opens the picker and taps week-row +3; with the lazy window it proves rows exist/are hittable after the range change (the "known prior scroll bug" check). Expected: PASS. If it fails → `superpowers:systematic-debugging` (likely suspects: initial `scrollPosition` anchor, LazyVStack instantiation).
- [ ] **Step 6.3:** Scope audit: `git diff main --stat` — only `Features/WeekPicker/*`, `WeeklyPlannerTests/WeekPicker/*`, `Accessibility/AccessibilityIDs.swift` (+ this plan doc). `git diff main -- WeeklyPlanner/Accessibility/AccessibilityIDs.swift` shows additions only.
- [ ] **Step 6.4:** Mark task #2 completed; SendMessage report to team-lead (branch, worktree path, files, approach, year-boundary/DST results, deviations, exact test-count line).

---

## Self-Review (done at planning time)

1. **Spec coverage:** (34) Task 4 centered title ✓; (33) Task 4 weekday header + W## removal, weekend kept, presentation-only (model field survives, tested) ✓; (35) Task 2 API + Task 5 nav bar ✓; (36) Task 1 window + Task 5 lazy scroll ✓; red marker/blue wash/tap-dismiss untouched (`WeekRowView` states + `handlePick` unchanged) ✓; offset math at far months Task 3 ✓; prior scroll bug re-verified Task 6.2 + sizing modifiers preserved ✓; jump keeps `selectedWeekOffset` (tested) ✓.
2. **Placeholder scan:** one intentional note in Step 3.1 about writing the offset-0 assertion plainly — instruction is concrete. No TBDs.
3. **Type consistency:** `displayedMonth: PickerMonth?` / `jumpTo(year:month:) -> PickerMonth?` / `stepMonth(by:)` / `canStepForward/Backward` / `syncDisplayedMonth(toID:)` consistent across Tasks 2 and 5; `titleAlignment: TextAlignment` (Sendable-safe, unlike `Alignment`) consumed via `frameAlignment`; `weekdaySymbols: [String]` consumed by `weekdayHeader`; `showsWeekNumberColumn`/`accessibilityLabel(for:)` consistent across Tasks 4's test and impl.

**Known deviations to report:** initial scroll anchors the focus *month* to the top (was: focus *week* centered) — a consequence of month-granular `scrollPosition`; selected-week blue wash still marks the focus week. Weekday header moved from sticky-in-sheet to per-month (spec's file table assigns it to `MonthGridView`). VoiceOver row label changed from "Week 21" to "Week of May 11" (no UITest queried the old label).
