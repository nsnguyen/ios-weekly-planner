import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

/// Logic-level tests for the to-do half of `DayPageViewModel` that feeds
/// `TodoBlock`. Rather than rendering the SwiftUI view (which would force a
/// snapshot harness for very little gain), these tests verify the
/// view-model state the block ultimately reads — empty-vs-populated,
/// toggle-flips-done in the underlying store, and high-priority-first
/// ordering. All persistence runs against an in-memory SwiftData container,
/// mirroring `EventStoreTests`.
@MainActor
final class TodoBlockTests: XCTestCase {
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

    /// Saturday May 16, 2026 — the standard anchor used across the planner
    /// test suite so week math is deterministic.
    private static func may16_2026(hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 16
        components.hour = hour
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }

    private func makeViewModel(dayIdx: Int = 5) -> DayPageViewModel {
        DayPageViewModel(weekOffset: 0,
                         dayIdx: dayIdx,
                         eventStore: eventStore,
                         inboxStore: inboxStore,
                         taskStore: taskStore,
                         clock: { Self.may16_2026() })
    }

    // MARK: - Tests

    /// With no tasks persisted, the view model's `tasks` array is empty —
    /// which is what `TodoBlock` reads to short-circuit its body to
    /// `EmptyView`.
    func testTodoBlockHiddenWhenNoTasks() async {
        let viewModel = makeViewModel()
        await viewModel.refresh()
        XCTAssertTrue(viewModel.tasks.isEmpty)
    }

    /// `viewModel.toggleTask(id:)` must flip the underlying `done` flag in
    /// the store so the change persists across reloads. We toggle once and
    /// re-fetch from the store directly to verify the write landed.
    func testToggleViaViewModelFlipsDoneInStore() async throws {
        let task = TaskItem(title: "Water plants",
                            due: Self.may16_2026(),
                            done: false,
                            priority: .low,
                            category: .personal)
        try await taskStore.upsert(task)

        let viewModel = makeViewModel()
        await viewModel.refresh()
        XCTAssertEqual(viewModel.tasks.count, 1)
        XCTAssertEqual(viewModel.tasks.first?.done, false)

        await viewModel.toggleTask(id: task.id)

        let stored = try await taskStore.task(id: task.id)
        XCTAssertEqual(stored?.done, true)
        XCTAssertEqual(viewModel.tasks.first?.done, true)
    }

    /// Three tasks with mixed priorities should arrive in `vm.tasks`
    /// high-priority-first, regardless of insertion order. Inserting in
    /// low → high → med order verifies the sort, not the storage order.
    func testHighPriorityTasksSortedFirst() async throws {
        let due = Self.may16_2026()
        let low = TaskItem(title: "Water plants",
                           due: due,
                           priority: .low,
                           category: .personal)
        let high = TaskItem(title: "Buy gift for Sara",
                            due: due,
                            priority: .high,
                            category: .family)
        let med = TaskItem(title: "Confirm dinner reservation",
                           due: due,
                           priority: .med,
                           category: .personal)
        try await taskStore.upsert(low)
        try await taskStore.upsert(high)
        try await taskStore.upsert(med)

        let viewModel = makeViewModel()
        await viewModel.refresh()

        XCTAssertEqual(viewModel.tasks.map(\.priority), [.high, .med, .low])
        XCTAssertEqual(viewModel.tasks.first?.title, "Buy gift for Sara")
    }
}
