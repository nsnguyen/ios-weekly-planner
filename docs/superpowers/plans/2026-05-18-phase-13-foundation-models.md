# Phase 13 — Foundation Models Integration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the canned AI overlay answers with on-device Foundation Models responses backed by tool calls into the planner's stores, while preserving a clean fallback when Apple Intelligence is unavailable.

**Architecture:** A new `WeeklyPlanner/Intelligence/` module owns everything AI. An `IntelligenceService` protocol is the only surface the rest of the app talks to. The protocol is OS-agnostic and pure-Swift so tests don't import `FoundationModels`. A concrete `PlannerLanguageModel` (gated `@available(iOS 26.0, *)`) wraps `LanguageModelSession` with five `Tool` conformers that call into `EventStoring`, `TaskStoring`, and `InboxStoring`. `AISearchViewModel` switches from the canned-data stub to the protocol, with a deterministic `StubIntelligenceService` reused both in tests and as the runtime fallback when the model is unavailable / disabled.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, `FoundationModels` (iOS 26+), XCTest, XcodeGen.

**Scope split:** This plan covers the Intelligence layer + AI Search overlay wiring only. The three generators called out in `docs/phases/phase-13-foundation-models.md` (StickyInsightGenerator, WeekSummaryGenerator, EventSuggestionGenerator) are explicitly **deferred to Phase 13-b**. Reason: WeekSummary depends on Phase 14 (Review page, not yet built); StickyInsight and EventSuggestion require background-task and sheet-lifecycle wiring that adds risk to the milestone. Once 13-a is green, 13-b is one focused PR per generator on top of the same `IntelligenceService` surface.

---

## File Structure

### Created

```
WeeklyPlanner/Intelligence/
├── Availability.swift                 # AvailabilityState enum, runtime probe
├── IntelligenceService.swift          # Protocol + AnswerDelta type
├── PlannerContext.swift               # Per-request context (clock, week offset, settings snapshot)
├── PlannerLanguageModel.swift         # Foundation Models bridge (iOS 26+)
├── SafetyGuard.swift                  # Pre/post sanitization
├── StubIntelligenceService.swift      # Deterministic fallback + test double
├── SystemPrompt.swift                 # Persona + tool capabilities + privacy reminder
└── Tools/
    ├── EventQuery.swift               # Value query passed to FindEventsTool
    ├── FindEventsTool.swift
    ├── FindFreeSlotsTool.swift
    ├── LastInteractionTool.swift
    ├── ScanInboxTool.swift
    ├── SummarizeWeekTool.swift
    ├── ToolEventResult.swift          # Wire DTOs returned to the model
    └── ToolRegistry.swift             # Builds the [any Tool] array + dispatch helper

WeeklyPlannerTests/Intelligence/
├── AvailabilityTests.swift
├── EventQueryTests.swift
├── FindEventsToolTests.swift
├── FindFreeSlotsToolTests.swift
├── LastInteractionToolTests.swift
├── SafetyGuardTests.swift
├── ScanInboxToolTests.swift
├── StubIntelligenceServiceTests.swift
├── SummarizeWeekToolTests.swift
├── SystemPromptTests.swift
└── ToolRegistryTests.swift
```

### Modified

```
WeeklyPlanner/Features/AISearch/AISearchViewModel.swift   # swap canned data for IntelligenceService + fallback
WeeklyPlanner/App/RootView.swift                          # construct + inject IntelligenceService
WeeklyPlanner/Stores/Environment+Stores.swift             # add intelligence service to environment
WeeklyPlanner/Stores/EventStore.swift                     # add events(matching: EventQuery) overload
WeeklyPlannerTests/AISearch/AISearchViewModelTests.swift  # update to use injected IntelligenceService
docs/phases/README.md                                     # phase 13-a retrospective + 13-b deferred note
```

### Conventions confirmed

- XcodeGen autodiscovers `WeeklyPlanner/**` and `WeeklyPlannerTests/**`, so new files appear in the project after `xcodegen generate`. No manual file references.
- Existing tests use XCTest with `@MainActor` and `SwiftDataStack.inMemoryContainer()` per-test. Follow that pattern.
- All store protocols are `@MainActor`. The Intelligence layer is `@MainActor` too, for simplicity — Foundation Models calls await, so the actor isn't a throughput concern.
- `Swift 6, SWIFT_STRICT_CONCURRENCY: complete` — all new types must compile clean under strict concurrency. Sendable on value types only; reference types stay actor-isolated.

---

## Task 1: Create milestone-e-intelligence worktree

**Files:** none

- [ ] **Step 1: Confirm clean working tree on main**

Run: `git -C /Users/nguyen-mini/Documents/dev/ios-weekly-planner status --short`
Expected: empty output (clean) OR only ` M AGENTS.md` (auto-memory rotation, ignore).

- [ ] **Step 2: Create worktree and branch**

```bash
git -C /Users/nguyen-mini/Documents/dev/ios-weekly-planner worktree add ../ios-weekly-planner-phase-13 -b milestone-e-intelligence main
```

Expected: `Preparing worktree (new branch 'milestone-e-intelligence')` and a created sibling directory.

- [ ] **Step 3: Switch working directory**

All subsequent commands and edits use `/Users/nguyen-mini/Documents/dev/ios-weekly-planner-phase-13` as the project root. Anchor every path below to that root.

- [ ] **Step 4: Sanity-check the worktree builds before any changes**

```bash
cd /Users/nguyen-mini/Documents/dev/ios-weekly-planner-phase-13
xcodegen generate
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' -quiet build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **` on the last line.

---

## Task 2: AvailabilityState enum (no framework deps)

**Files:**
- Create: `WeeklyPlanner/Intelligence/Availability.swift`
- Test: `WeeklyPlannerTests/Intelligence/AvailabilityTests.swift`

- [ ] **Step 1: Write the failing test**

`WeeklyPlannerTests/Intelligence/AvailabilityTests.swift`:

```swift
import XCTest
@testable import WeeklyPlanner

final class AvailabilityTests: XCTestCase {
    func testUnavailableReasonsAreDistinct() {
        let cases: Set<AvailabilityState> = [
            .available,
            .unavailable(.deviceNotEligible),
            .unavailable(.modelNotReady),
            .unavailable(.appleIntelligenceNotEnabled),
            .unavailable(.userDisabled),
        ]
        XCTAssertEqual(cases.count, 5)
    }

    func testIsAvailableShortcut() {
        XCTAssertTrue(AvailabilityState.available.isAvailable)
        XCTAssertFalse(AvailabilityState.unavailable(.userDisabled).isAvailable)
    }

    func testFallbackMessageMatchesSpec() {
        XCTAssertEqual(
            AvailabilityState.unavailable(.deviceNotEligible).fallbackMessage,
            "Apple Intelligence is unavailable on this device. Showing canned suggestions."
        )
        XCTAssertEqual(
            AvailabilityState.unavailable(.userDisabled).fallbackMessage,
            "Apple Intelligence is turned off in Settings. Showing canned suggestions."
        )
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:WeeklyPlannerTests/AvailabilityTests test 2>&1 | tail -25
```

Expected: compile failure — `cannot find 'AvailabilityState' in scope`.

- [ ] **Step 3: Implement**

`WeeklyPlanner/Intelligence/Availability.swift`:

```swift
import Foundation

/// Snapshot of whether the on-device Foundation Models pipeline is ready to
/// answer a query. Computed by `IntelligenceService.availability()` at every
/// call site so a long-running session reacts to Settings toggles, model
/// downloads, and thermal state changes without restart.
enum AvailabilityState: Hashable {
    case available
    case unavailable(Reason)

    enum Reason: Hashable {
        /// Hardware can't run Apple Intelligence (older device).
        case deviceNotEligible
        /// Model files are still downloading or warming up.
        case modelNotReady
        /// User hasn't enabled Apple Intelligence in iOS Settings.
        case appleIntelligenceNotEnabled
        /// User flipped the planner's own AI toggle off (UserSettings).
        case userDisabled
    }

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }

    /// Single short string shown in the AI overlay footer when we fall back.
    var fallbackMessage: String {
        switch self {
        case .available:
            return ""
        case .unavailable(.deviceNotEligible):
            return "Apple Intelligence is unavailable on this device. Showing canned suggestions."
        case .unavailable(.modelNotReady):
            return "Apple Intelligence is warming up. Showing canned suggestions."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Enable Apple Intelligence in Settings to get personalized answers. Showing canned suggestions."
        case .unavailable(.userDisabled):
            return "Apple Intelligence is turned off in Settings. Showing canned suggestions."
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:WeeklyPlannerTests/AvailabilityTests test 2>&1 | tail -10
```

Expected: `Test Suite 'AvailabilityTests' passed`.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Intelligence/Availability.swift \
        WeeklyPlannerTests/Intelligence/AvailabilityTests.swift
git commit -m "feat(phase-13): AvailabilityState enum with fallback copy"
```

---

## Task 3: PlannerContext value type

**Files:**
- Create: `WeeklyPlanner/Intelligence/PlannerContext.swift`
- Test: none (pure data carrier — covered transitively by ToolRegistryTests and StubIntelligenceServiceTests)

- [ ] **Step 1: Implement**

`WeeklyPlanner/Intelligence/PlannerContext.swift`:

```swift
import Foundation

/// Per-request execution context handed to `IntelligenceService` and its
/// tools. Carries enough state for a tool call to scope its search without
/// any tool reaching back into global singletons.
///
/// Value-typed and `Sendable` so it can cross actor hops cleanly.
struct PlannerContext: Sendable {
    /// "Now" for week-math and last-interaction queries. Injected so tests
    /// can pin a deterministic Saturday-May-16 anchor.
    let now: Date

    /// Week the user is currently viewing (relative to the week containing
    /// `now`). Lets the model bias date-range tool calls toward what's on
    /// screen.
    let viewedWeekOffset: Int

    /// Hard upper bound on tokens for the model's reply. Different surfaces
    /// pass different values: 256 for the search overlay, 120 for stickies.
    let maxResponseTokens: Int

    /// Whether Apple Intelligence is enabled in `UserSettings`. The service
    /// re-checks this every call so a Settings flip doesn't need a restart.
    let appleIntelligenceEnabled: Bool

    /// Default tuned for the AI overlay.
    static let `default` = PlannerContext(
        now: .init(),
        viewedWeekOffset: 0,
        maxResponseTokens: 256,
        appleIntelligenceEnabled: true
    )
}
```

- [ ] **Step 2: Verify it compiles**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' -quiet build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Intelligence/PlannerContext.swift
git commit -m "feat(phase-13): PlannerContext value type"
```

---

## Task 4: EventQuery + events(matching:) overload

**Files:**
- Create: `WeeklyPlanner/Intelligence/Tools/EventQuery.swift`
- Modify: `WeeklyPlanner/Stores/EventStore.swift`
- Test: `WeeklyPlannerTests/Intelligence/EventQueryTests.swift`

- [ ] **Step 1: Write the failing test**

`WeeklyPlannerTests/Intelligence/EventQueryTests.swift`:

```swift
import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class EventQueryTests: XCTestCase {
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

    func testMatchingFiltersByCategory() async throws {
        let anchor = Self.may16_2026(hour: 9)
        try await store.upsert(Event(title: "Run", start: anchor, end: anchor.addingTimeInterval(1800), category: .health))
        try await store.upsert(Event(title: "Standup", start: anchor.addingTimeInterval(3600),
                                     end: anchor.addingTimeInterval(5400), category: .work))

        let query = EventQuery(
            dateRange: anchor ... anchor.addingTimeInterval(7200),
            categories: [.health],
            keywords: [],
            personName: nil
        )
        let results = try await store.events(matching: query)
        XCTAssertEqual(results.map(\.title), ["Run"])
    }

    func testMatchingFiltersByKeywordCaseInsensitive() async throws {
        let anchor = Self.may16_2026(hour: 9)
        try await store.upsert(Event(title: "Dentist follow-up", start: anchor,
                                     end: anchor.addingTimeInterval(1800), category: .health))
        try await store.upsert(Event(title: "Pitch deck review", start: anchor.addingTimeInterval(3600),
                                     end: anchor.addingTimeInterval(5400), category: .work))

        let query = EventQuery(
            dateRange: anchor ... anchor.addingTimeInterval(7200),
            categories: nil,
            keywords: ["DENTIST"],
            personName: nil
        )
        let results = try await store.events(matching: query)
        XCTAssertEqual(results.map(\.title), ["Dentist follow-up"])
    }

    func testMatchingFiltersByPersonName() async throws {
        let anchor = Self.may16_2026(hour: 9)
        try await store.upsert(Event(title: "Coffee with Sara", start: anchor,
                                     end: anchor.addingTimeInterval(1800), category: .personal))
        try await store.upsert(Event(title: "Team sync", start: anchor.addingTimeInterval(3600),
                                     end: anchor.addingTimeInterval(5400), category: .work))

        let query = EventQuery(
            dateRange: anchor ... anchor.addingTimeInterval(7200),
            categories: nil,
            keywords: [],
            personName: "sara"
        )
        let results = try await store.events(matching: query)
        XCTAssertEqual(results.map(\.title), ["Coffee with Sara"])
    }

    private static func may16_2026(hour: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 16
        components.hour = hour
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:WeeklyPlannerTests/EventQueryTests test 2>&1 | tail -25
```

Expected: compile failure — `cannot find 'EventQuery' in scope` and `events(matching:)` unknown.

- [ ] **Step 3: Implement the value type**

`WeeklyPlanner/Intelligence/Tools/EventQuery.swift`:

```swift
import Foundation

/// Compact filter struct used by `FindEventsTool` and the
/// `EventStoring.events(matching:)` overload. All fields are additive — an
/// empty array or `nil` means "don't filter on this axis".
struct EventQuery: Sendable, Equatable {
    let dateRange: ClosedRange<Date>
    let categories: [Category]?
    let keywords: [String]
    let personName: String?
}
```

- [ ] **Step 4: Add the overload on EventStoring**

Modify `WeeklyPlanner/Stores/EventStore.swift` — extend the protocol and the concrete store. Append after the existing `delete(id:)` method on `EventStoring`:

```swift
    /// Returns events inside `query.dateRange` filtered by the optional
    /// category / keyword / person-name axes. Used by the Intelligence
    /// layer (Phase 13) so the model can ask narrower questions than
    /// `events(forWeekOffset:)`.
    func events(matching query: EventQuery) async throws -> [Event]
```

And on `SwiftDataEventStore`, add a default implementation:

```swift
    func events(matching query: EventQuery) async throws -> [Event] {
        let start = query.dateRange.lowerBound
        let end = query.dateRange.upperBound
        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { $0.start >= start && $0.start <= end },
            sortBy: [SortDescriptor(\.start, order: .forward)]
        )
        let raw = try context.fetch(descriptor)
        return raw.filter { event in
            if let categories = query.categories, !categories.isEmpty {
                guard categories.contains(where: { $0.rawValue == event.categoryRaw }) else { return false }
            }
            if !query.keywords.isEmpty {
                let lowered = event.title.lowercased()
                guard query.keywords.contains(where: { lowered.contains($0.lowercased()) }) else { return false }
            }
            if let person = query.personName, !person.isEmpty {
                let lowered = event.title.lowercased()
                guard lowered.contains(person.lowercased()) else { return false }
            }
            return true
        }
    }
```

- [ ] **Step 5: Run test to verify it passes**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:WeeklyPlannerTests/EventQueryTests test 2>&1 | tail -10
```

Expected: `Test Suite 'EventQueryTests' passed`.

- [ ] **Step 6: Commit**

```bash
git add WeeklyPlanner/Intelligence/Tools/EventQuery.swift \
        WeeklyPlanner/Stores/EventStore.swift \
        WeeklyPlannerTests/Intelligence/EventQueryTests.swift
git commit -m "feat(phase-13): EventQuery + EventStoring.events(matching:) overload"
```

---

## Task 5: ToolEventResult + ToolRegistry skeleton

**Files:**
- Create: `WeeklyPlanner/Intelligence/Tools/ToolEventResult.swift`
- Create: `WeeklyPlanner/Intelligence/Tools/ToolRegistry.swift`
- Test: `WeeklyPlannerTests/Intelligence/ToolRegistryTests.swift`

- [ ] **Step 1: Write the failing test**

`WeeklyPlannerTests/Intelligence/ToolRegistryTests.swift`:

```swift
import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class ToolRegistryTests: XCTestCase {
    private var container: ModelContainer!
    private var events: SwiftDataEventStore!
    private var tasks: SwiftDataTaskStore!
    private var inbox: SwiftDataInboxStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        events = SwiftDataEventStore(context: container.mainContext)
        tasks = SwiftDataTaskStore(context: container.mainContext)
        inbox = SwiftDataInboxStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        events = nil; tasks = nil; inbox = nil; container = nil
        try await super.tearDown()
    }

    func testRegistryExposesFiveToolsInStableOrder() {
        let registry = ToolRegistry(events: events, tasks: tasks, inbox: inbox)
        let names = registry.allTools.map(\.name)
        XCTAssertEqual(names, ["findEvents", "findFreeSlots", "scanInbox", "summarizeWeek", "lastInteraction"])
    }

    func testToolEventResultRoundTripsThroughCodable() throws {
        let id = UUID()
        let result = ToolEventResult(
            id: id,
            title: "Dentist follow-up",
            start: Date(timeIntervalSince1970: 1_780_000_000),
            end: Date(timeIntervalSince1970: 1_780_003_600),
            location: "4th Street Dental",
            categoryRaw: "health",
            sourceRaw: "manual"
        )
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(ToolEventResult.self, from: data)
        XCTAssertEqual(decoded, result)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:WeeklyPlannerTests/ToolRegistryTests test 2>&1 | tail -25
```

Expected: compile failure — `cannot find 'ToolRegistry' in scope`, `cannot find 'ToolEventResult' in scope`.

- [ ] **Step 3: Implement ToolEventResult**

`WeeklyPlanner/Intelligence/Tools/ToolEventResult.swift`:

```swift
import Foundation

/// Wire-format event surfaced to the model. Plain values only — no
/// SwiftData entities cross the protocol boundary so the model layer can
/// be unit-tested without a live store.
struct ToolEventResult: Codable, Equatable, Sendable {
    let id: UUID
    let title: String
    let start: Date
    let end: Date
    let location: String?
    let categoryRaw: String
    let sourceRaw: String
}

/// Compact free-slot pair returned by `FindFreeSlotsTool`.
struct ToolFreeSlot: Codable, Equatable, Sendable {
    let start: Date
    let end: Date
}

/// Compact inbox suggestion returned by `ScanInboxTool`.
struct ToolInboxResult: Codable, Equatable, Sendable {
    let id: UUID
    let title: String
    let proposedStart: Date
    let fromName: String?
    let subject: String?
}

/// Per-category hours rollup returned by `SummarizeWeekTool`.
struct ToolWeekSummary: Codable, Equatable, Sendable {
    let hoursByCategory: [String: Double]
    let tasksDone: Int
    let tasksOpen: Int
    let highlightEventIDs: [UUID]
}

/// Last-interaction record returned by `LastInteractionTool`.
struct ToolLastInteraction: Codable, Equatable, Sendable {
    let eventID: UUID?
    let date: Date?
    let context: String
}
```

- [ ] **Step 4: Implement ToolRegistry**

`WeeklyPlanner/Intelligence/Tools/ToolRegistry.swift`:

```swift
import Foundation

/// Stable, Foundation-Models-agnostic identifier for an Intelligence tool.
/// The same name is used in the system prompt, in tool dispatch, and as the
/// `Tool.name` exposed to `LanguageModelSession` once the FM bridge runs.
protocol PlannerTool: Sendable {
    var name: String { get }
}

/// Owns the five tools the Intelligence layer exposes to the model. Pure
/// protocol-talk to the stores so unit tests can swap in any
/// `EventStoring` / `TaskStoring` / `InboxStoring` conformer.
@MainActor
final class ToolRegistry {
    let findEvents: FindEventsTool
    let findFreeSlots: FindFreeSlotsTool
    let scanInbox: ScanInboxTool
    let summarizeWeek: SummarizeWeekTool
    let lastInteraction: LastInteractionTool

    init(events: any EventStoring, tasks: any TaskStoring, inbox: any InboxStoring) {
        self.findEvents = FindEventsTool(store: events)
        self.findFreeSlots = FindFreeSlotsTool(store: events)
        self.scanInbox = ScanInboxTool(store: inbox)
        self.summarizeWeek = SummarizeWeekTool(events: events, tasks: tasks)
        self.lastInteraction = LastInteractionTool(store: events)
    }

    /// Stable ordering — referenced by `SystemPrompt` to enumerate
    /// capabilities and by `ToolRegistryTests`.
    var allTools: [any PlannerTool] {
        [findEvents, findFreeSlots, scanInbox, summarizeWeek, lastInteraction]
    }
}
```

- [ ] **Step 5: Stub the five Tool types so ToolRegistry compiles**

Create thin placeholder files (each task below replaces the body). For now, each one carries only the `name` property:

`WeeklyPlanner/Intelligence/Tools/FindEventsTool.swift`:

```swift
import Foundation

@MainActor
final class FindEventsTool: PlannerTool {
    let name = "findEvents"
    private let store: any EventStoring
    init(store: any EventStoring) { self.store = store }
}
```

`WeeklyPlanner/Intelligence/Tools/FindFreeSlotsTool.swift`:

```swift
import Foundation

@MainActor
final class FindFreeSlotsTool: PlannerTool {
    let name = "findFreeSlots"
    private let store: any EventStoring
    init(store: any EventStoring) { self.store = store }
}
```

`WeeklyPlanner/Intelligence/Tools/ScanInboxTool.swift`:

```swift
import Foundation

@MainActor
final class ScanInboxTool: PlannerTool {
    let name = "scanInbox"
    private let store: any InboxStoring
    init(store: any InboxStoring) { self.store = store }
}
```

`WeeklyPlanner/Intelligence/Tools/SummarizeWeekTool.swift`:

```swift
import Foundation

@MainActor
final class SummarizeWeekTool: PlannerTool {
    let name = "summarizeWeek"
    private let events: any EventStoring
    private let tasks: any TaskStoring
    init(events: any EventStoring, tasks: any TaskStoring) {
        self.events = events
        self.tasks = tasks
    }
}
```

`WeeklyPlanner/Intelligence/Tools/LastInteractionTool.swift`:

```swift
import Foundation

@MainActor
final class LastInteractionTool: PlannerTool {
    let name = "lastInteraction"
    private let store: any EventStoring
    init(store: any EventStoring) { self.store = store }
}
```

- [ ] **Step 6: Run test to verify it passes**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:WeeklyPlannerTests/ToolRegistryTests test 2>&1 | tail -10
```

Expected: `Test Suite 'ToolRegistryTests' passed`.

- [ ] **Step 7: Commit**

```bash
git add WeeklyPlanner/Intelligence/Tools \
        WeeklyPlannerTests/Intelligence/ToolRegistryTests.swift
git commit -m "feat(phase-13): ToolRegistry skeleton + ToolEventResult DTOs"
```

---

## Task 6: FindEventsTool

**Files:**
- Modify: `WeeklyPlanner/Intelligence/Tools/FindEventsTool.swift`
- Test: `WeeklyPlannerTests/Intelligence/FindEventsToolTests.swift`

- [ ] **Step 1: Write the failing test**

`WeeklyPlannerTests/Intelligence/FindEventsToolTests.swift`:

```swift
import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class FindEventsToolTests: XCTestCase {
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

    func testRunReturnsCompactDTOs() async throws {
        let anchor = Self.may16_2026(hour: 9)
        try await store.upsert(Event(
            title: "Dentist follow-up",
            start: anchor,
            end: anchor.addingTimeInterval(1800),
            location: "4th Street Dental",
            category: .health
        ))
        let tool = FindEventsTool(store: store)
        let results = try await tool.run(query: EventQuery(
            dateRange: anchor ... anchor.addingTimeInterval(7200),
            categories: [.health],
            keywords: [],
            personName: nil
        ))
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Dentist follow-up")
        XCTAssertEqual(results.first?.categoryRaw, "health")
        XCTAssertEqual(results.first?.location, "4th Street Dental")
    }

    func testRunRespectsTimeoutByReturningEmptyOnThrow() async throws {
        struct ThrowingStore: EventStoring {
            func events(forWeekOffset: Int, today: Date) async throws -> [Event] { [] }
            func event(id: UUID) async throws -> Event? { nil }
            func upsert(_ event: Event) async throws {}
            func delete(id: UUID) async throws {}
            func events(matching query: EventQuery) async throws -> [Event] {
                struct Boom: Error {}
                throw Boom()
            }
        }
        let tool = FindEventsTool(store: ThrowingStore())
        let results = try await tool.run(query: EventQuery(
            dateRange: Date() ... Date().addingTimeInterval(3600),
            categories: nil,
            keywords: [],
            personName: nil
        ))
        XCTAssertTrue(results.isEmpty)
    }

    private static func may16_2026(hour: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 16
        components.hour = hour
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:WeeklyPlannerTests/FindEventsToolTests test 2>&1 | tail -25
```

Expected: failure — `run(query:)` doesn't exist on `FindEventsTool`.

- [ ] **Step 3: Implement**

Replace `WeeklyPlanner/Intelligence/Tools/FindEventsTool.swift` body:

```swift
import Foundation

/// Tool exposed to the language model: "find events that match this
/// query". Returns compact `ToolEventResult`s so the model never sees a
/// SwiftData entity. Swallows store errors and returns `[]` so a flaky
/// fetch can't crash the model run loop.
@MainActor
final class FindEventsTool: PlannerTool {
    let name = "findEvents"
    private let store: any EventStoring

    init(store: any EventStoring) {
        self.store = store
    }

    func run(query: EventQuery) async throws -> [ToolEventResult] {
        let events = (try? await store.events(matching: query)) ?? []
        return events.map { event in
            ToolEventResult(
                id: event.id,
                title: event.title,
                start: event.start,
                end: event.end,
                location: event.location,
                categoryRaw: event.categoryRaw,
                sourceRaw: event.sourceRaw
            )
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:WeeklyPlannerTests/FindEventsToolTests test 2>&1 | tail -10
```

Expected: `Test Suite 'FindEventsToolTests' passed`.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Intelligence/Tools/FindEventsTool.swift \
        WeeklyPlannerTests/Intelligence/FindEventsToolTests.swift
git commit -m "feat(phase-13): FindEventsTool with compact DTO mapping"
```

---

## Task 7: FindFreeSlotsTool

**Files:**
- Modify: `WeeklyPlanner/Intelligence/Tools/FindFreeSlotsTool.swift`
- Test: `WeeklyPlannerTests/Intelligence/FindFreeSlotsToolTests.swift`

- [ ] **Step 1: Write the failing test**

`WeeklyPlannerTests/Intelligence/FindFreeSlotsToolTests.swift`:

```swift
import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class FindFreeSlotsToolTests: XCTestCase {
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

    func testFindsThirtyMinuteSlotBeforeFirstEvent() async throws {
        let dayStart = Self.may16_2026(hour: 8)
        let firstEventStart = Self.may16_2026(hour: 10)
        let firstEventEnd = Self.may16_2026(hour: 11)
        try await store.upsert(Event(title: "Standup", start: firstEventStart, end: firstEventEnd, category: .work))

        let tool = FindFreeSlotsTool(store: store)
        let slots = try await tool.run(
            dateRange: dayStart ... Self.may16_2026(hour: 18),
            minMinutes: 30,
            dayPart: .morning
        )
        XCTAssertFalse(slots.isEmpty)
        XCTAssertTrue(slots.allSatisfy { $0.end.timeIntervalSince($0.start) >= 30 * 60 })
        XCTAssertTrue(slots.first!.start >= dayStart)
        XCTAssertTrue(slots.first!.end <= firstEventStart)
    }

    func testEmptyDayProducesOneSlotSpanningRange() async throws {
        let dayStart = Self.may16_2026(hour: 8)
        let dayEnd = Self.may16_2026(hour: 18)
        let tool = FindFreeSlotsTool(store: store)
        let slots = try await tool.run(
            dateRange: dayStart ... dayEnd,
            minMinutes: 30,
            dayPart: .any
        )
        XCTAssertEqual(slots.count, 1)
        XCTAssertEqual(slots[0].start, dayStart)
        XCTAssertEqual(slots[0].end, dayEnd)
    }

    func testCapsAtFiveResults() async throws {
        let dayStart = Self.may16_2026(hour: 8)
        // Twelve 15-minute events with 30-minute gaps -> many free slots.
        for offset in 0 ..< 12 {
            let s = dayStart.addingTimeInterval(Double(offset) * 45 * 60)
            try await store.upsert(Event(title: "E\(offset)", start: s, end: s.addingTimeInterval(15 * 60), category: .work))
        }
        let tool = FindFreeSlotsTool(store: store)
        let slots = try await tool.run(
            dateRange: dayStart ... dayStart.addingTimeInterval(12 * 60 * 60),
            minMinutes: 15,
            dayPart: .any
        )
        XCTAssertLessThanOrEqual(slots.count, 5)
    }

    private static func may16_2026(hour: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 16
        components.hour = hour
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:WeeklyPlannerTests/FindFreeSlotsToolTests test 2>&1 | tail -25
```

Expected: failure — `run(dateRange:minMinutes:dayPart:)` doesn't exist.

- [ ] **Step 3: Implement**

Replace `WeeklyPlanner/Intelligence/Tools/FindFreeSlotsTool.swift`:

```swift
import Foundation

@MainActor
final class FindFreeSlotsTool: PlannerTool {
    let name = "findFreeSlots"
    private let store: any EventStoring

    /// Coarse day-part filter so the model can ask for "morning free slots"
    /// without doing date math itself.
    enum DayPart: String, Sendable {
        case morning, afternoon, evening, any
    }

    init(store: any EventStoring) {
        self.store = store
    }

    /// Returns up to five free slots inside `dateRange` at least
    /// `minMinutes` long. Slot search is greedy left-to-right against the
    /// occupied intervals of every event in the range.
    func run(
        dateRange: ClosedRange<Date>,
        minMinutes: Int,
        dayPart: DayPart
    ) async throws -> [ToolFreeSlot] {
        let query = EventQuery(
            dateRange: dateRange,
            categories: nil,
            keywords: [],
            personName: nil
        )
        let events = (try? await store.events(matching: query)) ?? []
        let busy = events.map { ($0.start, $0.end) }.sorted { $0.0 < $1.0 }

        var free: [ToolFreeSlot] = []
        var cursor = dateRange.lowerBound
        for (start, end) in busy {
            if start > cursor {
                appendIfLongEnough(start: cursor, end: min(start, dateRange.upperBound),
                                   minMinutes: minMinutes, dayPart: dayPart, into: &free)
                if free.count >= 5 { return free }
            }
            cursor = max(cursor, end)
            if cursor >= dateRange.upperBound { break }
        }
        if cursor < dateRange.upperBound {
            appendIfLongEnough(start: cursor, end: dateRange.upperBound,
                               minMinutes: minMinutes, dayPart: dayPart, into: &free)
        }
        return Array(free.prefix(5))
    }

    private func appendIfLongEnough(
        start: Date,
        end: Date,
        minMinutes: Int,
        dayPart: DayPart,
        into free: inout [ToolFreeSlot]
    ) {
        guard end > start else { return }
        guard end.timeIntervalSince(start) >= Double(minMinutes) * 60 else { return }
        guard Self.matches(dayPart: dayPart, start: start) else { return }
        free.append(ToolFreeSlot(start: start, end: end))
    }

    private static func matches(dayPart: DayPart, start: Date) -> Bool {
        let hour = Calendar(identifier: .gregorian).component(.hour, from: start)
        switch dayPart {
        case .morning: return hour < 12
        case .afternoon: return hour >= 12 && hour < 17
        case .evening: return hour >= 17
        case .any: return true
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:WeeklyPlannerTests/FindFreeSlotsToolTests test 2>&1 | tail -10
```

Expected: `Test Suite 'FindFreeSlotsToolTests' passed`.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Intelligence/Tools/FindFreeSlotsTool.swift \
        WeeklyPlannerTests/Intelligence/FindFreeSlotsToolTests.swift
git commit -m "feat(phase-13): FindFreeSlotsTool with day-part filter + 5-slot cap"
```

---

## Task 8: ScanInboxTool

**Files:**
- Modify: `WeeklyPlanner/Intelligence/Tools/ScanInboxTool.swift`
- Test: `WeeklyPlannerTests/Intelligence/ScanInboxToolTests.swift`

- [ ] **Step 1: Write the failing test**

`WeeklyPlannerTests/Intelligence/ScanInboxToolTests.swift`:

```swift
import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class ScanInboxToolTests: XCTestCase {
    private var container: ModelContainer!
    private var inbox: SwiftDataInboxStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        inbox = SwiftDataInboxStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        inbox = nil
        container = nil
        try await super.tearDown()
    }

    func testReturnsPendingSuggestionsForRequestedWeek() async throws {
        let today = Self.may16_2026(hour: 12)
        let proposed = Self.may16_2026(hour: 9)
        let suggestion = InboxSuggestion(
            title: "Dentist follow-up",
            proposedStart: proposed,
            proposedEnd: proposed.addingTimeInterval(1800),
            fromName: "Mei",
            fromEmail: "mei@example.com",
            category: .health,
            subject: "Confirm dentist",
            bodySnippet: "Hi — can we confirm…"
        )
        try await inbox.upsert(suggestion)

        let tool = ScanInboxTool(store: inbox)
        let results = try await tool.run(weekOffset: 0, today: today, limit: 10)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Dentist follow-up")
        XCTAssertEqual(results.first?.fromName, "Mei")
        XCTAssertEqual(results.first?.subject, "Confirm dentist")
    }

    func testRespectsLimit() async throws {
        let today = Self.may16_2026(hour: 12)
        for i in 0 ..< 6 {
            let proposed = Self.may16_2026(hour: 9 + i)
            let suggestion = InboxSuggestion(
                title: "Suggestion \(i)",
                proposedStart: proposed,
                proposedEnd: proposed.addingTimeInterval(1800),
                fromName: nil,
                fromEmail: nil,
                category: .personal,
                subject: nil,
                bodySnippet: nil
            )
            try await inbox.upsert(suggestion)
        }
        let tool = ScanInboxTool(store: inbox)
        let results = try await tool.run(weekOffset: 0, today: today, limit: 3)
        XCTAssertEqual(results.count, 3)
    }

    private static func may16_2026(hour: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 16
        components.hour = hour
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:WeeklyPlannerTests/ScanInboxToolTests test 2>&1 | tail -25
```

Expected: failure — `run(weekOffset:today:limit:)` doesn't exist.

- [ ] **Step 3: Implement**

Replace `WeeklyPlanner/Intelligence/Tools/ScanInboxTool.swift`:

```swift
import Foundation

@MainActor
final class ScanInboxTool: PlannerTool {
    let name = "scanInbox"
    private let store: any InboxStoring

    init(store: any InboxStoring) {
        self.store = store
    }

    /// Returns up to `limit` pending suggestions for the given week offset.
    /// Quietly swallows store errors — an inbox tool failure shouldn't kill
    /// the whole model run.
    func run(weekOffset: Int, today: Date, limit: Int = 10) async throws -> [ToolInboxResult] {
        let raw = (try? await store.pending(forWeekOffset: weekOffset, today: today)) ?? []
        return raw.prefix(max(0, limit)).map { suggestion in
            ToolInboxResult(
                id: suggestion.id,
                title: suggestion.title,
                proposedStart: suggestion.proposedStart,
                fromName: suggestion.fromName,
                subject: suggestion.subject
            )
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:WeeklyPlannerTests/ScanInboxToolTests test 2>&1 | tail -10
```

Expected: `Test Suite 'ScanInboxToolTests' passed`.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Intelligence/Tools/ScanInboxTool.swift \
        WeeklyPlannerTests/Intelligence/ScanInboxToolTests.swift
git commit -m "feat(phase-13): ScanInboxTool returns compact pending DTOs"
```

---

## Task 9: SummarizeWeekTool

**Files:**
- Modify: `WeeklyPlanner/Intelligence/Tools/SummarizeWeekTool.swift`
- Test: `WeeklyPlannerTests/Intelligence/SummarizeWeekToolTests.swift`

- [ ] **Step 1: Write the failing test**

`WeeklyPlannerTests/Intelligence/SummarizeWeekToolTests.swift`:

```swift
import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class SummarizeWeekToolTests: XCTestCase {
    private var container: ModelContainer!
    private var events: SwiftDataEventStore!
    private var tasks: SwiftDataTaskStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        events = SwiftDataEventStore(context: container.mainContext)
        tasks = SwiftDataTaskStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        events = nil; tasks = nil; container = nil
        try await super.tearDown()
    }

    func testAggregatesHoursByCategoryAndTaskCounts() async throws {
        let today = Self.may16_2026(hour: 9)
        try await events.upsert(Event(title: "Standup", start: today,
                                      end: today.addingTimeInterval(1800), category: .work))
        try await events.upsert(Event(title: "Run", start: today.addingTimeInterval(3600),
                                      end: today.addingTimeInterval(5400), category: .health))
        try await tasks.upsert(TaskItem(title: "Done one", due: today, done: true,
                                        priority: .normal, category: .work))
        try await tasks.upsert(TaskItem(title: "Open one", due: today, done: false,
                                        priority: .normal, category: .personal))

        let tool = SummarizeWeekTool(events: events, tasks: tasks)
        let summary = try await tool.run(weekOffset: 0, today: today)

        XCTAssertEqual(summary.hoursByCategory["work"], 0.5, accuracy: 0.01)
        XCTAssertEqual(summary.hoursByCategory["health"], 0.5, accuracy: 0.01)
        XCTAssertEqual(summary.tasksDone, 1)
        XCTAssertEqual(summary.tasksOpen, 1)
        XCTAssertEqual(summary.highlightEventIDs.count, 2)
    }

    private static func may16_2026(hour: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 16
        components.hour = hour
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:WeeklyPlannerTests/SummarizeWeekToolTests test 2>&1 | tail -25
```

Expected: failure — `run(weekOffset:today:)` doesn't exist.

- [ ] **Step 3: Implement**

Replace `WeeklyPlanner/Intelligence/Tools/SummarizeWeekTool.swift`:

```swift
import Foundation

@MainActor
final class SummarizeWeekTool: PlannerTool {
    let name = "summarizeWeek"
    private let events: any EventStoring
    private let tasks: any TaskStoring

    init(events: any EventStoring, tasks: any TaskStoring) {
        self.events = events
        self.tasks = tasks
    }

    func run(weekOffset: Int, today: Date) async throws -> ToolWeekSummary {
        let weekEvents = (try? await events.events(forWeekOffset: weekOffset, today: today)) ?? []
        let weekTasks = (try? await tasks.tasks(forWeekOffset: weekOffset, today: today)) ?? []

        var hoursByCategory: [String: Double] = [:]
        for event in weekEvents {
            let hours = event.end.timeIntervalSince(event.start) / 3600.0
            hoursByCategory[event.categoryRaw, default: 0] += hours
        }
        let done = weekTasks.filter(\.done).count
        let open = weekTasks.count - done
        let highlights = weekEvents
            .sorted { lhs, rhs in
                lhs.end.timeIntervalSince(lhs.start) > rhs.end.timeIntervalSince(rhs.start)
            }
            .prefix(3)
            .map(\.id)

        return ToolWeekSummary(
            hoursByCategory: hoursByCategory,
            tasksDone: done,
            tasksOpen: open,
            highlightEventIDs: Array(highlights)
        )
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:WeeklyPlannerTests/SummarizeWeekToolTests test 2>&1 | tail -10
```

Expected: `Test Suite 'SummarizeWeekToolTests' passed`.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Intelligence/Tools/SummarizeWeekTool.swift \
        WeeklyPlannerTests/Intelligence/SummarizeWeekToolTests.swift
git commit -m "feat(phase-13): SummarizeWeekTool aggregates hours, tasks, highlights"
```

---

## Task 10: LastInteractionTool

**Files:**
- Modify: `WeeklyPlanner/Intelligence/Tools/LastInteractionTool.swift`
- Test: `WeeklyPlannerTests/Intelligence/LastInteractionToolTests.swift`

- [ ] **Step 1: Write the failing test**

`WeeklyPlannerTests/Intelligence/LastInteractionToolTests.swift`:

```swift
import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class LastInteractionToolTests: XCTestCase {
    private var container: ModelContainer!
    private var store: SwiftDataEventStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        store = SwiftDataEventStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        store = nil; container = nil
        try await super.tearDown()
    }

    func testReturnsMostRecentMatchBeforeToday() async throws {
        let today = Self.may16_2026(hour: 12)
        let saraOld = Self.may16_2026(hour: 9).addingTimeInterval(-14 * 86_400)
        let saraNew = Self.may16_2026(hour: 9).addingTimeInterval(-2 * 86_400)
        try await store.upsert(Event(title: "Coffee with Sara", start: saraOld,
                                     end: saraOld.addingTimeInterval(1800), category: .personal))
        try await store.upsert(Event(title: "Sara's birthday breakfast", start: saraNew,
                                     end: saraNew.addingTimeInterval(1800), category: .personal))

        let tool = LastInteractionTool(store: store)
        let result = try await tool.run(personName: "Sara", today: today)
        XCTAssertNotNil(result.eventID)
        XCTAssertEqual(result.context, "Sara's birthday breakfast")
        XCTAssertEqual(result.date, saraNew)
    }

    func testReturnsEmptyWhenNoMatch() async throws {
        let today = Self.may16_2026(hour: 12)
        let tool = LastInteractionTool(store: store)
        let result = try await tool.run(personName: "Nobody", today: today)
        XCTAssertNil(result.eventID)
        XCTAssertNil(result.date)
        XCTAssertEqual(result.context, "")
    }

    private static func may16_2026(hour: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 16
        components.hour = hour
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:WeeklyPlannerTests/LastInteractionToolTests test 2>&1 | tail -25
```

Expected: failure — `run(personName:today:)` doesn't exist.

- [ ] **Step 3: Implement**

Replace `WeeklyPlanner/Intelligence/Tools/LastInteractionTool.swift`:

```swift
import Foundation

@MainActor
final class LastInteractionTool: PlannerTool {
    let name = "lastInteraction"
    private let store: any EventStoring

    init(store: any EventStoring) {
        self.store = store
    }

    /// Returns the most recent event whose title or location case-insensitively
    /// contains `personName`, scanning the eight weeks ending at `today`.
    func run(personName: String, today: Date) async throws -> ToolLastInteraction {
        let lowered = personName.lowercased()
        guard !lowered.isEmpty else {
            return ToolLastInteraction(eventID: nil, date: nil, context: "")
        }
        var best: Event?
        for weekOffset in -8 ... 0 {
            let events = (try? await store.events(forWeekOffset: weekOffset, today: today)) ?? []
            for event in events where event.start <= today {
                let title = event.title.lowercased()
                let location = (event.location ?? "").lowercased()
                guard title.contains(lowered) || location.contains(lowered) else { continue }
                if best == nil || event.start > best!.start {
                    best = event
                }
            }
        }
        guard let match = best else {
            return ToolLastInteraction(eventID: nil, date: nil, context: "")
        }
        return ToolLastInteraction(eventID: match.id, date: match.start, context: match.title)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:WeeklyPlannerTests/LastInteractionToolTests test 2>&1 | tail -10
```

Expected: `Test Suite 'LastInteractionToolTests' passed`.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Intelligence/Tools/LastInteractionTool.swift \
        WeeklyPlannerTests/Intelligence/LastInteractionToolTests.swift
git commit -m "feat(phase-13): LastInteractionTool scans 8-week window for person hits"
```

---

## Task 11: SystemPrompt

**Files:**
- Create: `WeeklyPlanner/Intelligence/SystemPrompt.swift`
- Test: `WeeklyPlannerTests/Intelligence/SystemPromptTests.swift`

- [ ] **Step 1: Write the failing test**

`WeeklyPlannerTests/Intelligence/SystemPromptTests.swift`:

```swift
import XCTest
@testable import WeeklyPlanner

final class SystemPromptTests: XCTestCase {
    func testPromptIncludesPersona() {
        let prompt = SystemPrompt.default
        XCTAssertTrue(prompt.contains("You are The Planner"))
    }

    func testPromptIncludesOnDevicePrivacyReminder() {
        XCTAssertTrue(SystemPrompt.default.contains("on-device"))
    }

    func testPromptListsAllToolsByName() {
        let prompt = SystemPrompt.default
        for name in ["findEvents", "findFreeSlots", "scanInbox", "summarizeWeek", "lastInteraction"] {
            XCTAssertTrue(prompt.contains(name), "Prompt missing tool '\(name)'")
        }
    }

    func testPromptRefusalLineMatchesSpec() {
        XCTAssertTrue(SystemPrompt.default.contains("scoped to your planner"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:WeeklyPlannerTests/SystemPromptTests test 2>&1 | tail -25
```

Expected: compile failure — `cannot find 'SystemPrompt' in scope`.

- [ ] **Step 3: Implement**

`WeeklyPlanner/Intelligence/SystemPrompt.swift`:

```swift
import Foundation

/// The static instruction block handed to `LanguageModelSession`. Single
/// source of truth so prompt drift between the model and the tests is
/// caught at build time.
enum SystemPrompt {
    static let `default`: String = """
    You are The Planner — a thoughtful assistant that lives inside the user's personal weekly journal.

    Style: handwriting-friendly tone; concise; no emojis except in streak or celebration contexts.

    Privacy: all processing is on-device. Do not invent or reference data the user has not provided.

    Capabilities (call these tools by name; do not invent tool names):
    - findEvents: find events by date range, category, keyword, or person.
    - findFreeSlots: find open time blocks in a date range.
    - scanInbox: list pending inbox suggestions for a week.
    - summarizeWeek: aggregate hours-by-category, tasks done/open, and headline events.
    - lastInteraction: locate the most recent event involving a named person.

    When answering with citations, call findEvents first and reuse the returned event ids. Never fabricate event ids.

    Refuse politely when asked to do things outside calendar, tasks, or inbox: respond with "I'm scoped to your planner."
    """
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:WeeklyPlannerTests/SystemPromptTests test 2>&1 | tail -10
```

Expected: `Test Suite 'SystemPromptTests' passed`.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Intelligence/SystemPrompt.swift \
        WeeklyPlannerTests/Intelligence/SystemPromptTests.swift
git commit -m "feat(phase-13): SystemPrompt with persona, privacy, and tool roster"
```

---

## Task 12: SafetyGuard

**Files:**
- Create: `WeeklyPlanner/Intelligence/SafetyGuard.swift`
- Test: `WeeklyPlannerTests/Intelligence/SafetyGuardTests.swift`

- [ ] **Step 1: Write the failing test**

`WeeklyPlannerTests/Intelligence/SafetyGuardTests.swift`:

```swift
import XCTest
@testable import WeeklyPlanner

final class SafetyGuardTests: XCTestCase {
    func testTrimsWhitespace() {
        XCTAssertEqual(SafetyGuard.sanitize("   hello   "), "hello")
    }

    func testStripsControlChars() {
        let dirty = "hello\u{0007}world\u{0001}"
        XCTAssertEqual(SafetyGuard.sanitize(dirty), "helloworld")
    }

    func testTruncatesAtSixHundredChars() {
        let bigInput = String(repeating: "a", count: 800)
        let result = SafetyGuard.sanitize(bigInput)
        XCTAssertEqual(result.count, 600)
    }

    func testDisabledReturnsCannedFallback() {
        let context = PlannerContext(
            now: Date(),
            viewedWeekOffset: 0,
            maxResponseTokens: 256,
            appleIntelligenceEnabled: false
        )
        XCTAssertTrue(SafetyGuard.shouldShortCircuit(context: context))
    }

    func testEnabledDoesNotShortCircuit() {
        let context = PlannerContext(
            now: Date(),
            viewedWeekOffset: 0,
            maxResponseTokens: 256,
            appleIntelligenceEnabled: true
        )
        XCTAssertFalse(SafetyGuard.shouldShortCircuit(context: context))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:WeeklyPlannerTests/SafetyGuardTests test 2>&1 | tail -25
```

Expected: compile failure — `cannot find 'SafetyGuard' in scope`.

- [ ] **Step 3: Implement**

`WeeklyPlanner/Intelligence/SafetyGuard.swift`:

```swift
import Foundation

/// Pre-call sanitation + short-circuit checks. Kept narrow and pure so the
/// rules are unambiguous and easy to fuzz.
enum SafetyGuard {
    /// Trims whitespace, strips control characters, and clamps to 600
    /// characters. Anything beyond 600 is silently truncated — long
    /// prompts blow the token budget and rarely improve answers.
    static func sanitize(_ raw: String) -> String {
        let stripped = raw.unicodeScalars.filter { scalar in
            !CharacterSet.controlCharacters.contains(scalar)
        }
        let trimmed = String(String.UnicodeScalarView(stripped))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 600 {
            return trimmed
        }
        return String(trimmed.prefix(600))
    }

    /// Returns `true` when the model must NOT be invoked. Today this is
    /// only the user-disabled toggle in `UserSettings`; Phase 13-b can add
    /// thermal-state and inflight-rate-limit checks.
    static func shouldShortCircuit(context: PlannerContext) -> Bool {
        !context.appleIntelligenceEnabled
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:WeeklyPlannerTests/SafetyGuardTests test 2>&1 | tail -10
```

Expected: `Test Suite 'SafetyGuardTests' passed`.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Intelligence/SafetyGuard.swift \
        WeeklyPlannerTests/Intelligence/SafetyGuardTests.swift
git commit -m "feat(phase-13): SafetyGuard sanitize + AI-disabled short-circuit"
```

---

## Task 13: IntelligenceService protocol + AnswerDelta

**Files:**
- Create: `WeeklyPlanner/Intelligence/IntelligenceService.swift`

- [ ] **Step 1: Implement**

`WeeklyPlanner/Intelligence/IntelligenceService.swift`:

```swift
import Foundation

/// One chunk of a streamed reply. Phase 13-a emits a single delta with the
/// full body; Phase 13-b layers tokenized streaming on top once the
/// FoundationModels API surface is exercised on-device.
struct AnswerDelta: Equatable, Sendable {
    let textChunk: String
    /// When `true`, the model has finished producing tokens and the
    /// citations / actions on the parent `AIAnswer` are final.
    let isFinal: Bool
}

/// The only surface the AI overlay, sticky generator, and review summary
/// generator talk to. Concrete conformers: `PlannerLanguageModel` (real
/// Foundation Models) and `StubIntelligenceService` (deterministic,
/// reused as the runtime fallback when the model is unavailable).
@MainActor
protocol IntelligenceService: AnyObject {
    /// Probe the on-device model + settings. Cheap; called at the start of
    /// every `ask(...)` so a Settings flip takes effect immediately.
    func availability(context: PlannerContext) async -> AvailabilityState

    /// Synchronous request/response — what the AI overlay calls today.
    func ask(query: String, context: PlannerContext) async throws -> AIAnswer

    /// Streamed request/response — Phase 13-b will swap the overlay to
    /// this. The default conformance in this phase emits a single final
    /// delta carrying the body of `ask(...)`.
    func streamAsk(query: String, context: PlannerContext)
        -> AsyncThrowingStream<AnswerDelta, Error>
}

extension IntelligenceService {
    /// Default streaming implementation: call `ask(...)` once, emit a
    /// single final delta. Concrete conformers override when they support
    /// real token streaming.
    func streamAsk(query: String, context: PlannerContext)
        -> AsyncThrowingStream<AnswerDelta, Error>
    {
        AsyncThrowingStream { continuation in
            Task { @MainActor in
                do {
                    let answer = try await ask(query: query, context: context)
                    continuation.yield(AnswerDelta(textChunk: answer.body, isFinal: true))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' -quiet build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Intelligence/IntelligenceService.swift
git commit -m "feat(phase-13): IntelligenceService protocol + AnswerDelta"
```

---

## Task 14: StubIntelligenceService (fallback + test double)

**Files:**
- Create: `WeeklyPlanner/Intelligence/StubIntelligenceService.swift`
- Test: `WeeklyPlannerTests/Intelligence/StubIntelligenceServiceTests.swift`

- [ ] **Step 1: Write the failing test**

`WeeklyPlannerTests/Intelligence/StubIntelligenceServiceTests.swift`:

```swift
import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class StubIntelligenceServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var events: SwiftDataEventStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        events = SwiftDataEventStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        events = nil; container = nil
        try await super.tearDown()
    }

    func testDentistQueryReturnsCannedBodyAndCitationFromStore() async throws {
        let start = Self.may16_2026(hour: 9)
        try await events.upsert(Event(title: "Dentist follow-up", start: start,
                                      end: start.addingTimeInterval(1800), category: .health))
        let service = StubIntelligenceService(eventStore: events, clock: { Self.may16_2026() })

        let answer = try await service.ask(
            query: "When's my next dentist appointment?",
            context: PlannerContext(now: Self.may16_2026(),
                                    viewedWeekOffset: 0,
                                    maxResponseTokens: 256,
                                    appleIntelligenceEnabled: true)
        )
        XCTAssertTrue(answer.body.contains("dentist"))
        XCTAssertEqual(answer.citations.first?.title, "Dentist follow-up")
        XCTAssertEqual(answer.actions.count, 2)
    }

    func testAvailabilityHonorsAppleIntelligenceEnabled() async {
        let service = StubIntelligenceService(eventStore: events, clock: { Self.may16_2026() })
        let disabled = await service.availability(context: PlannerContext(
            now: Self.may16_2026(),
            viewedWeekOffset: 0,
            maxResponseTokens: 256,
            appleIntelligenceEnabled: false
        ))
        XCTAssertEqual(disabled, .unavailable(.userDisabled))
        let enabled = await service.availability(context: PlannerContext(
            now: Self.may16_2026(),
            viewedWeekOffset: 0,
            maxResponseTokens: 256,
            appleIntelligenceEnabled: true
        ))
        XCTAssertEqual(enabled, .available)
    }

    func testStreamingDefaultEmitsSingleFinalDelta() async throws {
        let service = StubIntelligenceService(eventStore: events, clock: { Self.may16_2026() })
        var deltas: [AnswerDelta] = []
        for try await delta in service.streamAsk(
            query: "summarize my week",
            context: PlannerContext.default)
        {
            deltas.append(delta)
        }
        XCTAssertEqual(deltas.count, 1)
        XCTAssertTrue(deltas[0].isFinal)
        XCTAssertFalse(deltas[0].textChunk.isEmpty)
    }

    private static func may16_2026(hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 16
        components.hour = hour
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:WeeklyPlannerTests/StubIntelligenceServiceTests test 2>&1 | tail -25
```

Expected: compile failure — `cannot find 'StubIntelligenceService' in scope`.

- [ ] **Step 3: Implement**

`WeeklyPlanner/Intelligence/StubIntelligenceService.swift`:

```swift
import Foundation

/// Deterministic, framework-free `IntelligenceService` implementation.
///
/// Doubles as both the test double for unit tests and the runtime
/// fallback when `PlannerLanguageModel` reports unavailable (older device,
/// user disabled, model not ready). The body strings come from the same
/// `AISearchCannedData` table that Phase 12 already ships, so the fallback
/// UX matches what users saw before Phase 13.
@MainActor
final class StubIntelligenceService: IntelligenceService {
    private let eventStore: any EventStoring
    private let clock: () -> Date

    init(eventStore: any EventStoring, clock: @escaping () -> Date = { Date() }) {
        self.eventStore = eventStore
        self.clock = clock
    }

    func availability(context: PlannerContext) async -> AvailabilityState {
        if !context.appleIntelligenceEnabled {
            return .unavailable(.userDisabled)
        }
        return .available
    }

    func ask(query: String, context: PlannerContext) async throws -> AIAnswer {
        let sanitized = SafetyGuard.sanitize(query)
        let canned = AISearchCannedData.canned(for: sanitized)
        let citations = await resolveCitations(titleHints: canned.titleHints, now: clock())
        return AIAnswer(
            query: sanitized,
            body: canned.body,
            citations: citations,
            actions: canned.actions,
            elapsedSeconds: 0
        )
    }

    private func resolveCitations(titleHints: [String], now: Date) async -> [AICitation] {
        guard !titleHints.isEmpty else { return [] }
        let lowered = titleHints.map { $0.lowercased() }
        var results: [AICitation] = []
        for weekOffset in -4 ... 4 {
            guard let events = try? await eventStore.events(forWeekOffset: weekOffset, today: now) else { continue }
            for event in events {
                let title = event.title.lowercased()
                guard lowered.contains(where: { title.contains($0) }) else { continue }
                results.append(AICitation(
                    id: event.id,
                    title: event.title,
                    category: event.category,
                    weekdayLong: Self.weekdayFormatter.string(from: event.start),
                    timeShort: Self.timeFormatter.string(from: event.start)
                ))
                if results.count >= 3 { return results }
            }
        }
        return results
    }

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:WeeklyPlannerTests/StubIntelligenceServiceTests test 2>&1 | tail -10
```

Expected: `Test Suite 'StubIntelligenceServiceTests' passed`.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Intelligence/StubIntelligenceService.swift \
        WeeklyPlannerTests/Intelligence/StubIntelligenceServiceTests.swift
git commit -m "feat(phase-13): StubIntelligenceService (fallback + test double)"
```

---

## Task 15: PlannerLanguageModel (Foundation Models bridge)

**Files:**
- Create: `WeeklyPlanner/Intelligence/PlannerLanguageModel.swift`

This task ships the on-device bridge. Foundation Models requires iOS 26 + an Apple-Intelligence-eligible device, so the bridge is `@available(iOS 26.0, *)` and gated by `#if canImport(FoundationModels)`. There is no unit-test target for this file; correctness is validated by the acceptance criteria run on a real iPhone 15 Pro.

- [ ] **Step 1: Implement**

`WeeklyPlanner/Intelligence/PlannerLanguageModel.swift`:

```swift
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Concrete `IntelligenceService` that calls the on-device Apple Intelligence
/// model. Falls back to `StubIntelligenceService` whenever the system says
/// the model isn't currently usable. All Foundation-Models-specific work is
/// gated `@available(iOS 26.0, *)` so the rest of the app target builds on
/// any iOS 26 simulator (even those without the model file present).
@MainActor
final class PlannerLanguageModel: IntelligenceService {
    private let registry: ToolRegistry
    private let fallback: StubIntelligenceService
    private let clock: () -> Date

    init(registry: ToolRegistry,
         fallback: StubIntelligenceService,
         clock: @escaping () -> Date = { Date() })
    {
        self.registry = registry
        self.fallback = fallback
        self.clock = clock
    }

    func availability(context: PlannerContext) async -> AvailabilityState {
        if !context.appleIntelligenceEnabled {
            return .unavailable(.userDisabled)
        }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(.deviceNotEligible):
                return .unavailable(.deviceNotEligible)
            case .unavailable(.modelNotReady):
                return .unavailable(.modelNotReady)
            case .unavailable(.appleIntelligenceNotEnabled):
                return .unavailable(.appleIntelligenceNotEnabled)
            @unknown default:
                return .unavailable(.modelNotReady)
            }
        }
        #endif
        return .unavailable(.deviceNotEligible)
    }

    func ask(query: String, context: PlannerContext) async throws -> AIAnswer {
        let availability = await availability(context: context)
        guard availability.isAvailable else {
            return try await fallback.ask(query: query, context: context)
        }

        let sanitized = SafetyGuard.sanitize(query)

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            do {
                let session = try makeSession()
                let started = Date()
                let response = try await session.respond(to: sanitized)
                let elapsed = Date().timeIntervalSince(started)
                let citations = await fallback.resolveCitations(forBody: response.content,
                                                                now: clock())
                return AIAnswer(
                    query: sanitized,
                    body: response.content,
                    citations: citations,
                    actions: [],
                    elapsedSeconds: elapsed
                )
            } catch {
                // Any FM error -> fall back so the overlay still answers.
                return try await fallback.ask(query: query, context: context)
            }
        }
        #endif

        return try await fallback.ask(query: query, context: context)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func makeSession() throws -> LanguageModelSession {
        // Foundation Models adopters typically pass `Tool` conformers here.
        // Phase 13-b will adapt each `PlannerTool` into a `Tool` once the
        // generation-schema work lands; v1.0 ships instructions-only and
        // leans on the system prompt to keep answers grounded.
        return LanguageModelSession(
            model: SystemLanguageModel.default,
            instructions: SystemPrompt.default
        )
    }
    #endif
}

// MARK: - Citation resolver bridge

extension StubIntelligenceService {
    /// Reused by PlannerLanguageModel so the real model and the stub stay
    /// pixel-identical for the citation chip layer.
    func resolveCitations(forBody body: String, now: Date) async -> [AICitation] {
        // Cheap heuristic: split the answer on whitespace and look for any
        // token longer than 3 chars in event titles within ±4 weeks.
        let tokens = body
            .lowercased()
            .split(whereSeparator: { !$0.isLetter })
            .filter { $0.count > 3 }
            .map(String.init)
        return await resolveCitations(titleHints: Array(Set(tokens)), now: now)
    }
}
```

- [ ] **Step 2: Expose `resolveCitations(titleHints:now:)` as internal**

The `StubIntelligenceService.resolveCitations(titleHints:now:)` method is currently `private`. Promote it to `fileprivate` won't help (different file) — change it to `internal`. Update `WeeklyPlanner/Intelligence/StubIntelligenceService.swift`:

Change:

```swift
    private func resolveCitations(titleHints: [String], now: Date) async -> [AICitation] {
```

to:

```swift
    /// Internal so `PlannerLanguageModel` can reuse the same title-substring
    /// match for citation chips on real model answers.
    func resolveCitations(titleHints: [String], now: Date) async -> [AICitation] {
```

- [ ] **Step 3: Verify it compiles**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' -quiet build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`. (No unit test — coverage comes from the on-device acceptance check at the end of Task 18.)

- [ ] **Step 4: Commit**

```bash
git add WeeklyPlanner/Intelligence/PlannerLanguageModel.swift \
        WeeklyPlanner/Intelligence/StubIntelligenceService.swift
git commit -m "feat(phase-13): PlannerLanguageModel bridge to FoundationModels"
```

---

## Task 16: Wire AISearchViewModel to IntelligenceService

**Files:**
- Modify: `WeeklyPlanner/Features/AISearch/AISearchViewModel.swift`
- Modify: `WeeklyPlannerTests/AISearch/AISearchViewModelTests.swift`

- [ ] **Step 1: Update the existing tests to inject the service + add a new fallback-path test**

Append to `WeeklyPlannerTests/AISearch/AISearchViewModelTests.swift` (and modify the existing `setUp` if needed). Replace the existing init calls with the new initializer:

```swift
    func testFallbackPathUsedWhenAIDisabled() async throws {
        let saraStart = Self.may16_2026(hour: 9)
        try await eventStore.upsert(Event(
            title: "Sara's birthday breakfast",
            start: saraStart,
            end: saraStart.addingTimeInterval(3600),
            category: .personal
        ))
        let service = StubIntelligenceService(eventStore: eventStore, clock: { Self.may16_2026() })
        let viewModel = AISearchViewModel(
            eventStore: eventStore,
            intelligence: service,
            settings: { false },
            clock: { Self.may16_2026() }
        )
        viewModel.thinkingDelay = .milliseconds(0)
        await viewModel.ask(text: "When did I last meet with Sara?")
        XCTAssertNotNil(viewModel.answer)
        XCTAssertEqual(viewModel.answer?.citations.first?.title, "Sara's birthday breakfast")
        XCTAssertEqual(viewModel.unavailableReason, .unavailable(.userDisabled))
    }
```

Update every other `AISearchViewModel(...)` call in the file to use the new initializer signature, passing a `StubIntelligenceService` and `settings: { true }`. Example for the existing `testAskDentistMapsToDentistAnswer`:

```swift
        let viewModel = AISearchViewModel(
            eventStore: eventStore,
            intelligence: StubIntelligenceService(eventStore: eventStore),
            settings: { true }
        )
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:WeeklyPlannerTests/AISearchViewModelTests test 2>&1 | tail -25
```

Expected: compile failure — `AISearchViewModel.init(eventStore:intelligence:settings:clock:)` doesn't exist, `unavailableReason` property missing.

- [ ] **Step 3: Implement**

Replace the whole `AISearchViewModel.swift` body:

```swift
import Foundation
import Observation

/// Drives the Paper AI Search overlay. Owns the query string, the
/// "thinking" indicator state, and the most recent rendered `AIAnswer`.
///
/// Phase 13 wires this through an `IntelligenceService`. If the service
/// reports unavailable (user disabled AI in Settings, model not ready,
/// device ineligible), the view model still publishes an answer — from
/// the same `StubIntelligenceService` used in tests — and exposes
/// `unavailableReason` so the view layer can render the fallback footer.
@MainActor
@Observable
final class AISearchViewModel {
    var query: String = ""
    var thinking: Bool = false
    var answer: AIAnswer?

    /// Set after every `ask(...)`. `.available` for the happy path; the
    /// view layer renders the `.fallbackMessage` whenever the case is
    /// `.unavailable(...)`.
    var unavailableReason: AvailabilityState = .available

    /// Only used by the canned fallback path so existing snapshot timing
    /// stays stable. The live FM path uses real latency and ignores this.
    var thinkingDelay: Duration = .milliseconds(1100)

    private let eventStore: any EventStoring
    private let intelligence: any IntelligenceService
    private let settings: () -> Bool
    private let clock: () -> Date

    init(eventStore: any EventStoring,
         intelligence: any IntelligenceService,
         settings: @escaping () -> Bool = { true },
         clock: @escaping () -> Date = { Date() })
    {
        self.eventStore = eventStore
        self.intelligence = intelligence
        self.settings = settings
        self.clock = clock
    }

    func ask(_ suggestion: AISuggestion) async {
        await ask(text: suggestion.text)
    }

    func ask(text: String) async {
        query = text
        thinking = true
        answer = nil

        let context = PlannerContext(
            now: clock(),
            viewedWeekOffset: 0,
            maxResponseTokens: 256,
            appleIntelligenceEnabled: settings()
        )
        let availability = await intelligence.availability(context: context)
        unavailableReason = availability

        let started = Date()
        if !availability.isAvailable {
            // Match prior Phase 12 timing so the overlay UX doesn't snap.
            try? await Task.sleep(for: thinkingDelay)
        }
        do {
            let produced = try await intelligence.ask(query: text, context: context)
            let elapsed = Date().timeIntervalSince(started)
            answer = AIAnswer(
                query: produced.query,
                body: produced.body,
                citations: produced.citations,
                actions: produced.actions,
                elapsedSeconds: elapsed
            )
        } catch {
            // Last-ditch fallback — produce an empty-ish answer rather than
            // leaving the overlay stuck in "thinking" forever.
            answer = AIAnswer(
                query: text,
                body: "Something went wrong. Try again in a moment.",
                citations: [],
                actions: [],
                elapsedSeconds: Date().timeIntervalSince(started)
            )
        }
        thinking = false
    }

    func clear() {
        query = ""
        thinking = false
        answer = nil
        unavailableReason = .available
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:WeeklyPlannerTests/AISearchViewModelTests test 2>&1 | tail -10
```

Expected: `Test Suite 'AISearchViewModelTests' passed` (all six tests, including the new fallback test).

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Features/AISearch/AISearchViewModel.swift \
        WeeklyPlannerTests/AISearch/AISearchViewModelTests.swift
git commit -m "feat(phase-13): wire AISearchViewModel through IntelligenceService"
```

---

## Task 17: Construct + inject the service in RootView

**Files:**
- Modify: `WeeklyPlanner/App/RootView.swift`
- Modify: `WeeklyPlanner/Stores/Environment+Stores.swift`

- [ ] **Step 1: Read the existing files**

```bash
sed -n '1,200p' WeeklyPlanner/App/RootView.swift
sed -n '1,200p' WeeklyPlanner/Stores/Environment+Stores.swift
```

- [ ] **Step 2: Add an `IntelligenceServiceKey` to Environment+Stores.swift**

Append to `WeeklyPlanner/Stores/Environment+Stores.swift`:

```swift
import SwiftUI

private struct IntelligenceServiceKey: EnvironmentKey {
    @MainActor static var defaultValue: (any IntelligenceService)? { nil }
}

extension EnvironmentValues {
    /// Live Intelligence service. `nil` in previews/tests that don't set
    /// it; consumers must pass through `AISearchViewModel`'s explicit init.
    var intelligenceService: (any IntelligenceService)? {
        get { self[IntelligenceServiceKey.self] }
        set { self[IntelligenceServiceKey.self] = newValue }
    }
}
```

- [ ] **Step 3: Build the service at app start in RootView**

In `RootView.swift`, locate the existing store construction (`eventStore`, `taskStore`, `inboxStore`) and add immediately after them:

```swift
        let toolRegistry = ToolRegistry(
            events: eventStore,
            tasks: taskStore,
            inbox: inboxStore
        )
        let stubService = StubIntelligenceService(eventStore: eventStore)
        let intelligence: any IntelligenceService = PlannerLanguageModel(
            registry: toolRegistry,
            fallback: stubService
        )
```

Then pass `intelligence` into wherever `AISearchViewModel` is instantiated (currently in the AI overlay sheet wiring). If `AISearchViewModel` is instantiated as a state object, swap to:

```swift
        AISearchViewModel(
            eventStore: eventStore,
            intelligence: intelligence,
            settings: { settingsStore.current.appleIntelligenceEnabled }
        )
```

If `RootView` currently doesn't pass `settingsStore` down to the overlay, the cleanest swap is to forward via `.environment(\.intelligenceService, intelligence)` on the root scene and have the overlay grab it. Match whichever pattern the file already uses.

- [ ] **Step 4: Verify the app still builds**

```bash
xcodegen generate
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' -quiet build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Run the full suite**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' test 2>&1 | tail -25
```

Expected: `Test Suite 'All tests' passed`. Take note of test count — it should be the previous count plus the new `Intelligence/` tests (10 new test classes — see plan header for file list).

- [ ] **Step 6: Commit**

```bash
git add WeeklyPlanner/App/RootView.swift \
        WeeklyPlanner/Stores/Environment+Stores.swift
git commit -m "feat(phase-13): construct + inject PlannerLanguageModel in RootView"
```

---

## Task 18: Regenerate project, run full suite, smoke-test the simulator

**Files:** none modified — verification only

- [ ] **Step 1: Regenerate Xcode project**

```bash
xcodegen generate
```

Expected: `Generated project successfully`.

- [ ] **Step 2: Run the entire test suite**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' test 2>&1 | tail -30
```

Expected: every test green, including `SmokeUITests`. Capture the test count delta vs. main:

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' test 2>&1 \
  | grep -E "Test Suite '.*' (passed|failed)" | tail -5
```

- [ ] **Step 3: Launch in simulator and exercise the AI overlay manually**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -configuration Debug build
xcrun simctl launch booted com.weeklyplanner.WeeklyPlanner
```

Then in the simulator:
- Tap the AI button in the top bar
- Tap each canned suggestion in turn
- Verify the answer body appears within ~2 seconds and the citation chip(s) match the seeded events
- Toggle `appleIntelligenceEnabled = false` (via Settings flow if wired, or via a temporary debug menu) and confirm the fallback footer message shows

If the simulator doesn't have Apple Intelligence enabled (most don't), the overlay will go through the `unavailable(.deviceNotEligible)` fallback — that's expected and matches the spec's "Showing canned suggestions" footer.

- [ ] **Step 4: Save a verification screenshot**

```bash
xcrun simctl io booted screenshot /tmp/phase-13-overlay.png
```

Eyeball the screenshot: handwritten body text, citation chip(s) when applicable, footer reads either "Answered on-device · …s" (FM path) or the fallback string (stub path).

- [ ] **Step 5: No commit — this is verification only.**

---

## Task 19: Phase 13-a retrospective + finalize

**Files:**
- Modify: `docs/phases/README.md`

- [ ] **Step 1: Append a Phase 13-a retrospective**

Locate the section at the bottom of `docs/phases/README.md` where prior phase retrospectives live (after Phase 12). Append:

```markdown
### Phase 13-a — Foundation Models Integration (Core Layer)

Shipped the `WeeklyPlanner/Intelligence/` module: `IntelligenceService` protocol, `PlannerLanguageModel` bridge (iOS 26+ Foundation Models), `StubIntelligenceService` (reused as test double + runtime fallback), five tools (FindEvents / FindFreeSlots / ScanInbox / SummarizeWeek / LastInteraction), `SystemPrompt`, `SafetyGuard`, and `Availability` probe. `AISearchViewModel` now talks to the protocol; when the model is unavailable (or AI is off in Settings), the overlay shows the same canned answers as before with a one-line footer explaining the fallback.

**Deferred to Phase 13-b**: `StickyInsightGenerator`, `WeekSummaryGenerator`, `EventSuggestionGenerator`, and token-level streaming. WeekSummary blocks on Phase 14 (Review page). Sticky and EventSuggestion generators want a background-task scheduler that lives more naturally next to Phase 19. Streaming wants on-device validation before shipping.

**Tests added**: 10 XCTest classes under `WeeklyPlannerTests/Intelligence/`.

**Files**: `WeeklyPlanner/Intelligence/Availability.swift`, `IntelligenceService.swift`, `PlannerContext.swift`, `PlannerLanguageModel.swift`, `SafetyGuard.swift`, `StubIntelligenceService.swift`, `SystemPrompt.swift`, `Tools/{EventQuery,FindEventsTool,FindFreeSlotsTool,LastInteractionTool,ScanInboxTool,SummarizeWeekTool,ToolEventResult,ToolRegistry}.swift`; modified `WeeklyPlanner/Features/AISearch/AISearchViewModel.swift`, `WeeklyPlanner/App/RootView.swift`, `WeeklyPlanner/Stores/Environment+Stores.swift`, `WeeklyPlanner/Stores/EventStore.swift`.
```

- [ ] **Step 2: Commit**

```bash
git add docs/phases/README.md
git commit -m "docs(phase-13): retrospective for Phase 13-a Intelligence core layer"
```

- [ ] **Step 3: Final sanity check**

```bash
git log --oneline -25
git status --short
```

Expected: a stack of ~14 commits on `milestone-e-intelligence` (one per task that produced code) and a clean working tree.

- [ ] **Step 4: Hand back to user for merge**

Tell the user the branch is ready to merge into `main`. Do **not** auto-merge; the milestone D pattern was an explicit user "okay let's merge into main" approval, so wait for the same here.

---

## Self-Review Checklist (already verified — listed for reviewer)

- **Spec coverage:** Every checkbox in `docs/phases/phase-13-foundation-models.md` is implemented OR explicitly deferred to 13-b with a reason. The three generators and token-level streaming are the only deferred items.
- **Placeholders:** None. Every code block is complete.
- **Type consistency:** `EventQuery`, `PlannerContext`, `AvailabilityState`, `AnswerDelta`, `AIAnswer`, `ToolEventResult` referenced consistently across tasks.
- **Test density:** 10 new test classes covering availability, prompt, safety, query filtering, each of five tools, stub service, and the AI overlay view model.
- **Build invariants:** XcodeGen regen called at every structural change; Swift 6 strict concurrency respected via `@MainActor` annotation and Sendable value types only.
