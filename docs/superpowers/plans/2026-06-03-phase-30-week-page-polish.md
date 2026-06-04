# Phase 30 — Week Page Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline, single teammate) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Hobonichi week spread events-first: no header counts, no "Week NN", enlarged date-range title + day numerals, events-only rows with a defined two-column overflow rule, "none" empty copy, no bottom date.

**Architecture:** All changes are presentation-layer inside `WeeklyPlanner/Features/WeekPage/`. The one new type is `WeekDayRowLayout`, a pure value type (in `WeekDayRow.swift`) that converts an event array into a column layout — this is where the overflow rule lives, and it is what the unit tests pin (this codebase tests views via exposed pure statics, never view introspection — see `DayPageHeaderTests`).

**Tech Stack:** SwiftUI, Swift 6 strict concurrency, XCTest (NOT Swift Testing), XcodeGen.

---

## Decisions locked against the mock (`docs/mock/paper-planner.jsx`)

**Overflow rule (#25, decided together with #26):** The mock's week row (jsx lines 1149–1214) is `minHeight: 56`, single full-width column, `overflow: hidden` — i.e. the mock silently clips after ~3 compact event lines (a `WeekEventEntry` line is ~18pt). Hiding the checklist (#26) hands that whole 3-line budget to events. The rule keeps the mock's 3-line row rhythm and replaces silent clipping with explicit horizontal use:

- **0 events** → italic `"none"` placeholder (#28).
- **1–3 events** → single full-width column (exactly the mock's layout).
- **4–6 events** → two side-by-side columns, **column-major** chronological order (read down the left column, then down the right; left column gets `ceil(n/2)`). Row stays ≤ 3 lines.
- **≥7 events** → 6 visible slots: first **5** events (left 3, right 2) + a `"+K more"` affordance as the right column's last line, `K = n − 5`. Non-interactive (new week-level interactions are out of scope).

**Constants:** `singleColumnMax = 3`, `overflowVisibleEventCap = 5`.

**`WeekEventEntry` unchanged:** titles already `lineLimit(1)` + tail-ellipsize, and the title is inked in the category color, so the entry degrades gracefully at half width. (Spec marked it REVIEW; reviewed, no change.)

**Header type sizes (#30):** date range becomes the only title — `font.font(at: 30, weight: .bold)`, `theme.ink`, text `"\(weekMeta.range), \(year)"` (e.g. "May 11 – 17, 2026"). Day numerals 28 → **32pt**.

**Pruning (#29):** `WeekPageHeader` loses `eventCount`/`openTaskCount` params; `WeekPageViewModel.eventCount`/`.openTaskCount` are deleted (only consumer was the header; confirmed by grep). `tasksByDay`/`toggleTask` STAY (task data is presentation-only untouched per pre-made decision). `WeekDayRow` loses `tasks` + `onToggleTask` (events-only is permanent). `WeekTaskEntry.swift` is kept on disk (spec says "gated out", not deleted) with a doc-note that it is currently unrendered.

**Accessibility:** week rows use `.accessibilityElement(children: .combine)` — removing task rows and the count Texts updates combined labels automatically; no stale "N events"/"tasks left" remains anywhere. Add `.accessibilityLabel("\(K) more events")` on the overflow text so VoiceOver doesn't read "+". `AccessibilityIDs.swift` untouched (Phase 27 UITests).

**Bottom date (#27):** delete the `PageNumber(date:)` element from `WeekPageView` only (the primitive stays — Day page uses it).

---

### Task 1: WeekPageHeaderTests — failing tests for #29/#30

**Files:**
- Create: `WeeklyPlannerTests/WeekPage/WeekPageHeaderTests.swift`

- [ ] **Step 1: Write the failing test file**

```swift
import XCTest
@testable import WeeklyPlanner

/// Phase 30 tweaks (29) + (30): the week header drops the "N events" /
/// "M tasks left" count lines and the "Week NN" label; the date range is
/// the single enlarged title. The title is exposed as a testable static
/// (no view-introspection dependency in this codebase).
@MainActor
final class WeekPageHeaderTests: XCTestCase {
    /// Saturday May 16, 2026 at noon — the standard planner test anchor.
    private static let anchor: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 5; c.day = 16; c.hour = 12
        return WeekMath.mondayCalendar().date(from: c) ?? Date()
    }()

    private func sampleMeta() -> WeekMeta {
        WeekMath.weekMeta(forOffset: 0, today: Self.anchor)
    }

    func testTitleHasNoWeekLabel() {
        let title = WeekPageHeader.title(weekMeta: sampleMeta(), year: 2026)
        XCTAssertFalse(title.contains("Week"),
                       "Phase 30 (30): the 'Week NN' label must be removed")
    }

    func testTitleIsDateRangeWithYear() {
        let meta = sampleMeta()
        let title = WeekPageHeader.title(weekMeta: meta, year: 2026)
        XCTAssertTrue(title.contains(meta.range), "date range is the title")
        XCTAssertTrue(title.contains("2026"), "year retained")
    }

    func testHeaderHasNoCountLines() {
        // Compile-time pin: the initializer no longer accepts counts. If
        // someone re-adds eventCount/openTaskCount params, this fails to
        // build — exactly the regression Phase 30 (29) forbids.
        _ = WeekPageHeader(weekMeta: sampleMeta(), year: 2026)

        let title = WeekPageHeader.title(weekMeta: sampleMeta(), year: 2026)
        XCTAssertFalse(title.lowercased().contains("events"),
                       "Phase 30 (29): no 'N events' line")
        XCTAssertFalse(title.lowercased().contains("tasks left"),
                       "Phase 30 (29): no 'M tasks left' line")
    }
}
```

- [ ] **Step 2: Regenerate the project and run the new suite — expect compile FAILURE**

Run: `xcodegen generate` then the test command (see Task 6 footer) filtered with `-only-testing:WeeklyPlannerTests/WeekPageHeaderTests`
Expected: build error — `WeekPageHeader` has no static `title` and requires `eventCount:`/`openTaskCount:`. That is the failing-first state.

### Task 2: WeekPageHeader — remove counts + "Week NN", enlarge range (#29, #30)

**Files:**
- Modify: `WeeklyPlanner/Features/WeekPage/WeekPageHeader.swift`

- [ ] **Step 1: Replace the header implementation**

Properties: delete `eventCount` + `openTaskCount` and their doc comments. Body: delete the `HStack`/`Spacer`/`rightColumn` wrapper — the title column stands alone. Delete `rightColumn`. Replace `leftColumn` with:

```swift
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Self.title(weekMeta: weekMeta, year: year))
                .font(font.font(at: 30, weight: .bold))
                .foregroundStyle(theme.ink)
                .padding(EdgeInsets(top: 14, leading: 44, bottom: 4, trailing: 18))

            underline
                .padding(EdgeInsets(top: 6, leading: 44, bottom: 0, trailing: 18))
        }
    }

    /// The header's single line of copy — the week's date range plus year,
    /// e.g. `"May 11 – 17, 2026"`. Static + internal so
    /// `WeekPageHeaderTests` can pin the no-"Week"/no-counts contract
    /// without view introspection (Phase 30, #29 + #30).
    static func title(weekMeta: WeekMeta, year: Int) -> String {
        "\(weekMeta.range), \(year)"
    }
```

Update the struct doc comment (no more counts/right column) and the `#Preview` (drop `eventCount:`/`openTaskCount:` arguments).

- [ ] **Step 2: Run WeekPageHeaderTests — expect PASS** (same command as Task 1 Step 2)

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Features/WeekPage/WeekPageHeader.swift WeeklyPlannerTests/WeekPage/WeekPageHeaderTests.swift
git commit -m "feat(week-page): date range is the enlarged header title, counts removed (Phase 30 #29 #30)"
```

(Build of the app target will momentarily break at `WeekPageView.swift:101` — fixed in Task 5; run only the filtered header test target compile? No: the test target links the app. So Tasks 2–5 must land before the filtered suites compile. Acceptable: do Steps as written, but defer ALL test runs to Task 5 Step 2 if the intermediate compile blocks. Keep commits atomic per task regardless.)

### Task 3: WeekDayRowTests — failing tests for #25/#26/#28/#30

**Files:**
- Create: `WeeklyPlannerTests/WeekPage/WeekDayRowTests.swift`

- [ ] **Step 1: Write the failing test file**

```swift
import XCTest
@testable import WeeklyPlanner

/// Phase 30 tweaks (25), (26), (28): the week row is events-only, empties
/// read "none", and event-heavy days split into two columns with a "+K more"
/// cap instead of clipping. The layout decision is a pure value type
/// (`WeekDayRowLayout`) so the rule is pinned without view introspection.
@MainActor
final class WeekDayRowTests: XCTestCase {
    /// Saturday May 16, 2026 — the standard planner test anchor.
    private static let anchor: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 5; c.day = 16; c.hour = 12
        return WeekMath.mondayCalendar().date(from: c) ?? Date()
    }()

    private func makeEvents(_ count: Int) -> [Event] {
        let calendar = WeekMath.mondayCalendar()
        return (0..<count).map { i in
            let start = calendar.date(byAdding: .hour, value: i, to: Self.anchor) ?? Self.anchor
            let end = calendar.date(byAdding: .hour, value: 1, to: start) ?? start
            return Event(title: "Event \(i)", start: start, end: end, category: .work)
        }
    }

    private func saturday() -> WeekDay {
        let days = WeekMath.weekDays(forOffset: 0, today: Self.anchor)
        return days.first { $0.idx == 5 } ?? days[0]
    }

    // MARK: - (28) empty day

    func testEmptyDayPlaceholderReadsNone() {
        XCTAssertEqual(WeekDayRow.emptyPlaceholder, "none",
                       "Phase 30 (28): empty days read 'none', not '—'")
        XCTAssertTrue(WeekDayRowLayout.compute(for: []).isEmpty)
    }

    // MARK: - (26) events-only

    func testTaskBearingDayRendersNoTaskRows() {
        // Compile-time pin: WeekDayRow no longer accepts tasks or a toggle
        // callback — a task-bearing day cannot render task rows because the
        // row has no channel for them (Phase 30, #26; events-only is the
        // permanent week-page default).
        _ = WeekDayRow(day: saturday(), events: makeEvents(1), isToday: false)

        // And a day whose only content is tasks lays out as empty → "none".
        XCTAssertTrue(WeekDayRowLayout.compute(for: []).isEmpty,
                      "tasks must not influence the week row layout")
    }

    // MARK: - (25) layout rule: 1–3 single column

    func testUpToThreeEventsStaySingleColumn() {
        for n in 1...3 {
            let layout = WeekDayRowLayout.compute(for: makeEvents(n))
            XCTAssertEqual(layout.leftColumn.count, n)
            XCTAssertTrue(layout.rightColumn.isEmpty, "n=\(n) is single column")
            XCTAssertEqual(layout.overflowCount, 0)
        }
    }

    // MARK: - (25) layout rule: 4–6 two columns, column-major

    func testFourToSixEventsSplitTwoColumnsColumnMajor() {
        let expected: [(n: Int, left: Int, right: Int)] = [(4, 2, 2), (5, 3, 2), (6, 3, 3)]
        for c in expected {
            let layout = WeekDayRowLayout.compute(for: makeEvents(c.n))
            XCTAssertEqual(layout.leftColumn.count, c.left, "n=\(c.n) left")
            XCTAssertEqual(layout.rightColumn.count, c.right, "n=\(c.n) right")
            XCTAssertEqual(layout.overflowCount, 0, "n=\(c.n) no overflow")
        }
        // Column-major: chronological order reads down-left then down-right.
        let five = makeEvents(5)
        let layout = WeekDayRowLayout.compute(for: five)
        XCTAssertEqual(layout.leftColumn.map(\.title), ["Event 0", "Event 1", "Event 2"])
        XCTAssertEqual(layout.rightColumn.map(\.title), ["Event 3", "Event 4"])
    }

    // MARK: - (25) layout rule: 7+ caps at 5 visible + overflow affordance

    func testEventHeavyDayCapsRowsAndShowsOverflow() {
        let layout = WeekDayRowLayout.compute(for: makeEvents(7))
        XCTAssertEqual(layout.leftColumn.count, 3)
        XCTAssertEqual(layout.rightColumn.count, 2)
        XCTAssertEqual(layout.overflowCount, 2, "7 events → 5 visible + '+2 more'")

        let heavy = WeekDayRowLayout.compute(for: makeEvents(12))
        XCTAssertEqual(heavy.leftColumn.count + heavy.rightColumn.count, 5,
                       "visible events cap at 5 when overflowing")
        XCTAssertEqual(heavy.overflowCount, 7)
    }

    func testOverflowLabel() {
        XCTAssertEqual(WeekDayRowLayout.overflowLabel(2), "+2 more")
        XCTAssertEqual(WeekDayRowLayout.overflowLabel(7), "+7 more")
    }
}
```

- [ ] **Step 2: Run — expect compile FAILURE** (`WeekDayRowLayout` / `emptyPlaceholder` don't exist; `WeekDayRow` still requires `tasks:`)

### Task 4: WeekDayRow — events-only + layout rule + "none" + bigger numerals

**Files:**
- Modify: `WeeklyPlanner/Features/WeekPage/WeekDayRow.swift`

- [ ] **Step 1: Implement**

1. Delete the `tasks` and `onToggleTask` properties (and doc comments). Update the struct doc comment: events-only (Phase 30 #26), "none" placeholder, two-column overflow.
2. Numeral: `font.font(at: 28, ...)` → `font.font(at: 32, weight: .bold)` (#30).
3. Add `static let emptyPlaceholder = "none"` with a doc comment referencing #28.
4. Replace `rightColumn` with:

```swift
    /// Flex right column. Either the day's events laid out per
    /// `WeekDayRowLayout` (single column up to 3, two columns 4–6, capped
    /// at 5 + "+K more" beyond — Phase 30 #25) or the italic "none"
    /// placeholder (#28). Tasks never render here (#26).
    @ViewBuilder
    private var rightColumn: some View {
        let layout = WeekDayRowLayout.compute(for: events)
        if layout.isEmpty {
            Text(Self.emptyPlaceholder)
                .font(font.font(at: 16, weight: .regular).italic())
                .foregroundStyle(theme.ink3)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if !layout.isTwoColumn {
            eventColumn(layout.leftColumn, overflowCount: 0)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .top, spacing: 10) {
                eventColumn(layout.leftColumn, overflowCount: 0)
                eventColumn(layout.rightColumn, overflowCount: layout.overflowCount)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// One vertical run of compact event entries; when `overflowCount > 0`
    /// the column ends with the non-interactive "+K more" affordance.
    private func eventColumn(_ events: [Event], overflowCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(events, id: \.id) { event in
                WeekEventEntry(event: event, onTap: { onTapEvent(event.id) })
            }
            if overflowCount > 0 {
                Text(WeekDayRowLayout.overflowLabel(overflowCount))
                    .font(font.font(at: 13, weight: .regular).italic())
                    .foregroundStyle(theme.ink3)
                    .accessibilityLabel("\(overflowCount) more events")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
```

5. Append the pure layout type at file scope (above the previews):

```swift
// MARK: - WeekDayRowLayout

/// Pure layout decision for a week row's events column (Phase 30, #25).
/// Chosen against `docs/mock/paper-planner.jsx`: the mock row is a 56pt-min,
/// single-column run that silently clips after ~3 compact lines. This keeps
/// that 3-line rhythm but spends the horizontal space instead of clipping:
/// 1–3 events → one column; 4–6 → two columns (column-major chronological);
/// 7+ → first 5 events + "+K more".
struct WeekDayRowLayout {
    /// Events rendered in the (always-present) left column.
    let leftColumn: [Event]
    /// Events rendered in the right column; empty in single-column mode.
    let rightColumn: [Event]
    /// How many events are hidden behind "+K more". 0 when everything fits.
    let overflowCount: Int

    /// Max events that render as a single full-width column (the mock's
    /// natural 3-line row height).
    static let singleColumnMax = 3
    /// Visible-event cap once a day overflows two full columns.
    static let overflowVisibleEventCap = 5

    var isEmpty: Bool { leftColumn.isEmpty }
    var isTwoColumn: Bool { !rightColumn.isEmpty }

    static func compute(for events: [Event]) -> WeekDayRowLayout {
        if events.count <= singleColumnMax {
            return .init(leftColumn: events, rightColumn: [], overflowCount: 0)
        }
        if events.count <= singleColumnMax * 2 {
            let mid = (events.count + 1) / 2
            return .init(leftColumn: Array(events[..<mid]),
                         rightColumn: Array(events[mid...]),
                         overflowCount: 0)
        }
        let visible = events.prefix(overflowVisibleEventCap)
        return .init(leftColumn: Array(visible.prefix(singleColumnMax)),
                     rightColumn: Array(visible.dropFirst(singleColumnMax)),
                     overflowCount: events.count - overflowVisibleEventCap)
    }

    /// `"+K more"` copy for the overflow affordance.
    static func overflowLabel(_ count: Int) -> String { "+\(count) more" }
}
```

6. Fix the `#Preview`: drop `tasks:`/`onToggleTask:` arguments and the `TaskItem`; add an event-heavy preview day (7 events) to eyeball the overflow rule.

- [ ] **Step 2: Run WeekDayRowTests — expect PASS** (may require Task 5 first for the target to compile)

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Features/WeekPage/WeekDayRow.swift WeeklyPlannerTests/WeekPage/WeekDayRowTests.swift
git commit -m "feat(week-page): events-only rows with two-column overflow rule, 'none' empties, 32pt numerals (Phase 30 #25 #26 #28 #30)"
```

### Task 5: WeekPageView + WeekPageViewModel + WeekTaskEntry — wiring, pruning, bottom date

**Files:**
- Modify: `WeeklyPlanner/Features/WeekPage/WeekPageView.swift`
- Modify: `WeeklyPlanner/Features/WeekPage/WeekPageViewModel.swift`
- Modify: `WeeklyPlanner/Features/WeekPage/WeekTaskEntry.swift` (doc comment only)
- Modify: `WeeklyPlannerTests/WeekPage/WeekPageViewModelTests.swift`

- [ ] **Step 1: WeekPageView**

1. In `content(...)`, the header call becomes `WeekPageHeader(weekMeta: weekMeta, year: year)`.
2. The `WeekDayRow(...)` call drops `tasks:` and `onToggleTask:` arguments.
3. Delete the `PageNumber(date: ...)` element and its `.frame(...)` modifier from the ZStack (#27). Update the struct doc comment ("page-number footer" mention).

- [ ] **Step 2: WeekPageViewModel — prune dead count plumbing (#29)**

Delete the `eventCount` and `openTaskCount` computed properties (sole consumer was the header — verified by grep). Keep `tasksByDay` + `toggleTask` (task data untouched; presentation-only change). Update the class doc comment if it mentions the counts.

- [ ] **Step 3: WeekTaskEntry — doc note**

Top doc comment gains: "As of Phase 30 (#26) the week spread is events-only, so this row is no longer rendered there; it is retained for previews and any future task surface."

- [ ] **Step 4: WeekPageViewModelTests — replace count tests with grouping coverage**

Delete `testTaskCountExcludesDone` and `testEventCountIsTotal` (they pin the pruned properties). Add, in the Tasks MARK section, a grouping test so task bucketing keeps direct coverage:

```swift
    /// Tasks should land in the Monday-based weekday bucket of their due
    /// date, sorted high-priority-first. (The week UI no longer renders
    /// tasks — Phase 30 #26 — but the data layer is untouched.)
    func testTasksGroupedByDayIndex() async throws {
        let satLow = TaskItem(title: "Water plants",
                              due: Self.may16_2026(hour: 9),
                              done: false,
                              priority: .low,
                              category: .personal)
        let satHigh = TaskItem(title: "Buy gift for Sara",
                               due: Self.may16_2026(hour: 10),
                               done: false,
                               priority: .high,
                               category: .family)
        let mon = TaskItem(title: "File expenses",
                           due: Self.may11_2026(hour: 9),
                           done: false,
                           priority: .med,
                           category: .work)
        try await taskStore.upsert(satLow)
        try await taskStore.upsert(satHigh)
        try await taskStore.upsert(mon)

        let vm = makeViewModel()
        await vm.refresh()

        XCTAssertEqual(vm.tasksByDay[5]?.count, 2)
        XCTAssertEqual(vm.tasksByDay[0]?.count, 1)
        XCTAssertEqual(vm.tasksByDay[5]?.first?.title, "Buy gift for Sara",
                       "high priority sorts first")
    }
```

- [ ] **Step 5: Regenerate + run all WeekPage suites**

Run: `xcodegen generate`, then the test command (Task 6 footer) with `-only-testing:WeeklyPlannerTests/WeekPageHeaderTests -only-testing:WeeklyPlannerTests/WeekDayRowTests -only-testing:WeeklyPlannerTests/WeekPageViewModelTests`
Expected: ALL PASS.

- [ ] **Step 6: Commit**

```bash
git add WeeklyPlanner/Features/WeekPage/ WeeklyPlannerTests/WeekPage/
git commit -m "feat(week-page): drop header-count plumbing, task wiring, and bottom date (Phase 30 #27 #29)"
```

### Task 6: Full-suite verification (superpowers:verification-before-completion)

- [ ] **Step 1: Run the FULL unit suite**

```bash
xcodegen generate
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=<available iPhone, iOS 26.5>' \
  -only-testing:WeeklyPlannerTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO
```

Expected: `** TEST SUCCEEDED **`, ~387+ tests, 0 failures (Phase 21 accessibility audit included). Pick the device from `xcrun simctl list devices available`.

- [ ] **Step 2: Spec checklist sweep** — re-read `docs/phases/phase-30-week-page-polish.md` checkboxes against the diff; confirm today-row yellow fade + red-ink left column untouched (we did not touch `todayBackground`/`leftColumn` color logic).

- [ ] **Step 3: Report** — TaskUpdate #1 → completed; SendMessage to team-lead (branch, worktree, files, overflow rule + rationale, deviations, final test line).

---

## Self-review notes

- Spec coverage: #25 (Task 4 layout), #26 (Tasks 3–5), #27 (Task 5 Step 1.3), #28 (Task 4), #29 (Tasks 1–2, 5), #30 (Tasks 2 header 30pt + Task 4 numeral 32pt). Today-row styling untouched (verified — no edits to `todayBackground`). Accessibility: combined labels self-update; overflow label override added; `AccessibilityIDs.swift` untouched.
- Type consistency: `WeekDayRowLayout.compute(for:)`, `.overflowLabel(_:)`, `WeekDayRow.emptyPlaceholder`, `WeekPageHeader.title(weekMeta:year:)` used identically in tests (Tasks 1, 3) and impl (Tasks 2, 4).
- Known intermediate state: the app target won't compile between Tasks 2 and 5 (call-site arity). Commits stay atomic per task; test runs that need a compiling target are deferred to Task 5 Step 5.
