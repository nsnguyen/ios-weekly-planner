import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class AnnotationLayerTests: XCTestCase {
    private var container: ModelContainer!
    private var eventStore: SwiftDataEventStore!
    private var inboxStore: SwiftDataInboxStore!
    private var taskStore: SwiftDataTaskStore!
    private var annotationStore: SwiftDataAnnotationStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        eventStore = SwiftDataEventStore(context: container.mainContext)
        inboxStore = SwiftDataInboxStore(context: container.mainContext)
        taskStore = SwiftDataTaskStore(context: container.mainContext)
        annotationStore = SwiftDataAnnotationStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        annotationStore = nil
        taskStore = nil
        inboxStore = nil
        eventStore = nil
        container = nil
        try await super.tearDown()
    }

    private static func may16_2026(hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 16
        components.hour = hour
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }

    private func makeViewModel(weekOffset: Int = 0, dayIdx: Int = 5) -> DayPageViewModel {
        DayPageViewModel(weekOffset: weekOffset,
                         dayIdx: dayIdx,
                         eventStore: eventStore,
                         inboxStore: inboxStore,
                         taskStore: taskStore,
                         annotationStore: annotationStore,
                         clock: { Self.may16_2026() })
    }

    func testAddAnnotationLandsOnRightDayKeyAndClamps() async throws {
        let vm = makeViewModel(weekOffset: 0, dayIdx: 5)
        let created = await vm.addAnnotation(atUnit: CGPoint(x: 1.4, y: -0.2))

        XCTAssertEqual(created?.dayKey, "0:5")
        XCTAssertEqual(created?.unitX ?? -1, 1.0, accuracy: 0.0001)
        XCTAssertEqual(created?.unitY ?? -1, 0.0, accuracy: 0.0001)
        XCTAssertEqual(vm.annotations.count, 1)

        let friday = makeViewModel(weekOffset: 0, dayIdx: 4)
        await friday.refresh()
        XCTAssertTrue(friday.annotations.isEmpty, "Annotations must not leak across days")
    }

    func testRefreshLoadsExistingAnnotationsForDay() async throws {
        try await annotationStore.upsert(
            Annotation(dayKey: "0:5", text: "seeded", colorToken: .blue, isBold: false, unitX: 0.4, unitY: 0.4))
        let vm = makeViewModel()
        await vm.refresh()
        XCTAssertEqual(vm.annotations.map(\.text), ["seeded"])
    }

    func testCommitTextPersistsTrimmed() async throws {
        let vm = makeViewModel()
        let created = await vm.addAnnotation(atUnit: CGPoint(x: 0.5, y: 0.5))
        let id = try XCTUnwrap(created?.id)

        await vm.commitAnnotationText(id: id, text: "  buy flowers \n")

        let persisted = try await annotationStore.annotations(dayKey: "0:5").first
        XCTAssertEqual(persisted?.text, "buy flowers")
    }

    func testCommitEmptyTextDeletesAnnotation() async throws {
        let vm = makeViewModel()
        let created = await vm.addAnnotation(atUnit: CGPoint(x: 0.5, y: 0.5))
        let id = try XCTUnwrap(created?.id)

        await vm.commitAnnotationText(id: id, text: "   ")

        XCTAssertTrue(vm.annotations.isEmpty, "Empty-text commit must delete the annotation")
        let persisted = try await annotationStore.annotations(dayKey: "0:5")
        XCTAssertTrue(persisted.isEmpty)
    }

    func testStyleChangesPersist() async throws {
        let vm = makeViewModel()
        let created = await vm.addAnnotation(atUnit: CGPoint(x: 0.5, y: 0.5))
        let id = try XCTUnwrap(created?.id)

        await vm.setAnnotationStyle(id: id, colorToken: .green)
        await vm.setAnnotationStyle(id: id, isBold: true)

        let persisted = try await annotationStore.annotations(dayKey: "0:5").first
        XCTAssertEqual(persisted?.colorToken, .green)
        XCTAssertEqual(persisted?.isBold, true)
    }

    func testMoveClampsAndPersists() async throws {
        let vm = makeViewModel()
        let created = await vm.addAnnotation(atUnit: CGPoint(x: 0.5, y: 0.5))
        let id = try XCTUnwrap(created?.id)

        await vm.moveAnnotation(id: id, toUnit: CGPoint(x: 2.0, y: 0.7))

        let persisted = try await annotationStore.annotations(dayKey: "0:5").first
        XCTAssertEqual(persisted?.unitX ?? -1, 1.0, accuracy: 0.0001)
        XCTAssertEqual(persisted?.unitY ?? -1, 0.7, accuracy: 0.0001)
    }

    func testDeleteRemovesAnnotation() async throws {
        let vm = makeViewModel()
        let created = await vm.addAnnotation(atUnit: CGPoint(x: 0.5, y: 0.5))
        let id = try XCTUnwrap(created?.id)

        await vm.deleteAnnotation(id: id)

        XCTAssertTrue(vm.annotations.isEmpty)
    }
}
