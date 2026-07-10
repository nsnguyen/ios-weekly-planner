# Phase 42 — Event Sheet Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The add/edit event sheet gets a legible header ("Add New Event" / bigger Cancel/Save), loses the hairlines crossing the form rows, gains user-editable quick-add template chips and discoverable repeat presets (incl. "Every 2 weeks"), and loses the Ask-AI affordance entirely (suggestions #63, #67, #68, #69, #70, #71).

**Architecture:** Header/hairlines are view-only edits in `PaperEventSheet+Edit.swift` and the five `EditableFields` row files. Repeat presets are a pure `RecurrencePreset` enum mapped onto the existing `Recurrence` struct (interval support already exists). Quick-add chips move from the hardcoded `EventTemplate.curated` array to a SwiftData-backed `EventTemplateRecord` store (protocol + SwiftData impl, matching every other store in the app), seeded once from the curated list and managed via a small editor sheet. Ask-AI removal deletes the view-mode section, the view-model plumbing, and the generator — `IntelligenceService` itself is untouched.

**Tech Stack:** SwiftUI, SwiftData, XCTest, XcodeGen.

## Global Constraints

- iOS 26.0+, Swift 6 strict concurrency, SwiftUI only (no UIKit shells).
- XcodeGen is the source of truth: run `xcodegen generate` after adding/deleting files, before building.
- Canonical test command (device from `xcrun simctl list devices available`):

```bash
xcodegen generate
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=<available iPhone, iOS 26.5>' \
  -only-testing:<filter> \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO
```

- Lint: the repo has a large pre-existing swiftlint/swiftformat baseline — check only that YOUR changed files add no new violations; do not run per-file lint with excludes bypassed.
- `RepeatingEventUITests` drives Menu buttons **by label** ("Daily", "Delete event") — do not rename existing labels; new menu items are additive.
- Copy is exact: create-mode title **"Add New Event"**, edit-mode title **"Edit Event"**.

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `WeeklyPlanner/Features/EventDetail/PaperEventSheet+Edit.swift` | MODIFY | header hierarchy + copy |
| `WeeklyPlanner/Features/EventDetail/EditableFields/PaperDateTimeRow.swift` | MODIFY | drop bottom hairline |
| `WeeklyPlanner/Features/EventDetail/EditableFields/CategorySwatchRow.swift` | MODIFY | drop bottom hairline |
| `WeeklyPlanner/Features/EventDetail/EditableFields/LocationField.swift` | MODIFY | drop bottom hairline |
| `WeeklyPlanner/Features/EventDetail/EditableFields/NotesField.swift` | MODIFY | drop bottom hairline |
| `WeeklyPlanner/Features/EventDetail/EditableFields/RecurrenceRow.swift` | MODIFY | drop hairline; preset menu |
| `WeeklyPlanner/Models/RecurrencePreset.swift` | NEW | preset → `Recurrence` mapping |
| `WeeklyPlanner/Models/EventTemplateRecord.swift` | NEW | SwiftData model for chips |
| `WeeklyPlanner/Stores/EventTemplateStore.swift` | NEW | `EventTemplateStoring` protocol + SwiftData impl |
| `WeeklyPlanner/Models/EventTemplate.swift` | MODIFY | keep struct; `curated` becomes seed data |
| `WeeklyPlanner/Models/UserSettings.swift` | MODIFY | `eventTemplatesSeeded` flag |
| `WeeklyPlanner/Stores/SwiftDataStack.swift` | MODIFY | register `EventTemplateRecord` in schema |
| `WeeklyPlanner/Stores/Environment+Stores.swift` | MODIFY | `@Entry eventTemplateStore` + stub |
| `WeeklyPlanner/WeeklyPlannerApp.swift` | MODIFY | build store + one-time seed |
| `WeeklyPlanner/Navigation/AppShell.swift` | MODIFY | inject store into environment |
| `WeeklyPlanner/Features/EventDetail/EditableFields/TemplateChipsRow.swift` | MODIFY | read store; Edit chip |
| `WeeklyPlanner/Features/EventDetail/EditableFields/TemplateEditorSheet.swift` | NEW | add/delete chips UI |
| `WeeklyPlanner/Features/EventDetail/PaperEventSheet.swift` | MODIFY | remove Ask-AI section + wiring |
| `WeeklyPlanner/Features/EventDetail/EventDetailViewModel.swift` | MODIFY | remove suggestion plumbing |
| `WeeklyPlanner/Features/EventDetail/EventAISticky.swift` | DELETE | Ask-AI sticky view |
| `WeeklyPlanner/Features/EventDetail/EventAISuggestion.swift` | DELETE | canned suggestion table |
| `WeeklyPlanner/Intelligence/Tasks/EventSuggestionGenerator.swift` | DELETE | Ask-AI generator |
| `WeeklyPlanner/Accessibility/AccessibilityIDs.swift` | MODIFY | new ids for editor/chips |
| tests | NEW/MODIFY | see tasks |

---

### Task 1: Header hierarchy + "Add New Event" copy

**Files:**
- Modify: `WeeklyPlanner/Features/EventDetail/PaperEventSheet+Edit.swift` (the `header` var, ~lines 68–94)
- Modify: `WeeklyPlannerUITests/EventCreateFlowUITests.swift` (copy assertions)

**Interfaces:**
- Produces: header title a11y id `"paperEventSheet.title"`; copy "Add New Event" / "Edit Event". Save keeps `"paperEventSheet.save"`.

- [ ] **Step 1: Re-grep the anchors** (`grep -n "New event" WeeklyPlanner/ WeeklyPlannerUITests/ -r`) — note every place the old copy appears, including any UI test assertion.

- [ ] **Step 2: Edit the header.** In `PaperEventSheet+Edit.swift`, replace the three text elements inside `private var header`:

```swift
            Button(action: onCancel) {
                Text("Cancel")
                    .font(font.font(at: 17 * size.scale, weight: .regular))
                    .foregroundStyle(theme.ink2)
            }

            Spacer()

            Text(isCreate ? "Add New Event" : "Edit Event")
                .font(font.font(at: 19 * size.scale, weight: .semibold))
                .foregroundStyle(theme.ink)
                .lineLimit(1)
                .accessibilityIdentifier("paperEventSheet.title")

            Spacer()

            Button(action: onSave) {
                Text("Save")
                    .font(font.font(at: 17 * size.scale, weight: .bold))
                    .foregroundStyle(canSave ? theme.blueInk : theme.ink3)
            }
            .disabled(!canSave)
            .accessibilityIdentifier("paperEventSheet.save")
```

Keep the surrounding `HStack(spacing: 16)` and the existing header padding insets. Adapt the exact Button/label shape to what's already there (the current code may use `Button("Cancel", action: onCancel)` — only the font sizes/weights, title copy, `theme.ink` title color, and the new `.accessibilityIdentifier("paperEventSheet.title")` are the required changes).

- [ ] **Step 3: Update UI test copy.** In `EventCreateFlowUITests.swift`, replace any `"New event"` assertion with:

```swift
        XCTAssertTrue(app.staticTexts["Add New Event"].waitForExistence(timeout: 3),
                      "Create-mode sheet must be titled 'Add New Event'")
```

- [ ] **Step 4: Run** `-only-testing:WeeklyPlannerUITests/EventCreateFlowUITests`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Features/EventDetail/PaperEventSheet+Edit.swift WeeklyPlannerUITests/EventCreateFlowUITests.swift
git commit -m "feat(event-sheet): dominant header, 'Add New Event' copy (Phase 42 #70)"
```

---

### Task 2: Remove the hairlines crossing the form rows

**Files:**
- Modify: `WeeklyPlanner/Features/EventDetail/EditableFields/PaperDateTimeRow.swift` (~33–37), `CategorySwatchRow.swift` (~35–39), `RecurrenceRow.swift` (~44–46), `LocationField.swift` (~28–31), `NotesField.swift` (~53–56)

- [ ] **Step 1: Delete the overlay in all five files.** Each row carries the identical modifier — remove it wherever it appears in these five files (re-grep: `grep -rn "alignment: .bottom" WeeklyPlanner/Features/EventDetail/EditableFields/`):

```swift
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.ink3).frame(height: 0.5)
        }
```

If deleting the rule leaves rows visually merged, add breathing room instead of a line: bump the row's existing vertical padding by 2–4 pt (match siblings). Do NOT reintroduce any Rectangle/Divider.

- [ ] **Step 2: Compile check** — run `-only-testing:WeeklyPlannerTests/PaperEventSheetEditTests`. Expected: PASS (view-only change).

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Features/EventDetail/EditableFields/
git commit -m "fix(event-sheet): remove hairlines crossing Start/End/Category rows (Phase 42 #69)"
```

---

### Task 3: `RecurrencePreset` + preset menu in `RecurrenceRow`

**Files:**
- Create: `WeeklyPlanner/Models/RecurrencePreset.swift`
- Modify: `WeeklyPlanner/Features/EventDetail/EditableFields/RecurrenceRow.swift` (the frequency `Menu`, ~lines 20–33)
- Test: `WeeklyPlannerTests/Models/RecurrencePresetTests.swift` (NEW)

**Interfaces:**
- Consumes: `Recurrence(frequency:interval:end:)`, `RecurrenceFrequency` (`WeeklyPlanner/Models/Recurrence.swift`).
- Produces: `enum RecurrencePreset: CaseIterable` with `displayName: String`, `recurrence: Recurrence?`, `static func matching(_ recurrence: Recurrence?) -> RecurrencePreset?`.

- [ ] **Step 1: Write the failing test** (`WeeklyPlannerTests/Models/RecurrencePresetTests.swift`):

```swift
import XCTest
@testable import WeeklyPlanner

final class RecurrencePresetTests: XCTestCase {
    func testPresetOrderAndDisplayNames() {
        XCTAssertEqual(RecurrencePreset.allCases.map(\.displayName),
                       ["None", "Daily", "Weekly", "Every 2 weeks", "Monthly", "Yearly", "Custom…"])
    }

    func testPresetToRecurrenceMapping() {
        XCTAssertNil(RecurrencePreset.none.recurrence)
        XCTAssertEqual(RecurrencePreset.daily.recurrence?.frequency, .daily)
        XCTAssertEqual(RecurrencePreset.weekly.recurrence?.frequency, .weekly)
        XCTAssertEqual(RecurrencePreset.weekly.recurrence?.interval, 1)
        XCTAssertEqual(RecurrencePreset.everyTwoWeeks.recurrence?.frequency, .weekly)
        XCTAssertEqual(RecurrencePreset.everyTwoWeeks.recurrence?.interval, 2)
        XCTAssertEqual(RecurrencePreset.monthly.recurrence?.frequency, .monthly)
        XCTAssertEqual(RecurrencePreset.yearly.recurrence?.frequency, .yearly)
        // Custom seeds a starting rule the steppers then refine.
        XCTAssertEqual(RecurrencePreset.custom.recurrence?.frequency, .weekly)
    }

    func testMatchingRoundTrip() {
        XCTAssertEqual(RecurrencePreset.matching(nil), RecurrencePreset.none)
        XCTAssertEqual(RecurrencePreset.matching(Recurrence(frequency: .weekly, interval: 2)), .everyTwoWeeks)
        XCTAssertEqual(RecurrencePreset.matching(Recurrence(frequency: .daily)), .daily)
        // Off-preset combos surface as Custom.
        XCTAssertEqual(RecurrencePreset.matching(Recurrence(frequency: .weekly, interval: 3)), .custom)
        XCTAssertEqual(RecurrencePreset.matching(Recurrence(frequency: .monthly, interval: 2)), .custom)
    }
}
```

- [ ] **Step 2: Run to verify failure** — `-only-testing:WeeklyPlannerTests/RecurrencePresetTests`. Expected: compile failure (type missing).

- [ ] **Step 3: Implement** `WeeklyPlanner/Models/RecurrencePreset.swift`:

```swift
import Foundation

/// Discoverable repeat presets for the event sheet (Phase 42 #71).
/// Wraps the existing `Recurrence` model — `interval` support already
/// exists; presets only make it reachable without the steppers.
enum RecurrencePreset: CaseIterable, Equatable {
    case none
    case daily
    case weekly
    case everyTwoWeeks
    case monthly
    case yearly
    case custom

    var displayName: String {
        switch self {
        case .none: "None"
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .everyTwoWeeks: "Every 2 weeks"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        case .custom: "Custom…"
        }
    }

    /// The rule this preset stands for. `.custom` seeds weekly/1 as a
    /// starting point for the steppers.
    var recurrence: Recurrence? {
        switch self {
        case .none: nil
        case .daily: Recurrence(frequency: .daily)
        case .weekly: Recurrence(frequency: .weekly)
        case .everyTwoWeeks: Recurrence(frequency: .weekly, interval: 2)
        case .monthly: Recurrence(frequency: .monthly)
        case .yearly: Recurrence(frequency: .yearly)
        case .custom: Recurrence(frequency: .weekly)
        }
    }

    /// Which preset a stored rule corresponds to; off-preset combos → `.custom`.
    static func matching(_ recurrence: Recurrence?) -> RecurrencePreset {
        guard let recurrence else { return .none }
        switch (recurrence.frequency, recurrence.interval) {
        case (.daily, 1): return .daily
        case (.weekly, 1): return .weekly
        case (.weekly, 2): return .everyTwoWeeks
        case (.monthly, 1): return .monthly
        case (.yearly, 1): return .yearly
        default: return .custom
        }
    }
}
```

⚠️ `matching` returns non-optional here (`.none` covers nil); adjust the test's `RecurrencePreset.matching(nil)` expectation accordingly — the assertions above already treat it that way.

- [ ] **Step 4: Run to verify pass** — `-only-testing:WeeklyPlannerTests/RecurrencePresetTests`. Expected: PASS.

- [ ] **Step 5: Rewire the menu.** In `RecurrenceRow.swift`, replace the frequency `Menu`'s options ("None" + `RecurrenceFrequency.allCases`) with the presets:

```swift
            Menu {
                ForEach(RecurrencePreset.allCases, id: \.self) { preset in
                    Button {
                        recurrence = preset.recurrence
                    } label: {
                        if RecurrencePreset.matching(recurrence) == preset {
                            Label(preset.displayName, systemImage: "checkmark")
                        } else {
                            Text(preset.displayName)
                        }
                    }
                }
            } label: {
                // keep the row's existing label chrome; the visible value becomes:
                Text(RecurrencePreset.matching(recurrence).displayName)
            }
```

Keep the existing a11y id `AccessibilityIDs.eventRepeatMenu` on the Menu. Keep `intervalLine`/`endLine` exactly as they are — they already render whenever `recurrence != nil`, which is how "Custom…" (and any preset) exposes fine-tuning.

- [ ] **Step 6: Run** `-only-testing:WeeklyPlannerTests/RecurrenceComposerTests -only-testing:WeeklyPlannerTests/RecurrenceSummaryTests` then `-only-testing:WeeklyPlannerUITests/RepeatingEventUITests`. Expected: PASS ("Daily"/"Weekly" labels unchanged; new items additive).

- [ ] **Step 7: Commit**

```bash
git add WeeklyPlanner/Models/RecurrencePreset.swift WeeklyPlanner/Features/EventDetail/EditableFields/RecurrenceRow.swift WeeklyPlannerTests/Models/RecurrencePresetTests.swift
git commit -m "feat(event-sheet): repeat presets incl. 'Every 2 weeks' + Custom (Phase 42 #71)"
```

---

### Task 4: `EventTemplateRecord` model + `EventTemplateStoring` store

**Files:**
- Create: `WeeklyPlanner/Models/EventTemplateRecord.swift`
- Create: `WeeklyPlanner/Stores/EventTemplateStore.swift`
- Modify: `WeeklyPlanner/Stores/SwiftDataStack.swift` (register model in schema)
- Modify: `WeeklyPlanner/Models/UserSettings.swift` (seed flag)
- Test: `WeeklyPlannerTests/Stores/EventTemplateStoreTests.swift` (NEW)

**Interfaces:**
- Consumes: `EventTemplate` struct + `EventTemplate.curated` (`WeeklyPlanner/Models/EventTemplate.swift` — struct fields `id: String, title: String, category: Category, durationMinutes: Int, alertMinutes: Int?`; verify exact field names/types in the file and mirror them).
- Produces:
  - `@Model final class EventTemplateRecord` with `id: UUID`, `title: String`, `categoryRaw: String`, `durationMinutes: Int`, `alertMinutes: Int?`, `sortOrder: Int`, and `var asTemplate: EventTemplate`.
  - `protocol EventTemplateStoring: AnyObject { func templates() throws -> [EventTemplateRecord]; func add(title: String, category: Category, durationMinutes: Int) throws; func delete(id: UUID) throws; func seedIfNeeded(from: [EventTemplate], settings: any SettingsStoring) throws }`
  - Notification `Notification.Name.eventTemplateStoreDidChange` posted on mutation (mirror `AnnotationStore`'s `.annotationStoreDidChange` pattern).
  - `UserSettings.eventTemplatesSeeded: Bool = false`.

- [ ] **Step 1: Write the failing tests** (`WeeklyPlannerTests/Stores/EventTemplateStoreTests.swift`) — copy the in-memory-container setup pattern from `WeeklyPlannerTests/Stores/SettingsStoreTests.swift` (each store test in this repo builds a `ModelContainer` with `isStoredInMemoryOnly: true`):

```swift
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class EventTemplateStoreTests: XCTestCase {
    private var container: ModelContainer!
    private var store: SwiftDataEventTemplateStore!
    private var settings: SwiftDataSettingsStore!

    override func setUp() async throws {
        // Mirror SettingsStoreTests' container construction, including
        // EventTemplateRecord.self + UserSettings.self in the schema.
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: EventTemplateRecord.self, UserSettings.self,
            configurations: config
        )
        store = SwiftDataEventTemplateStore(context: ModelContext(container))
        settings = SwiftDataSettingsStore(context: ModelContext(container))
    }

    func testSeedIfNeededInsertsCuratedOnceOnly() throws {
        try store.seedIfNeeded(from: EventTemplate.curated, settings: settings)
        XCTAssertEqual(try store.templates().count, EventTemplate.curated.count)
        XCTAssertTrue(try settings.current().eventTemplatesSeeded)

        // Second call is a no-op even after the user empties the list.
        for record in try store.templates() { try store.delete(id: record.id) }
        try store.seedIfNeeded(from: EventTemplate.curated, settings: settings)
        XCTAssertEqual(try store.templates().count, 0, "Deleting all chips must be durable")
    }

    func testTemplatesSortedBySortOrder() throws {
        try store.seedIfNeeded(from: EventTemplate.curated, settings: settings)
        let titles = try store.templates().map(\.title)
        XCTAssertEqual(titles, EventTemplate.curated.map(\.title), "Seed preserves curated order")
    }

    func testAddAppendsAtEnd() throws {
        try store.seedIfNeeded(from: EventTemplate.curated, settings: settings)
        try store.add(title: "Swim", category: .personal, durationMinutes: 45)
        let all = try store.templates()
        XCTAssertEqual(all.last?.title, "Swim")
        XCTAssertEqual(all.last?.durationMinutes, 45)
    }

    func testDeleteRemovesRecord() throws {
        try store.seedIfNeeded(from: EventTemplate.curated, settings: settings)
        let first = try XCTUnwrap(try store.templates().first)
        try store.delete(id: first.id)
        XCTAssertFalse(try store.templates().contains { $0.id == first.id })
    }

    func testRecordConvertsToEventTemplate() throws {
        try store.add(title: "Swim", category: .personal, durationMinutes: 45)
        let template = try XCTUnwrap(try store.templates().first?.asTemplate)
        XCTAssertEqual(template.title, "Swim")
        XCTAssertEqual(template.durationMinutes, 45)
    }
}
```

⚠️ Adapt `Category` case names (`.personal` etc.) and `SwiftDataSettingsStore`'s init signature to the real code — read `Stores/SettingsStore.swift` first. Assertion INTENT is fixed.

- [ ] **Step 2: Run to verify failure** — `-only-testing:WeeklyPlannerTests/EventTemplateStoreTests`. Expected: compile failure.

- [ ] **Step 3: Implement.**

`WeeklyPlanner/Models/EventTemplateRecord.swift`:

```swift
import Foundation
import SwiftData

/// A user-editable quick-add chip for the create-event sheet (Phase 42 #68).
/// Replaces the hardcoded `EventTemplate.curated` array as the source of
/// truth; `EventTemplate` remains the value type the composer consumes.
@Model
final class EventTemplateRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var categoryRaw: String
    var durationMinutes: Int
    var alertMinutes: Int?
    var sortOrder: Int

    init(id: UUID = UUID(),
         title: String,
         categoryRaw: String,
         durationMinutes: Int,
         alertMinutes: Int? = nil,
         sortOrder: Int) {
        self.id = id
        self.title = title
        self.categoryRaw = categoryRaw
        self.durationMinutes = durationMinutes
        self.alertMinutes = alertMinutes
        self.sortOrder = sortOrder
    }
}

extension EventTemplateRecord {
    var category: Category {
        Category(rawValue: categoryRaw) ?? .personal
    }

    var asTemplate: EventTemplate {
        EventTemplate(id: id.uuidString,
                      title: title,
                      category: category,
                      durationMinutes: durationMinutes,
                      alertMinutes: alertMinutes)
    }
}
```

⚠️ Match `EventTemplate`'s real memberwise init and `Category`'s raw-value type exactly (read `Models/EventTemplate.swift` and the `Category` definition first; if `EventTemplate.id` is not a `String`, adapt `asTemplate`).

`WeeklyPlanner/Stores/EventTemplateStore.swift`:

```swift
import Foundation
import SwiftData

extension Notification.Name {
    static let eventTemplateStoreDidChange = Notification.Name("eventTemplateStoreDidChange")
}

@MainActor
protocol EventTemplateStoring: AnyObject {
    func templates() throws -> [EventTemplateRecord]
    func add(title: String, category: Category, durationMinutes: Int) throws
    func delete(id: UUID) throws
    func seedIfNeeded(from curated: [EventTemplate], settings: any SettingsStoring) throws
}

@MainActor
final class SwiftDataEventTemplateStore: EventTemplateStoring {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func templates() throws -> [EventTemplateRecord] {
        let descriptor = FetchDescriptor<EventTemplateRecord>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return try context.fetch(descriptor)
    }

    func add(title: String, category: Category, durationMinutes: Int) throws {
        let nextOrder = ((try? templates().last?.sortOrder) ?? -1) + 1
        context.insert(EventTemplateRecord(title: title,
                                           categoryRaw: category.rawValue,
                                           durationMinutes: durationMinutes,
                                           sortOrder: nextOrder))
        try context.save()
        NotificationCenter.default.post(name: .eventTemplateStoreDidChange, object: nil)
    }

    func delete(id: UUID) throws {
        guard let record = try templates().first(where: { $0.id == id }) else { return }
        context.delete(record)
        try context.save()
        NotificationCenter.default.post(name: .eventTemplateStoreDidChange, object: nil)
    }

    /// Seed curated defaults exactly once per install; an emptied list stays empty.
    func seedIfNeeded(from curated: [EventTemplate], settings: any SettingsStoring) throws {
        guard try !settings.current().eventTemplatesSeeded else { return }
        for (index, template) in curated.enumerated() {
            context.insert(EventTemplateRecord(title: template.title,
                                               categoryRaw: template.category.rawValue,
                                               durationMinutes: template.durationMinutes,
                                               alertMinutes: template.alertMinutes,
                                               sortOrder: index))
        }
        try context.save()
        try settings.update { $0.eventTemplatesSeeded = true }
        NotificationCenter.default.post(name: .eventTemplateStoreDidChange, object: nil)
    }
}
```

`WeeklyPlanner/Models/UserSettings.swift` — add stored property (property-level default = lightweight migration; keep placement next to the other Bools) and an `eventTemplatesSeeded: Bool = false` parameter in the init following the existing pattern:

```swift
    /// One-time seed guard for quick-add event templates (Phase 42 #68).
    /// Once true, an emptied template list is never re-seeded.
    var eventTemplatesSeeded: Bool = false
```

`WeeklyPlanner/Stores/SwiftDataStack.swift` — add `EventTemplateRecord.self,` to the schema's model list (next to `Streak.self` etc.).

- [ ] **Step 4: Run to verify pass** — `-only-testing:WeeklyPlannerTests/EventTemplateStoreTests -only-testing:WeeklyPlannerTests/SettingsStoreTests`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Models/EventTemplateRecord.swift WeeklyPlanner/Stores/EventTemplateStore.swift WeeklyPlanner/Stores/SwiftDataStack.swift WeeklyPlanner/Models/UserSettings.swift WeeklyPlannerTests/Stores/EventTemplateStoreTests.swift
git commit -m "feat(templates): SwiftData-backed editable quick-add templates + one-time seed (Phase 42 #68)"
```

---

### Task 5: Wire the store + chips read it + editor sheet

**Files:**
- Modify: `WeeklyPlanner/Stores/Environment+Stores.swift` (`@Entry`), `WeeklyPlanner/WeeklyPlannerApp.swift` (construct + seed), `WeeklyPlanner/Navigation/AppShell.swift` (inject)
- Modify: `WeeklyPlanner/Features/EventDetail/EditableFields/TemplateChipsRow.swift`
- Create: `WeeklyPlanner/Features/EventDetail/EditableFields/TemplateEditorSheet.swift`
- Modify: `WeeklyPlanner/Accessibility/AccessibilityIDs.swift`
- Test: `WeeklyPlannerUITests/TemplateEditorUITests.swift` (NEW)

**Interfaces:**
- Consumes: `EventTemplateStoring` from Task 4; `EventComposerState.apply(_ template: EventTemplate)` (`Models/EventTemplate.swift:29`).
- Produces: a11y ids `AccessibilityIDs.eventTemplatesEdit = "paperEventSheet.templates.edit"`, `templateEditorAdd = "templateEditor.add"`, `templateEditorTitleField = "templateEditor.title"`, `templateEditorDelete(_ id:) -> "templateEditor.delete.<uuid>"`.

- [ ] **Step 1: Environment + startup wiring.**

`Environment+Stores.swift` — next to the other `@Entry` store keys:

```swift
    @Entry var eventTemplateStore: (any EventTemplateStoring)?
```

`WeeklyPlannerApp.swift` — where the other stores are constructed (Phase 18 wiring), build and seed:

```swift
        let eventTemplateStore = SwiftDataEventTemplateStore(context: mainContext)
        try? eventTemplateStore.seedIfNeeded(from: EventTemplate.curated, settings: settingsStore)
```

(match the actual context/store variable names in that file), then pass it down however the other stores reach `AppShell` — inject via the same `.environment(\.eventTemplateStore, eventTemplateStore)` chain used for `\.settingsStore` (find it in `AppShell.swift` ~line 138 region).

- [ ] **Step 2: Chips read the store.** In `TemplateChipsRow.swift`, replace the `ForEach(EventTemplate.curated)` source with store-backed state plus a trailing Edit chip:

```swift
    @Environment(\.eventTemplateStore) private var templateStore
    @State private var records: [EventTemplateRecord] = []
    @State private var showEditor = false

    // inside the ScrollView's HStack:
            ForEach(records.map(\.asTemplate)) { template in
                // existing chip button body unchanged
            }

            Button {
                showEditor = true
            } label: {
                Image(systemName: "pencil")
                    .font(font.font(at: 14 * size.scale, weight: .regular))
                    // match existing chip Capsule chrome
            }
            .accessibilityLabel("Edit quick-add templates")
            .accessibilityIdentifier(AccessibilityIDs.eventTemplatesEdit)

    // on the row's outermost view:
        .task { reload() }
        .onReceive(NotificationCenter.default.publisher(for: .eventTemplateStoreDidChange)) { _ in
            reload()
        }
        .sheet(isPresented: $showEditor) { TemplateEditorSheet() }

    private func reload() {
        records = (try? templateStore?.templates()) ?? []
    }
```

Fallback for previews/tests: when `templateStore == nil`, seed `records` from `EventTemplate.curated` in `reload()` so existing previews and `EventTemplateTests` fixtures keep working.

- [ ] **Step 3: Editor sheet.** Create `TemplateEditorSheet.swift` — a compact paper-styled list (reuse the sheet chrome conventions from `PaperEventSheet`; a plain `List` inside a themed container is acceptable here since it's a utility sheet):

```swift
import SwiftUI

/// Add/delete quick-add event templates (Phase 42 #68).
struct TemplateEditorSheet: View {
    @Environment(\.eventTemplateStore) private var store
    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.dismiss) private var dismiss

    @State private var records: [EventTemplateRecord] = []
    @State private var newTitle = ""
    @State private var newCategory: Category = .personal
    @State private var newDuration = 60

    var body: some View {
        NavigationStack {
            List {
                Section("Your quick-add buttons") {
                    ForEach(records, id: \.id) { record in
                        HStack {
                            Text(record.title)
                            Spacer()
                            Text("\(record.durationMinutes) min").foregroundStyle(.secondary)
                            Button(role: .destructive) {
                                try? store?.delete(id: record.id)
                                reload()
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .accessibilityIdentifier(AccessibilityIDs.templateEditorDelete(record.id))
                        }
                    }
                }
                Section("Add new") {
                    TextField("Title (e.g. Swim)", text: $newTitle)
                        .accessibilityIdentifier(AccessibilityIDs.templateEditorTitleField)
                    Picker("Category", selection: $newCategory) {
                        ForEach(Category.allCases, id: \.self) {
                            Text(CategoryPalette.displayName($0))
                        }
                    }
                    Stepper("Duration: \(newDuration) min", value: $newDuration, in: 15...240, step: 15)
                    Button("Add") {
                        let title = newTitle.trimmingCharacters(in: .whitespaces)
                        guard !title.isEmpty else { return }
                        try? store?.add(title: title, category: newCategory, durationMinutes: newDuration)
                        newTitle = ""
                        reload()
                    }
                    .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier(AccessibilityIDs.templateEditorAdd)
                }
            }
            .navigationTitle("Quick-Add Buttons")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { reload() }
    }

    private func reload() {
        records = (try? store?.templates()) ?? []
    }
}
```

⚠️ Match `Category.allCases`/`CategoryPalette.displayName` real signatures. Add to `AccessibilityIDs.swift`:

```swift
    static let eventTemplatesEdit = "paperEventSheet.templates.edit"
    static let templateEditorAdd = "templateEditor.add"
    static let templateEditorTitleField = "templateEditor.title"
    static func templateEditorDelete(_ id: UUID) -> String { "templateEditor.delete.\(id.uuidString)" }
```

- [ ] **Step 4: Write the UI test** (`WeeklyPlannerUITests/TemplateEditorUITests.swift`):

```swift
import XCTest

final class TemplateEditorUITests: XCTestCase {
    func testAddAndDeleteCustomTemplateChip() {
        let app = XCUIApplication()
        app.launch()

        // Open the create sheet from the day page.
        let addRow = app.buttons["daypage.events.addRow"]
        XCTAssertTrue(addRow.waitForExistence(timeout: 5))
        addRow.tap()

        // Open the template editor.
        let editChip = app.buttons["paperEventSheet.templates.edit"]
        XCTAssertTrue(editChip.waitForExistence(timeout: 5))
        editChip.tap()

        // Add "Swim".
        let titleField = app.textFields["templateEditor.title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        titleField.typeText("Swim")
        app.buttons["templateEditor.add"].tap()
        app.buttons["Done"].tap()

        // The new chip is in the chips row.
        XCTAssertTrue(app.buttons["Swim"].waitForExistence(timeout: 3),
                      "Custom chip must appear in the quick-add row")

        // Clean up: delete it again so the suite stays idempotent.
        editChip.tap()
        let deleteButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'templateEditor.delete.'"))
        XCTAssertGreaterThan(deleteButtons.count, 0)
        deleteButtons.element(boundBy: deleteButtons.count - 1).tap()
        app.buttons["Done"].tap()
    }
}
```

⚠️ Chip buttons may be matched by the template a11y id (`paperEventSheet.template.<id>`) rather than label — if `app.buttons["Swim"]` misses, match by label predicate. The suite must leave the simulator state clean (delete what it adds).

- [ ] **Step 5: Run** `-only-testing:WeeklyPlannerUITests/TemplateEditorUITests -only-testing:WeeklyPlannerTests/EventTemplateTests`. Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add WeeklyPlanner/ WeeklyPlannerUITests/TemplateEditorUITests.swift
git commit -m "feat(templates): chips read the store; add/delete editor sheet (Phase 42 #68)"
```

---

### Task 6: Remove Ask AI from the event sheets

**Files:**
- Modify: `WeeklyPlanner/Features/EventDetail/PaperEventSheet.swift` (delete `showAISuggestion` ~:84, its `.task` reset ~:105, generator construction + `refreshAISuggestion()` calls ~:109–117, the `aiSuggestionSection` call in `bodyRows` ~:345, and the whole `aiSuggestionSection` func ~:357–384)
- Modify: `WeeklyPlanner/Features/EventDetail/EventDetailViewModel.swift` (delete `suggestionGenerator` init param ~:59, `liveSuggestion` ~:41–46, `aiSuggestion` ~:219, `refreshAISuggestion()` ~:237)
- Delete: `WeeklyPlanner/Features/EventDetail/EventAISticky.swift`, `WeeklyPlanner/Features/EventDetail/EventAISuggestion.swift`, `WeeklyPlanner/Intelligence/Tasks/EventSuggestionGenerator.swift`
- Delete: `WeeklyPlannerTests/Intelligence/Tasks/EventSuggestionGeneratorTests.swift`
- Modify: `WeeklyPlannerTests/EventDetail/EventDetailViewModelTests.swift` (drop suggestion-related tests/fixtures)

- [ ] **Step 1: Sweep first.** `grep -rn "aiSuggestion\|EventAISticky\|EventAISuggestion\|EventSuggestionGenerator\|askAI" WeeklyPlanner/ WeeklyPlannerTests/ WeeklyPlannerUITests/` — the list above is the 2026-07-07 inventory; fix anything new the grep finds.

- [ ] **Step 2: Delete + edit per the file list.** Line numbers are anchors, not gospel — delete by symbol name. `IntelligenceService`, `PlannerLanguageModel`, and `StubIntelligenceService` stay (Ask-the-Planner + sticky notes use them).

- [ ] **Step 3: Regenerate + full unit suite.**

```bash
xcodegen generate
```

Run the test command with `-only-testing:WeeklyPlannerTests`. Expected: `** TEST SUCCEEDED **` after the test-file edits.

- [ ] **Step 4: Grep proof** (acceptance criterion): the Step-1 grep returns zero hits in `WeeklyPlanner/`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(event-sheet): remove Ask AI from event sheets (Phase 42 #63 #67)"
```

---

### Task 7: Full verification (superpowers:verification-before-completion)

- [ ] **Step 1: Full unit suite** — test command with `-only-testing:WeeklyPlannerTests`. Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 2: UI suites** — `-only-testing:WeeklyPlannerUITests/EventCreateFlowUITests -only-testing:WeeklyPlannerUITests/RepeatingEventUITests -only-testing:WeeklyPlannerUITests/TemplateEditorUITests -only-testing:WeeklyPlannerUITests/SmokeUITests`. Expected: all PASS.

- [ ] **Step 3: Manual smoke (signed build — see `tooling-run-app-needs-signing`: omit `CODE_SIGNING_ALLOWED=NO`, set `ENABLE_DEBUG_DYLIB=NO` to run the app):** open add-event → header reads "Add New Event" and is visibly larger than field rows; no hairlines across Starts/Ends/Category; chips show + Edit works; Repeat menu shows "Every 2 weeks" and "Custom…"; tap an existing event → no "Ask AI" anywhere.

- [ ] **Step 4: Phase-doc checklist sweep** — tick every box in `docs/phases/phase-42-event-sheet-overhaul.md`.

- [ ] **Step 5: Report** — branch, diffstat, deviations.

---

## Self-review notes

- **Spec coverage:** #70 (T1), #69 (T2), #71 (T3), #68 (T4+T5), #63/#67 (T6).
- **Type consistency:** `EventTemplateStoring.templates()/add/delete/seedIfNeeded` identical T4→T5; `RecurrencePreset.matching` non-optional everywhere; a11y id strings match between `AccessibilityIDs` additions and both UI tests.
- **Known adaptation points (all flagged inline):** `EventTemplate`/`Category` exact field names, `SwiftDataSettingsStore` init, chip button matching in the UI test, current header Button shape.
- **Deliberate choices:** seed-once flag on `UserSettings` (empty list durable); presets wrap — not replace — the existing `Recurrence` steppers; Ask-AI removal keeps the shared Intelligence layer intact.
