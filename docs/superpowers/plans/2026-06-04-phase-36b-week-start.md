# Phase 36b — Week-Start Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** "Week starts on" supports **all seven days** (suggestion 45) and actually re-lays the Day page, Week page, side tabs, and Week Picker — today the toggle exists but every one of ~50 call sites hardcodes `mondayCalendar()` (and `WeekMath.mondayOfWeek` contains a dead branch where both sides of the `if` are identical).

**Architecture:** A `WeekStartDay` enum (raw = `Calendar.firstWeekday`, 1=Sun…7=Sat) and `WeekMath.calendar(startingOn:)`. A process-global `WeekMath.preferredCalendar` (default Monday) becomes the default `calendar:` parameter — set from `UserSettings` at app startup and on change (AppShell bumps a layout epoch to rebuild week-anchored views). The Monday-hardcoded weekday-index formula `(weekday + 5) % 7` generalizes to `(weekday - calendar.firstWeekday + 7) % 7` (identical for Monday). Production call sites that spell `WeekMath.mondayCalendar()` explicitly are swept to `preferredCalendar`; previews and test fixtures stay explicitly Monday for determinism.

**Persistence/migration:** new `UserSettings.weekStartRaw: Int = 0` (0 = unset sentinel); accessor falls back to the legacy `weekStartsOnMonday` Bool, so existing installs keep their choice.

**Tech Stack:** Foundation `Calendar`, SwiftData, SwiftUI, XCTest, XcodeGen.

**User decision (2026-06-04):** own plan (this one), all seven days, still ships this milestone.

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `WeeklyPlanner/Stores/WeekMath.swift` | MODIFY | `WeekStartDay`, `calendar(startingOn:)`, `preferredCalendar`, generalized `startOfWeek`, rotating initials |
| `WeeklyPlanner/Models/Event.swift` | MODIFY | generalize `weekdayIndex(in:)` |
| `WeeklyPlanner/Features/DayPage/DayPageViewModel.swift` | MODIFY | generalize `mondayBasedWeekdayIndex` copy |
| `WeeklyPlanner/Features/WeekPage/WeekPageViewModel.swift` | MODIFY | generalize duplicate copy |
| `WeeklyPlanner/Models/TaskItem.swift` | MODIFY | generalize `startOfWeekMondayBased`-based `weekOffset` |
| `WeeklyPlanner/Models/UserSettings.swift` | MODIFY | `weekStartRaw` + `weekStart` accessor w/ legacy fallback |
| `WeeklyPlanner/Features/Settings/SettingsViewModel.swift` | MODIFY | `weekStart` + `setWeekStart` (replaces the Bool) |
| week-start row in `Features/Settings/` (grep `Week starts`) | MODIFY | 7-day Menu |
| `WeeklyPlanner/WeeklyPlannerApp.swift` | MODIFY | seed `preferredCalendar` before first layout |
| `WeeklyPlanner/Navigation/AppShell.swift` | MODIFY | onChange → re-seed + epoch rebuild |
| ~18 production call sites (table in Task 6) | MODIFY | literal `mondayCalendar()` → `preferredCalendar` |
| `WeeklyPlanner/Features/WeekPicker/MonthGridView.swift` | MODIFY | weekday header rotates |
| `WeeklyPlanner/Features/WeekPicker/WeekPickerViewModel.swift` | MODIFY | (sweep) week construction follows preference |
| `WeeklyPlannerTests/Stores/WeekMathTests.swift` | MODIFY | parameterized start-day coverage |
| `WeeklyPlannerTests/Models/WeekdayIndexTests.swift` | NEW | index formula across calendars |
| `WeeklyPlannerTests/...Settings...` | MODIFY | weekStart defaults/migration/persistence |
| `WeeklyPlannerTests/WeekPicker/WeekPickerViewModelTests.swift` | MODIFY | sunday-start offsets + year boundary |
| `WeeklyPlannerUITests/WeekStartUITests.swift` | NEW | flip to Sunday → week re-lays |

**Canonical test command** ("the test command"; device from `xcrun simctl list devices available`):

```bash
xcodegen generate
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=<available iPhone, iOS 26.5>' \
  -only-testing:<filter> \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO
```

**Global-state test rule:** any test that mutates `WeekMath.preferredCalendar` MUST reset it in `tearDown` (`WeekMath.preferredCalendar = WeekMath.mondayCalendar()`). Prefer passing `calendar:` explicitly. (Unit-test classes run serially within the target by default; do not enable parallel testing for these.)

---

### Task 1: `WeekStartDay` + generalized `WeekMath`

**Files:**
- Modify: `WeeklyPlanner/Stores/WeekMath.swift`
- Test: extend `WeeklyPlannerTests/Stores/WeekMathTests.swift`

- [ ] **Step 1: Write the failing tests** (append; the class already has a `may16_2026()` helper — May 16 2026 is a **Saturday**)

```swift
    func testSundayStartWeekOnMay16_2026() {
        let cal = WeekMath.sundayCalendar()
        let week = WeekMath.weekDays(forOffset: 0, calendar: cal, today: Self.may16_2026())

        XCTAssertEqual(week.first?.weekdayShort, "Sun")
        XCTAssertEqual(week.first?.dayNumber, 10)
        XCTAssertEqual(week.last?.weekdayShort, "Sat")
        XCTAssertEqual(week.last?.dayNumber, 16)
        XCTAssertEqual(WeekMath.todayIndex(in: week, for: Self.may16_2026(), calendar: cal), 6)
        XCTAssertEqual(week.map(\.weekdayInitial), ["S", "M", "T", "W", "T", "F", "S"])
    }

    func testSaturdayStartWeekOnMay16_2026() {
        let cal = WeekMath.calendar(startingOn: .saturday)
        let week = WeekMath.weekDays(forOffset: 0, calendar: cal, today: Self.may16_2026())

        XCTAssertEqual(week.first?.weekdayShort, "Sat")
        XCTAssertEqual(week.first?.dayNumber, 16, "Today IS the week start")
        XCTAssertEqual(week.last?.weekdayShort, "Fri")
        XCTAssertEqual(week.last?.dayNumber, 22)
        XCTAssertEqual(WeekMath.todayIndex(in: week, for: Self.may16_2026(), calendar: cal), 0)
        XCTAssertEqual(week.map(\.weekdayInitial), ["S", "S", "M", "T", "W", "T", "F"])
    }

    func testEveryStartDayProducesSevenConsecutiveDaysContainingToday() {
        for day in WeekStartDay.allCases {
            let cal = WeekMath.calendar(startingOn: day)
            let week = WeekMath.weekDays(forOffset: 0, calendar: cal, today: Self.may16_2026())

            XCTAssertEqual(week.count, 7, "\(day)")
            XCTAssertEqual(cal.component(.weekday, from: week[0].date), day.rawValue,
                           "\(day): week must begin on its start day")
            XCTAssertNotNil(WeekMath.todayIndex(in: week, for: Self.may16_2026(), calendar: cal), "\(day)")
            for index in 1 ..< 7 {
                let gap = cal.dateComponents([.day], from: week[index - 1].date, to: week[index].date).day
                XCTAssertEqual(gap, 1, "\(day): days must be consecutive")
            }
        }
    }

    func testOffsetMathStableAcrossYearBoundarySundayStart() {
        // Wed Dec 30 2026; Sunday-start week = Dec 27 2026 – Jan 2 2027.
        var c = DateComponents(); c.year = 2026; c.month = 12; c.day = 30; c.hour = 12
        let today = WeekMath.mondayCalendar().date(from: c)!
        let cal = WeekMath.sundayCalendar()

        let thisWeek = WeekMath.weekDays(forOffset: 0, calendar: cal, today: today)
        XCTAssertEqual(thisWeek.first?.dayNumber, 27)
        XCTAssertEqual(thisWeek.last?.dayNumber, 2)

        let nextWeek = WeekMath.weekDays(forOffset: 1, calendar: cal, today: today)
        XCTAssertEqual(nextWeek.first?.dayNumber, 3)
        XCTAssertEqual(nextWeek.first?.year, 2027)
    }

    func testPreferredCalendarDefaultsToMonday() {
        XCTAssertEqual(WeekMath.preferredCalendar.firstWeekday, 2)
    }

    func testWeekStartDayDisplayNames() {
        XCTAssertEqual(WeekStartDay.allCases.map(\.displayName),
                       ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"])
    }
```

- [ ] **Step 2: Run to verify failure** — `-only-testing:WeeklyPlannerTests/WeekMathTests`. Expected: compile failure (`WeekStartDay`, `calendar(startingOn:)`, `weekdayInitial` rotation missing).

- [ ] **Step 3: Implement in `WeekMath.swift`:**

3.1 — Add the enum (top of the file, above `enum WeekMath`):

```swift
/// User-selectable week start (Phase 36b). Raw value == `Calendar.firstWeekday`
/// (1 = Sunday … 7 = Saturday) so it threads straight into Calendar.
enum WeekStartDay: Int, CaseIterable, Codable, Sendable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var displayName: String {
        switch self {
        case .sunday: "Sunday"
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        }
    }
}
```

3.2 — Calendar factories + the process-global preference (replace `mondayCalendar`/`sundayCalendar` bodies):

```swift
    /// Calendar for an arbitrary week start.
    static func calendar(startingOn day: WeekStartDay) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = day.rawValue
        cal.minimumDaysInFirstWeek = 4
        return cal
    }

    /// Calendar configured to start weeks on Monday. ISO 8601 in spirit.
    static func mondayCalendar() -> Calendar { calendar(startingOn: .monday) }

    /// Calendar configured to start weeks on Sunday.
    static func sundayCalendar() -> Calendar { calendar(startingOn: .sunday) }

    /// Process-wide week-start preference (Phase 36b). Seeded from
    /// `UserSettings.weekStart` in `WeeklyPlannerApp` before first layout
    /// and re-set by `AppShell` when the setting changes. Main-actor
    /// confined by convention (app shell writes; UI/store reads); tests
    /// that mutate it MUST reset to `mondayCalendar()` in tearDown.
    nonisolated(unsafe) static var preferredCalendar: Calendar = WeekMath.mondayCalendar()
```

(If the project's strict-concurrency settings reject `nonisolated(unsafe)`, use `@MainActor static var` and adjust the two non-UI readers to hop accordingly — but try `nonisolated(unsafe)` first.)

3.3 — Change BOTH default parameters from `mondayCalendar()` to `preferredCalendar` in `weekDays(forOffset:calendar:today:)`, `weekMeta(forOffset:today:calendar:)`, and `todayIndex(in:for:calendar:)`:

```swift
                         calendar: Calendar = preferredCalendar,
```

3.4 — Replace `mondayOfWeek(containing:offsetBy:calendar:)` (the one with the dead branch) with the generalized version, and update its two call sites (`weekDays`, `weekMeta`):

```swift
    private static func startOfWeek(containing date: Date, offsetBy weeks: Int, calendar: Calendar) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        // Days since the calendar's first weekday. For Monday-start
        // (firstWeekday == 2) this is the old `(weekday + 5) % 7`.
        let daysSinceStart = (weekday - calendar.firstWeekday + 7) % 7
        let weekStart = calendar.date(byAdding: .day, value: -daysSinceStart, to: startOfDay) ?? startOfDay
        return calendar.date(byAdding: .day, value: weeks * 7, to: weekStart) ?? weekStart
    }
```

3.5 — Rotate the initials (and widen access so the Week Picker header can reuse it; pass the calendar at the `weekDays` call site):

```swift
    /// Single-letter weekday initial for column `idx` of a week that
    /// starts on `calendar.firstWeekday`.
    static func weekdayInitial(for idx: Int, calendar: Calendar) -> String {
        // Calendar.weekday order: 1=Sun … 7=Sat.
        let base = ["S", "M", "T", "W", "T", "F", "S"]
        return base[(calendar.firstWeekday - 1 + idx) % 7]
    }
```

In `weekDays`, the `WeekDay` construction changes to `weekdayInitial: weekdayInitial(for: idx, calendar: calendar)`.

3.6 — Update the file-top doc comment (it references "Monday-based by default … `weekStartsOnMonday == true`") to describe `preferredCalendar`.

- [ ] **Step 4: Run to verify pass**

Run: `-only-testing:WeeklyPlannerTests/WeekMathTests`
Expected: PASS — all NEW tests green AND every pre-existing Monday-based test untouched-green (the generalized formula is identity for Monday — if any old test breaks, the generalization is wrong; stop and fix).

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Stores/WeekMath.swift WeeklyPlannerTests/Stores/WeekMathTests.swift
git commit -m "feat(week-start): WeekStartDay + calendar(startingOn:) + preferredCalendar; generalize start-of-week (Phase 36b #45)"
```

---

### Task 2: Generalize the weekday-index helpers

**Files:**
- Modify: `WeeklyPlanner/Models/Event.swift` (`weekdayIndex(in:)`)
- Modify: `WeeklyPlanner/Features/DayPage/DayPageViewModel.swift` (the `Date.mondayBasedWeekdayIndex` extension, ~line 312)
- Modify: `WeeklyPlanner/Features/WeekPage/WeekPageViewModel.swift` (duplicate extension, ~line 148)
- Modify: `WeeklyPlanner/Models/TaskItem.swift` (`weekOffset(from:calendar:)` / `startOfWeekMondayBased`)
- Test: `WeeklyPlannerTests/Models/WeekdayIndexTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import WeeklyPlanner

final class WeekdayIndexTests: XCTestCase {
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d; c.hour = 12
        return WeekMath.mondayCalendar().date(from: c)!
    }

    func testEventWeekdayIndexFollowsCalendarFirstWeekday() {
        // Sun May 10 2026 / Mon May 11 2026.
        let sundayEvent = Event(title: "Sun", start: date(2026, 5, 10),
                                end: date(2026, 5, 10).addingTimeInterval(3600), category: .personal)
        let mondayEvent = Event(title: "Mon", start: date(2026, 5, 11),
                                end: date(2026, 5, 11).addingTimeInterval(3600), category: .personal)

        let monCal = WeekMath.mondayCalendar()
        XCTAssertEqual(sundayEvent.weekdayIndex(in: monCal), 6)
        XCTAssertEqual(mondayEvent.weekdayIndex(in: monCal), 0)

        let sunCal = WeekMath.sundayCalendar()
        XCTAssertEqual(sundayEvent.weekdayIndex(in: sunCal), 0)
        XCTAssertEqual(mondayEvent.weekdayIndex(in: sunCal), 1)

        let satCal = WeekMath.calendar(startingOn: .saturday)
        XCTAssertEqual(sundayEvent.weekdayIndex(in: satCal), 1)
        XCTAssertEqual(mondayEvent.weekdayIndex(in: satCal), 2)
    }

    func testTaskWeekOffsetRespectsWeekBoundary() {
        // Base Sat May 16 2026. Due Sun May 17:
        //   Monday-start  → same week (offset 0)
        //   Sunday-start  → next week (offset 1)
        let task = TaskItem(title: "t", due: date(2026, 5, 17), category: .personal)

        XCTAssertEqual(task.weekOffset(from: date(2026, 5, 16), calendar: WeekMath.mondayCalendar()), 0)
        XCTAssertEqual(task.weekOffset(from: date(2026, 5, 16), calendar: WeekMath.sundayCalendar()), 1)
    }
}
```

⚠️ Match `TaskItem.weekOffset`'s actual signature/param labels (the inventory shows `weekOffset(from:calendar:)` calling a `startOfWeekMondayBased(for:)` helper).

- [ ] **Step 2: Run to verify failure** — `-only-testing:WeeklyPlannerTests/WeekdayIndexTests`. Expected: the non-Monday assertions FAIL (formula hardcodes `+5`).

- [ ] **Step 3: Implement.** In all FOUR locations, replace the body `(weekday + 5) % 7` with the generalized formula (keep the existing function names to avoid churn; fix the doc comments):

```swift
        // Index of this date's weekday relative to the calendar's first
        // weekday (0 = week start). For Monday-start calendars this is the
        // historical `(weekday + 5) % 7`.
        (weekday - calendar.firstWeekday + 7) % 7
```

For `TaskItem`: the `startOfWeekMondayBased(for:)` helper generalizes the same way (it derives "days since week start"); rename ONLY its doc comment, not its symbol, unless the symbol is private to the file (then renaming to `startOfWeek(for:)` is free — do it).

- [ ] **Step 4: Run to verify pass**

Run: `-only-testing:WeeklyPlannerTests/WeekdayIndexTests -only-testing:WeeklyPlannerTests/DayPageViewModelTests -only-testing:WeeklyPlannerTests/WeekPageViewModelTests`
Expected: PASS — new green, old Monday-based behavior untouched.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Models/ WeeklyPlanner/Features/DayPage/DayPageViewModel.swift WeeklyPlanner/Features/WeekPage/WeekPageViewModel.swift WeeklyPlannerTests/Models/WeekdayIndexTests.swift
git commit -m "feat(week-start): generalize weekday-index math to any firstWeekday (Phase 36b #45)"
```

---

### Task 3: Settings persistence + view model

**Files:**
- Modify: `WeeklyPlanner/Models/UserSettings.swift`
- Modify: `WeeklyPlanner/Features/Settings/SettingsViewModel.swift`
- Test: extend `WeeklyPlannerTests/Features/Settings/SettingsViewModelTests.swift`

- [ ] **Step 1: Write the failing tests** (replace the old Bool-based tests):

```swift
    func testDefaultWeekStartIsMonday() throws {
        let vm = SettingsViewModel(store: store)
        XCTAssertEqual(vm.weekStart, .monday)
    }

    func testSettingWeekStartPersists() throws {
        let vm = SettingsViewModel(store: store)
        vm.setWeekStart(.saturday)
        XCTAssertEqual(vm.weekStart, .saturday)
        XCTAssertEqual(try store.current().weekStart, .saturday)
        XCTAssertEqual(try store.current().weekStartRaw, 7)
    }

    func testLegacySundayBoolMigratesWhenRawUnset() throws {
        // Pre-36b installs persisted only the Bool.
        try store.update {
            $0.weekStartsOnMonday = false
            $0.weekStartRaw = 0
        }
        let vm = SettingsViewModel(store: store)
        XCTAssertEqual(vm.weekStart, .sunday)
    }
```

Also update `testDefaultsAfterFreshInstall`: replace `XCTAssertTrue(vm.weekStartsOnMonday)` with `XCTAssertEqual(vm.weekStart, .monday)`, and delete `testSettingWeekStartToSundayPersists` (superseded).

- [ ] **Step 2: Run to verify failure** — `-only-testing:WeeklyPlannerTests/SettingsViewModelTests`. Expected: compile failure.

- [ ] **Step 3: Implement.**

`UserSettings.swift` — stored property after `weekStartsOnMonday` (keep the Bool for legacy rows; mark its doc comment "legacy — superseded by `weekStartRaw` (Phase 36b); kept for migration"):

```swift
    /// Week-start day as `Calendar.firstWeekday` raw (1 = Sunday …
    /// 7 = Saturday). `0` = unset → fall back to the legacy
    /// `weekStartsOnMonday` (Phase 36b migration).
    var weekStartRaw: Int = 0
```

Init: add parameter `weekStartRaw: Int = 0` next to `weekStartsOnMonday` and assign it. Typed accessor in the existing `extension UserSettings`:

```swift
    var weekStart: WeekStartDay {
        get {
            if let day = WeekStartDay(rawValue: weekStartRaw) { return day }
            return weekStartsOnMonday ? .monday : .sunday
        }
        set { weekStartRaw = newValue.rawValue }
    }
```

`SettingsViewModel.swift` — replace the Bool property + setter:

```swift
    var weekStart: WeekStartDay
```

(init: `weekStart = settings.weekStart`)

```swift
    func setWeekStart(_ day: WeekStartDay) {
        weekStart = day
        try? store.update { $0.weekStart = day }
    }
```

Delete `weekStartsOnMonday` + `setWeekStartsOnMonday` from the VM and fix their references (the settings row — rewired in Task 4 anyway; grep `weekStartsOnMonday` across `WeeklyPlanner/` to catch any other reader).

- [ ] **Step 4: Run to verify pass** — `-only-testing:WeeklyPlannerTests/SettingsViewModelTests`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Models/UserSettings.swift WeeklyPlanner/Features/Settings/SettingsViewModel.swift WeeklyPlannerTests/Features/Settings/SettingsViewModelTests.swift
git commit -m "feat(week-start): weekStartRaw persistence with legacy Bool migration (Phase 36b #45)"
```

---

### Task 4: Settings UI — 7-day picker row

**Files:**
- Modify: the week-start row (grep `"Week starts"` under `WeeklyPlanner/Features/Settings/` — it currently binds `viewModel.weekStartsOnMonday`)

- [ ] **Step 1: Replace the row's control** with a Menu, keeping the row's existing label/divider chrome:

```swift
            HStack(spacing: 12) {
                Text("Week starts on")
                    .font(font.font(at: 17 * size.scale, weight: .regular))
                    .foregroundStyle(theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Menu {
                    ForEach(WeekStartDay.allCases, id: \.self) { day in
                        Button(day.displayName) { viewModel.setWeekStart(day) }
                    }
                } label: {
                    Text(viewModel.weekStart.displayName)
                        .font(font.font(at: 15 * size.scale, weight: .regular))
                        .foregroundStyle(theme.blueInk)
                }
                .tint(theme.blueInk)
                .accessibilityLabel("Week starts on")
                .accessibilityValue(viewModel.weekStart.displayName)
                .accessibilityIdentifier("settings.weekstart.menu")
            }
            .padding(.vertical, 11)
```

(Adapt paddings/divider to the surrounding preference rows — match siblings exactly; the Menu + identifier + setter call are the fixed parts.)

- [ ] **Step 2: Compile check** — run `-only-testing:WeeklyPlannerTests/SettingsViewModelTests`. Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Features/Settings/
git commit -m "feat(week-start): 7-day week-start menu in Settings preferences (Phase 36b #45)"
```

---

### Task 5: Seed + propagate the preference

**Files:**
- Modify: `WeeklyPlanner/WeeklyPlannerApp.swift`
- Modify: `WeeklyPlanner/Navigation/AppShell.swift`

- [ ] **Step 1: Seed BEFORE first layout.** `AppShell.init` computes today's flip target via `WeekMath` (lines ~64–65), so the preference must be set earlier — in `WeeklyPlannerApp.init`, right after the settings store is constructed (it already builds stores there per the Phase 18 wiring):

```swift
        // Phase 36b: week-start preference must be live before AppShell's
        // first WeekMath call.
        let storedWeekStart = (try? settingsStore.current().weekStart) ?? .monday
        WeekMath.preferredCalendar = WeekMath.calendar(startingOn: storedWeekStart)
```

(Use the actual settings-store property name in that file.)

- [ ] **Step 2: React to changes.** In `AppShell` (it already has `@Query private var settingsRows: [UserSettings]`):

```swift
    @State private var weekLayoutEpoch = 0
```

```swift
        .onChange(of: settingsRows.first?.weekStartRaw) { _, _ in
            applyWeekStartPreference()
        }
```

```swift
    private func applyWeekStartPreference() {
        let day = settingsRows.first?.weekStart ?? .monday
        WeekMath.preferredCalendar = WeekMath.calendar(startingOn: day)
        // Week-anchored state (flip coordinates, cached week arrays) is
        // derived from the old calendar — rebuild the calendar tab wholesale.
        // A week-start change is rare; a full rebuild is the correct cost.
        weekLayoutEpoch += 1
    }
```

and tag the calendar tab content (where `calendarTab` is rendered in the routing switch):

```swift
            case .calendar:
                calendarTab
                    .id(weekLayoutEpoch)
```

- [ ] **Step 3: Manual smoke** — build & run; flip Settings → Week starts on → Saturday; switch to Calendar: the Week page's first row and the side tabs must start on Saturday, today-highlight intact. Flip back to Monday.

- [ ] **Step 4: Commit**

```bash
git add WeeklyPlanner/WeeklyPlannerApp.swift WeeklyPlanner/Navigation/AppShell.swift
git commit -m "feat(week-start): seed preferredCalendar at launch + epoch rebuild on change (Phase 36b #45)"
```

---

### Task 6: Sweep explicit `mondayCalendar()` production call sites

**Files:** the table below (inventory snapshot 2026-06-04 — **re-grep before editing**; Phases 33–35 may have added sites: `grep -rn "WeekMath.mondayCalendar()" WeeklyPlanner/`).

Replace `let calendar = WeekMath.mondayCalendar()` (and inline uses) with `let calendar = WeekMath.preferredCalendar` at:

| File | Line (≈) | Context |
|---|---|---|
| `Features/DayPage/DayPageViewModel.swift` | 128 | day-level event filtering |
| `Features/DayPage/InboxBlock.swift` | 105 | inbox filtering |
| `Features/DayPage/InboxSuggestionRow.swift` | 142 | suggestion date alignment |
| `Features/DayPage/TodoBlock.swift` | 119 | task filtering |
| `Features/DayPage/TodoRow.swift` | 174 | task date extraction |
| `Features/DayPage/EventEntryList.swift` | 70 | event filtering |
| `Features/DayPage/EventEntryRow.swift` | 133 | event date extraction |
| `Features/WeekPage/WeekPageViewModel.swift` | 84 | bucket-by-day grouping |
| `Features/WeekPage/WeekDayRow.swift` | 202 | cell date indexing |
| `Features/WeekPage/WeekEventEntry.swift` | 111 | entry time/date |
| `Features/WeekPage/WeekTaskEntry.swift` | 117 | entry date |
| `Features/WeekPicker/WeekPickerViewModel.swift` | 127, 185 | month/week construction |
| `Features/Review/PaperReviewView.swift` | 92 | week grouping |
| `Features/EventDetail/EventHeader.swift` | 166 | date extraction |
| `Features/EventDetail/PaperEventSheet.swift` | 115, 432 | start alignment / date handling |
| `Stores/EventStore.swift` | 113 | `weekBounds` query window |

**Leave Monday-explicit (determinism):** all `#Preview` blocks (`DayPageHeader.swift:158`, `SideTabs.swift:56`, `WeekPageHeader.swift:89`, `WeekDayRow.swift:208`, `BookTopBar` previews) and every test fixture (`EventStoreTests.may16_2026` etc.).

**If Phase 35 already landed:** also sweep the `WeekMath.mondayCalendar()` passed to `OccurrenceExpander` in `SwiftDataEventStore.events(forWeekOffset:)` and in `EventNotificationScheduler.schedule` — recurring expansion must follow the same week preference as the query window.

- [ ] **Step 1: Re-grep, apply the sweep** (mechanical; keep each diff line minimal).

- [ ] **Step 2: FULL unit suite**

Run: the test command with `-only-testing:WeeklyPlannerTests`
Expected: `** TEST SUCCEEDED **` — every existing test still passes because `preferredCalendar` defaults to Monday in the test process.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/
git commit -m "refactor(week-start): production call sites read WeekMath.preferredCalendar (Phase 36b #45)"
```

---

### Task 7: Week Picker rotation

**Files:**
- Modify: `WeeklyPlanner/Features/WeekPicker/MonthGridView.swift` (weekday header)
- Test: extend `WeeklyPlannerTests/WeekPicker/WeekPickerViewModelTests.swift`

- [ ] **Step 1: Write the failing tests** (mutating the global → reset in tearDown, per the plan-top rule):

```swift
    override func tearDown() {
        WeekMath.preferredCalendar = WeekMath.mondayCalendar()
        super.tearDown()
    }

    func testSundayStartWeeksBeginOnSunday() {
        WeekMath.preferredCalendar = WeekMath.sundayCalendar()
        let vm = makeViewModel() // the file's existing factory/fixture
        let firstWeek = vm.months.first?.weeks.first
        let firstDay = firstWeek?.days.first
        XCTAssertEqual(firstDay.map { WeekMath.sundayCalendar().component(.weekday, from: $0.date) }, 1,
                       "Picker weeks must start on Sunday under a Sunday week-start")
    }

    func testSundayStartOffsetZeroContainsToday() {
        WeekMath.preferredCalendar = WeekMath.sundayCalendar()
        let vm = makeViewModel()
        // The week with offset 0 must contain the picker's `today`.
        let zero = vm.months.flatMap(\.weeks).first { $0.offset == 0 }
        XCTAssertNotNil(zero)
    }
```

⚠️ Adapt property paths (`months`/`weeks`/`days`/`offset`) and the fixture to the actual Phase 31 `WeekPickerViewModel` shapes — read the existing tests in this file first; assertions' INTENT is fixed.

- [ ] **Step 2: Run to verify failure** — `-only-testing:WeeklyPlannerTests/WeekPickerViewModelTests`. Expected: new tests fail (Task 6 swept the VM's calendar — if they already pass, good: keep them as regression pins and continue).

- [ ] **Step 3: Rotate the header.** In `MonthGridView.swift`, find the Mon-first weekday header (a literal like `["M", "T", "W", "T", "F", "S", "S"]` from Phase 31) and derive it instead:

```swift
    private var weekdayInitials: [String] {
        (0 ..< 7).map { WeekMath.weekdayInitial(for: $0, calendar: WeekMath.preferredCalendar) }
    }
```

using `weekdayInitials` where the literal was.

- [ ] **Step 4: Run to verify pass** — `-only-testing:WeeklyPlannerTests/WeekPickerViewModelTests -only-testing:WeeklyPlannerTests/MonthGridViewTests`. Expected: PASS (including Phase 31's suites).

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Features/WeekPicker/ WeeklyPlannerTests/WeekPicker/
git commit -m "feat(week-start): week picker weeks + weekday header follow the preference (Phase 36b #45)"
```

---

### Task 8: UI test + full verification (superpowers:verification-before-completion)

**Files:**
- Create: `WeeklyPlannerUITests/WeekStartUITests.swift`

- [ ] **Step 1: Write the UI test** (flips to Sunday, asserts the week page re-lays, then RESTORES Monday — simulator settings persist across tests):

```swift
import XCTest

final class WeekStartUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testSwitchingWeekStartToSundayRelaysWeekPage() {
        let app = XCUIApplication()
        app.launch()

        // Settings → Week starts on → Sunday.
        let settingsTab = app.buttons["tabbar.tab.settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        let menu = app.buttons["settings.weekstart.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5), "Week-start menu missing")
        menu.tap()
        let sunday = app.buttons["Sunday"]
        XCTAssertTrue(sunday.waitForExistence(timeout: 3))
        sunday.tap()

        // Calendar → Week view: Sunday's row must now sit above Monday's.
        app.buttons["tabbar.tab.calendar"].tap()
        let weekSeg = app.buttons["topbar.dayweek.week"]
        XCTAssertTrue(weekSeg.waitForExistence(timeout: 5))
        weekSeg.tap()

        let sunRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS 'Sunday'")).firstMatch
        let monRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS 'Monday'")).firstMatch
        XCTAssertTrue(sunRow.waitForExistence(timeout: 5), "No Sunday row on the week page")
        XCTAssertTrue(monRow.waitForExistence(timeout: 5), "No Monday row on the week page")
        XCTAssertLessThan(sunRow.frame.minY, monRow.frame.minY,
                          "Sunday must lead the week after the switch")

        // Restore Monday (leave the simulator clean for other suites).
        app.buttons["tabbar.tab.settings"].tap()
        menu.tap()
        let monday = app.buttons["Monday"]
        XCTAssertTrue(monday.waitForExistence(timeout: 3))
        monday.tap()
    }
}
```

⚠️ Week rows expose combined accessibility labels (Phase 21/30); if they carry short names ("Sun"/"Mon") instead of long, adjust the predicates — the frame-ordering assertion is the deliverable.

- [ ] **Step 2: Run** — `-only-testing:WeeklyPlannerUITests/WeekStartUITests`. Expected: PASS.

- [ ] **Step 3: FULL unit suite + regression UI suites**

```bash
xcodegen generate
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=<available iPhone, iOS 26.5>' \
  -only-testing:WeeklyPlannerTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO
```

then `-only-testing:WeeklyPlannerUITests/WeekStartUITests -only-testing:WeeklyPlannerUITests/SmokeUITests -only-testing:WeeklyPlannerUITests/StickySwipeUITests` (+ the Phase 27 week-view-stability suite — grep `WeeklyPlannerUITests/` for its name — the spec explicitly calls out verifying the freeze fix doesn't regress).
Expected: all `** TEST SUCCEEDED **`.

- [ ] **Step 4: Spec checklist sweep** — `docs/phases/phase-36-personalization-expansion.md` item 45 + the week-start rows of the Logic checklist: options beyond Sun/Mon ✓ (all seven), Week page + picker + side tabs re-lay consistently ✓, offset math verified across year boundary ✓ (WeekMathTests + picker tests), Phase 27 freeze fix regression-checked ✓.

- [ ] **Step 5: Report** — branch, files, the call-site sweep diffstat, deviations (e.g., any site where `preferredCalendar` couldn't be used and why).

---

## Self-review notes

- **Spec coverage:** all-seven options (T3–4), `WeekMath` parameterization + dead-branch fix (T1), every Monday-assumption class from the inventory: week construction (T1), weekday indices (T2), explicit literals incl. side tabs/week page/picker/event sheet/store bounds (T6), picker headers + offsets (T7), propagation + re-layout (T5), freeze-fix regression check (T8).
- **Type consistency:** `WeekStartDay` raw == `Calendar.firstWeekday` everywhere; `WeekMath.calendar(startingOn:)` / `preferredCalendar` / `weekdayInitial(for:calendar:)` signatures identical across tasks; `setWeekStart(_:)` consistent T3/T4.
- **Deliberate choices:** process-global `preferredCalendar` over threading a calendar through every VM init (50 sites; the functions keep explicit `calendar:` params so tests stay pure); epoch-based full rebuild on change (rare event, correctness over cleverness); legacy Bool kept for migration only.
- **Known adaptation points:** picker VM property paths in T7's tests; settings-row chrome in T4; week-row label wording in T8.
- **Cross-plan note:** if Phase 35 lands first, T6 must also sweep its two `mondayCalendar()` uses (called out in the task).
