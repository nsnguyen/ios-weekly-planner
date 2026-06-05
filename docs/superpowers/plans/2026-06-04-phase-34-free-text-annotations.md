# Phase 34 — Free-Text Annotations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users long-press empty paper on a Day page to write free-form text — ink color + bold, draggable, editable, deletable, persisted per day — without ever locking page-flip navigation.

**Architecture:** An `Annotation` SwiftData `@Model` keyed by the existing `"<weekOffset>:<dayIdx>"` dayKey scheme, behind `AnnotationStoring` (SwiftData + stub). Annotation CRUD lives on `DayPageViewModel` (loaded with the day's other data). Rendering is an `AnnotationLayer` overlay on the Day page's scroll content; positions are stored in **unit space** (0…1 of the content area) so they survive rotation. Drag-to-move copies the **Phase 28 flip-suppression contract verbatim**: a `@GestureState` bool mirrored onto a NEW `PageFlipController.annotationDragActive` flag (separate from `stickyDragActive` so the sticky's own resets can never clear an annotation drag), with `.onChange` mirror + `.onDisappear` safety net.

**Tech Stack:** SwiftUI gestures (`LongPressGesture.sequenced(before: DragGesture)`, `@GestureState`), SwiftData, `@Observable`, XCTest, XcodeGen.

**User decision (2026-06-04):** Entry point = **long-press empty paper** (no toolbar button). Style set = color + bold only.

---

## The flip-suppression contract (DO NOT IMPROVISE — Phase 28 lesson)

From `AIStickyStack.swift` / `PageFlipController.swift` / `DayPageView.swift:50-53`:

1. The drag truth is a `@GestureState private var isDragging: Bool` set in `.updating` — SwiftUI guarantees it resets to `false` on gesture end, cancel, **or view teardown mid-drag**.
2. It is mirrored onto the shared controller via `.onChange(of: isDragging) { _, d in flipController?.annotationDragActive = d }` — never set the controller flag directly in `.onChanged`/`.onEnded` (a skipped `.onEnded` is exactly the Phase 28 swipe-lock bug).
3. `.onDisappear { flipController?.annotationDragActive = false }` as the final safety net.
4. The page-flip handler yields: `guard !controller.stickyDragActive, !controller.annotationDragActive else { return }`.

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `WeeklyPlanner/DesignSystem/InkColorToken.swift` | NEW | stable color tokens (ink/blue/red/green/pencil) → theme resolution |
| `WeeklyPlanner/Models/Annotation.swift` | NEW | `@Model`: dayKey, text, colorTokenRaw, isBold, unitX/unitY, timestamps + clamp helper |
| `WeeklyPlanner/Stores/AnnotationStore.swift` | NEW | `AnnotationStoring` + SwiftData impl + stub + `.annotationStoreDidChange` |
| `WeeklyPlanner/Stores/SwiftDataStack.swift` | MODIFY | register `Annotation.self` |
| `WeeklyPlanner/Stores/Environment+Stores.swift` | MODIFY | `@Entry var annotationStore` |
| app root (where `.environment(\.taskStore, …)` is injected) | MODIFY | inject production store |
| `WeeklyPlanner/Features/DayPage/PageFlipController.swift` | MODIFY | `var annotationDragActive = false` |
| `WeeklyPlanner/Features/DayPage/DayPageViewModel.swift` | MODIFY | `annotations` + add/commit/style/move/delete (loaded in `refresh()`) |
| `WeeklyPlanner/Features/DayPage/Annotations/TextStyleBar.swift` | NEW | swatches + bold + delete + done |
| `WeeklyPlanner/Features/DayPage/Annotations/AnnotationView.swift` | NEW | one annotation: display/edit/drag |
| `WeeklyPlanner/Features/DayPage/Annotations/AnnotationLayer.swift` | NEW | positions annotations in unit space |
| `WeeklyPlanner/Features/DayPage/DayPageView.swift` | MODIFY | overlay + size capture + creation gesture + flip guard |
| `WeeklyPlanner/Accessibility/AccessibilityIDs.swift` | MODIFY | annotation IDs |
| `WeeklyPlannerTests/Annotations/AnnotationStoreTests.swift` | NEW | round-trip incl. token + bold + units |
| `WeeklyPlannerTests/Annotations/AnnotationLayerTests.swift` | NEW | VM logic: add/clamp/commit/style/move/delete |
| `WeeklyPlannerUITests/AnnotationsUITests.swift` | NEW | place/style/persist + aborted-drag-no-lock |

**Position model (decided):** unit-space (0…1) relative to the Day page's scroll-content area; `.position` uses `unit × layerSize`. Annotations scroll with the paper content (paper metaphor: ink is on the page). Width/height changes (rotation) re-derive pixel positions from units.

**Canonical test command** (referenced as "the test command" below; pick the device from `xcrun simctl list devices available`):

```bash
xcodegen generate
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=<available iPhone, iOS 26.5>' \
  -only-testing:<filter> \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO
```

---

### Task 1: `InkColorToken` + `Annotation` model + `AnnotationStore`

**Files:**
- Create: `WeeklyPlanner/DesignSystem/InkColorToken.swift`
- Create: `WeeklyPlanner/Models/Annotation.swift`
- Create: `WeeklyPlanner/Stores/AnnotationStore.swift`
- Modify: `WeeklyPlanner/Stores/SwiftDataStack.swift`
- Test: `WeeklyPlannerTests/Annotations/AnnotationStoreTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class AnnotationStoreTests: XCTestCase {
    private var container: ModelContainer!
    private var store: SwiftDataAnnotationStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        store = SwiftDataAnnotationStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        store = nil
        container = nil
        try await super.tearDown()
    }

    func testRoundTripPreservesStyleAndPosition() async throws {
        let a = Annotation(dayKey: "0:5", text: "call mom",
                           colorToken: .red, isBold: true,
                           unitX: 0.62, unitY: 0.31)
        try await store.upsert(a)

        let fetched = try await store.annotations(dayKey: "0:5")
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.text, "call mom")
        XCTAssertEqual(fetched.first?.colorToken, .red)
        XCTAssertEqual(fetched.first?.isBold, true)
        XCTAssertEqual(fetched.first?.unitX ?? 0, 0.62, accuracy: 0.0001)
        XCTAssertEqual(fetched.first?.unitY ?? 0, 0.31, accuracy: 0.0001)
    }

    func testAnnotationsAreScopedToTheirDayKey() async throws {
        try await store.upsert(Annotation(dayKey: "0:5", text: "sat", colorToken: .ink, isBold: false, unitX: 0.5, unitY: 0.5))
        try await store.upsert(Annotation(dayKey: "0:4", text: "fri", colorToken: .ink, isBold: false, unitX: 0.5, unitY: 0.5))

        let saturday = try await store.annotations(dayKey: "0:5")
        XCTAssertEqual(saturday.map(\.text), ["sat"])
    }

    func testUpsertExistingUpdatesInPlace() async throws {
        let id = UUID()
        try await store.upsert(Annotation(id: id, dayKey: "0:5", text: "v1", colorToken: .ink, isBold: false, unitX: 0.5, unitY: 0.5))
        try await store.upsert(Annotation(id: id, dayKey: "0:5", text: "v2", colorToken: .green, isBold: true, unitX: 0.1, unitY: 0.9))

        let count = try container.mainContext.fetch(FetchDescriptor<Annotation>()).count
        XCTAssertEqual(count, 1, "Upsert should update, not insert a second row")
        let fetched = try await store.annotations(dayKey: "0:5").first
        XCTAssertEqual(fetched?.text, "v2")
        XCTAssertEqual(fetched?.colorToken, .green)
    }

    func testDeleteRemovesAnnotation() async throws {
        let a = Annotation(dayKey: "0:5", text: "bye", colorToken: .ink, isBold: false, unitX: 0.5, unitY: 0.5)
        try await store.upsert(a)
        try await store.delete(id: a.id)
        let remaining = try await store.annotations(dayKey: "0:5")
        XCTAssertTrue(remaining.isEmpty)
    }

    func testMutationsPostChangeNotification() async throws {
        let exp = expectation(forNotification: .annotationStoreDidChange, object: nil)
        try await store.upsert(Annotation(dayKey: "0:5", text: "ping", colorToken: .ink, isBold: false, unitX: 0.5, unitY: 0.5))
        await fulfillment(of: [exp], timeout: 1)
    }

    func testClampUnitBoundsToUnitSquare() {
        let clamped = Annotation.clampUnit(CGPoint(x: 1.4, y: -0.2))
        XCTAssertEqual(clamped.x, 1.0)
        XCTAssertEqual(clamped.y, 0.0)
    }

    func testDayKeyHelperMatchesAppScheme() {
        XCTAssertEqual(Annotation.key(weekOffset: 0, dayIdx: 5), "0:5")
        XCTAssertEqual(Annotation.key(weekOffset: -2, dayIdx: 0), "-2:0")
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: the test command with `-only-testing:WeeklyPlannerTests/AnnotationStoreTests`
Expected: compile failure — types don't exist.

- [ ] **Step 3: Implement**

`WeeklyPlanner/DesignSystem/InkColorToken.swift`:

```swift
import SwiftUI

/// Stable, theme-independent ink color identity for user-styled text
/// (Phase 34 annotations). Stored as the raw String; resolved against the
/// active `PaperTheme` at render time so annotations re-theme correctly.
enum InkColorToken: String, CaseIterable, Codable, Sendable {
    case ink
    case blue
    case red
    case green
    case pencil

    func resolve(in theme: PaperTheme) -> Color {
        switch self {
        case .ink: theme.ink
        case .blue: theme.blueInk
        case .red: theme.redInk
        case .green: theme.greenInk
        case .pencil: theme.pencil
        }
    }
}
```

`WeeklyPlanner/Models/Annotation.swift`:

```swift
import Foundation
import SwiftData

/// Free-text written directly on a Day page (Phase 34). Position is
/// unit-space (0…1) relative to the page's annotation layer so it
/// survives rotation and size changes.
@Model
final class Annotation {
    @Attribute(.unique) var id: UUID
    /// `"<weekOffset>:<dayIdx>"` — same scheme as `AIInsight.dayKey`.
    var dayKey: String
    var text: String
    /// `InkColorToken` raw value (stable token, never a raw platform color).
    var colorTokenRaw: String
    var isBold: Bool
    var unitX: Double
    var unitY: Double
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(),
         dayKey: String,
         text: String,
         colorToken: InkColorToken = .ink,
         isBold: Bool = false,
         unitX: Double,
         unitY: Double,
         createdAt: Date = .init(),
         updatedAt: Date = .init())
    {
        self.id = id
        self.dayKey = dayKey
        self.text = text
        colorTokenRaw = colorToken.rawValue
        self.isBold = isBold
        self.unitX = unitX
        self.unitY = unitY
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension Annotation {
    var colorToken: InkColorToken {
        get { InkColorToken(rawValue: colorTokenRaw) ?? .ink }
        set { colorTokenRaw = newValue.rawValue }
    }

    static func key(weekOffset: Int, dayIdx: Int) -> String {
        "\(weekOffset):\(dayIdx)"
    }

    static func clampUnit(_ point: CGPoint) -> CGPoint {
        CGPoint(x: min(max(point.x, 0), 1), y: min(max(point.y, 0), 1))
    }
}
```

`WeeklyPlanner/Stores/AnnotationStore.swift`:

```swift
import Foundation
import SwiftData

@MainActor
protocol AnnotationStoring: AnyObject {
    /// Annotations for one day cell, oldest-first (stable z-order).
    func annotations(dayKey: String) async throws -> [Annotation]
    func upsert(_ annotation: Annotation) async throws
    func delete(id: UUID) async throws
}

@MainActor
final class SwiftDataAnnotationStore: AnnotationStoring {
    private let context: ModelContext
    private let changeSubject = NotificationCenter.default

    init(context: ModelContext) {
        self.context = context
    }

    func annotations(dayKey: String) async throws -> [Annotation] {
        try context.fetch(FetchDescriptor<Annotation>(
            predicate: #Predicate<Annotation> { $0.dayKey == dayKey },
            sortBy: [SortDescriptor(\Annotation.createdAt, order: .forward)]))
    }

    func upsert(_ annotation: Annotation) async throws {
        let id = annotation.id
        let existing = try context.fetch(
            FetchDescriptor<Annotation>(predicate: #Predicate<Annotation> { $0.id == id })).first

        if let existing {
            existing.dayKey = annotation.dayKey
            existing.text = annotation.text
            existing.colorTokenRaw = annotation.colorTokenRaw
            existing.isBold = annotation.isBold
            existing.unitX = annotation.unitX
            existing.unitY = annotation.unitY
            existing.updatedAt = .init()
        } else {
            context.insert(annotation)
        }
        try context.save()
        changeSubject.post(name: .annotationStoreDidChange, object: nil)
    }

    func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<Annotation>(predicate: #Predicate<Annotation> { $0.id == id })
        if let annotation = try context.fetch(descriptor).first {
            context.delete(annotation)
            try context.save()
            changeSubject.post(name: .annotationStoreDidChange, object: nil)
        }
    }
}

extension Notification.Name {
    static let annotationStoreDidChange = Notification.Name("WeeklyPlanner.AnnotationStore.didChange")
}
```

In `SwiftDataStack.allModels`, append `Annotation.self` (after `Note.self` if Phase 33 already landed, else after `UserSettings.self`).

- [ ] **Step 4: Run to verify pass**

Run: the test command with `-only-testing:WeeklyPlannerTests/AnnotationStoreTests`
Expected: PASS — 7 tests.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/DesignSystem/InkColorToken.swift WeeklyPlanner/Models/Annotation.swift WeeklyPlanner/Stores/AnnotationStore.swift WeeklyPlanner/Stores/SwiftDataStack.swift WeeklyPlannerTests/Annotations/
git commit -m "feat(annotations): Annotation model, InkColorToken, AnnotationStore (Phase 34)"
```

---

### Task 2: Stub + environment key + app wiring

**Files:**
- Modify: `WeeklyPlanner/Stores/AnnotationStore.swift` (append stub)
- Modify: `WeeklyPlanner/Stores/Environment+Stores.swift`
- Modify: app root (grep `environment(\.taskStore`)

- [ ] **Step 1: Append stub**

```swift
/// Inert default for previews and unwired subtrees.
@MainActor
final class StubAnnotationStore: AnnotationStoring {
    nonisolated init() {}

    func annotations(dayKey _: String) async throws -> [Annotation] { [] }
    func upsert(_: Annotation) async throws {}
    func delete(id _: UUID) async throws {}
}
```

- [ ] **Step 2: Environment key** (in `Environment+Stores.swift`)

```swift
    /// The active `AnnotationStoring` for this subtree. Defaults to `StubAnnotationStore`.
    @Entry var annotationStore: any AnnotationStoring = StubAnnotationStore()
```

- [ ] **Step 3: Production wiring** — at the app root next to the existing store injections, matching their construction style:

```swift
.environment(\.annotationStore, SwiftDataAnnotationStore(context: SwiftDataStack.production.mainContext))
```

- [ ] **Step 4: Compile check** — re-run `-only-testing:WeeklyPlannerTests/AnnotationStoreTests`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Stores/ WeeklyPlanner/WeeklyPlannerApp.swift
git commit -m "feat(annotations): stub store + environment key + production wiring (Phase 34)"
```

---

### Task 3: `DayPageViewModel` annotation logic

**Files:**
- Modify: `WeeklyPlanner/Features/DayPage/DayPageViewModel.swift`
- Test: `WeeklyPlannerTests/Annotations/AnnotationLayerTests.swift`

- [ ] **Step 1: Write the failing tests** (setup mirrors `DayPageViewModelTests` exactly — in-memory container + per-store instances + fixed clock; copy its `may16_2026` date helper)

```swift
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
```

- [ ] **Step 2: Run to verify failure**

Run: the test command with `-only-testing:WeeklyPlannerTests/AnnotationLayerTests`
Expected: compile failure — `DayPageViewModel` has no `annotationStore:` parameter / annotation API.

- [ ] **Step 3: Implement in `DayPageViewModel`**

3.1 — Add a defaulted init parameter (after `taskStore:`) and stored property, so existing call sites keep compiling:

```swift
    private let annotationStore: any AnnotationStoring
    var annotations: [Annotation] = []
```

```swift
         taskStore: any TaskStoring,
         annotationStore: any AnnotationStoring = StubAnnotationStore(),
```

and in the init body: `self.annotationStore = annotationStore`.

3.2 — In `refresh()`, after the tasks block, load annotations (best-effort, mirrors the VM's tolerance for secondary data):

```swift
        // Phase 34: free-text annotations for this day cell.
        annotations = (try? await annotationStore.annotations(dayKey: dayKey)) ?? []
```

with a computed property near the top of the class:

```swift
    /// `"<weekOffset>:<dayIdx>"` — shared dayKey scheme.
    var dayKey: String { Annotation.key(weekOffset: weekOffset, dayIdx: dayIdx) }
```

3.3 — Add the CRUD methods:

```swift
    // MARK: - Annotations (Phase 34)

    @discardableResult
    func addAnnotation(atUnit point: CGPoint) async -> Annotation? {
        let clamped = Annotation.clampUnit(point)
        let annotation = Annotation(dayKey: dayKey,
                                    text: "",
                                    colorToken: .ink,
                                    isBold: false,
                                    unitX: clamped.x,
                                    unitY: clamped.y)
        do {
            try await annotationStore.upsert(annotation)
            await refreshAnnotations()
            return annotations.first(where: { $0.id == annotation.id })
        } catch {
            return nil
        }
    }

    /// Commit edited text. Empty (trimmed) text deletes the annotation —
    /// an abandoned draft must not leave an invisible row behind.
    func commitAnnotationText(id: UUID, text: String) async {
        guard let annotation = annotations.first(where: { $0.id == id }) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            try? await annotationStore.delete(id: id)
        } else {
            annotation.text = trimmed
            try? await annotationStore.upsert(annotation)
        }
        await refreshAnnotations()
    }

    func setAnnotationStyle(id: UUID, colorToken: InkColorToken? = nil, isBold: Bool? = nil) async {
        guard let annotation = annotations.first(where: { $0.id == id }) else { return }
        if let colorToken { annotation.colorToken = colorToken }
        if let isBold { annotation.isBold = isBold }
        try? await annotationStore.upsert(annotation)
        await refreshAnnotations()
    }

    func moveAnnotation(id: UUID, toUnit point: CGPoint) async {
        guard let annotation = annotations.first(where: { $0.id == id }) else { return }
        let clamped = Annotation.clampUnit(point)
        annotation.unitX = clamped.x
        annotation.unitY = clamped.y
        try? await annotationStore.upsert(annotation)
        await refreshAnnotations()
    }

    func deleteAnnotation(id: UUID) async {
        try? await annotationStore.delete(id: id)
        await refreshAnnotations()
    }

    private func refreshAnnotations() async {
        annotations = (try? await annotationStore.annotations(dayKey: dayKey)) ?? []
    }
```

- [ ] **Step 4: Run to verify pass**

Run: the test command with `-only-testing:WeeklyPlannerTests/AnnotationLayerTests -only-testing:WeeklyPlannerTests/DayPageViewModelTests`
Expected: PASS — new tests green AND the existing `DayPageViewModelTests` untouched-green (defaulted param).

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Features/DayPage/DayPageViewModel.swift WeeklyPlannerTests/Annotations/AnnotationLayerTests.swift
git commit -m "feat(annotations): DayPageViewModel annotation CRUD with dayKey scoping + clamping (Phase 34)"
```

---

### Task 4: `PageFlipController.annotationDragActive` + flip-guard

**Files:**
- Modify: `WeeklyPlanner/Features/DayPage/PageFlipController.swift`
- Modify: `WeeklyPlanner/Features/DayPage/DayPageView.swift` (the `.horizontalSwipe` closure, ~line 50)
- Test: `WeeklyPlannerTests/Annotations/AnnotationFlipSuppressionTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import WeeklyPlanner

@MainActor
final class AnnotationFlipSuppressionTests: XCTestCase {
    func testAnnotationDragFlagDefaultsToFalseAndIsIndependentOfStickyFlag() {
        let controller = PageFlipController(current: PageCoordinate(week: 0, day: 0))
        XCTAssertFalse(controller.annotationDragActive)

        controller.annotationDragActive = true
        XCTAssertFalse(controller.stickyDragActive,
                       "Annotation drags must not piggyback on the sticky flag — independent suppressors")
        controller.annotationDragActive = false
        XCTAssertFalse(controller.annotationDragActive)
    }
}
```

⚠️ If `PageFlipController`'s init signature differs from `init(current:)`, match the one used in `DayPageView`'s `#Preview` (`PageFlipController(current: PageCoordinate(week: 0, day: 5))`).

- [ ] **Step 2: Run to verify failure** — `-only-testing:WeeklyPlannerTests/AnnotationFlipSuppressionTests`. Expected: compile failure (`annotationDragActive` missing).

- [ ] **Step 3: Implement**

In `PageFlipController.swift`, directly under `stickyDragActive`:

```swift
    /// Set (via `@GestureState` mirroring — see `AnnotationView`) while an
    /// annotation drag is genuinely in progress so the page-level
    /// `HorizontalSwipeGesture` yields. Phase 28 contract: never set this
    /// directly from `.onChanged`/`.onEnded`.
    var annotationDragActive = false
```

In `DayPageView.swift`, the existing guard becomes:

```swift
        .horizontalSwipe { direction in
            guard !controller.stickyDragActive, !controller.annotationDragActive else { return }
            controller.flipDay(direction: direction)
        }
```

- [ ] **Step 4: Run to verify pass** — same filter. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Features/DayPage/PageFlipController.swift WeeklyPlanner/Features/DayPage/DayPageView.swift WeeklyPlannerTests/Annotations/AnnotationFlipSuppressionTests.swift
git commit -m "feat(annotations): independent annotationDragActive flip-suppression flag (Phase 34)"
```

---

### Task 5: Accessibility IDs

**Files:**
- Modify: `WeeklyPlanner/Accessibility/AccessibilityIDs.swift`

- [ ] **Step 1: Add** (no behavior — compile-only step, verified by Task 6's build):

```swift
    // MARK: Annotations (Phase 34)
    static let annotationsLayer = "daypage.annotations.layer"
    static func annotationView(_ id: UUID) -> String { "daypage.annotation.\(id)" }
    /// Static (not per-id): only one annotation is ever in edit mode.
    static let annotationActiveEditor = "daypage.annotation.editor"
    static func annotationStyleColor(_ token: String) -> String { "annotation.style.color.\(token)" }
    static let annotationStyleBold = "annotation.style.bold"
    static let annotationStyleDelete = "annotation.style.delete"
    static let annotationStyleDone = "annotation.style.done"
```

- [ ] **Step 2: Commit**

```bash
git add WeeklyPlanner/Accessibility/AccessibilityIDs.swift
git commit -m "feat(annotations): accessibility identifiers (Phase 34)"
```

---

### Task 6: Views — `TextStyleBar`, `AnnotationView`, `AnnotationLayer`

**Files:**
- Create: `WeeklyPlanner/Features/DayPage/Annotations/TextStyleBar.swift`
- Create: `WeeklyPlanner/Features/DayPage/Annotations/AnnotationView.swift`
- Create: `WeeklyPlanner/Features/DayPage/Annotations/AnnotationLayer.swift`

Declarative views over Task 3's tested logic. Verification: compile + previews; behavior lands in Task 8's UI tests.

- [ ] **Step 1: `TextStyleBar.swift`**

```swift
import SwiftUI

/// Floating style controls shown while an annotation is being edited:
/// five ink swatches, bold toggle, delete, done.
struct TextStyleBar: View {
    let selectedColor: InkColorToken
    let isBold: Bool
    let onColor: (InkColorToken) -> Void
    let onBoldToggle: () -> Void
    let onDelete: () -> Void
    let onDone: () -> Void

    @Environment(\.paperTheme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            ForEach(InkColorToken.allCases, id: \.self) { token in
                Button { onColor(token) } label: {
                    Circle()
                        .fill(token.resolve(in: theme))
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .strokeBorder(theme.ink, lineWidth: 2)
                                .opacity(token == selectedColor ? 1 : 0)
                                .padding(-3)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(token.rawValue) ink")
                .accessibilityAddTraits(token == selectedColor ? [.isButton, .isSelected] : .isButton)
                .accessibilityIdentifier(AccessibilityIDs.annotationStyleColor(token.rawValue))
            }

            Rectangle().fill(theme.rule).frame(width: 0.5, height: 16)

            Button(action: onBoldToggle) {
                Text(verbatim: "B")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(isBold ? theme.ink : theme.ink3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Bold")
            .accessibilityAddTraits(isBold ? [.isButton, .isSelected] : .isButton)
            .accessibilityIdentifier(AccessibilityIDs.annotationStyleBold)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.redInk)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete annotation")
            .accessibilityIdentifier(AccessibilityIDs.annotationStyleDelete)

            Button(action: onDone) {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.blueInk)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Done editing")
            .accessibilityIdentifier(AccessibilityIDs.annotationStyleDone)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.creamHi)
                .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
        )
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(theme.rule, lineWidth: 0.5))
    }
}

#Preview("TextStyleBar · cream") {
    TextStyleBar(selectedColor: .red, isBold: true,
                 onColor: { _ in }, onBoldToggle: {}, onDelete: {}, onDone: {})
        .padding()
        .background(PaperTheme.cream.cream)
        .paperTheme(.cream)
}
```

- [ ] **Step 2: `AnnotationView.swift`** — the flip-suppression contract lives here; copy it faithfully:

```swift
import SwiftUI

/// One free-text annotation: handwriting text in display mode (tap to
/// edit, drag to move), a focused multiline field + `TextStyleBar` in
/// edit mode. Commit-on-blur; empty text deletes (via the VM).
struct AnnotationView: View {
    let annotation: Annotation
    let layerSize: CGSize
    @Binding var editingID: UUID?
    let viewModel: DayPageViewModel

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size
    @Environment(PageFlipController.self) private var flipController: PageFlipController?

    @State private var draft = ""
    @GestureState private var dragOffset: CGSize = .zero
    /// Gesture-state-backed "an annotation drag is in progress" truth.
    /// SwiftUI guarantees this resets on end/cancel/teardown; the
    /// `.onChange` below mirrors it onto the shared controller so the
    /// page-flip suppression can never strand `true` (Phase 28 contract).
    @GestureState private var isDragging: Bool = false
    @FocusState private var focused: Bool

    private var isEditing: Bool { editingID == annotation.id }

    var body: some View {
        Group {
            if isEditing { editor } else { display }
        }
        .offset(dragOffset)
        .onChange(of: isDragging) { _, dragging in
            flipController?.annotationDragActive = dragging
        }
        .onDisappear {
            // Final safety net: leaving the page mid-drag must never leave
            // navigation locked.
            flipController?.annotationDragActive = false
        }
    }

    private var display: some View {
        Text(annotation.text)
            .font(font.font(at: 16 * size.scale, weight: annotation.isBold ? .bold : .regular))
            .foregroundStyle(annotation.colorToken.resolve(in: theme))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 220, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                draft = annotation.text
                editingID = annotation.id
            }
            .highPriorityGesture(moveGesture)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Annotation: \(annotation.text)")
            .accessibilityHint("Double tap to edit.")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier(AccessibilityIDs.annotationView(annotation.id))
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .updating($dragOffset) { value, state, _ in
                state = value.translation
            }
            .updating($isDragging) { _, state, _ in
                state = true
            }
            .onEnded { value in
                guard layerSize.width > 0, layerSize.height > 0 else { return }
                let newUnit = CGPoint(
                    x: annotation.unitX + value.translation.width / layerSize.width,
                    y: annotation.unitY + value.translation.height / layerSize.height)
                Task { await viewModel.moveAnnotation(id: annotation.id, toUnit: newUnit) }
            }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextStyleBar(
                selectedColor: annotation.colorToken,
                isBold: annotation.isBold,
                onColor: { token in
                    Task { await viewModel.setAnnotationStyle(id: annotation.id, colorToken: token) }
                },
                onBoldToggle: {
                    Task { await viewModel.setAnnotationStyle(id: annotation.id, isBold: !annotation.isBold) }
                },
                onDelete: {
                    editingID = nil
                    Task { await viewModel.deleteAnnotation(id: annotation.id) }
                },
                onDone: { focused = false })

            TextField("Write…", text: $draft, axis: .vertical)
                .font(font.font(at: 16 * size.scale, weight: annotation.isBold ? .bold : .regular))
                .foregroundStyle(annotation.colorToken.resolve(in: theme))
                .tint(theme.blueInk)
                .textFieldStyle(.plain)
                .frame(width: 220, alignment: .leading)
                .focused($focused)
                .accessibilityLabel("Annotation text")
                .accessibilityIdentifier(AccessibilityIDs.annotationActiveEditor)
        }
        .task { focused = true }
        .onChange(of: focused) { _, isFocused in
            if !isFocused, isEditing {
                let text = draft
                editingID = nil
                Task { await viewModel.commitAnnotationText(id: annotation.id, text: text) }
            }
        }
    }
}
```

- [ ] **Step 3: `AnnotationLayer.swift`**

```swift
import SwiftUI

/// Overlay hosting all of a day's annotations, positioned in unit space.
/// Hit-testing: the ZStack has no background, so only the annotation
/// views themselves receive touches — empty paper stays interactive
/// (scroll, taps, the creation long-press) underneath.
struct AnnotationLayer: View {
    let viewModel: DayPageViewModel
    @Binding var editingID: UUID?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(viewModel.annotations, id: \.id) { annotation in
                    AnnotationView(annotation: annotation,
                                   layerSize: geo.size,
                                   editingID: $editingID,
                                   viewModel: viewModel)
                        .position(x: geo.size.width * annotation.unitX,
                                  y: geo.size.height * annotation.unitY)
                }
            }
            .accessibilityIdentifier(AccessibilityIDs.annotationsLayer)
        }
    }
}
```

- [ ] **Step 4: Compile check** — run `-only-testing:WeeklyPlannerTests/AnnotationLayerTests`. Expected: PASS (compiles; logic unchanged).

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Features/DayPage/Annotations/
git commit -m "feat(annotations): AnnotationLayer/AnnotationView/TextStyleBar with gesture-state flip suppression (Phase 34)"
```

---

### Task 7: Day-page integration — overlay, size capture, creation gesture

**Files:**
- Modify: `WeeklyPlanner/Features/DayPage/DayPageView.swift` (`DayPageContent`)

- [ ] **Step 1: Wire the store into the view model construction.** Where `DayPageContent` builds `DayPageViewModel(weekOffset:dayIdx:eventStore:…)` (~line 231), add `annotationStore: annotationStore,` after `taskStore:`, with the environment read at the top of `DayPageContent` alongside the other stores:

```swift
    @Environment(\.annotationStore) private var annotationStore
```

- [ ] **Step 2: Add state to `DayPageContent`:**

```swift
    @State private var annotationLayerSize: CGSize = .zero
    @State private var editingAnnotationID: UUID?
```

- [ ] **Step 3: Attach overlay + size capture + creation gesture.** The ScrollView content chain currently reads:

```swift
                    content(weekDay: weekDay, weekMeta: weekMeta)
                        .padding(…)
                        .overlay(alignment: .topTrailing) { stickyNoteOverlay }
                        .contentShape(Rectangle())
                        .onTapGesture { commitPendingTaskIfAny() }
```

Extend it to:

```swift
                    content(weekDay: weekDay, weekMeta: weekMeta)
                        .padding(…)                       // unchanged
                        .overlay(alignment: .topTrailing) { stickyNoteOverlay }
                        .overlay(alignment: .topLeading) {
                            if let viewModel {
                                AnnotationLayer(viewModel: viewModel,
                                                editingID: $editingAnnotationID)
                            }
                        }
                        .onGeometryChange(for: CGSize.self) { proxy in
                            proxy.size
                        } action: { newSize in
                            annotationLayerSize = newSize
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { commitPendingTaskIfAny() }
                        .simultaneousGesture(annotationCreationGesture)
```

(The overlay's `GeometryReader` fills the same bounds the gesture's `.local` coordinates are measured in, so units line up.)

- [ ] **Step 4: The creation gesture** (long-press → location via sequenced zero-distance drag):

```swift
    /// Long-press on empty paper creates an annotation at the press point.
    /// `.simultaneousGesture` keeps scrolling and row taps working; the
    /// sequenced zero-distance drag is the standard recipe for getting a
    /// location out of a long-press.
    private var annotationCreationGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.45)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .onEnded { value in
                guard case let .second(true, drag) = value, let drag,
                      annotationLayerSize.width > 0, annotationLayerSize.height > 0
                else { return }
                let unit = CGPoint(x: drag.startLocation.x / annotationLayerSize.width,
                                   y: drag.startLocation.y / annotationLayerSize.height)
                Task {
                    if let created = await viewModel?.addAnnotation(atUnit: unit) {
                        editingAnnotationID = created.id
                    }
                }
            }
    }
```

- [ ] **Step 5: Refresh on external change.** Next to the existing `.onReceive(… .taskStoreDidChange)` lines add:

```swift
        .onReceive(NotificationCenter.default.publisher(for: .annotationStoreDidChange)) { _ in
            Task { await viewModel?.refresh() }
        }
```

⚠️ This fires on the VM's own writes too — `refresh()` is already idempotent (same pattern as events/tasks). If it visibly fights the in-flight editor (focus loss while typing), guard it: `if editingAnnotationID == nil { … }`.

- [ ] **Step 6: Run the Day-page suites**

Run: the test command with `-only-testing:WeeklyPlannerTests/DayPageViewModelTests -only-testing:WeeklyPlannerTests/AnnotationLayerTests`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add WeeklyPlanner/Features/DayPage/DayPageView.swift
git commit -m "feat(annotations): day-page overlay, size capture, long-press creation gesture (Phase 34)"
```

---

### Task 8: UI tests — place/style/persist + aborted drag never locks navigation

**Files:**
- Create: `WeeklyPlannerUITests/AnnotationsUITests.swift`

- [ ] **Step 1: Write the UI tests** (IDs from `StickySwipeUITests` conventions; `-UITestSeedEmptyStore` keeps the paper empty so the long-press lands on blank space)

```swift
import XCTest

final class AnnotationsUITests: XCTestCase {
    private enum ID {
        static func dayWeekSegment(_ v: String) -> String { "topbar.dayweek.\(v)" }
        static func sideTab(_ n: Int) -> String { "daypage.sidetab.\(n)" }
        static let editor = "daypage.annotation.editor"
        static let styleDone = "annotation.style.done"
        static let styleBold = "annotation.style.bold"
        static let styleRed = "annotation.style.color.red"
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchOnEmptyDayPage() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestSeedEmptyStore"]
        app.launch()
        let calendarTab = app.buttons["tabbar.tab.calendar"]
        if calendarTab.waitForExistence(timeout: 3) { calendarTab.tap() }
        let daySeg = app.buttons[ID.dayWeekSegment("day")]
        if daySeg.waitForExistence(timeout: 3) { daySeg.tap() }
        return app
    }

    func testLongPressCreatesStyledAnnotationThatPersists() {
        let app = launchOnEmptyDayPage()

        // Long-press empty paper (lower-middle area, clear of header/rows).
        let paper = app.scrollViews.firstMatch
        XCTAssertTrue(paper.waitForExistence(timeout: 5))
        paper.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.55))
            .press(forDuration: 0.8)

        // Editor appears focused — type, style, commit.
        let editor = app.textFields[ID.editor]
        XCTAssertTrue(editor.waitForExistence(timeout: 4), "Annotation editor did not appear after long-press")
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 2)
        app.typeText("call mom")

        app.buttons[ID.styleRed].tap()
        app.buttons[ID.styleBold].tap()
        app.buttons[ID.styleDone].tap()

        let placed = app.staticTexts["call mom"]
        XCTAssertTrue(placed.waitForExistence(timeout: 4), "Committed annotation not rendered")

        // Relaunch — must persist on the same day.
        app.terminate()
        let relaunched = XCUIApplication()
        relaunched.launchArguments += ["-UITestSeedEmptyStore"]
        relaunched.launch()
        let after = relaunched.staticTexts["call mom"]
        XCTAssertTrue(after.waitForExistence(timeout: 6), "Annotation did not survive relaunch")

        // Cleanup: open editor, delete.
        after.tap()
        let delete = relaunched.buttons["annotation.style.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        delete.tap()
        XCTAssertTrue(after.waitForNonExistence(timeout: 4))
    }

    func testAbortedAnnotationDragDoesNotLockNavigation() {
        let app = launchOnEmptyDayPage()

        // Create a quick annotation.
        let paper = app.scrollViews.firstMatch
        XCTAssertTrue(paper.waitForExistence(timeout: 5))
        paper.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.55))
            .press(forDuration: 0.8)
        let editor = app.textFields[ID.editor]
        XCTAssertTrue(editor.waitForExistence(timeout: 4))
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 2)
        app.typeText("drag me")
        app.buttons[ID.styleDone].tap()

        let annotation = app.staticTexts["drag me"]
        XCTAssertTrue(annotation.waitForExistence(timeout: 4))

        // Drag it a little and release — then navigation must still work
        // (Phase 28 contract: the gesture-state reset clears suppression).
        let start = annotation.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: 60, dy: 25))
        start.press(forDuration: 0.1, thenDragTo: end)

        let friday = app.buttons[ID.sideTab(4)]
        XCTAssertTrue(friday.waitForExistence(timeout: 3), "Friday side tab not found")
        friday.tap()
        XCTAssertTrue(friday.isHittable, "Day navigation unresponsive after annotation drag")

        // Cleanup.
        let monday = app.buttons[ID.sideTab(0)]
        _ = monday.waitForExistence(timeout: 2)
        // Return to the original day via side tab where the annotation lives is
        // not required for cleanup — find it wherever the current page is:
        if annotation.waitForExistence(timeout: 2) {
            annotation.tap()
            let delete = app.buttons["annotation.style.delete"]
            if delete.waitForExistence(timeout: 3) { delete.tap() }
        }
    }
}
```

⚠️ The cleanup tail of the second test is best-effort (the drag moved the annotation to another spot on the same day; navigating away then asserting hittability is the actual test). If `-UITestSeedEmptyStore` also wipes annotations on each launch (check how the flag is honored — grep `UITestSeedEmptyStore`), the cleanup blocks can be dropped entirely.

- [ ] **Step 2: Run**

Run: the test command with `-only-testing:WeeklyPlannerUITests/AnnotationsUITests`
Expected: PASS — 2 tests. If the long-press coordinate happens to hit a row on your simulator size, nudge `dy` (0.5–0.65 band is empty under seeded-empty store).

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlannerUITests/AnnotationsUITests.swift
git commit -m "test(annotations): UI place/style/persist + aborted-drag navigation safety (Phase 34)"
```

---

### Task 9: Full-suite verification (superpowers:verification-before-completion)

- [ ] **Step 1: FULL unit suite**

```bash
xcodegen generate
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=<available iPhone, iOS 26.5>' \
  -only-testing:WeeklyPlannerTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO
```

Expected: `** TEST SUCCEEDED **`, 0 failures.

- [ ] **Step 2: Gesture-regression UI suites** — the Phase 27/28 protections MUST stay green:

Same command with `-only-testing:WeeklyPlannerUITests/AnnotationsUITests -only-testing:WeeklyPlannerUITests/StickySwipeUITests -only-testing:WeeklyPlannerUITests/SmokeUITests`
Expected: PASS.

- [ ] **Step 3: Spec checklist sweep** — `docs/phases/phase-34-free-text-annotations.md`: long-press add ✓, live color+bold ✓, move/edit/delete ✓, theme+size respected (font/env-driven) ✓, per-day persistence ✓, no flip conflict (separate flag, gesture-state derived, onDisappear net) ✓, color stored as token ✓, position model = relative unit-space ✓, VoiceOver labels ✓.

- [ ] **Step 4: Screenshot** an annotated page (2 annotations, one red+bold) for the acceptance record.

- [ ] **Step 5: Report** — branch, files, test counts, any coordinate-tuning deviations.

---

## Self-review notes

- **Spec coverage:** model/store (T1–2), VM logic incl. dayKey scoping + clamp (T3), flip suppression (T4 + AnnotationView), style bar color+bold (T6), long-press entry + position model (T7), persistence + a11y (T1/T5/T6), UI tests incl. the Phase-28-style abort test (T8). Out of scope honored: no PencilKit, no week/month surfaces, color+bold only.
- **Type consistency:** `addAnnotation(atUnit:) -> Annotation?`, `commitAnnotationText(id:text:)`, `setAnnotationStyle(id:colorToken:isBold:)`, `moveAnnotation(id:toUnit:)`, `deleteAnnotation(id:)` identical across tests (T3) and views (T6–7). `Annotation.clampUnit`/`Annotation.key` defined T1, used T3.
- **Deliberate choices:** separate `annotationDragActive` flag (sticky's `.onDisappear`/count-reset must not clear annotation drags); unit-space positions on the scroll content (annotations scroll with the paper — the paper metaphor); `.simultaneousGesture` for creation so scroll/taps never break; static editor a11y ID (single concurrent editor).
- **Known intermediate states:** none — every task compiles standalone.
