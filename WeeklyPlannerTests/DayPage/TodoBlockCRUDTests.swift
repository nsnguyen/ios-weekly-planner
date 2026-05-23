import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class TodoBlockCRUDTests: XCTestCase {
    private var container: ModelContainer!
    private var taskStore: SwiftDataTaskStore!
    private var eventStore: SwiftDataEventStore!
    private var inboxStore: SwiftDataInboxStore!
    private var calendar: Calendar!
    private var today: Date!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        taskStore = SwiftDataTaskStore(context: container.mainContext)
        eventStore = SwiftDataEventStore(context: container.mainContext)
        inboxStore = SwiftDataInboxStore(context: container.mainContext)
        calendar = WeekMath.mondayCalendar()
        today = Date(timeIntervalSince1970: 1_780_000_000)
    }

    override func tearDown() async throws {
        taskStore = nil; eventStore = nil; inboxStore = nil
        calendar = nil; today = nil; container = nil
        try await super.tearDown()
    }

    private func makeViewModel() -> DayPageViewModel {
        DayPageViewModel(weekOffset: 0,
                          dayIdx: WeekMath.todayIndex(in: WeekMath.weekDays(forOffset: 0,
                                                                            today: today),
                                                       for: today) ?? 0,
                          eventStore: eventStore,
                          inboxStore: inboxStore,
                          taskStore: taskStore,
                          clock: { self.today })
    }

    func testAddTask_persistsAndAppearsInList() async throws {
        let vm = makeViewModel()
        await vm.refresh()
        XCTAssertEqual(vm.tasks.count, 0)

        vm.taskComposer.title = "Prep slides"
        vm.taskComposer.priority = .high
        await vm.addTask()

        await vm.refresh()
        XCTAssertEqual(vm.tasks.count, 1)
        XCTAssertEqual(vm.tasks.first?.title, "Prep slides")
        XCTAssertEqual(vm.tasks.first?.priority, .high)
    }

    func testAddTask_emptyTitle_isNoOp() async throws {
        let vm = makeViewModel()
        vm.taskComposer.title = "   "
        await vm.addTask()
        await vm.refresh()
        XCTAssertEqual(vm.tasks.count, 0)
    }

    func testAddTask_resetsTitleKeepsComposing() async throws {
        let vm = makeViewModel()
        vm.taskComposer.isComposing = true
        vm.taskComposer.title = "Prep slides"
        await vm.addTask()
        XCTAssertEqual(vm.taskComposer.title, "")
        XCTAssertTrue(vm.taskComposer.isComposing)
    }

    func testDeleteTask_removesRow() async throws {
        let task = TaskItem(title: "Prep slides",
                            due: today,
                            priority: .med,
                            category: .personal)
        try await taskStore.upsert(task)

        let vm = makeViewModel()
        await vm.refresh()
        XCTAssertEqual(vm.tasks.count, 1)

        await vm.deleteTask(id: task.id)
        await vm.refresh()
        XCTAssertEqual(vm.tasks.count, 0)
    }

    func testUpdateTask_changesPriority() async throws {
        let task = TaskItem(title: "Prep slides",
                            due: today,
                            priority: .low,
                            category: .personal)
        try await taskStore.upsert(task)

        let vm = makeViewModel()
        await vm.refresh()

        await vm.updateTask(id: task.id) { $0.priority = .high }
        await vm.refresh()
        XCTAssertEqual(vm.tasks.first?.priority, .high)
    }

    func testUpdateTask_changesDueDate() async throws {
        let task = TaskItem(title: "Prep slides",
                            due: today,
                            priority: .med,
                            category: .personal)
        try await taskStore.upsert(task)

        let vm = makeViewModel()
        await vm.refresh()

        let tomorrow = today.addingTimeInterval(86_400)
        await vm.updateTask(id: task.id) { $0.due = tomorrow }
        await vm.refresh()
        // The task moved to a different day; this day-vm should no
        // longer surface it.
        XCTAssertEqual(vm.tasks.count, 0)
    }
}
