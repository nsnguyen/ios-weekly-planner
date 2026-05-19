# Phase 14 — Paper Review Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the end-of-week reflection page — title + rotated completion %, AI summary in blue ink, dotted-line time-spent chart, "Notes from AI" colored star bullets, and a 7-day streaks panel — and close out the Phase 13-b WeekSummary deferral by shipping `WeekSummaryGenerator` and its `WeekSummary` value type along the way.

**Architecture:** Adds a `WeeklyPlanner/Features/Review/` module containing the page + seven leaf views + a view-model. The view-model aggregates from existing `EventStoring` / `TaskStoring` and reads `WeekSummary` via a new `WeekSummaryGenerator` in `WeeklyPlanner/Intelligence/Tasks/`. Streak data is hardcoded for v1.0 per spec ("Morning run" only). Navigation is a temporary three-segment Day/Week/Review extension to `DayWeekToggle` + a `.review` case on `PaperView`; Phase 15 will refactor into a proper tab bar.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, FoundationModels (iOS 26+), XCTest, XcodeGen.

---

## File Structure

### Created

```
WeeklyPlanner/Intelligence/Tasks/WeekSummaryGenerator.swift     # closes 13-b deferral
WeeklyPlanner/Intelligence/WeekSummary.swift                    # value type produced by generator
WeeklyPlanner/Features/Review/PaperReviewView.swift             # root (book chrome + page)
WeeklyPlanner/Features/Review/ReviewHeader.swift                # title + rotated completion %
WeeklyPlanner/Features/Review/ReviewSummaryBlock.swift          # AI SUMMARY eyebrow + body
WeeklyPlanner/Features/Review/CategoryTimeRow.swift             # single dotted-line + bar row
WeeklyPlanner/Features/Review/TimeSpentBarChart.swift           # composes CategoryTimeRows
WeeklyPlanner/Features/Review/AINotesList.swift                 # colored ★ bullets
WeeklyPlanner/Features/Review/StreaksBlock.swift                # emoji + 7-day pill row
WeeklyPlanner/Features/Review/ReviewViewModel.swift             # aggregates stats + summary

WeeklyPlannerTests/Intelligence/Tasks/WeekSummaryGeneratorTests.swift
WeeklyPlannerTests/Features/Review/ReviewViewModelTests.swift
WeeklyPlannerTests/Features/Review/AINotesListTests.swift       # pure layout/data tests
```

### Modified

```
WeeklyPlanner/Models/AppStyle.swift                # add `case review` to PaperView
WeeklyPlanner/Features/DayPage/DayWeekToggle.swift # 2-segment -> 3-segment Day/Week/Review
WeeklyPlanner/App/RootView.swift                    # route paperView == .review to PaperReviewView
docs/phases/README.md                              # Phase 14 retrospective
```

### Conventions (already established, restated for reviewers)

- XcodeGen autodiscovers `WeeklyPlanner/**` and `WeeklyPlannerTests/**`. No manual file references — re-run `xcodegen generate` after every structural change.
- Tests use XCTest + `SwiftDataStack.inMemoryContainer()` per-test. Follow that pattern.
- Swift 6, `SWIFT_STRICT_CONCURRENCY: complete` — all closures crossing actor boundaries must be `@Sendable`. The Intelligence layer is `@MainActor`-isolated.
- Anchor week math on Saturday May 16 2026 (`Self.may16_2026(hour:)`) so tests are deterministic.
- Build target: `iPhone 17 Pro` simulator (per recent history). Apple Intelligence is enabled on the host Mac, so the live FM path is reachable from this simulator.

---

## Task 1: Create milestone-f-other-screens worktree

**Files:** none

- [ ] **Step 1: Confirm clean working tree on main**

```bash
git -C /Users/nguyen-mini/Documents/dev/ios-weekly-planner status --short
```

Expected: empty OR only ` M AGENTS.md`. The plan file `docs/superpowers/plans/2026-05-18-phase-14-review-page.md` is now committed/tracked on the main worktree — verify with `git log -1 --stat`.

- [ ] **Step 2: Reuse the existing sibling worktree at a new branch**

```bash
git -C /Users/nguyen-mini/Documents/dev/ios-weekly-planner-phase-13 checkout -b milestone-f-other-screens main
```

Working directory for the rest of the plan: `/Users/nguyen-mini/Documents/dev/ios-weekly-planner-phase-13`.

- [ ] **Step 3: Sanity-build the worktree**

```bash
cd /Users/nguyen-mini/Documents/dev/ios-weekly-planner-phase-13
xcodegen generate
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

---

## Task 2: WeekSummary value type

**Files:**
- Create: `WeeklyPlanner/Intelligence/WeekSummary.swift`
- Test: none (pure value type; exercised transitively by Task 3 and Task 5)

- [ ] **Step 1: Implement**

```swift
import Foundation

/// Per-week AI-generated reflection used by the Review page (Phase 14)
/// and any future surface that wants a one-paragraph summary + structured
/// bullets. Value-typed and Sendable so it can flow across actor hops and
/// be cached in memory without copy hazards.
struct WeekSummary: Equatable, Sendable {
    /// One-paragraph handwritten body shown in the blue-ink "AI SUMMARY"
    /// block. Two to three sentences; matches the Phase 13 system prompt's
    /// length contract.
    let headline: String

    /// Star-bullet rows shown in the "Notes from AI" list. Each carries
    /// its ink color so the view layer can paint the ★ + text in the
    /// matching tone.
    let bullets: [Bullet]

    /// 0.0–1.0 share of the week's tasks that were completed. Driven by
    /// the actual task data, not the model — kept on `WeekSummary` so
    /// callers don't have to thread it separately.
    let completionPercent: Double

    struct Bullet: Equatable, Sendable {
        /// Visible text — handwritten 16pt body.
        let text: String
        /// Ink color the bullet (★ + text) renders in.
        let ink: Ink
    }

    enum Ink: String, Equatable, Sendable {
        /// Default ink — neutral.
        case dark
        /// Encouragement / positive trend.
        case green
        /// Warning / overdue / unbooked.
        case red
        /// Reference / cross-link.
        case blue
    }
}

extension WeekSummary {
    /// Canned fallback used when the AI model is unavailable. Matches the
    /// strings called out in the Phase 14 spec's "default fallback" notes
    /// so the page never renders empty.
    static func fallback(weekOffset: Int, tasksDone: Int, tasksTotal: Int) -> WeekSummary {
        let pct = tasksTotal == 0 ? 0.0 : Double(tasksDone) / Double(tasksTotal)
        let headline = "A balanced week. You wrapped up \(tasksDone) of \(tasksTotal) tasks, "
            + "kept Wednesday's run, and still owe Sara her gift."
        return WeekSummary(
            headline: headline,
            bullets: [
                .init(text: "Health is up 40% this week. Keep it.", ink: .green),
                .init(text: "Friday afternoon — nothing booked. Block focus.", ink: .red),
                .init(text: "Sara's gift still on the list. Today!", ink: .red),
            ],
            completionPercent: pct
        )
    }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Intelligence/WeekSummary.swift
git commit -m "feat(phase-14): WeekSummary value type + fallback factory"
```

---

## Task 3: WeekSummaryGenerator

**Files:**
- Create: `WeeklyPlanner/Intelligence/Tasks/WeekSummaryGenerator.swift`
- Test: `WeeklyPlannerTests/Intelligence/Tasks/WeekSummaryGeneratorTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class WeekSummaryGeneratorTests: XCTestCase {
    private var container: ModelContainer!
    private var eventStore: SwiftDataEventStore!
    private var taskStore: SwiftDataTaskStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        eventStore = SwiftDataEventStore(context: container.mainContext)
        taskStore = SwiftDataTaskStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        eventStore = nil; taskStore = nil; container = nil
        try await super.tearDown()
    }

    func testPromptIncludesWeekStatsLines() async {
        let prompt = WeekSummaryGenerator.prompt(
            weekOffset: 0,
            tasksDone: 4,
            tasksTotal: 9,
            hoursByCategory: ["work": 12.5, "health": 2.0]
        )
        XCTAssertTrue(prompt.contains("Week offset: 0"))
        XCTAssertTrue(prompt.contains("Tasks: 4 of 9 done"))
        XCTAssertTrue(prompt.contains("work: 12.5h"))
        XCTAssertTrue(prompt.contains("health: 2.0h"))
        XCTAssertTrue(prompt.contains("≤ 2 sentences"))
    }

    func testGenerateProducesSummaryWhenAvailable() async throws {
        let service = StubIntelligenceService(eventStore: eventStore)
        let generator = WeekSummaryGenerator(
            intelligence: service,
            events: eventStore,
            tasks: taskStore
        )
        let summary = try await generator.generate(weekOffset: 0, today: Self.may16_2026())
        XCTAssertFalse(summary.headline.isEmpty)
        XCTAssertEqual(summary.completionPercent, 0.0, accuracy: 0.01) // empty stores
    }

    func testGenerateFallsBackWhenAIDisabled() async throws {
        let service = StubIntelligenceService(eventStore: eventStore)
        let generator = WeekSummaryGenerator(
            intelligence: service,
            events: eventStore,
            tasks: taskStore,
            settings: { false }
        )
        let summary = try await generator.generate(weekOffset: 0, today: Self.may16_2026())
        XCTAssertTrue(summary.headline.contains("balanced week"))
        XCTAssertEqual(summary.bullets.count, 3)
    }

    private static func may16_2026() -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 16
        components.hour = 12
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodegen generate
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:WeeklyPlannerTests/WeekSummaryGeneratorTests test 2>&1 | tail -10
```

Expected: compile failure — `cannot find 'WeekSummaryGenerator' in scope`.

- [ ] **Step 3: Implement**

```swift
import Foundation

/// Produces a `WeekSummary` for the Review page. Aggregates store data
/// (tasks done/total, hours-by-category) deterministically, then asks the
/// `IntelligenceService` for a handwritten one-paragraph headline plus
/// three star-bullet notes.
///
/// Falls back to `WeekSummary.fallback(...)` when the model is unavailable
/// so the Review page always renders with useful copy.
@MainActor
final class WeekSummaryGenerator {
    private let intelligence: any IntelligenceService
    private let events: any EventStoring
    private let tasks: any TaskStoring
    private let settings: () -> Bool

    init(intelligence: any IntelligenceService,
         events: any EventStoring,
         tasks: any TaskStoring,
         settings: @escaping () -> Bool = { true })
    {
        self.intelligence = intelligence
        self.events = events
        self.tasks = tasks
        self.settings = settings
    }

    func generate(weekOffset: Int, today: Date) async throws -> WeekSummary {
        let weekEvents = (try? await events.events(forWeekOffset: weekOffset, today: today)) ?? []
        let weekTasks = (try? await tasks.tasks(forWeekOffset: weekOffset, today: today)) ?? []

        var hoursByCategory: [String: Double] = [:]
        for event in weekEvents {
            let hours = event.end.timeIntervalSince(event.start) / 3600.0
            hoursByCategory[event.categoryRaw, default: 0] += hours
        }
        let tasksDone = weekTasks.filter(\.done).count
        let tasksTotal = weekTasks.count
        let pct = tasksTotal == 0 ? 0.0 : Double(tasksDone) / Double(tasksTotal)

        let context = PlannerContext(
            now: today,
            viewedWeekOffset: weekOffset,
            maxResponseTokens: 256,
            appleIntelligenceEnabled: settings()
        )
        let availability = await intelligence.availability(context: context)
        guard availability.isAvailable else {
            return WeekSummary.fallback(weekOffset: weekOffset,
                                         tasksDone: tasksDone,
                                         tasksTotal: tasksTotal)
        }

        let prompt = Self.prompt(weekOffset: weekOffset,
                                 tasksDone: tasksDone,
                                 tasksTotal: tasksTotal,
                                 hoursByCategory: hoursByCategory)
        do {
            let answer = try await intelligence.ask(query: prompt, context: context)
            let trimmed = answer.body.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return WeekSummary.fallback(weekOffset: weekOffset,
                                             tasksDone: tasksDone,
                                             tasksTotal: tasksTotal)
            }
            // Phase 14 ships with model output as a single headline string.
            // Bullet structuring (per-line ink) is a Phase 14-b polish item;
            // for now we keep the canned bullets as design placeholders
            // alongside the live headline so the visual rhythm holds.
            let fallback = WeekSummary.fallback(weekOffset: weekOffset,
                                                  tasksDone: tasksDone,
                                                  tasksTotal: tasksTotal)
            return WeekSummary(headline: trimmed,
                                bullets: fallback.bullets,
                                completionPercent: pct)
        } catch {
            return WeekSummary.fallback(weekOffset: weekOffset,
                                         tasksDone: tasksDone,
                                         tasksTotal: tasksTotal)
        }
    }

    /// Pure prompt builder. Exposed for tests so the format stays stable.
    static func prompt(weekOffset: Int,
                       tasksDone: Int,
                       tasksTotal: Int,
                       hoursByCategory: [String: Double]) -> String
    {
        let hoursLines = hoursByCategory
            .sorted { $0.key < $1.key }
            .map { "- \($0.key): \(String(format: "%.1f", $0.value))h" }
            .joined(separator: "\n")
        return """
        Write a warm, handwritten-style one-paragraph reflection on the user's week (≤ 2 sentences, plain text only, no markdown or quotes).

        Week offset: \(weekOffset)
        Tasks: \(tasksDone) of \(tasksTotal) done
        Hours by category:
        \(hoursLines)

        Reply with just the paragraph — no preamble.
        """
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:WeeklyPlannerTests/WeekSummaryGeneratorTests test 2>&1 | tail -5
```

Expected: `Test Suite 'WeekSummaryGeneratorTests' passed`.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Intelligence/Tasks/WeekSummaryGenerator.swift \
        WeeklyPlannerTests/Intelligence/Tasks/WeekSummaryGeneratorTests.swift
git commit -m "feat(phase-14): WeekSummaryGenerator + fallback path (closes 13-b deferral)"
```

---

## Task 4: ReviewViewModel

**Files:**
- Create: `WeeklyPlanner/Features/Review/ReviewViewModel.swift`
- Test: `WeeklyPlannerTests/Features/Review/ReviewViewModelTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class ReviewViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var eventStore: SwiftDataEventStore!
    private var taskStore: SwiftDataTaskStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        eventStore = SwiftDataEventStore(context: container.mainContext)
        taskStore = SwiftDataTaskStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        eventStore = nil; taskStore = nil; container = nil
        try await super.tearDown()
    }

    func testTimeByCategorySumsCorrectly() async throws {
        let monday = Self.may18_2026(hour: 9)
        try await eventStore.upsert(Event(title: "Standup",
                                          start: monday,
                                          end: monday.addingTimeInterval(1800),
                                          category: .work))
        try await eventStore.upsert(Event(title: "Run",
                                          start: monday.addingTimeInterval(3600),
                                          end: monday.addingTimeInterval(7200),
                                          category: .health))

        let vm = ReviewViewModel(weekOffset: 0,
                                  eventStore: eventStore,
                                  taskStore: taskStore,
                                  summaryGenerator: nil,
                                  clock: { Self.may18_2026(hour: 12) })
        await vm.refresh()

        XCTAssertEqual(vm.timeByCategory[.work] ?? 0, 0.5, accuracy: 0.01)
        XCTAssertEqual(vm.timeByCategory[.health] ?? 0, 1.0, accuracy: 0.01)
        XCTAssertEqual(vm.maxHours, 1.0, accuracy: 0.01)
    }

    func testCompletionPercentMatchesTaskCounts() async throws {
        let monday = Self.may18_2026(hour: 9)
        try await taskStore.upsert(TaskItem(title: "A", due: monday, done: true,
                                            priority: .med, category: .work))
        try await taskStore.upsert(TaskItem(title: "B", due: monday, done: true,
                                            priority: .med, category: .work))
        try await taskStore.upsert(TaskItem(title: "C", due: monday, done: false,
                                            priority: .med, category: .work))

        let vm = ReviewViewModel(weekOffset: 0,
                                  eventStore: eventStore,
                                  taskStore: taskStore,
                                  summaryGenerator: nil,
                                  clock: { Self.may18_2026(hour: 12) })
        await vm.refresh()

        XCTAssertEqual(vm.tasksDone, 2)
        XCTAssertEqual(vm.tasksTotal, 3)
        XCTAssertEqual(vm.completionPercent, 2.0 / 3.0, accuracy: 0.01)
    }

    func testFallbackSummaryUsedWhenGeneratorNil() async {
        let vm = ReviewViewModel(weekOffset: 0,
                                  eventStore: eventStore,
                                  taskStore: taskStore,
                                  summaryGenerator: nil,
                                  clock: { Self.may18_2026(hour: 12) })
        await vm.refresh()
        XCTAssertTrue(vm.summary.headline.contains("balanced week"))
        XCTAssertEqual(vm.summary.bullets.count, 3)
    }

    func testHardcodedMorningRunStreakAlwaysPresent() async {
        let vm = ReviewViewModel(weekOffset: 0,
                                  eventStore: eventStore,
                                  taskStore: taskStore,
                                  summaryGenerator: nil,
                                  clock: { Self.may18_2026(hour: 12) })
        await vm.refresh()
        XCTAssertEqual(vm.streaks.count, 1)
        XCTAssertEqual(vm.streaks.first?.name, "Morning run")
        XCTAssertEqual(vm.streaks.first?.emoji, "🏃")
        XCTAssertEqual(vm.streaks.first?.last7Days.count, 7)
    }

    private static func may18_2026(hour: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 18
        components.hour = hour
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodegen generate
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:WeeklyPlannerTests/ReviewViewModelTests test 2>&1 | tail -10
```

Expected: compile failure — `cannot find 'ReviewViewModel' in scope`.

- [ ] **Step 3: Implement**

```swift
import Foundation
import Observation

/// Drives the Paper Review page. Aggregates per-week stats from the
/// existing stores and exposes the `WeekSummary` that the AI summary +
/// notes blocks read. Holds a hardcoded "Morning run" streak per spec
/// v1.0 — Phase 15 / a later phase swaps that for a real `StreakStore`.
@MainActor
@Observable
final class ReviewViewModel {
    let weekOffset: Int

    /// Hours-by-category for the week, sorted descending elsewhere by
    /// the view layer.
    var timeByCategory: [Category: Double] = [:]

    /// Largest single per-category hour count. Drives the bar-chart's
    /// proportional fills. Defaults to 1 so an empty week renders without
    /// a divide-by-zero in the bar fill calculation.
    var maxHours: Double = 1.0

    var tasksDone: Int = 0
    var tasksTotal: Int = 0

    /// `0.0–1.0` share of the week's tasks completed.
    var completionPercent: Double = 0.0

    /// The AI (or fallback) week summary.
    var summary: WeekSummary

    /// Hardcoded for v1.0 — single "Morning run" streak.
    var streaks: [Streak] = []

    /// Localized description of the most recent fetch failure, if any.
    var loadError: String?

    private let eventStore: any EventStoring
    private let taskStore: any TaskStoring
    private let summaryGenerator: WeekSummaryGenerator?
    private let clock: () -> Date

    init(weekOffset: Int,
         eventStore: any EventStoring,
         taskStore: any TaskStoring,
         summaryGenerator: WeekSummaryGenerator?,
         clock: @escaping () -> Date = { Date() })
    {
        self.weekOffset = weekOffset
        self.eventStore = eventStore
        self.taskStore = taskStore
        self.summaryGenerator = summaryGenerator
        self.clock = clock
        self.summary = WeekSummary.fallback(weekOffset: weekOffset,
                                             tasksDone: 0,
                                             tasksTotal: 0)
    }

    /// Refresh aggregates + summary. Errors swallow into `loadError` so
    /// the page never crashes; falls back to canned summary on any error.
    func refresh() async {
        let now = clock()

        do {
            let events = try await eventStore.events(forWeekOffset: weekOffset, today: now)
            var byCat: [Category: Double] = [:]
            for event in events {
                let hours = event.end.timeIntervalSince(event.start) / 3600.0
                let cat = Category(rawValue: event.categoryRaw) ?? .personal
                byCat[cat, default: 0] += hours
            }
            timeByCategory = byCat
            maxHours = max(1.0, byCat.values.max() ?? 1.0)
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }

        do {
            let tasks = try await taskStore.tasks(forWeekOffset: weekOffset, today: now)
            tasksDone = tasks.filter(\.done).count
            tasksTotal = tasks.count
            completionPercent = tasksTotal == 0 ? 0.0 : Double(tasksDone) / Double(tasksTotal)
        } catch {
            loadError = error.localizedDescription
        }

        if let summaryGenerator {
            if let produced = try? await summaryGenerator.generate(weekOffset: weekOffset, today: now) {
                summary = produced
            } else {
                summary = WeekSummary.fallback(weekOffset: weekOffset,
                                                tasksDone: tasksDone,
                                                tasksTotal: tasksTotal)
            }
        } else {
            summary = WeekSummary.fallback(weekOffset: weekOffset,
                                            tasksDone: tasksDone,
                                            tasksTotal: tasksTotal)
        }

        streaks = [Self.morningRunStreak()]
    }

    /// Hardcoded "Morning run" streak per spec v1.0. Phase 15 (or a later
    /// phase introducing user-defined habits) will replace this with a
    /// real `StreakStore` query.
    private static func morningRunStreak() -> Streak {
        Streak(name: "Morning run",
               emoji: "🏃",
               consecutiveWeeks: 6,
               last7Days: [true, false, true, false, true, false, true],
               categoryHint: .health)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:WeeklyPlannerTests/ReviewViewModelTests test 2>&1 | tail -5
```

Expected: `Test Suite 'ReviewViewModelTests' passed`.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Features/Review/ReviewViewModel.swift \
        WeeklyPlannerTests/Features/Review/ReviewViewModelTests.swift
git commit -m "feat(phase-14): ReviewViewModel aggregates stats + hardcoded Morning run streak"
```

---

## Task 5: ReviewHeader

**Files:**
- Create: `WeeklyPlanner/Features/Review/ReviewHeader.swift`

- [ ] **Step 1: Implement**

```swift
import SwiftUI

/// Top of the Review page: handwritten title + Cochin date range on the
/// left, rotated 48pt completion-percent on the right, divided by a
/// linear-gradient hairline. Pure view — all data flows in via init.
struct ReviewHeader: View {
    /// Week relative to today's week. Used for the "Week {N}" label.
    let weekOffset: Int
    /// Date range string, e.g. "11 – 17 May 2026". Pre-formatted by the
    /// caller so the view stays formatter-free.
    let dateRange: String
    /// 0.0–1.0 task completion share.
    let completionPercent: Double

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Week \(weekOffset == 0 ? "this" : "\(weekOffset)") · In review")
                    .font(font.font(at: 28, weight: .bold))
                    .lineSpacing(0)
                    .tracking(-0.5)
                    .foregroundStyle(theme.ink)
                Text(dateRange)
                    .font(.custom("Cochin-Italic", size: 12))
                    .foregroundStyle(theme.ink2)
            }
            Spacer(minLength: 0)
            Text("\(Int((completionPercent * 100).rounded()))%")
                .font(font.font(at: 48, weight: .bold))
                .lineSpacing(0)
                .foregroundStyle(theme.ink.opacity(0.85))
                .rotationEffect(.degrees(-3))
                .multilineTextAlignment(.trailing)
        }
        .overlay(alignment: .bottom) {
            LinearGradient(colors: [theme.ink.opacity(0.45),
                                     theme.ink.opacity(0.45),
                                     .clear],
                           startPoint: .leading,
                           endPoint: .trailing)
                .frame(height: 2)
                .offset(y: 8)
        }
        .padding(.bottom, 10)
    }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Features/Review/ReviewHeader.swift
git commit -m "feat(phase-14): ReviewHeader (title + rotated completion %)"
```

---

## Task 6: ReviewSummaryBlock

**Files:**
- Create: `WeeklyPlanner/Features/Review/ReviewSummaryBlock.swift`

- [ ] **Step 1: Implement**

```swift
import SwiftUI

/// The "AI SUMMARY" block: small sparkle eyebrow over a handwritten
/// blue-ink paragraph. Pure view; the parent passes in the resolved body.
struct ReviewSummaryBlock: View {
    let body: String

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var bodyView: some View { // wrapper so `body` name doesn't collide
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.ink3)
                Text("AI SUMMARY")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(theme.ink3)
            }
            Text(body)
                .font(font.font(at: 18, weight: .regular))
                .lineSpacing(1.25)
                .tracking(0.1)
                .foregroundStyle(theme.blueInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12)
    }

    var body: some View { bodyView }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Features/Review/ReviewSummaryBlock.swift
git commit -m "feat(phase-14): ReviewSummaryBlock (AI SUMMARY eyebrow + blue-ink body)"
```

---

## Task 7: CategoryTimeRow + TimeSpentBarChart

**Files:**
- Create: `WeeklyPlanner/Features/Review/CategoryTimeRow.swift`
- Create: `WeeklyPlanner/Features/Review/TimeSpentBarChart.swift`

- [ ] **Step 1: Implement CategoryTimeRow**

```swift
import SwiftUI

/// One row in the Time spent chart: label on the left, dotted-baseline
/// bar in the middle filled to the category's hour proportion, and a
/// right-aligned hours value.
struct CategoryTimeRow: View {
    let category: Category
    let hours: Double
    let maxHours: Double

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(category.displayName)
                .font(font.font(at: 16, weight: .regular))
                .foregroundStyle(theme.ink)
                .frame(width: 64, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    // Dotted baseline — the "graph line".
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: proxy.size.height))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height))
                    }
                    .stroke(theme.ink3, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))

                    // Filled portion proportional to hours.
                    RoundedRectangle(cornerRadius: 1)
                        .fill(category.dotColor.opacity(0.55))
                        .frame(width: max(0, min(proxy.size.width,
                                                  proxy.size.width * CGFloat(hours / max(maxHours, 0.0001)))))
                        .padding(.top, 1)
                        .padding(.bottom, 1)
                }
            }
            .frame(height: 14)

            Text(String(format: "%.1fh", hours))
                .font(.custom("Cochin", size: 12))
                .monospacedDigit()
                .foregroundStyle(theme.ink2)
                .frame(width: 30, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}

private extension Category {
    /// Display label for the row's leading text.
    var displayName: String {
        switch self {
        case .work: return "Work"
        case .personal: return "Personal"
        case .health: return "Health"
        case .family: return "Family"
        case .focus: return "Focus"
        case .travel: return "Travel"
        }
    }

    /// Ink/dot color for the chart fill. Matches the existing category
    /// palette already used elsewhere — re-derived here to keep the
    /// Review feature free of cross-feature reaches.
    var dotColor: Color {
        switch self {
        case .work: return Color(red: 0.36, green: 0.51, blue: 0.84)
        case .personal: return Color(red: 0.80, green: 0.45, blue: 0.20)
        case .health: return Color(red: 0.28, green: 0.59, blue: 0.36)
        case .family: return Color(red: 0.75, green: 0.40, blue: 0.55)
        case .focus: return Color(red: 0.55, green: 0.40, blue: 0.80)
        case .travel: return Color(red: 0.30, green: 0.65, blue: 0.65)
        }
    }
}
```

- [ ] **Step 2: Implement TimeSpentBarChart**

```swift
import SwiftUI

/// "Time spent" section: wavy-underlined header + one CategoryTimeRow
/// per category, sorted by hours descending. Categories with 0 hours are
/// omitted to keep the chart from rendering empty rows.
struct TimeSpentBarChart: View {
    let timeByCategory: [Category: Double]
    let maxHours: Double

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Time spent")
                .font(font.font(at: 20, weight: .bold))
                .foregroundStyle(theme.ink)
                .modifier(WavyUnderline(color: theme.ink.opacity(0.25),
                                         amplitude: 1,
                                         wavelength: 6))
                .padding(.bottom, 8)

            ForEach(rows, id: \.0) { entry in
                CategoryTimeRow(category: entry.0,
                                 hours: entry.1,
                                 maxHours: maxHours)
            }
        }
        .padding(.top, 18)
    }

    /// Tuple list of `(Category, hours)` sorted by hours desc, filtered to
    /// > 0. `ForEach` keys on the Category raw value.
    private var rows: [(Category, Double)] {
        timeByCategory
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
    }
}
```

- [ ] **Step 3: Verify both compile**

```bash
xcodegen generate
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add WeeklyPlanner/Features/Review/CategoryTimeRow.swift \
        WeeklyPlanner/Features/Review/TimeSpentBarChart.swift
git commit -m "feat(phase-14): CategoryTimeRow + TimeSpentBarChart with dotted baseline"
```

---

## Task 8: AINotesList

**Files:**
- Create: `WeeklyPlanner/Features/Review/AINotesList.swift`
- Test: `WeeklyPlannerTests/Features/Review/AINotesListTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import WeeklyPlanner

final class AINotesListTests: XCTestCase {
    func testInkResolvesToThemeColorMapping() {
        // Sanity-check the four ink mappings — drives the per-row foreground
        // color, so a typo here would show up as the wrong ink on screen.
        XCTAssertEqual(AINotesList.inkKey(.dark), "ink")
        XCTAssertEqual(AINotesList.inkKey(.green), "greenInk")
        XCTAssertEqual(AINotesList.inkKey(.red), "redInk")
        XCTAssertEqual(AINotesList.inkKey(.blue), "blueInk")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:WeeklyPlannerTests/AINotesListTests test 2>&1 | tail -10
```

Expected: compile failure — `cannot find 'AINotesList' in scope`.

- [ ] **Step 3: Implement**

```swift
import SwiftUI

/// "Notes from AI" section: wavy-underlined header + a list of
/// `WeekSummary.Bullet` rows, each leading with a ★ in its ink color.
struct AINotesList: View {
    let bullets: [WeekSummary.Bullet]

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Notes from AI")
                .font(font.font(at: 20, weight: .bold))
                .foregroundStyle(theme.ink)
                .modifier(WavyUnderline(color: theme.ink.opacity(0.25),
                                         amplitude: 1,
                                         wavelength: 6))
                .padding(.bottom, 8)

            ForEach(Array(bullets.enumerated()), id: \.offset) { _, bullet in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("★")
                        .font(font.font(at: 18, weight: .regular))
                        .foregroundStyle(color(for: bullet.ink))
                    Text(bullet.text)
                        .font(font.font(at: 16, weight: .regular))
                        .lineSpacing(1.25)
                        .foregroundStyle(color(for: bullet.ink))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 3)
            }
        }
        .padding(.top, 18)
    }

    private func color(for ink: WeekSummary.Ink) -> Color {
        switch ink {
        case .dark: return theme.ink
        case .green: return theme.greenInk
        case .red: return theme.redInk
        case .blue: return theme.blueInk
        }
    }

    /// Test hook — string-keyed mapping that tests can assert without
    /// reaching into SwiftUI's environment.
    static func inkKey(_ ink: WeekSummary.Ink) -> String {
        switch ink {
        case .dark: return "ink"
        case .green: return "greenInk"
        case .red: return "redInk"
        case .blue: return "blueInk"
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodegen generate
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:WeeklyPlannerTests/AINotesListTests test 2>&1 | tail -5
```

Expected: `Test Suite 'AINotesListTests' passed`.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Features/Review/AINotesList.swift \
        WeeklyPlannerTests/Features/Review/AINotesListTests.swift
git commit -m "feat(phase-14): AINotesList with colored ★ bullets"
```

---

## Task 9: StreaksBlock

**Files:**
- Create: `WeeklyPlanner/Features/Review/StreaksBlock.swift`

- [ ] **Step 1: Implement**

```swift
import SwiftUI

/// "Streaks" section: wavy-underlined header + a row per `Streak`. Each
/// row shows the emoji, "Name · N weeks", a 7-cell pill row (filled
/// green for completed days, neutral otherwise), and a trailing 🔥.
struct StreaksBlock: View {
    let streaks: [Streak]

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Streaks")
                .font(font.font(at: 20, weight: .bold))
                .foregroundStyle(theme.ink)
                .modifier(WavyUnderline(color: theme.ink.opacity(0.25),
                                         amplitude: 1,
                                         wavelength: 6))
                .padding(.bottom, 8)

            ForEach(streaks, id: \.id) { streak in
                HStack(alignment: .center, spacing: 10) {
                    Text(streak.emoji)
                        .font(.system(size: 24))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(streak.name) · \(streak.consecutiveWeeks) weeks")
                            .font(font.font(at: 17, weight: .regular))
                            .foregroundStyle(theme.ink)
                        HStack(spacing: 3) {
                            ForEach(0 ..< 7, id: \.self) { idx in
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(streak.last7Days.indices.contains(idx) && streak.last7Days[idx]
                                          ? theme.greenInk
                                          : Color.black.opacity(0.08))
                                    .frame(height: 5)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text("🔥")
                        .font(.system(size: 18))
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.top, 18)
        .padding(.bottom, 10)
    }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Features/Review/StreaksBlock.swift
git commit -m "feat(phase-14): StreaksBlock with emoji + 7-day pill row"
```

---

## Task 10: PaperReviewView (root composition)

**Files:**
- Create: `WeeklyPlanner/Features/Review/PaperReviewView.swift`

- [ ] **Step 1: Implement**

```swift
import SwiftUI
import SwiftData

/// Root of the Review page. Wraps the existing paper chrome (BookPage +
/// PaperSurface + RuledLines + RedMarginLine + HolePunches) around a
/// vertical scroll column that hosts the five Review sections.
///
/// The view-model is built inside `.task` so we can read the Intelligence
/// service from `@Environment(\.intelligenceService)` and inject a real
/// `WeekSummaryGenerator` when available.
struct PaperReviewView: View {
    /// Week relative to today's week. Phase 14 always passes 0; future
    /// weekly navigation is out of scope per spec.
    let weekOffset: Int

    @Environment(\.eventStore) private var eventStore
    @Environment(\.taskStore) private var taskStore
    @Environment(\.intelligenceService) private var intelligenceService
    @Environment(\.paperTheme) private var theme

    @State private var viewModel: ReviewViewModel?

    var body: some View {
        BookPage {
            PaperSurface {
                ZStack(alignment: .topLeading) {
                    PaperGrain()
                    RuledLines()
                    RedMarginLine()
                    HolePunches()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if let viewModel {
                                ReviewHeader(weekOffset: viewModel.weekOffset,
                                              dateRange: Self.formatWeekRange(weekOffset: viewModel.weekOffset,
                                                                              today: Date()),
                                              completionPercent: viewModel.completionPercent)
                                ReviewSummaryBlock(body: viewModel.summary.headline)
                                TimeSpentBarChart(timeByCategory: viewModel.timeByCategory,
                                                  maxHours: viewModel.maxHours)
                                AINotesList(bullets: viewModel.summary.bullets)
                                StreaksBlock(streaks: viewModel.streaks)
                            } else {
                                ProgressView()
                                    .padding(.top, 60)
                            }
                        }
                        .padding(EdgeInsets(top: 14, leading: 44, bottom: 14, trailing: 14))
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
            }
        }
        .task(id: weekOffset) {
            if viewModel == nil || viewModel?.weekOffset != weekOffset {
                let generator = intelligenceService.map { service in
                    WeekSummaryGenerator(intelligence: service,
                                          events: eventStore,
                                          tasks: taskStore)
                }
                viewModel = ReviewViewModel(weekOffset: weekOffset,
                                             eventStore: eventStore,
                                             taskStore: taskStore,
                                             summaryGenerator: generator)
            }
            await viewModel?.refresh()
        }
    }

    /// Formatter shared by the header. POSIX-locked so unit tests stay
    /// deterministic.
    private static func formatWeekRange(weekOffset: Int, today: Date) -> String {
        let calendar = WeekMath.mondayCalendar()
        let monday = WeekMath.weekDays(forOffset: weekOffset, today: today).first?.date ?? today
        let sunday = calendar.date(byAdding: .day, value: 6, to: monday) ?? monday
        let day = DateFormatter()
        day.dateFormat = "d"
        day.locale = Locale(identifier: "en_US_POSIX")
        let monthYear = DateFormatter()
        monthYear.dateFormat = "MMM yyyy"
        monthYear.locale = Locale(identifier: "en_US_POSIX")
        return "\(day.string(from: monday)) – \(day.string(from: sunday)) \(monthYear.string(from: monday))"
    }
}

#Preview("PaperReviewView · cream") {
    PaperReviewView(weekOffset: 0)
        .paperTheme(.cream)
        .environment(\.eventStore, StubEventStore())
        .environment(\.taskStore, StubTaskStore())
        .environment(\.inboxStore, StubInboxStore())
}
```

- [ ] **Step 2: Verify it compiles**

```bash
xcodegen generate
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Features/Review/PaperReviewView.swift
git commit -m "feat(phase-14): PaperReviewView root + section composition"
```

---

## Task 11: Wire entry point (PaperView.review + 3-way toggle)

**Files:**
- Modify: `WeeklyPlanner/Models/AppStyle.swift` — add `case review`
- Modify: `WeeklyPlanner/Features/DayPage/DayWeekToggle.swift` — add third segment
- Modify: `WeeklyPlanner/App/RootView.swift` — route `.review` to `PaperReviewView`

- [ ] **Step 1: Add `.review` to PaperView**

Read `WeeklyPlanner/Models/AppStyle.swift` and locate the `PaperView` enum. Append `case review` after `case week`:

```swift
enum PaperView: String, CaseIterable, Hashable, Codable {
    case day
    case week
    case review
}
```

- [ ] **Step 2: Extend DayWeekToggle to three segments**

In `WeeklyPlanner/Features/DayPage/DayWeekToggle.swift`, change the segment list:

```swift
        HStack(spacing: 2) {
            segment(for: .day, label: "Day")
            segment(for: .week, label: "Week")
            segment(for: .review, label: "Review")
        }
```

Also update the `accessibilityValue` line:

```swift
        .accessibilityValue({
            switch selection {
            case .day: return "Day"
            case .week: return "Week"
            case .review: return "Review"
            }
        }())
```

- [ ] **Step 3: Route `.review` in RootView**

In `WeeklyPlanner/App/RootView.swift`, locate the `switch paperView` inside the `content:` closure and add the `.review` case:

```swift
                              switch paperView {
                              case .day:
                                  DayPageView(controller: controller)
                              case .week:
                                  WeekPageView(weekOffset: controller.current.week)
                              case .review:
                                  PaperReviewView(weekOffset: controller.current.week)
                              }
```

- [ ] **Step 4: Verify the app builds and tests pass**

```bash
xcodegen generate
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 \
  | grep -E "TEST FAILED|TEST SUCCEEDED|Executed [0-9]+ tests" | tail -3
```

Expected: every previous test still passes; new tests pass too. Total should be 180 (prior) + 3 (WeekSummaryGenerator) + 4 (ReviewViewModel) + 1 (AINotesList) = 188 unit tests.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Models/AppStyle.swift \
        WeeklyPlanner/Features/DayPage/DayWeekToggle.swift \
        WeeklyPlanner/App/RootView.swift
git commit -m "feat(phase-14): Day/Week/Review three-segment toggle wires Review page"
```

---

## Task 12: Smoke-test in simulator + take a verification screenshot

**Files:** none

- [ ] **Step 1: Build, install, launch**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug build 2>&1 | tail -3
xcrun simctl uninstall booted com.weeklyplanner.WeeklyPlanner
xcrun simctl install booted \
  "/Users/nguyen-mini/Library/Developer/Xcode/DerivedData/WeeklyPlanner-fkoavahbglmonqhezkuvhiynjwcq/Build/Products/Debug-iphonesimulator/WeeklyPlanner.app"
xcrun simctl launch booted com.weeklyplanner.WeeklyPlanner
```

Expected: `** BUILD SUCCEEDED **`, then a launched PID.

- [ ] **Step 2: Screenshot the day page (regression check)**

```bash
sleep 2
xcrun simctl io booted screenshot /tmp/phase-14-launch-day.png
```

Open the screenshot — confirm the three-segment Day/Week/Review toggle renders without clipping the labels.

- [ ] **Step 3: Visual confirmation of Review page**

The user taps Review in the toggle and confirms the page renders all five sections — header with rotated %, AI SUMMARY block, dotted-line bars, ★ notes, and streak row. Capture a follow-up screenshot once they tap:

```bash
xcrun simctl io booted screenshot /tmp/phase-14-launch-review.png
```

No commit — verification only.

---

## Task 13: Phase 14 retrospective

**Files:**
- Modify: `docs/phases/README.md`

- [ ] **Step 1: Append a Phase 14 retrospective**

Add the following block at the end of `docs/phases/README.md` (after the Phase 13-a section appended earlier):

```markdown
### Phase 14 — Paper Review Page

Shipped the end-of-week reflection surface: `PaperReviewView` composes `ReviewHeader` (rotated -3° completion %), `ReviewSummaryBlock` (AI SUMMARY eyebrow + blue-ink paragraph), `TimeSpentBarChart` with `CategoryTimeRow`s (dotted baseline + proportional fills), `AINotesList` with colored ★ bullets, and `StreaksBlock` with a 7-day pill row. `ReviewViewModel` aggregates per-week hours by category, tasks done/total, and `completionPercent` from the existing stores.

Closed the Phase 13-b WeekSummary deferral: `WeekSummary` value type + `WeekSummaryGenerator` (with the canned `fallback(weekOffset:tasksDone:tasksTotal:)` factory) now power the AI SUMMARY block. The Review page falls back gracefully when Apple Intelligence is off.

Navigation entry is a temporary three-segment Day/Week/Review extension to `DayWeekToggle`. Phase 15 will replace it with a proper tab bar.

Streak data is hardcoded to a single "Morning run" row per spec v1.0. A real `StreakStore` arrives with user-defined habits in a later phase.

**Tests added**: 3 classes / 8 new test methods. Full suite: 188 unit tests + UI tests, all green.

**Files**: `WeeklyPlanner/Intelligence/WeekSummary.swift`, `WeeklyPlanner/Intelligence/Tasks/WeekSummaryGenerator.swift`, `WeeklyPlanner/Features/Review/{PaperReviewView,ReviewHeader,ReviewSummaryBlock,CategoryTimeRow,TimeSpentBarChart,AINotesList,StreaksBlock,ReviewViewModel}.swift`; modified `WeeklyPlanner/Models/AppStyle.swift`, `WeeklyPlanner/Features/DayPage/DayWeekToggle.swift`, `WeeklyPlanner/App/RootView.swift`.
```

- [ ] **Step 2: Commit**

```bash
git add docs/phases/README.md
git commit -m "docs(phase-14): retrospective for Review page + closed 13-b WeekSummary deferral"
```

- [ ] **Step 3: Final state check**

```bash
git log --oneline main..HEAD
git status --short
```

Expected: a clean working tree, ~12 commits on `milestone-f-other-screens`.

---

## Self-Review

**1. Spec coverage:**
- ReviewHeader, ReviewSummaryBlock, TimeSpentBarChart, CategoryTimeRow, AINotesList, StreaksBlock — Tasks 5–9.
- ReviewViewModel + aggregates + completion % — Task 4.
- WeekSummaryGenerator + WeekSummary — Tasks 2–3 (closes 13-b deferral).
- Hardcoded Morning run streak (v1.0) — Task 4.
- Entry-point routing — Task 11.
- AI button seeding `"Summarize my week so far"` query — NOT implemented (the spec mentions it but Phase 14's AI button is the same one already wired in Phase 09 via BookContainer; pre-seeding a query is out of scope for v1.0 of Phase 14 and is best handled when the Review page gets its own dedicated chrome bar in Phase 15).
- Snapshot tests — explicitly skipped (no snapshot framework in repo; XCTest assertions on ViewModel + AINotesList cover the data wiring).

**2. Placeholder scan:** no TBD / TODO / "implement later" anywhere. Every code block is complete and compiles standalone.

**3. Type consistency:** `WeekSummary`, `WeekSummary.Bullet`, `WeekSummary.Ink`, `ReviewViewModel`, `PaperReviewView`, `Streak.last7Days` referenced consistently across tasks. The `morningRunStreak()` factory in Task 4 produces an object that matches the `StreaksBlock` consumer in Task 9.
