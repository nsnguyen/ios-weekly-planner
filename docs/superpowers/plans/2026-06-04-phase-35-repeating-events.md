# Phase 35 — Repeating Events Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Events can repeat (daily/weekly/monthly/yearly, "every N", end never/on-date/after-count), render on every occurrence across Day/Week views, round-trip through EventKit, and delete with this-occurrence vs all-occurrences scoping — with reminder scheduling bounded.

**Architecture:** A `Recurrence` Codable value type stored on `Event` (like `reminders: [Reminder]`), plus an `isRecurring` flag for predicate-friendly fetches and `excludedOccurrenceStarts` for single-occurrence deletes. `RecurrenceMapper` converts to/from `EKRecurrenceRule`; the EventKit mirror carries the real rule (with `EKSpan` plumbed through the gateway). **Display expansion uses a small local `OccurrenceExpander`** over our 4-frequency subset, inside `SwiftDataEventStore.events(forWeekOffset:)` — transient per-occurrence copies of the master, never inserted. Editing always edits the series; deleting prompts for scope (user decision 2026-06-04). Reminders schedule only occurrences inside a 30-day window, capped.

**Tech Stack:** EventKit (`EKRecurrenceRule`, `EKSpan`), SwiftData, SwiftUI, XCTest, XcodeGen.

---

## ⚠️ Declared deviation from the phase doc (decided in writing-plans — flag at review)

The spec says "the EventKit mirror is the source of truth for occurrence expansion — don't hand-roll an occurrence generator." We deviate **for display expansion only**, with a local `OccurrenceExpander`, because:
1. Display must work when Calendar access is denied (SwiftData remains the app's display source today; EventKit-only expansion would silently break recurring display for no-access users).
2. UI tests run without EventKit grants (mirroring is already best-effort `try?` — an EventKit-dependent display path would make the acceptance UI test impossible).
3. The supported subset (4 frequencies × interval × 3 end modes, no BY-sets) is ~40 lines to expand deterministically; `RecurrenceMapperTests` + `OccurrenceExpanderTests` pin EventKit-compatible semantics (end-date inclusivity, count-from-anchor, DST).

EventKit remains the source of truth for the **system mirror** (real `EKRecurrenceRule` round-trip, span-scoped saves/removes, external-edit sync). On-device acceptance still validates the EventKit round-trip.

**Other stated v1 limits (per user decision + spec option):**
- Edits always apply to the whole series (no per-occurrence edit/detach-with-changes).
- Delete prompts: "this occurrence" (exclusion + EK detach) vs "all occurrences" (series removal).
- Externally-created rules outside our subset import as a single occurrence (unmappable → `recurrence = nil`); mappable external rules import with the earliest in-window occurrence as anchor.
- `events(matching:)` (AI search) returns series masters, not expanded occurrences.
- Gmail-accepted events stay single-occurrence.

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `WeeklyPlanner/Models/Recurrence.swift` | NEW | value type: frequency, interval, end + display names |
| `WeeklyPlanner/Models/Event.swift` | MODIFY | `recurrence: Recurrence?`, `isRecurring: Bool`, `excludedOccurrenceStarts: [Date]`, `occurrenceCopy` |
| `WeeklyPlanner/Stores/EventKit/RecurrenceMapper.swift` | NEW | `Recurrence ↔ EKRecurrenceRule` |
| `WeeklyPlanner/Stores/OccurrenceExpander.swift` | NEW | window expansion of the simple rule subset |
| `WeeklyPlanner/Stores/EventStore.swift` | MODIFY | singles fetch excludes recurring; merge expanded occurrences; copy new fields in upsert; `deleteOccurrence` |
| `WeeklyPlanner/Stores/EventKit/EventKitGateway.swift` | MODIFY | span-ful `save`/`remove` + extension overloads |
| `WeeklyPlanner/Stores/EventKit/EKEvent+Mapping.swift` | MODIFY | write/read `recurrenceRules` |
| `WeeklyPlanner/Stores/EventStore+EventKit.swift` | MODIFY | span on save/remove; occurrence detach; `deleteOccurrence` |
| `WeeklyPlanner/Stores/EventKit/EventKitSync.swift` | MODIFY | group occurrences by identifier; don't thrash series anchors |
| `WeeklyPlanner/Features/EventDetail/EventComposerState.swift` | MODIFY | draft recurrence in from/build/isDirty |
| `WeeklyPlanner/Features/EventDetail/EditableFields/RecurrenceRow.swift` | NEW | Repeat row: frequency, interval, end |
| `WeeklyPlanner/Features/EventDetail/PaperEventSheet+Edit.swift` | MODIFY | host `RecurrenceRow` |
| `WeeklyPlanner/Features/EventDetail/RecurrenceSummary.swift` | NEW | "Every week on Mon" formatter |
| `WeeklyPlanner/Features/EventDetail/EventDetailViewModel.swift` | MODIFY | `recurrenceSummary` |
| read-mode sheet + delete host (in `PaperEventSheet.swift` / `DayPageView.swift`) | MODIFY | summary row + scoped-delete dialog |
| `WeeklyPlanner/Notifications/EventNotificationScheduler.swift` | MODIFY | bounded recurring scheduling |
| `WeeklyPlannerTests/EventKit/FakeEventKitGateway.swift` | NEW | recording gateway test double |
| `WeeklyPlannerTests/...` | NEW/MODIFY | mapper, expander, store, mirror, composer, summary, scheduler, gmail-guard tests |
| `WeeklyPlannerUITests/RepeatingEventUITests.swift` | NEW | daily event on adjacent days + scoped delete |

**Canonical test command** ("the test command"; device from `xcrun simctl list devices available`):

```bash
xcodegen generate
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=<available iPhone, iOS 26.5>' \
  -only-testing:<filter> \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO
```

---

### Task 1: `Recurrence` value type

**Files:**
- Create: `WeeklyPlanner/Models/Recurrence.swift`
- Test: `WeeklyPlannerTests/Models/RecurrenceTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import WeeklyPlanner

final class RecurrenceTests: XCTestCase {
    func testCodableRoundTripAllEndModes() throws {
        let cases: [Recurrence] = [
            Recurrence(frequency: .daily),
            Recurrence(frequency: .weekly, interval: 2, end: .afterCount(10)),
            Recurrence(frequency: .monthly, interval: 3, end: .onDate(Date(timeIntervalSince1970: 1_800_000_000))),
            Recurrence(frequency: .yearly, end: .never),
        ]
        for original in cases {
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(Recurrence.self, from: data)
            XCTAssertEqual(decoded, original)
        }
    }

    func testIntervalClampsToAtLeastOne() {
        XCTAssertEqual(Recurrence(frequency: .daily, interval: 0).interval, 1)
        XCTAssertEqual(Recurrence(frequency: .daily, interval: -3).interval, 1)
        XCTAssertEqual(Recurrence(frequency: .daily, interval: 4).interval, 4)
    }

    func testDisplayNames() {
        XCTAssertEqual(RecurrenceFrequency.daily.displayName, "Daily")
        XCTAssertEqual(RecurrenceFrequency.weekly.displayName, "Weekly")
        XCTAssertEqual(RecurrenceFrequency.monthly.displayName, "Monthly")
        XCTAssertEqual(RecurrenceFrequency.yearly.displayName, "Yearly")
        XCTAssertEqual(RecurrenceFrequency.weekly.unitName, "week")
    }
}
```

- [ ] **Step 2: Run to verify failure** — `-only-testing:WeeklyPlannerTests/RecurrenceTests`. Expected: compile failure.

- [ ] **Step 3: Implement** `WeeklyPlanner/Models/Recurrence.swift`:

```swift
import Foundation

/// Supported repeat cadences (Phase 35). Deliberately the simple subset:
/// no BYDAY sets, no "last weekday of month" — extend on demand.
enum RecurrenceFrequency: String, Codable, CaseIterable, Sendable {
    case daily
    case weekly
    case monthly
    case yearly

    var displayName: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }

    /// Unit noun for "Every N <unit>s".
    var unitName: String {
        switch self {
        case .daily: "day"
        case .weekly: "week"
        case .monthly: "month"
        case .yearly: "year"
        }
    }
}

/// When a series stops. `onDate` is inclusive of occurrences falling on
/// that calendar day (EventKit `EKRecurrenceEnd(end:)` semantics).
enum RecurrenceEnd: Codable, Equatable, Hashable, Sendable {
    case never
    case onDate(Date)
    case afterCount(Int)
}

/// A repeat rule for an `Event`. Stored directly on the model as a
/// Codable value (same mechanism as `reminders: [Reminder]`).
struct Recurrence: Codable, Equatable, Hashable, Sendable {
    var frequency: RecurrenceFrequency
    var interval: Int
    var end: RecurrenceEnd

    init(frequency: RecurrenceFrequency, interval: Int = 1, end: RecurrenceEnd = .never) {
        self.frequency = frequency
        self.interval = max(1, interval)
        self.end = end
    }
}
```

- [ ] **Step 4: Run to verify pass** — same filter. Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Models/Recurrence.swift WeeklyPlannerTests/Models/RecurrenceTests.swift
git commit -m "feat(recurrence): Recurrence value type — frequency, interval, end (Phase 35)"
```

---

### Task 2: `RecurrenceMapper` — `Recurrence ↔ EKRecurrenceRule`

**Files:**
- Create: `WeeklyPlanner/Stores/EventKit/RecurrenceMapper.swift`
- Test: `WeeklyPlannerTests/Models/RecurrenceMapperTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import EventKit
import XCTest
@testable import WeeklyPlanner

final class RecurrenceMapperTests: XCTestCase {
    func testEachFrequencyMapsBothWays() {
        let pairs: [(RecurrenceFrequency, EKRecurrenceFrequency)] = [
            (.daily, .daily), (.weekly, .weekly), (.monthly, .monthly), (.yearly, .yearly),
        ]
        for (ours, theirs) in pairs {
            let rule = RecurrenceMapper.toEKRule(Recurrence(frequency: ours))
            XCTAssertEqual(rule.frequency, theirs)
            XCTAssertEqual(rule.interval, 1)
            XCTAssertNil(rule.recurrenceEnd)

            let back = RecurrenceMapper.toRecurrence([rule])
            XCTAssertEqual(back, Recurrence(frequency: ours))
        }
    }

    func testIntervalGreaterThanOnePreserved() {
        let rule = RecurrenceMapper.toEKRule(Recurrence(frequency: .weekly, interval: 3))
        XCTAssertEqual(rule.interval, 3)
        XCTAssertEqual(RecurrenceMapper.toRecurrence([rule])?.interval, 3)
    }

    func testEndOnDateRoundTrips() {
        let endDate = Date(timeIntervalSince1970: 1_790_000_000)
        let rule = RecurrenceMapper.toEKRule(Recurrence(frequency: .daily, end: .onDate(endDate)))
        XCTAssertNotNil(rule.recurrenceEnd?.endDate)

        let back = RecurrenceMapper.toRecurrence([rule])
        guard case let .onDate(date)? = back?.end else {
            return XCTFail("Expected .onDate end, got \(String(describing: back?.end))")
        }
        // EventKit normalizes the end date; same calendar day is the contract.
        XCTAssertEqual(Calendar.current.startOfDay(for: date),
                       Calendar.current.startOfDay(for: endDate))
    }

    func testEndAfterCountRoundTrips() {
        let rule = RecurrenceMapper.toEKRule(Recurrence(frequency: .monthly, end: .afterCount(5)))
        XCTAssertEqual(rule.recurrenceEnd?.occurrenceCount, 5)
        XCTAssertEqual(RecurrenceMapper.toRecurrence([rule])?.end, .afterCount(5))
    }

    func testNilAndEmptyRulesMapToNil() {
        XCTAssertNil(RecurrenceMapper.toRecurrence(nil))
        XCTAssertNil(RecurrenceMapper.toRecurrence([]))
    }

    func testComplexRuleOutsideSubsetMapsToNil() {
        // "Weekly on Mon+Wed" — a BYDAY set we don't model.
        let complex = EKRecurrenceRule(
            recurrenceWith: .weekly,
            interval: 1,
            daysOfTheWeek: [EKRecurrenceDayOfWeek(.monday), EKRecurrenceDayOfWeek(.wednesday)],
            daysOfTheMonth: nil, monthsOfTheYear: nil, weeksOfTheYear: nil,
            daysOfTheYear: nil, setPositions: nil, end: nil)
        XCTAssertNil(RecurrenceMapper.toRecurrence([complex]))
    }

    func testWeeklySingleDayOfWeekIsAcceptedAsPlainWeekly() {
        // Other apps commonly emit weekly rules carrying the anchor weekday.
        let single = EKRecurrenceRule(
            recurrenceWith: .weekly,
            interval: 2,
            daysOfTheWeek: [EKRecurrenceDayOfWeek(.friday)],
            daysOfTheMonth: nil, monthsOfTheYear: nil, weeksOfTheYear: nil,
            daysOfTheYear: nil, setPositions: nil, end: nil)
        XCTAssertEqual(RecurrenceMapper.toRecurrence([single]),
                       Recurrence(frequency: .weekly, interval: 2))
    }
}
```

- [ ] **Step 2: Run to verify failure** — `-only-testing:WeeklyPlannerTests/RecurrenceMapperTests`. Expected: compile failure.

- [ ] **Step 3: Implement** `WeeklyPlanner/Stores/EventKit/RecurrenceMapper.swift`:

```swift
import EventKit
import Foundation

/// Lossless mapping between the app's simple `Recurrence` and
/// `EKRecurrenceRule`, for the supported subset. Anything fancier
/// (BYDAY sets, set positions, …) maps to `nil` and the event imports
/// as a single occurrence — a stated Phase 35 limit.
enum RecurrenceMapper {
    static func toEKRule(_ recurrence: Recurrence) -> EKRecurrenceRule {
        let frequency: EKRecurrenceFrequency = switch recurrence.frequency {
        case .daily: .daily
        case .weekly: .weekly
        case .monthly: .monthly
        case .yearly: .yearly
        }
        let end: EKRecurrenceEnd? = switch recurrence.end {
        case .never: nil
        case let .onDate(date): EKRecurrenceEnd(end: date)
        case let .afterCount(count): EKRecurrenceEnd(occurrenceCount: count)
        }
        return EKRecurrenceRule(recurrenceWith: frequency,
                                interval: recurrence.interval,
                                end: end)
    }

    static func toRecurrence(_ rules: [EKRecurrenceRule]?) -> Recurrence? {
        guard let rule = rules?.first else { return nil }

        // Subset guard: at most the single anchor weekday on weekly rules,
        // and no other BY-components.
        guard (rule.daysOfTheWeek?.count ?? 0) <= 1,
              rule.daysOfTheMonth?.isEmpty ?? true,
              rule.daysOfTheYear?.isEmpty ?? true,
              rule.weeksOfTheYear?.isEmpty ?? true,
              rule.setPositions?.isEmpty ?? true
        else { return nil }
        if let months = rule.monthsOfTheYear, !months.isEmpty, rule.frequency != .yearly {
            return nil
        }
        if let days = rule.daysOfTheWeek, !days.isEmpty, rule.frequency != .weekly {
            return nil
        }

        let frequency: RecurrenceFrequency
        switch rule.frequency {
        case .daily: frequency = .daily
        case .weekly: frequency = .weekly
        case .monthly: frequency = .monthly
        case .yearly: frequency = .yearly
        @unknown default: return nil
        }

        let end: RecurrenceEnd
        if let ekEnd = rule.recurrenceEnd {
            if let date = ekEnd.endDate {
                end = .onDate(date)
            } else {
                end = .afterCount(ekEnd.occurrenceCount)
            }
        } else {
            end = .never
        }
        return Recurrence(frequency: frequency, interval: rule.interval, end: end)
    }
}
```

- [ ] **Step 4: Run to verify pass** — same filter. Expected: PASS, 7 tests. If `testWeeklySingleDayOfWeekIsAcceptedAsPlainWeekly` reveals `EKRecurrenceRule` normalizes differently on this SDK, adjust the guard — the TEST defines the contract.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Stores/EventKit/RecurrenceMapper.swift WeeklyPlannerTests/Models/RecurrenceMapperTests.swift
git commit -m "feat(recurrence): RecurrenceMapper with subset guard, ends, intervals (Phase 35)"
```

---

### Task 3: `OccurrenceExpander`

**Files:**
- Create: `WeeklyPlanner/Stores/OccurrenceExpander.swift`
- Test: `WeeklyPlannerTests/Stores/OccurrenceExpanderTests.swift`

- [ ] **Step 1: Write the failing tests** (fixed dates; LA timezone for the DST case)

```swift
import XCTest
@testable import WeeklyPlanner

final class OccurrenceExpanderTests: XCTestCase {
    private var calendar: Calendar = {
        var cal = WeekMath.mondayCalendar()
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return cal
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = h
        return calendar.date(from: c)!
    }

    func testDailyFillsTheWindow() {
        let starts = OccurrenceExpander.occurrenceStarts(
            seriesStart: date(2026, 6, 1),
            recurrence: Recurrence(frequency: .daily),
            in: date(2026, 6, 3, 0) ..< date(2026, 6, 6, 0),
            calendar: calendar)
        XCTAssertEqual(starts, [date(2026, 6, 3), date(2026, 6, 4), date(2026, 6, 5)])
    }

    func testWeeklyIntervalTwoSkipsAlternateWeeks() {
        let starts = OccurrenceExpander.occurrenceStarts(
            seriesStart: date(2026, 6, 1), // Monday
            recurrence: Recurrence(frequency: .weekly, interval: 2),
            in: date(2026, 6, 1, 0) ..< date(2026, 7, 14, 0),
            calendar: calendar)
        XCTAssertEqual(starts, [date(2026, 6, 1), date(2026, 6, 15), date(2026, 6, 29), date(2026, 7, 13)])
    }

    func testAfterCountStopsCountingFromSeriesAnchor() {
        // 3 total occurrences from the anchor — window sees only what's left.
        let starts = OccurrenceExpander.occurrenceStarts(
            seriesStart: date(2026, 6, 1),
            recurrence: Recurrence(frequency: .daily, end: .afterCount(3)),
            in: date(2026, 6, 2, 0) ..< date(2026, 6, 30, 0),
            calendar: calendar)
        XCTAssertEqual(starts, [date(2026, 6, 2), date(2026, 6, 3)])
    }

    func testEndOnDateIsInclusiveOfThatDay() {
        let starts = OccurrenceExpander.occurrenceStarts(
            seriesStart: date(2026, 6, 1),
            recurrence: Recurrence(frequency: .daily, end: .onDate(date(2026, 6, 3, 0))),
            in: date(2026, 6, 1, 0) ..< date(2026, 6, 30, 0),
            calendar: calendar)
        XCTAssertEqual(starts, [date(2026, 6, 1), date(2026, 6, 2), date(2026, 6, 3)],
                       "An occurrence ON the end date must be included (EK semantics)")
    }

    func testExcludedOccurrencesAreSkipped() {
        let starts = OccurrenceExpander.occurrenceStarts(
            seriesStart: date(2026, 6, 1),
            recurrence: Recurrence(frequency: .daily),
            in: date(2026, 6, 1, 0) ..< date(2026, 6, 4, 0),
            excluding: [date(2026, 6, 2)],
            calendar: calendar)
        XCTAssertEqual(starts, [date(2026, 6, 1), date(2026, 6, 3)])
    }

    func testWeeklyAcrossYearBoundaryAndDSTKeepsWallClockTime() {
        // Weekly from Dec 28 2026 (Mon) — across New Year and into
        // March 2027 past the spring-forward (Mar 14 2027 in LA).
        let starts = OccurrenceExpander.occurrenceStarts(
            seriesStart: date(2026, 12, 28),
            recurrence: Recurrence(frequency: .weekly),
            in: date(2027, 1, 1, 0) ..< date(2027, 3, 23, 0),
            calendar: calendar)
        XCTAssertEqual(starts.first, date(2027, 1, 4))
        XCTAssertTrue(starts.contains(date(2027, 3, 15)), "Post-DST occurrence missing")
        // Wall-clock hour survives DST.
        for start in starts {
            XCTAssertEqual(calendar.component(.hour, from: start), 9)
        }
    }

    func testSafetyCapBoundsRunawayExpansion() {
        let starts = OccurrenceExpander.occurrenceStarts(
            seriesStart: date(2026, 6, 1),
            recurrence: Recurrence(frequency: .daily),
            in: date(2026, 6, 1, 0) ..< date(2036, 6, 1, 0),
            calendar: calendar,
            limit: 50)
        XCTAssertEqual(starts.count, 50)
    }
}
```

- [ ] **Step 2: Run to verify failure** — `-only-testing:WeeklyPlannerTests/OccurrenceExpanderTests`. Expected: compile failure.

- [ ] **Step 3: Implement** `WeeklyPlanner/Stores/OccurrenceExpander.swift`:

```swift
import Foundation

/// Expands the app's simple recurrence subset into concrete occurrence
/// dates inside a window. Used for display, reminder bounding, and tests.
/// The EventKit mirror still carries the real `EKRecurrenceRule` — this
/// expander exists so display works without Calendar access (see the
/// Phase 35 plan's declared deviation).
enum OccurrenceExpander {
    /// Occurrence starts of a series intersecting `window`, skipping
    /// `excluding` (single-occurrence deletes), capped at `limit`
    /// iterations as a runaway backstop.
    static func occurrenceStarts(seriesStart: Date,
                                 recurrence: Recurrence,
                                 in window: Range<Date>,
                                 excluding excluded: [Date] = [],
                                 calendar: Calendar,
                                 limit: Int = 400) -> [Date]
    {
        let component: Calendar.Component = switch recurrence.frequency {
        case .daily: .day
        case .weekly: .weekOfYear
        case .monthly: .month
        case .yearly: .year
        }

        // Inclusive end-of-day for `.onDate` (EKRecurrenceEnd(end:) keeps
        // occurrences ON the end day).
        var endCutoff: Date?
        if case let .onDate(endDate) = recurrence.end {
            let startOfEndDay = calendar.startOfDay(for: endDate)
            endCutoff = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: startOfEndDay)
        }

        var result: [Date] = []
        var current = seriesStart
        var index = 0

        while index < limit {
            if case let .afterCount(count) = recurrence.end, index >= count { break }
            if let endCutoff, current > endCutoff { break }
            if current >= window.upperBound { break }

            if current >= window.lowerBound,
               !excluded.contains(where: { abs($0.timeIntervalSince(current)) < 1 })
            {
                result.append(current)
            }

            index += 1
            guard let next = calendar.date(byAdding: component,
                                           value: recurrence.interval,
                                           to: current) else { break }
            current = next
        }
        return result
    }

    /// Transient display copies of `event` for each occurrence in `window`.
    /// Single events pass through when their start is inside the window.
    /// Copies share the master's `id` and are NEVER inserted into a context.
    static func occurrences(of event: Event,
                            in window: Range<Date>,
                            calendar: Calendar) -> [Event]
    {
        guard let recurrence = event.recurrence else {
            return window.contains(event.start) ? [event] : []
        }
        return occurrenceStarts(seriesStart: event.start,
                                recurrence: recurrence,
                                in: window,
                                excluding: event.excludedOccurrenceStarts,
                                calendar: calendar)
            .map { event.occurrenceCopy(start: $0) }
    }
}
```

(`Event.occurrenceCopy` and `excludedOccurrenceStarts` arrive in Task 4 — implement Tasks 3+4's model halves together if the compiler demands it, but keep the commits separate: expander first with only `occurrenceStarts`, then the `occurrences(of:)` overload with Task 4. If you prefer one compiling unit, move `occurrences(of:)` into Task 4's step.)

- [ ] **Step 4: Run to verify pass** — `-only-testing:WeeklyPlannerTests/OccurrenceExpanderTests`. Expected: PASS, 7 tests.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Stores/OccurrenceExpander.swift WeeklyPlannerTests/Stores/OccurrenceExpanderTests.swift
git commit -m "feat(recurrence): OccurrenceExpander — windowed expansion, ends, exclusions, DST-safe (Phase 35)"
```

---

### Task 4: `Event` model fields + store expansion

**Files:**
- Modify: `WeeklyPlanner/Models/Event.swift`
- Modify: `WeeklyPlanner/Stores/EventStore.swift`
- Test: `WeeklyPlannerTests/Stores/RecurringEventStoreTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class RecurringEventStoreTests: XCTestCase {
    private var container: ModelContainer!
    private var store: SwiftDataEventStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        store = SwiftDataEventStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        store = nil
        container = nil
        try await super.tearDown()
    }

    private static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = h
        return WeekMath.mondayCalendar().date(from: c)!
    }

    /// "Today" = Sat Jun 6 2026; current week = Jun 1–7.
    private static func today() -> Date { date(2026, 6, 6, 12) }

    func testRecurrencePersistsThroughUpsert() async throws {
        let event = Event(title: "Gym",
                          start: Self.date(2026, 6, 1), end: Self.date(2026, 6, 1, 10),
                          category: .health,
                          recurrence: Recurrence(frequency: .weekly))
        try await store.upsert(event)

        let fetched = try await store.event(id: event.id)
        XCTAssertEqual(fetched?.recurrence, Recurrence(frequency: .weekly))
        XCTAssertEqual(fetched?.isRecurring, true)
    }

    func testWeeklySeriesFromPastWeekAppearsInCurrentWeekFetch() async throws {
        // Master anchored 3 weeks before "today" — base start-in-window
        // predicate alone would miss it.
        let master = Event(title: "Standup",
                           start: Self.date(2026, 5, 11), end: Self.date(2026, 5, 11, 10),
                           category: .work,
                           recurrence: Recurrence(frequency: .weekly))
        try await store.upsert(master)

        let thisWeek = try await store.events(forWeekOffset: 0, today: Self.today())
        XCTAssertEqual(thisWeek.count, 1)
        XCTAssertEqual(thisWeek.first?.title, "Standup")
        XCTAssertEqual(thisWeek.first?.id, master.id, "Occurrence copies carry the master id")
        XCTAssertEqual(thisWeek.first?.start, Self.date(2026, 6, 1), "Occurrence lands on this week's Monday")
    }

    func testDailySeriesYieldsOneOccurrencePerDay() async throws {
        let master = Event(title: "Walk",
                           start: Self.date(2026, 6, 1), end: Self.date(2026, 6, 1, 10),
                           category: .health,
                           recurrence: Recurrence(frequency: .daily))
        try await store.upsert(master)

        let thisWeek = try await store.events(forWeekOffset: 0, today: Self.today())
        XCTAssertEqual(thisWeek.count, 7)
        XCTAssertEqual(Set(thisWeek.map(\.id)).count, 1)
    }

    func testSingleEventsAreUnaffected() async throws {
        let single = Event(title: "Dentist",
                           start: Self.date(2026, 6, 3), end: Self.date(2026, 6, 3, 10),
                           category: .personal)
        try await store.upsert(single)

        let thisWeek = try await store.events(forWeekOffset: 0, today: Self.today())
        XCTAssertEqual(thisWeek.map(\.title), ["Dentist"])
        let nextWeek = try await store.events(forWeekOffset: 1, today: Self.today())
        XCTAssertTrue(nextWeek.isEmpty)
    }

    func testDeleteOccurrenceExcludesOnlyThatDay() async throws {
        let master = Event(title: "Walk",
                           start: Self.date(2026, 6, 1), end: Self.date(2026, 6, 1, 10),
                           category: .health,
                           recurrence: Recurrence(frequency: .daily))
        try await store.upsert(master)

        try await store.deleteOccurrence(eventID: master.id, occurrenceStart: Self.date(2026, 6, 3))

        let thisWeek = try await store.events(forWeekOffset: 0, today: Self.today())
        XCTAssertEqual(thisWeek.count, 6)
        XCTAssertFalse(thisWeek.contains { $0.start == Self.date(2026, 6, 3) })
    }

    func testDeleteSeriesRemovesAllOccurrences() async throws {
        let master = Event(title: "Walk",
                           start: Self.date(2026, 6, 1), end: Self.date(2026, 6, 1, 10),
                           category: .health,
                           recurrence: Recurrence(frequency: .daily))
        try await store.upsert(master)
        try await store.delete(id: master.id)

        let thisWeek = try await store.events(forWeekOffset: 0, today: Self.today())
        XCTAssertTrue(thisWeek.isEmpty)
    }
}
```

- [ ] **Step 2: Run to verify failure** — `-only-testing:WeeklyPlannerTests/RecurringEventStoreTests`. Expected: compile failure.

- [ ] **Step 3: Implement model fields.** In `Event.swift` add stored properties (after `reminders`):

```swift
    /// Phase 35: repeat rule. `nil` = single occurrence.
    var recurrence: Recurrence?
    /// Predicate-friendly mirror of `recurrence != nil` (SwiftData can't
    /// filter on the Codable column). Maintained by init and the store.
    var isRecurring: Bool = false
    /// Occurrence starts the user deleted individually ("this event only").
    var excludedOccurrenceStarts: [Date] = []
```

Extend the init parameter list (after `reminders: [Reminder] = [],`):

```swift
         recurrence: Recurrence? = nil,
         excludedOccurrenceStarts: [Date] = [],
```

and the init body (before timestamps):

```swift
        self.recurrence = recurrence
        isRecurring = recurrence != nil
        self.excludedOccurrenceStarts = excludedOccurrenceStarts
```

Add the occurrence-copy helper as an extension in `Event.swift`:

```swift
extension Event {
    /// Transient display copy for one occurrence of a recurring series —
    /// same `id` as the master; NEVER insert into a ModelContext.
    func occurrenceCopy(start occurrenceStart: Date) -> Event {
        let duration = end.timeIntervalSince(start)
        return Event(id: id,
                     eventKitIdentifier: eventKitIdentifier,
                     title: title,
                     start: occurrenceStart,
                     end: occurrenceStart.addingTimeInterval(duration),
                     location: location,
                     notes: notes,
                     category: category,
                     attendeesCount: attendeesCount,
                     travelMinutes: travelMinutes,
                     source: source,
                     gmailMessageID: gmailMessageID,
                     gmailFrom: gmailFrom,
                     gmailSubject: gmailSubject,
                     reminders: reminders,
                     recurrence: recurrence,
                     excludedOccurrenceStarts: excludedOccurrenceStarts,
                     createdAt: createdAt,
                     updatedAt: updatedAt)
    }
}
```

- [ ] **Step 4: Implement store changes.** In `EventStore.swift`:

4.1 — Protocol gains the scoped delete (all conformers must implement — grep `: EventStoring` for the full list: `SwiftDataEventStore`, `EventKitMirroringEventStore`, `StubEventStore`, plus any test fakes):

```swift
    /// Removes ONE occurrence of a recurring series ("delete this event
    /// only"). No-op for single events.
    func deleteOccurrence(eventID: UUID, occurrenceStart: Date) async throws
```

4.2 — `SwiftDataEventStore.events(forWeekOffset:)` becomes singles-plus-expansion:

```swift
    func events(forWeekOffset offset: Int, today: Date = .init()) async throws -> [Event] {
        let bounds = Self.weekBounds(forOffset: offset, today: today)
        let start = bounds.start
        let end = bounds.end

        // Single events: start-in-window, as before — recurring masters
        // are excluded here and expanded below instead.
        let singlesDescriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { $0.start >= start && $0.start < end && !$0.isRecurring },
            sortBy: [SortDescriptor(\.start, order: .forward)])
        let singles = try context.fetch(singlesDescriptor)

        // Recurring series: expand into this window (transient copies).
        let recurringDescriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { $0.isRecurring })
        let masters = try context.fetch(recurringDescriptor)
        let calendar = WeekMath.mondayCalendar()
        let occurrences = masters.flatMap {
            OccurrenceExpander.occurrences(of: $0, in: start ..< end, calendar: calendar)
        }

        return (singles + occurrences).sorted { $0.start < $1.start }
    }
```

4.3 — `upsert` copies the new fields in the update branch (next to `existing.reminders = event.reminders`):

```swift
            existing.reminders = event.reminders
            existing.recurrence = event.recurrence
            existing.isRecurring = event.recurrence != nil
            existing.excludedOccurrenceStarts = event.excludedOccurrenceStarts
```

4.4 — `SwiftDataEventStore.deleteOccurrence`:

```swift
    func deleteOccurrence(eventID: UUID, occurrenceStart: Date) async throws {
        guard let event = try await event(id: eventID), event.isRecurring else { return }
        event.excludedOccurrenceStarts.append(occurrenceStart)
        event.updatedAt = .init()
        try context.save()
        changeSubject.post(name: .eventStoreDidChange, object: nil)
    }
```

4.5 — `StubEventStore` gains `func deleteOccurrence(eventID _: UUID, occurrenceStart _: Date) async throws {}`. Give `EventKitMirroringEventStore` a pass-through for now (`try await base.deleteOccurrence(…)`) — Task 7 adds the EK detach.

- [ ] **Step 5: Run to verify pass**

Run: `-only-testing:WeeklyPlannerTests/RecurringEventStoreTests -only-testing:WeeklyPlannerTests/EventStoreTests`
Expected: PASS — new tests green, existing `EventStoreTests` untouched-green.

- [ ] **Step 6: Commit**

```bash
git add WeeklyPlanner/Models/Event.swift WeeklyPlanner/Stores/EventStore.swift WeeklyPlanner/Stores/OccurrenceExpander.swift WeeklyPlannerTests/Stores/RecurringEventStoreTests.swift
git commit -m "feat(recurrence): Event recurrence fields + store-level occurrence expansion + scoped delete (Phase 35)"
```

---

### Task 5: `EKEvent+Mapping` recurrence wiring

**Files:**
- Modify: `WeeklyPlanner/Stores/EventKit/EKEvent+Mapping.swift`
- Test: extend `WeeklyPlannerTests/EventKit/EKEventMappingTests.swift`

- [ ] **Step 1: Write the failing tests** (append to the existing class; it already has `scratchStore`/`makeBlankEKEvent`)

```swift
    func testApplyWritesRecurrenceRule() {
        let event = Event(title: "Gym",
                          start: Date(timeIntervalSinceReferenceDate: 1_000_000),
                          end: Date(timeIntervalSinceReferenceDate: 1_003_600),
                          category: .health,
                          recurrence: Recurrence(frequency: .weekly, interval: 2, end: .afterCount(8)))
        let ek = makeBlankEKEvent()
        EKEventMapping.apply(event, to: ek, calendar: nil)

        XCTAssertEqual(ek.recurrenceRules?.count, 1)
        XCTAssertEqual(ek.recurrenceRules?.first?.frequency, .weekly)
        XCTAssertEqual(ek.recurrenceRules?.first?.interval, 2)
        XCTAssertEqual(ek.recurrenceRules?.first?.recurrenceEnd?.occurrenceCount, 8)
    }

    func testApplyClearsRuleWhenRecurrenceRemoved() {
        let ek = makeBlankEKEvent()
        ek.recurrenceRules = [RecurrenceMapper.toEKRule(Recurrence(frequency: .daily))]

        let single = Event(title: "One-off",
                           start: Date(timeIntervalSinceReferenceDate: 1_000_000),
                           end: Date(timeIntervalSinceReferenceDate: 1_003_600),
                           category: .personal)
        EKEventMapping.apply(single, to: ek, calendar: nil)

        XCTAssertTrue(ek.recurrenceRules?.isEmpty ?? true,
                      "Editing a series to not-repeating must clear the EK rule")
    }

    func testToEventReadsRecurrenceBack() {
        let ek = makeBlankEKEvent()
        ek.title = "Gym"
        ek.startDate = Date(timeIntervalSinceReferenceDate: 1_000_000)
        ek.endDate = Date(timeIntervalSinceReferenceDate: 1_003_600)
        ek.recurrenceRules = [RecurrenceMapper.toEKRule(Recurrence(frequency: .monthly, interval: 3))]

        let event = EKEventMapping.toEvent(ek)
        XCTAssertEqual(event.recurrence, Recurrence(frequency: .monthly, interval: 3))
        XCTAssertTrue(event.isRecurring)
    }
```

- [ ] **Step 2: Run to verify failure** — `-only-testing:WeeklyPlannerTests/EKEventMappingTests`. Expected: 3 new failures.

- [ ] **Step 3: Implement.** In `apply(_:to:calendar:)`, after the alarms line:

```swift
        if let recurrence = event.recurrence {
            ekEvent.recurrenceRules = [RecurrenceMapper.toEKRule(recurrence)]
        } else {
            ekEvent.recurrenceRules = nil
        }
```

In `toEvent(_:defaultCategory:existingID:)`, add to the `Event(...)` construction (after `reminders:`):

```swift
                 recurrence: RecurrenceMapper.toRecurrence(ekEvent.recurrenceRules),
```

- [ ] **Step 4: Run to verify pass** — same filter, whole class. Expected: PASS (old + new).

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Stores/EventKit/EKEvent+Mapping.swift WeeklyPlannerTests/EventKit/EKEventMappingTests.swift
git commit -m "feat(recurrence): EKEvent mapping writes/reads recurrenceRules (Phase 35)"
```

---

### Task 6: Gateway span parameters

**Files:**
- Modify: `WeeklyPlanner/Stores/EventKit/EventKitGateway.swift`

- [ ] **Step 1: Change the protocol requirements** from `func save(_ event: EKEvent) throws` / `func remove(_ event: EKEvent) throws` to:

```swift
    func save(_ event: EKEvent, span: EKSpan) throws
    func remove(_ event: EKEvent, span: EKSpan) throws
```

and add span-less convenience overloads so existing call sites compile unchanged:

```swift
extension EventKitGateway {
    func save(_ event: EKEvent) throws { try save(event, span: .thisEvent) }
    func remove(_ event: EKEvent) throws { try remove(event, span: .thisEvent) }
}
```

- [ ] **Step 2: Update `SystemEventKitGateway`:**

```swift
    func save(_ event: EKEvent, span: EKSpan) throws {
        try store.save(event, span: span, commit: true)
    }

    func remove(_ event: EKEvent, span: EKSpan) throws {
        try store.remove(event, span: span, commit: true)
    }
```

(The reminder `save`/`remove` overloads for `EKReminder` are untouched — reminders have no spans.)

- [ ] **Step 3: Compile check** — run `-only-testing:WeeklyPlannerTests/EKEventMappingTests`. Expected: PASS (full target compiles).

- [ ] **Step 4: Commit**

```bash
git add WeeklyPlanner/Stores/EventKit/EventKitGateway.swift
git commit -m "feat(recurrence): EKSpan-aware save/remove on EventKitGateway (Phase 35)"
```

---

### Task 7: Mirroring — series spans, occurrence detach, `FakeEventKitGateway`

**Files:**
- Modify: `WeeklyPlanner/Stores/EventStore+EventKit.swift`
- Create: `WeeklyPlannerTests/EventKit/FakeEventKitGateway.swift`
- Test: `WeeklyPlannerTests/EventKit/EventKitMirroringRecurrenceTests.swift`

- [ ] **Step 1: Write the fake** (recording double; uses a scratch `EKEventStore` purely as an object factory — `eventIdentifier` is unavailable on unsaved events, so these tests assert on saves/removes/spans, not on identifier matching):

```swift
import EventKit
import Foundation
@testable import WeeklyPlanner

/// Recording in-memory `EventKitGateway`. Objects come from a scratch
/// `EKEventStore` that is never committed to the system calendar.
@MainActor
final class FakeEventKitGateway: EventKitGateway {
    private let scratch = EKEventStore()

    var eventsAuthStatus: EKAuthorizationStatus = .fullAccess
    var remindersAuthStatus: EKAuthorizationStatus = .fullAccess

    private(set) var savedEvents: [(event: EKEvent, span: EKSpan)] = []
    private(set) var removedEvents: [(event: EKEvent, span: EKSpan)] = []
    /// Events returned by `fetchEvents` regardless of range (tests keep
    /// ranges generous, so no filtering logic to get wrong).
    var stubbedEvents: [EKEvent] = []

    func requestEventsAccess() async -> EKAuthorizationStatus { eventsAuthStatus }
    func requestRemindersAccess() async -> EKAuthorizationStatus { remindersAuthStatus }

    func fetchEvents(from _: Date, to _: Date, calendars _: [EKCalendar]?) -> [EKEvent] {
        stubbedEvents
    }

    func fetchReminders(in _: [EKCalendar]?) async -> [EKReminder] { [] }

    func save(_ event: EKEvent, span: EKSpan) throws {
        savedEvents.append((event, span))
    }

    func remove(_ event: EKEvent, span: EKSpan) throws {
        removedEvents.append((event, span))
    }

    func save(_: EKReminder) throws {}
    func remove(_: EKReminder) throws {}

    private(set) var calendars: [EKCalendar] = []
    var eventCalendars: [EKCalendar] { calendars }
    var reminderCalendars: [EKCalendar] { [] }
    var defaultEventCalendarForNewEvents: EKCalendar? { calendars.first }
    var defaultReminderCalendar: EKCalendar? { nil }

    func newEvent() -> EKEvent { EKEvent(eventStore: scratch) }
    func newReminder() -> EKReminder { EKReminder(eventStore: scratch) }

    func newCalendar(for entityType: EKEntityType, source: EKSource?) -> EKCalendar {
        let calendar = EKCalendar(for: entityType, eventStore: scratch)
        if let source { calendar.source = source }
        return calendar
    }

    func saveCalendar(_ calendar: EKCalendar) throws {
        calendars.append(calendar)
    }

    func calendar(withIdentifier identifier: String) -> EKCalendar? {
        calendars.first { $0.calendarIdentifier == identifier }
    }

    var preferredSource: EKSource? { scratch.sources.first }

    var changes: AsyncStream<Void> { AsyncStream { _ in } }
}
```

⚠️ Conform to the ACTUAL protocol — diff against `EventKitGateway.swift` and fill any member this sketch misses (return inert values). If `CategoryCalendarManager.ensureCalendars()` needs more (e.g., a non-nil source), stub the minimum it touches; read its source first.

- [ ] **Step 2: Write the failing tests**

```swift
import EventKit
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class EventKitMirroringRecurrenceTests: XCTestCase {
    private var container: ModelContainer!
    private var base: SwiftDataEventStore!
    private var gateway: FakeEventKitGateway!
    private var store: EventKitMirroringEventStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        base = SwiftDataEventStore(context: container.mainContext)
        gateway = FakeEventKitGateway()
        store = EventKitMirroringEventStore(base: base,
                                            gateway: gateway,
                                            calendarManager: CategoryCalendarManager(gateway: gateway))
    }

    override func tearDown() async throws {
        store = nil
        gateway = nil
        base = nil
        container = nil
        try await super.tearDown()
    }

    private func makeWeekly(title: String = "Gym") -> Event {
        Event(title: title,
              start: Date(timeIntervalSinceReferenceDate: 800_000_000),
              end: Date(timeIntervalSinceReferenceDate: 800_003_600),
              category: .health,
              recurrence: Recurrence(frequency: .weekly))
    }

    func testUpsertRecurringEventSavesRuleWithFutureSpan() async throws {
        try await store.upsert(makeWeekly())

        let saved = try XCTUnwrap(gateway.savedEvents.last)
        XCTAssertEqual(saved.span, .futureEvents,
                       "Recurring saves must apply to the whole series")
        XCTAssertEqual(saved.event.recurrenceRules?.first?.frequency, .weekly)
    }

    func testUpsertSingleEventSavesWithThisEventSpan() async throws {
        let single = Event(title: "One-off",
                           start: Date(timeIntervalSinceReferenceDate: 800_000_000),
                           end: Date(timeIntervalSinceReferenceDate: 800_003_600),
                           category: .personal)
        try await store.upsert(single)

        let saved = try XCTUnwrap(gateway.savedEvents.last)
        XCTAssertEqual(saved.span, .thisEvent)
        XCTAssertTrue(saved.event.recurrenceRules?.isEmpty ?? true)
    }

    func testDeleteOccurrenceExcludesLocallyEvenWithoutEKMatch() async throws {
        let weekly = makeWeekly()
        try await store.upsert(weekly)
        let occurrence = weekly.start.addingTimeInterval(7 * 86_400)

        try await store.deleteOccurrence(eventID: weekly.id, occurrenceStart: occurrence)

        let master = try await base.event(id: weekly.id)
        XCTAssertEqual(master?.excludedOccurrenceStarts, [occurrence],
                       "Local exclusion must persist regardless of EK detach success")
    }
}
```

- [ ] **Step 3: Run to verify failure** — `-only-testing:WeeklyPlannerTests/EventKitMirroringRecurrenceTests`. Expected: failures (span is `.thisEvent` for recurring; `deleteOccurrence` is pass-through). If `CategoryCalendarManager`'s init signature differs, match it.

- [ ] **Step 4: Implement in `EventStore+EventKit.swift`:**

4.1 — `mirrorToEventKit`: the save picks its span:

```swift
        EKEventMapping.apply(event, to: ekEvent, calendar: target)
        let span: EKSpan = event.recurrence != nil ? .futureEvents : .thisEvent
        try gateway.save(ekEvent, span: span)
```

4.2 — Series delete: where `delete(id:)` removes from EventKit, pass `.futureEvents` for recurring events (anchored at the master, that removes the series). Locate the existing removal helper and extend it with a span parameter:

```swift
    func delete(id: UUID) async throws {
        if let event = try await base.event(id: id), let identifier = event.eventKitIdentifier {
            let span: EKSpan = event.recurrence != nil ? .futureEvents : .thisEvent
            removeFromEventKit(identifier: identifier,
                               searchFrom: event.start.addingTimeInterval(-86_400),
                               searchTo: max(event.end, event.start).addingTimeInterval(86_400),
                               span: span)
        }
        try await base.delete(id: id)
    }

    private func removeFromEventKit(identifier: String, searchFrom: Date, searchTo: Date, span: EKSpan) {
        guard gateway.eventsAuthStatus.isFullAccess else { return }
        let candidates = gateway.fetchEvents(from: searchFrom, to: searchTo, calendars: nil)
        if let match = candidates.first(where: { $0.eventIdentifier == identifier }) {
            try? gateway.remove(match, span: span)
        }
    }
```

(Adapt names to the existing removal helper rather than duplicating it.)

4.3 — Occurrence detach:

```swift
    func deleteOccurrence(eventID: UUID, occurrenceStart: Date) async throws {
        // EK detach is best-effort; the local exclusion is the source of truth.
        if let event = try await base.event(id: eventID),
           let identifier = event.eventKitIdentifier,
           gateway.eventsAuthStatus.isFullAccess
        {
            let duration = max(event.end.timeIntervalSince(event.start), 60)
            let candidates = gateway.fetchEvents(from: occurrenceStart.addingTimeInterval(-60),
                                                 to: occurrenceStart.addingTimeInterval(duration + 60),
                                                 calendars: nil)
            if let occurrence = candidates.first(where: {
                $0.eventIdentifier == identifier &&
                abs($0.startDate.timeIntervalSince(occurrenceStart)) < 60
            }) {
                try? gateway.remove(occurrence, span: .thisEvent)
            }
        }
        try await base.deleteOccurrence(eventID: eventID, occurrenceStart: occurrenceStart)
    }
```

4.4 — **Sync anchor guard** (in `EventKitSync.reconcileEvents()`): recurring EKEvents enumerate one instance per occurrence with the SAME `eventIdentifier`. Group before reconciling, and never overwrite a recurring app event's anchor dates from a later occurrence:

```swift
        // Group occurrence instances → one canonical (earliest) per series.
        let grouped = Dictionary(grouping: ekEvents) { $0.eventIdentifier ?? UUID().uuidString }
        for (identifier, instances) in grouped {
            guard let canonical = instances.min(by: { $0.startDate < $1.startDate }) else { continue }
            seenIdentifiers.insert(identifier)
            // … existing mapping logic on `canonical` instead of per-instance,
            // with ONE addition in the update branch:
            //   if existing.isRecurring { skip start/end overwrite; update
            //   title/location/notes/recurrence only }
        }
```

Keep the rest of the loop body as-is; this is a wrap-the-loop change, not a rewrite. (Stated limit: an externally-moved series anchor won't re-anchor the app copy; documented.)

- [ ] **Step 5: Run to verify pass**

Run: `-only-testing:WeeklyPlannerTests/EventKitMirroringRecurrenceTests -only-testing:WeeklyPlannerTests/EventStoreTests -only-testing:WeeklyPlannerTests/RecurringEventStoreTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add WeeklyPlanner/Stores/EventStore+EventKit.swift WeeklyPlanner/Stores/EventKit/EventKitSync.swift WeeklyPlannerTests/EventKit/
git commit -m "feat(recurrence): series-span mirroring, occurrence detach, sync grouping + FakeEventKitGateway (Phase 35)"
```

---

### Task 8: Composer + `RecurrenceRow` + sheet hosting

**Files:**
- Modify: `WeeklyPlanner/Features/EventDetail/EventComposerState.swift`
- Create: `WeeklyPlanner/Features/EventDetail/EditableFields/RecurrenceRow.swift`
- Modify: `WeeklyPlanner/Features/EventDetail/PaperEventSheet+Edit.swift`
- Modify: `WeeklyPlanner/Accessibility/AccessibilityIDs.swift`
- Test: `WeeklyPlannerTests/EventDetail/RecurrenceComposerTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import WeeklyPlanner

@MainActor
final class RecurrenceComposerTests: XCTestCase {
    private func makeEvent(recurrence: Recurrence?) -> Event {
        Event(title: "Gym",
              start: Date(timeIntervalSince1970: 1_780_000_000),
              end: Date(timeIntervalSince1970: 1_780_003_600),
              category: .health,
              recurrence: recurrence)
    }

    func testFromEventCarriesRecurrenceAndBuildRoundTrips() {
        let recurrence = Recurrence(frequency: .weekly, interval: 2, end: .afterCount(6))
        let state = EventComposerState.from(makeEvent(recurrence: recurrence))
        XCTAssertEqual(state.recurrence, recurrence)

        let rebuilt = state.build()
        XCTAssertEqual(rebuilt.recurrence, recurrence)
        XCTAssertTrue(rebuilt.isRecurring)
    }

    func testEmptyComposerHasNoRecurrence() {
        let state = EventComposerState.empty(at: Date(timeIntervalSince1970: 1_780_000_000),
                                             calendar: WeekMath.mondayCalendar())
        XCTAssertNil(state.recurrence)
        XCTAssertNil(state.build().recurrence)
        XCTAssertFalse(state.build().isRecurring)
    }

    func testIsDirtyDetectsRecurrenceChange() {
        let baseline = EventComposerState.from(makeEvent(recurrence: nil))
        let edited = EventComposerState.from(makeEvent(recurrence: nil))
        XCTAssertFalse(edited.isDirty(against: baseline))

        edited.recurrence = Recurrence(frequency: .daily)
        XCTAssertTrue(edited.isDirty(against: baseline))
    }
}
```

- [ ] **Step 2: Run to verify failure** — `-only-testing:WeeklyPlannerTests/RecurrenceComposerTests`. Expected: compile failure (`recurrence` missing).

- [ ] **Step 3: Implement composer.** In `EventComposerState`:
- stored property `var recurrence: Recurrence?` (with the other drafts; init param defaulted `recurrence: Recurrence? = nil`, assigned in init);
- `from(_ event:)` sets `recurrence: event.recurrence` (match how the factory passes other fields);
- `build(id:)` passes `recurrence: recurrence` into the `Event(...)` construction;
- `isDirty(against:)` adds `|| recurrence != other.recurrence`.

- [ ] **Step 4: Add accessibility IDs** (in `AccessibilityIDs.swift`):

```swift
    // MARK: Recurrence (Phase 35)
    static let eventRepeatMenu = "paperEventSheet.repeat"
    static let eventRepeatEndMenu = "paperEventSheet.repeat.end"
    static let eventRepeatIntervalMinus = "paperEventSheet.repeat.interval.minus"
    static let eventRepeatIntervalPlus = "paperEventSheet.repeat.interval.plus"
```

- [ ] **Step 5: Implement `RecurrenceRow.swift`** (sibling styling to `PaperDateTimeRow`/`CategorySwatchRow` — 72pt label column, 0.5pt bottom rule):

```swift
import SwiftUI

/// "Repeat" editable row: frequency menu, then (when repeating) an
/// "every N <unit>s" stepper line and an end-condition line.
struct RecurrenceRow: View {
    @Binding var recurrence: Recurrence?

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text("Repeat")
                    .font(font.font(at: 15 * size.scale, weight: .regular))
                    .foregroundStyle(theme.ink2)
                    .frame(width: 72, alignment: .leading)

                Menu {
                    Button("None") { recurrence = nil }
                    ForEach(RecurrenceFrequency.allCases, id: \.self) { frequency in
                        Button(frequency.displayName) { setFrequency(frequency) }
                    }
                } label: {
                    Text(recurrence?.frequency.displayName ?? "None")
                        .font(font.font(at: 15 * size.scale, weight: .regular))
                        .foregroundStyle(theme.ink)
                }
                .tint(theme.blueInk)
                .accessibilityLabel("Repeat")
                .accessibilityValue(recurrence?.frequency.displayName ?? "None")
                .accessibilityIdentifier(AccessibilityIDs.eventRepeatMenu)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)

            if let current = recurrence {
                intervalLine(current)
                endLine(current)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.ink3).frame(height: 0.5)
        }
    }

    private func setFrequency(_ frequency: RecurrenceFrequency) {
        if var current = recurrence {
            current.frequency = frequency
            recurrence = current
        } else {
            recurrence = Recurrence(frequency: frequency)
        }
    }

    private func intervalLine(_ current: Recurrence) -> some View {
        HStack(spacing: 10) {
            Spacer().frame(width: 72)
            Button {
                update { $0.interval = max(1, $0.interval - 1) }
            } label: {
                Image(systemName: "minus.circle").font(.system(size: 16))
                    .foregroundStyle(current.interval > 1 ? theme.blueInk : theme.ink3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Less often")
            .accessibilityIdentifier(AccessibilityIDs.eventRepeatIntervalMinus)

            Text(current.interval == 1
                 ? "Every \(current.frequency.unitName)"
                 : "Every \(current.interval) \(current.frequency.unitName)s")
                .font(font.font(at: 14 * size.scale, weight: .regular))
                .foregroundStyle(theme.ink)

            Button {
                update { $0.interval += 1 }
            } label: {
                Image(systemName: "plus.circle").font(.system(size: 16))
                    .foregroundStyle(theme.blueInk)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("More often")
            .accessibilityIdentifier(AccessibilityIDs.eventRepeatIntervalPlus)

            Spacer(minLength: 0)
        }
        .padding(.bottom, 8)
    }

    private func endLine(_ current: Recurrence) -> some View {
        HStack(spacing: 10) {
            Spacer().frame(width: 72)

            Menu {
                Button("Never") { update { $0.end = .never } }
                Button("On a date") {
                    update { $0.end = .onDate(defaultEndDate) }
                }
                Button("After 10 times") { update { $0.end = .afterCount(10) } }
            } label: {
                Text(endLabel(current.end))
                    .font(font.font(at: 14 * size.scale, weight: .regular))
                    .foregroundStyle(theme.ink)
            }
            .tint(theme.blueInk)
            .accessibilityLabel("Ends")
            .accessibilityValue(endLabel(current.end))
            .accessibilityIdentifier(AccessibilityIDs.eventRepeatEndMenu)

            if case let .onDate(date) = current.end {
                DatePicker("", selection: Binding(
                    get: { date },
                    set: { newDate in update { $0.end = .onDate(newDate) } }),
                    displayedComponents: [.date])
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(theme.blueInk)
            }

            if case let .afterCount(count) = current.end {
                Stepper("", value: Binding(
                    get: { count },
                    set: { newCount in update { $0.end = .afterCount(max(1, newCount)) } }),
                    in: 1 ... 999)
                    .labelsHidden()
                    .accessibilityLabel("Number of times")
            }

            Spacer(minLength: 0)
        }
        .padding(.bottom, 8)
    }

    private func endLabel(_ end: RecurrenceEnd) -> String {
        switch end {
        case .never: "Never ends"
        case .onDate: "Until"
        case let .afterCount(count): "\(count) times"
        }
    }

    private var defaultEndDate: Date {
        Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    }

    private func update(_ transform: (inout Recurrence) -> Void) {
        guard var current = recurrence else { return }
        transform(&current)
        recurrence = current
    }
}

#Preview("RecurrenceRow · weekly, after 6") {
    @Previewable @State var recurrence: Recurrence? =
        Recurrence(frequency: .weekly, interval: 2, end: .afterCount(6))
    return RecurrenceRow(recurrence: $recurrence)
        .padding()
        .background(PaperTheme.cream.cream)
        .paperTheme(.cream)
}
```

- [ ] **Step 6: Host it.** In `PaperEventSheet+Edit.swift` (`EditableEventContent.body`), after `CategorySwatchRow(selection: $composer.category)`:

```swift
            RecurrenceRow(recurrence: $composer.recurrence)
```

- [ ] **Step 7: Run to verify pass**

Run: `-only-testing:WeeklyPlannerTests/RecurrenceComposerTests -only-testing:WeeklyPlannerTests/EventComposerStateTests`
Expected: PASS — new tests green; the existing `testIsDirty_detectsEveryEditableField` still green (it builds fresh copies — if it enumerates fields exhaustively, add the recurrence mutation case there too).

- [ ] **Step 8: Commit**

```bash
git add WeeklyPlanner/Features/EventDetail/ WeeklyPlanner/Accessibility/AccessibilityIDs.swift WeeklyPlannerTests/EventDetail/RecurrenceComposerTests.swift
git commit -m "feat(recurrence): composer draft + paper RecurrenceRow in the event sheet (Phase 35)"
```

---

### Task 9: Read-mode summary + scoped-delete dialog

**Files:**
- Create: `WeeklyPlanner/Features/EventDetail/RecurrenceSummary.swift`
- Modify: `WeeklyPlanner/Features/EventDetail/EventDetailViewModel.swift`
- Modify: read-mode content in `PaperEventSheet.swift` + the delete host (`DayPageView.swift` sheet wiring)
- Test: `WeeklyPlannerTests/EventDetail/RecurrenceSummaryTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import WeeklyPlanner

final class RecurrenceSummaryTests: XCTestCase {
    private func monday() -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 6; c.day = 1; c.hour = 9 // Mon Jun 1 2026
        return WeekMath.mondayCalendar().date(from: c)!
    }

    func testWeeklyMentionsTheWeekday() {
        let text = RecurrenceSummary.text(for: Recurrence(frequency: .weekly), seriesStart: monday())
        XCTAssertEqual(text, "Every week on Mon")
    }

    func testIntervalPluralizes() {
        let text = RecurrenceSummary.text(for: Recurrence(frequency: .weekly, interval: 2), seriesStart: monday())
        XCTAssertEqual(text, "Every 2 weeks on Mon")
    }

    func testDailyUntilDate() {
        var c = DateComponents(); c.year = 2026; c.month = 6; c.day = 30
        let end = WeekMath.mondayCalendar().date(from: c)!
        let text = RecurrenceSummary.text(for: Recurrence(frequency: .daily, end: .onDate(end)), seriesStart: monday())
        XCTAssertEqual(text, "Every day until Jun 30")
    }

    func testMonthlyAfterCount() {
        let text = RecurrenceSummary.text(for: Recurrence(frequency: .monthly, end: .afterCount(5)), seriesStart: monday())
        XCTAssertEqual(text, "Every month, 5 times")
    }

    func testYearlyNeverEnding() {
        let text = RecurrenceSummary.text(for: Recurrence(frequency: .yearly), seriesStart: monday())
        XCTAssertEqual(text, "Every year")
    }
}
```

- [ ] **Step 2: Run to verify failure** — `-only-testing:WeeklyPlannerTests/RecurrenceSummaryTests`. Expected: compile failure.

- [ ] **Step 3: Implement** `RecurrenceSummary.swift`:

```swift
import Foundation

/// Human-readable recurrence line for read mode: "Every week on Mon",
/// "Every 2 weeks on Mon", "Every day until Jun 30", "Every month, 5 times".
enum RecurrenceSummary {
    static func text(for recurrence: Recurrence,
                     seriesStart: Date,
                     calendar: Calendar = WeekMath.mondayCalendar()) -> String
    {
        var base: String = if recurrence.interval == 1 {
            "Every \(recurrence.frequency.unitName)"
        } else {
            "Every \(recurrence.interval) \(recurrence.frequency.unitName)s"
        }

        if recurrence.frequency == .weekly {
            base += " on \(weekdayShortFormatter.string(from: seriesStart))"
        }

        switch recurrence.end {
        case .never:
            return base
        case let .onDate(date):
            return "\(base) until \(monthDayFormatter.string(from: date))"
        case let .afterCount(count):
            return "\(base), \(count) times"
        }
    }

    private static let weekdayShortFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEE"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()

    private static let monthDayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()
}
```

- [ ] **Step 4: Expose on the detail VM.** In `EventDetailViewModel` (next to `aiSuggestion`):

```swift
    /// Read-mode recurrence line, or nil for single events.
    var recurrenceSummary: String? {
        guard let event, let recurrence = event.recurrence else { return nil }
        return RecurrenceSummary.text(for: recurrence, seriesStart: event.start)
    }
```

- [ ] **Step 5: Render it.** In the read-mode content of `PaperEventSheet.swift` (locate the rows showing time/location — grep `EventHeader` usage), add under the time row, styled like the location line:

```swift
            if let summary = viewModel.recurrenceSummary {
                HStack(spacing: 8) {
                    Image(systemName: "repeat")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.ink2)
                    Text(summary)
                        .font(font.font(at: 15 * size.scale, weight: .regular))
                        .foregroundStyle(theme.ink)
                }
                .padding(.vertical, 6)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Repeats: \(summary)")
            }
```

(Adapt the env-property names to the surrounding view; the row content stays as written.)

- [ ] **Step 6: Scoped-delete dialog.** Wherever the sheet's delete action currently calls `eventStore.delete(id:)` (the host in `DayPageView.swift` / the sheet's `onDelete`):

6.1 — Thread the tapped occurrence's start: the day page opens the sheet from a row's `event` — keep `@State private var openEventOccurrenceStart: Date?` next to `openEventID`, set from the tapped (possibly transient-copy) event's `start`.

6.2 — Replace the direct delete with:

```swift
    @State private var showRecurringDeleteDialog = false
```

```swift
    private func requestDelete(for event: Event) {
        if event.recurrence != nil {
            showRecurringDeleteDialog = true
        } else {
            Task { try? await eventStore.delete(id: event.id) ; closeSheet() }
        }
    }
```

```swift
        .confirmationDialog("This is a repeating event",
                            isPresented: $showRecurringDeleteDialog,
                            titleVisibility: .visible) {
            Button("Delete this occurrence", role: .destructive) {
                if let id = openEventID, let start = openEventOccurrenceStart {
                    Task {
                        try? await eventStore.deleteOccurrence(eventID: id, occurrenceStart: start)
                        closeSheet()
                    }
                }
            }
            Button("Delete all occurrences", role: .destructive) {
                if let id = openEventID {
                    Task {
                        try? await eventStore.delete(id: id)
                        closeSheet()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
```

(`closeSheet()` = whatever the host already does after delete — clear `openEventID`/`editingEventID`. Adapt names; keep the dialog labels EXACTLY as written — the UI test matches them.)

- [ ] **Step 7: Run to verify pass**

Run: `-only-testing:WeeklyPlannerTests/RecurrenceSummaryTests -only-testing:WeeklyPlannerTests/EventDetailViewModelTests`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add WeeklyPlanner/Features/EventDetail/ WeeklyPlanner/Features/DayPage/DayPageView.swift WeeklyPlannerTests/EventDetail/RecurrenceSummaryTests.swift
git commit -m "feat(recurrence): read-mode summary + this-vs-all delete dialog (Phase 35)"
```

---

### Task 10: Bounded reminder scheduling

**Files:**
- Modify: `WeeklyPlanner/Notifications/EventNotificationScheduler.swift`
- Test: extend `WeeklyPlannerTests/Notifications/EventNotificationSchedulerTests.swift`

- [ ] **Step 1: Write the failing tests** (the file already has `FakeNotificationCenter` + `FakeLocationRegistrar`)

```swift
    func testRecurringEventSchedulesOnlyWindowedOccurrences() async throws {
        // Weekly with a 15-min alert: a 30-day window holds 4–5 occurrences.
        let start = Date().addingTimeInterval(2 * 24 * 3600)
        let event = Event(title: "Gym",
                          start: start,
                          end: start.addingTimeInterval(3600),
                          category: .health,
                          reminders: [.timeBefore(minutes: 15)],
                          recurrence: Recurrence(frequency: .weekly))

        try await scheduler.schedule(event: event)

        XCTAssertGreaterThanOrEqual(center.addedRequests.count, 4)
        XCTAssertLessThanOrEqual(center.addedRequests.count, 5)
        XCTAssertEqual(Set(center.addedRequests.map(\.identifier)).count,
                       center.addedRequests.count,
                       "Each occurrence needs a distinct identifier")
        XCTAssertTrue(center.addedRequests.allSatisfy {
            $0.identifier.hasPrefix("event-\(event.id.uuidString)-")
        }, "Identifiers must keep the event prefix so re-schedules can purge them")
    }

    func testDailyRecurringIsCappedAtMaxOccurrences() async throws {
        let start = Date().addingTimeInterval(24 * 3600)
        let event = Event(title: "Walk",
                          start: start,
                          end: start.addingTimeInterval(1800),
                          category: .health,
                          reminders: [.timeBefore(minutes: 5)],
                          recurrence: Recurrence(frequency: .daily))

        try await scheduler.schedule(event: event)

        XCTAssertEqual(center.addedRequests.count, 8,
                       "30-day daily series must cap at the max-occurrence bound")
    }

    func testExcludedOccurrenceIsNotScheduled() async throws {
        let start = Date().addingTimeInterval(24 * 3600)
        let excluded = start.addingTimeInterval(7 * 24 * 3600)
        let event = Event(title: "Gym",
                          start: start,
                          end: start.addingTimeInterval(3600),
                          category: .health,
                          reminders: [.timeBefore(minutes: 15)],
                          recurrence: Recurrence(frequency: .weekly),
                          excludedOccurrenceStarts: [excluded])

        try await scheduler.schedule(event: event)

        let expectedExcludedFire = excluded.addingTimeInterval(-15 * 60)
        for request in center.addedRequests {
            if let trigger = request.trigger as? UNCalendarNotificationTrigger,
               let fire = Calendar.current.date(from: trigger.dateComponents)
            {
                XCTAssertGreaterThan(abs(fire.timeIntervalSince(expectedExcludedFire)), 60,
                                     "Excluded occurrence must not get a reminder")
            }
        }
    }

    func testSingleEventIdentifiersUnchanged() async throws {
        // Phase 19 contract: single events keep "event-<id>-time-<min>".
        let start = Date().addingTimeInterval(7 * 24 * 3600)
        let event = Event(title: "Lunch",
                          start: start,
                          end: start.addingTimeInterval(3600),
                          category: .personal,
                          reminders: [.timeBefore(minutes: 15)])

        try await scheduler.schedule(event: event)

        XCTAssertEqual(center.addedRequests.map(\.identifier),
                       ["event-\(event.id.uuidString)-time-15"])
    }
```

- [ ] **Step 2: Run to verify failure** — `-only-testing:WeeklyPlannerTests/EventNotificationSchedulerTests`. Expected: new tests fail (recurring schedules once, at the master only).

- [ ] **Step 3: Implement.** In `EventNotificationScheduler`:

3.1 — Constants:

```swift
    /// Recurring series schedule only this far ahead; the Phase 19
    /// rescheduling observer rolls the window forward on every event
    /// change / app activation.
    static let recurringWindowDays = 30
    static let recurringMaxOccurrences = 8
```

3.2 — Refactor `scheduleTime` to take the firing anchor + an identifier suffix (single events keep the EXACT old identifier via the default):

```swift
    private func scheduleTime(event: Event,
                              occurrenceStart: Date,
                              minutesBefore: Int,
                              occurrenceSuffix: String = "") async throws
    {
        let fireDate = occurrenceStart.addingTimeInterval(TimeInterval(-minutesBefore * 60))
        guard fireDate > Date() else { return } // Past — silently skip.
        let identifier = "event-\(event.id.uuidString)-\(occurrenceSuffix)time-\(minutesBefore)"
        // … existing content + UNCalendarNotificationTrigger construction,
        // now built from `fireDate` and `identifier` …
    }
```

3.3 — In `schedule(event:)`, branch after the existing prefix purge + location unregister:

```swift
        if let recurrence = event.recurrence {
            let calendar = WeekMath.mondayCalendar()
            let now = Date()
            let windowEnd = calendar.date(byAdding: .day, value: Self.recurringWindowDays, to: now) ?? now
            let starts = OccurrenceExpander.occurrenceStarts(
                seriesStart: event.start,
                recurrence: recurrence,
                in: now ..< windowEnd,
                excluding: event.excludedOccurrenceStarts,
                calendar: calendar)
                .prefix(Self.recurringMaxOccurrences)

            for start in starts {
                for reminder in event.reminders {
                    do {
                        switch reminder {
                        case let .timeBefore(minutes):
                            try await scheduleTime(event: event,
                                                   occurrenceStart: start,
                                                   minutesBefore: minutes,
                                                   occurrenceSuffix: "occ-\(Int(start.timeIntervalSince1970))-")
                        case .onArrive:
                            break // Location reminders are not per-occurrence.
                        }
                    } catch {
                        Self.log.error("Recurring schedule failed: \(String(describing: error))")
                    }
                }
            }
            // Location reminders register once for the series.
            for reminder in event.reminders {
                if case let .onArrive(location) = reminder {
                    scheduleArrival(event: event, reminder: location)
                }
            }
            return
        }
        // …existing single-event loop, with the time case now calling
        // scheduleTime(event:, occurrenceStart: event.start, minutesBefore:)…
```

- [ ] **Step 4: Run to verify pass** — whole `EventNotificationSchedulerTests` class. Expected: PASS, old tests included (identifier contract pinned by `testSingleEventIdentifiersUnchanged`).

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Notifications/EventNotificationScheduler.swift WeeklyPlannerTests/Notifications/EventNotificationSchedulerTests.swift
git commit -m "feat(recurrence): bounded recurring reminder scheduling — 30-day window, 8-occurrence cap (Phase 35)"
```

---

### Task 11: Gmail accept path stays single-occurrence

**Files:**
- Test: `WeeklyPlannerTests/Stores/InboxAcceptRecurrenceGuardTests.swift` (mirror the setup of the existing InboxStore accept tests — grep `func accept` under `WeeklyPlannerTests/`)

- [ ] **Step 1: Write the test** (this is a pin, not new behavior — it should pass immediately)

```swift
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class InboxAcceptRecurrenceGuardTests: XCTestCase {
    func testAcceptedGmailSuggestionIsSingleOccurrence() async throws {
        let container = try SwiftDataStack.inMemoryContainer()
        let eventStore = SwiftDataEventStore(context: container.mainContext)
        let inboxStore = SwiftDataInboxStore(context: container.mainContext)
        // Match the existing accept-test wiring for connecting eventStore to
        // inboxStore (property/init — copy from the existing accept tests).
        inboxStore.eventStore = eventStore

        let suggestion = InboxSuggestion(title: "Coffee with Alex",
                                         proposedStart: Date().addingTimeInterval(86_400),
                                         category: .personal)
        // Adapt the construction to InboxSuggestion's actual initializer —
        // copy a fixture from the existing InboxStore tests.
        container.mainContext.insert(suggestion)
        try container.mainContext.save()

        try await inboxStore.accept(id: suggestion.id)

        let events = try container.mainContext.fetch(FetchDescriptor<Event>())
        XCTAssertEqual(events.count, 1)
        XCTAssertNil(events.first?.recurrence, "Phase 18 path must stay single-occurrence")
        XCTAssertFalse(events.first?.isRecurring ?? true)
    }
}
```

⚠️ The fixture construction and `eventStore` wiring MUST be copied from the existing InboxStore accept tests (the initializer has more fields). The assertion block is the deliverable.

- [ ] **Step 2: Run** — `-only-testing:WeeklyPlannerTests/InboxAcceptRecurrenceGuardTests`. Expected: PASS first try (guard test).

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlannerTests/Stores/InboxAcceptRecurrenceGuardTests.swift
git commit -m "test(recurrence): pin Gmail accept path to single-occurrence events (Phase 35)"
```

---

### Task 12: UI test — daily series across days + scoped delete

**Files:**
- Create: `WeeklyPlannerUITests/RepeatingEventUITests.swift`

- [ ] **Step 1: Write the UI test** (daily recurrence + side-tab navigation = deterministic any day of the week; weekly-across-weeks is covered by unit tests and the on-device acceptance check)

```swift
import XCTest

final class RepeatingEventUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testDailyEventAppearsOnAdjacentDayAndScopedDeleteWorks() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestSeedEmptyStore"]
        app.launch()

        let calendarTab = app.buttons["tabbar.tab.calendar"]
        if calendarTab.waitForExistence(timeout: 3) { calendarTab.tap() }
        let daySeg = app.buttons["topbar.dayweek.day"]
        if daySeg.waitForExistence(timeout: 3) { daySeg.tap() }

        // Create a daily event.
        let addLink = app.buttons["daypage.events.addRow"]
        XCTAssertTrue(addLink.waitForExistence(timeout: 5))
        addLink.tap()

        let title = "UITest Daily \(UUID().uuidString.prefix(6))"
        let titleField = app.textFields.firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 2)
        titleField.typeText(String(title))

        app.buttons["paperEventSheet.repeat"].tap()
        let daily = app.buttons["Daily"]
        XCTAssertTrue(daily.waitForExistence(timeout: 3), "Repeat menu did not open")
        daily.tap()

        let save = app.buttons["paperEventSheet.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 2))
        save.tap()
        _ = save.waitForNonExistence(timeout: 5)

        let predicate = NSPredicate(format: "label CONTAINS %@", String(title))
        XCTAssertTrue(app.descendants(matching: .any).matching(predicate).firstMatch
            .waitForExistence(timeout: 5), "Event missing on its creation day")

        // Navigate to an ADJACENT day in the same week via side tabs:
        // pick any side tab that isn't the currently-selected day.
        var adjacentFound = false
        for index in 0 ..< 7 {
            let tab = app.buttons["daypage.sidetab.\(index)"]
            guard tab.waitForExistence(timeout: 1), tab.isHittable else { continue }
            tab.tap()
            if app.descendants(matching: .any).matching(predicate).firstMatch
                .waitForExistence(timeout: 3)
            {
                adjacentFound = true
                break
            }
        }
        XCTAssertTrue(adjacentFound, "Daily event not found on any other day of the week")

        // Open the occurrence → delete ALL occurrences via the dialog.
        app.descendants(matching: .any).matching(predicate).firstMatch.tap()
        // Trigger delete from the sheet (read → edit → delete, or direct
        // delete affordance — follow the existing EventCreateFlow test's path).
        let deleteButton = app.buttons["Delete event"]
        if !deleteButton.waitForExistence(timeout: 3) {
            // Sheet may need edit mode for the delete affordance.
            let edit = app.buttons["paperEventSheet.edit"]
            if edit.waitForExistence(timeout: 2) { edit.tap() }
        }
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3))
        deleteButton.tap()

        let deleteAll = app.buttons["Delete all occurrences"]
        XCTAssertTrue(deleteAll.waitForExistence(timeout: 3),
                      "Scoped-delete dialog did not appear for a repeating event")
        deleteAll.tap()

        XCTAssertTrue(app.descendants(matching: .any).matching(predicate).firstMatch
            .waitForNonExistence(timeout: 5), "Series not removed after delete-all")
    }
}
```

⚠️ The delete-affordance path (read vs edit mode) must follow the actual Phase 22 sheet flow — adjust the two lines marked above; the dialog-button labels are fixed by Task 9.

- [ ] **Step 2: Run** — `-only-testing:WeeklyPlannerUITests/RepeatingEventUITests`. Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlannerUITests/RepeatingEventUITests.swift
git commit -m "test(recurrence): UI — daily series across days + delete-all-occurrences dialog (Phase 35)"
```

---

### Task 13: Full-suite verification (superpowers:verification-before-completion)

- [ ] **Step 1: FULL unit suite**

```bash
xcodegen generate
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=<available iPhone, iOS 26.5>' \
  -only-testing:WeeklyPlannerTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO
```

Expected: `** TEST SUCCEEDED **`, 0 failures.

- [ ] **Step 2: UI suites** — `-only-testing:WeeklyPlannerUITests/RepeatingEventUITests -only-testing:WeeklyPlannerUITests/EventCreateFlowUITests -only-testing:WeeklyPlannerUITests/SmokeUITests`. Expected: PASS.

- [ ] **Step 3: Spec checklist sweep** — `docs/phases/phase-35-repeating-events.md`: Repeat row ✓, occurrences across Day/Week ✓ (store-level expansion feeds both), human-readable summary ✓, this-vs-all delete ✓, EventKit round-trip (mirror) ✓, mapper fidelity ✓, bounded reminders ✓, Gmail unaffected ✓. Record the declared deviation (local display expander) and the stated v1 limits in the report.

- [ ] **Step 4: On-device acceptance note** — flag for the user: create a weekly event in-app on a device with Calendar access → verify the rule shows in iOS Calendar (and an external edit syncs back). This is the acceptance criterion that can't run in CI.

- [ ] **Step 5: Report** — branch, files, test counts, deviations.

---

## Self-review notes

- **Spec coverage:** value type + mapper (T1–2), expansion (T3–4), EK mirror w/ spans (T5–7), composer UI (T8), read mode + scoped delete (T9), bounded reminders (T10), Gmail guard (T11), UI test (T12). Out of scope honored: no complex RRULEs, no per-occurrence edits, no natural-language entry.
- **Type consistency:** `Recurrence(frequency:interval:end:)`, `RecurrenceMapper.toEKRule/toRecurrence`, `OccurrenceExpander.occurrenceStarts(seriesStart:recurrence:in:excluding:calendar:limit:)` / `occurrences(of:in:calendar:)`, `Event.occurrenceCopy(start:)`, `deleteOccurrence(eventID:occurrenceStart:)` — identical signatures across all tasks/tests.
- **Declared deviation:** local display expander (top of doc) — surface at plan review and in the final report.
- **Known adaptation points (executor judgment, behavior fixed):** `CategoryCalendarManager` init in the fake's wiring (T7), read-sheet row placement + delete-affordance path (T9, T12), InboxSuggestion fixture fields (T11).
- **Known intermediate states:** Task 3's `occurrences(of:)` references Task 4's model fields — the task notes the allowed split (commit `occurrenceStarts` first) if compiling strictly per-task.
