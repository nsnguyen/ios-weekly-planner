import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class DayPageViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var eventStore: SwiftDataEventStore!
    private var inboxStore: SwiftDataInboxStore!
    private var taskStore: SwiftDataTaskStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        eventStore = SwiftDataEventStore(context: container.mainContext)
        inboxStore = SwiftDataInboxStore(context: container.mainContext)
        taskStore = SwiftDataTaskStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        eventStore = nil
        inboxStore = nil
        taskStore = nil
        container = nil
        try await super.tearDown()
    }

    /// Saturday May 16, 2026 — same anchor used across the planner test
    /// suite so week math is deterministic.
    private static func may16_2026(hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 16
        components.hour = hour
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }

    /// Friday May 15, 2026.
    private static func may15_2026(hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 15
        components.hour = hour
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }

    private func makeViewModel(weekOffset: Int, dayIdx: Int, clock: @escaping () -> Date) -> DayPageViewModel {
        DayPageViewModel(weekOffset: weekOffset,
                         dayIdx: dayIdx,
                         eventStore: eventStore,
                         inboxStore: inboxStore,
                         taskStore: taskStore,
                         clock: clock)
    }

    // MARK: - Events

    func testRefreshLoadsEventsForGivenDayIdx() async throws {
        let sat9 = Event(title: "Sat 9 AM",
                         start: Self.may16_2026(hour: 9),
                         end: Self.may16_2026(hour: 10),
                         category: .work)
        let sat11 = Event(title: "Sat 11 AM",
                          start: Self.may16_2026(hour: 11),
                          end: Self.may16_2026(hour: 12),
                          category: .work)
        let fri = Event(title: "Fri noon",
                        start: Self.may15_2026(hour: 12),
                        end: Self.may15_2026(hour: 13),
                        category: .work)
        try await eventStore.upsert(sat9)
        try await eventStore.upsert(sat11)
        try await eventStore.upsert(fri)

        let vm = makeViewModel(weekOffset: 0, dayIdx: 5, clock: { Self.may16_2026() })
        await vm.refresh()

        XCTAssertEqual(vm.events.count, 2)
        XCTAssertEqual(vm.events.map(\.title), ["Sat 9 AM", "Sat 11 AM"])
        XCTAssertNil(vm.loadError)
    }

    func testEventsSortedByStartAscending() async throws {
        let late = Event(title: "Three PM",
                         start: Self.may16_2026(hour: 15),
                         end: Self.may16_2026(hour: 16),
                         category: .work)
        let early = Event(title: "Nine AM",
                          start: Self.may16_2026(hour: 9),
                          end: Self.may16_2026(hour: 10),
                          category: .work)
        let mid = Event(title: "Eleven AM",
                        start: Self.may16_2026(hour: 11),
                        end: Self.may16_2026(hour: 12),
                        category: .work)
        try await eventStore.upsert(late)
        try await eventStore.upsert(early)
        try await eventStore.upsert(mid)

        let vm = makeViewModel(weekOffset: 0, dayIdx: 5, clock: { Self.may16_2026() })
        await vm.refresh()

        let starts = vm.events.map(\.start)
        XCTAssertEqual(starts, starts.sorted())
        XCTAssertEqual(vm.events.map(\.title), ["Nine AM", "Eleven AM", "Three PM"])
    }

    // MARK: - isToday

    func testIsTodayTrueForCurrentWeekSaturday() {
        let vm = makeViewModel(weekOffset: 0, dayIdx: 5, clock: { Self.may16_2026() })
        XCTAssertTrue(vm.isToday)
    }

    func testIsTodayFalseForOtherDay() {
        let vm = makeViewModel(weekOffset: 0, dayIdx: 3, clock: { Self.may16_2026() })
        XCTAssertFalse(vm.isToday)
    }

    func testIsTodayFalseForOtherWeek() {
        let vm = makeViewModel(weekOffset: 1, dayIdx: 5, clock: { Self.may16_2026() })
        XCTAssertFalse(vm.isToday)
    }

    // MARK: - Inbox

    func testAcceptSuggestionMarksItAcceptedAndRemovesFromInbox() async throws {
        let suggestion = InboxSuggestion(gmailMessageID: "msg-1",
                                         proposedStart: Self.may16_2026(hour: 14),
                                         title: "Coffee with Dana",
                                         fromName: "Dana",
                                         fromEmail: "dana@example.com",
                                         subject: "coffee?",
                                         status: .pending)
        try await inboxStore.upsert(suggestion)

        let vm = makeViewModel(weekOffset: 0, dayIdx: 5, clock: { Self.may16_2026() })
        await vm.refresh()
        XCTAssertEqual(vm.inbox.count, 1)

        await vm.accept(suggestionID: suggestion.id)
        XCTAssertEqual(vm.inbox.count, 0)

        let stored = try await inboxStore.suggestion(id: suggestion.id)
        XCTAssertEqual(stored?.status, .accepted)
    }

    func testDismissSuggestionRemovesFromInbox() async throws {
        let suggestion = InboxSuggestion(gmailMessageID: "msg-2",
                                         proposedStart: Self.may16_2026(hour: 16),
                                         title: "Optional drinks",
                                         fromName: "Sam",
                                         fromEmail: "sam@example.com",
                                         subject: "drinks?",
                                         status: .pending)
        try await inboxStore.upsert(suggestion)

        let vm = makeViewModel(weekOffset: 0, dayIdx: 5, clock: { Self.may16_2026() })
        await vm.refresh()
        XCTAssertEqual(vm.inbox.count, 1)

        await vm.dismiss(suggestionID: suggestion.id)
        XCTAssertEqual(vm.inbox.count, 0)

        let stored = try await inboxStore.suggestion(id: suggestion.id)
        XCTAssertEqual(stored?.status, .dismissed)
    }

    func testInboxFilteredByDayIdx() async throws {
        let friSuggestion = InboxSuggestion(gmailMessageID: "fri",
                                            proposedStart: Self.may15_2026(hour: 10),
                                            title: "Friday standup",
                                            fromName: "Alex",
                                            fromEmail: "alex@example.com",
                                            subject: "standup",
                                            status: .pending)
        let satSuggestion = InboxSuggestion(gmailMessageID: "sat",
                                            proposedStart: Self.may16_2026(hour: 10),
                                            title: "Saturday brunch",
                                            fromName: "Mei",
                                            fromEmail: "mei@example.com",
                                            subject: "brunch",
                                            status: .pending)
        try await inboxStore.upsert(friSuggestion)
        try await inboxStore.upsert(satSuggestion)

        let vm = makeViewModel(weekOffset: 0, dayIdx: 5, clock: { Self.may16_2026() })
        await vm.refresh()

        XCTAssertEqual(vm.inbox.count, 1)
        XCTAssertEqual(vm.inbox.first?.title, "Saturday brunch")
    }

    // MARK: - Sticky orchestrator wiring (Phase 24, Task 10)

    func testRefresh_runsOrchestratorAndPopulatesInsights() async throws {
        let container = try SwiftDataStack.inMemoryContainer()
        let eventStore = SwiftDataEventStore(context: container.mainContext)
        let inboxStore = SwiftDataInboxStore(context: container.mainContext)
        let taskStore = SwiftDataTaskStore(context: container.mainContext)
        let today = Self.may16_2026(hour: 9)

        let inboxOnly = StickyOrchestrator(
            generators: [InboxInsightGenerator()],
            fallback: FixedNilGenerator())
        // Use the real `InboxSuggestion` initializer — the brief's
        // condensed shape doesn't exist on the model.
        let suggestion = InboxSuggestion(
            gmailMessageID: "test-msg-1",
            proposedStart: today,
            title: "T",
            fromName: "X",
            fromEmail: "x@y.com",
            category: .work,
            subject: "Test")
        try await inboxStore.upsert(suggestion)

        let days = WeekMath.weekDays(forOffset: 0, today: today)
        let dayIdx = WeekMath.todayIndex(in: days, for: today) ?? 0

        let vm = DayPageViewModel(weekOffset: 0,
                                  dayIdx: dayIdx,
                                  eventStore: eventStore,
                                  inboxStore: inboxStore,
                                  taskStore: taskStore,
                                  orchestrator: inboxOnly,
                                  modelContext: container.mainContext,
                                  clock: { today })
        await vm.refresh()

        XCTAssertEqual(vm.insights.count, 1)
        XCTAssertEqual(vm.insights.first?.kind, .inbox)
    }

    /// When `aiStickyNotesEnabled` is off, `refresh()` must NOT run the
    /// orchestrator at all — no insights surface and, crucially, no
    /// `AIInsight` rows are persisted (proving the WeatherKit/MapKit/
    /// FoundationModels cascade never fired). Opt-in gate, generation side.
    func testRefresh_whenStickyNotesDisabled_skipsOrchestratorAndPersistsNothing() async throws {
        let container = try SwiftDataStack.inMemoryContainer()
        let eventStore = SwiftDataEventStore(context: container.mainContext)
        let inboxStore = SwiftDataInboxStore(context: container.mainContext)
        let taskStore = SwiftDataTaskStore(context: container.mainContext)
        let today = Self.may16_2026(hour: 9)

        let settingsStore = SwiftDataSettingsStore(context: container.mainContext)
        try settingsStore.update { $0.aiStickyNotesEnabled = false }

        // InboxInsightGenerator WOULD emit an insight for a pending
        // suggestion, so a persisted row proves the cascade ran.
        let inboxOnly = StickyOrchestrator(
            generators: [InboxInsightGenerator()],
            fallback: FixedNilGenerator())
        let suggestion = InboxSuggestion(
            gmailMessageID: "test-msg-off",
            proposedStart: today,
            title: "T",
            fromName: "X",
            fromEmail: "x@y.com",
            category: .work,
            subject: "Test")
        try await inboxStore.upsert(suggestion)

        let days = WeekMath.weekDays(forOffset: 0, today: today)
        let dayIdx = WeekMath.todayIndex(in: days, for: today) ?? 0

        let vm = DayPageViewModel(weekOffset: 0,
                                  dayIdx: dayIdx,
                                  eventStore: eventStore,
                                  inboxStore: inboxStore,
                                  taskStore: taskStore,
                                  orchestrator: inboxOnly,
                                  modelContext: container.mainContext,
                                  settingsStore: settingsStore,
                                  clock: { today })
        await vm.refresh()

        XCTAssertTrue(vm.insights.isEmpty)
        let rows = try container.mainContext.fetch(FetchDescriptor<AIInsight>())
        XCTAssertEqual(rows.count, 0, "Generation must be skipped when the toggle is off")
    }

    /// With `aiStickyNotesEnabled` explicitly on, the cascade runs and
    /// insights surface as before — the gate doesn't suppress when enabled.
    func testRefresh_whenStickyNotesEnabled_runsOrchestrator() async throws {
        let container = try SwiftDataStack.inMemoryContainer()
        let eventStore = SwiftDataEventStore(context: container.mainContext)
        let inboxStore = SwiftDataInboxStore(context: container.mainContext)
        let taskStore = SwiftDataTaskStore(context: container.mainContext)
        let today = Self.may16_2026(hour: 9)

        let settingsStore = SwiftDataSettingsStore(context: container.mainContext)
        try settingsStore.update { $0.aiStickyNotesEnabled = true }

        let inboxOnly = StickyOrchestrator(
            generators: [InboxInsightGenerator()],
            fallback: FixedNilGenerator())
        let suggestion = InboxSuggestion(
            gmailMessageID: "test-msg-on",
            proposedStart: today,
            title: "T",
            fromName: "X",
            fromEmail: "x@y.com",
            category: .work,
            subject: "Test")
        try await inboxStore.upsert(suggestion)

        let days = WeekMath.weekDays(forOffset: 0, today: today)
        let dayIdx = WeekMath.todayIndex(in: days, for: today) ?? 0

        let vm = DayPageViewModel(weekOffset: 0,
                                  dayIdx: dayIdx,
                                  eventStore: eventStore,
                                  inboxStore: inboxStore,
                                  taskStore: taskStore,
                                  orchestrator: inboxOnly,
                                  modelContext: container.mainContext,
                                  settingsStore: settingsStore,
                                  clock: { today })
        await vm.refresh()

        XCTAssertEqual(vm.insights.count, 1)
        XCTAssertEqual(vm.insights.first?.kind, .inbox)
    }

    func testDismissInsight_marksAndRefetches() async throws {
        let container = try SwiftDataStack.inMemoryContainer()
        let today = Self.may16_2026()
        let stored = AIInsight(dayKey: AIInsight.key(weekOffset: 0, dayIdx: 5),
                                text: "Hi",
                                colorHex: "#FFE680",
                                tiltDegrees: 0,
                                kind: .keyword,
                                priority: 2)
        container.mainContext.insert(stored)
        try container.mainContext.save()

        let vm = DayPageViewModel(weekOffset: 0,
                                  dayIdx: 5,
                                  eventStore: SwiftDataEventStore(context: container.mainContext),
                                  inboxStore: SwiftDataInboxStore(context: container.mainContext),
                                  taskStore: SwiftDataTaskStore(context: container.mainContext),
                                  orchestrator: nil,
                                  modelContext: container.mainContext,
                                  clock: { today })
        vm.insights = [stored]
        await vm.dismissInsight(stored)

        XCTAssertTrue(stored.dismissed)
        XCTAssertFalse(vm.insights.contains { $0.id == stored.id })
    }
}

/// Always returns `nil` — used as the orchestrator's fallback in the
/// VM tests above so the cascade collapses to whatever the primary
/// generator produced (or nothing). Named distinctly from
/// `FixedGenerator` in `StickyOrchestratorTests.swift` purely to avoid
/// confusion when grepping; both are `private` so no symbol collision.
@MainActor
private final class FixedNilGenerator: InsightGenerator {
    let kind: InsightKind = .encouragement
    func generate(for _: DayContext) async -> AIInsight? { nil }
}
