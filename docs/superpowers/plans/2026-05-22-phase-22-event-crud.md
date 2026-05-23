# Phase 22 — Manual Event CRUD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user create new events on the Day/Week pages via a floating ink "+" button, and edit existing events' title / start / end / category / location through the same `PaperEventSheet`. Save round-trips through `EventKitMirroringEventStore` so changes land in real iOS Calendar.

**Architecture:** A new `EventComposerState` `@Observable` carries the editable draft. `PaperEventSheet` gains a `SheetMode = .view | .edit(UUID) | .create(at: Date)` and dispatches to either the existing read-only rows or new editable atoms (`InkTextField`, `PaperDateTimeRow`, `CategorySwatchRow`, `LocationField`). A `FloatingInkButton` mounted at the `AppShell` level opens the sheet in `.create` mode. Save → `EventStore.upsert(...)` → existing EventKit mirror + notification reschedule fires for free.

**Tech Stack:** Swift 6, SwiftUI (iOS 26+), SwiftData, `@Observable`, `@Bindable`, `EventKitMirroringEventStore` (Phase 04), `NotificationReschedulingObserver` (Phase 19), `AccessibilityModifiers` (Phase 21).

**Spec:** `docs/phases/phase-22-event-crud.md` · **Branch:** `milestone-j-completeness` (already created, committed `b012ded`).

---

## File Structure

### New files

| Path | Responsibility |
|------|----------------|
| `WeeklyPlanner/Features/EventDetail/EventComposerState.swift` | `@Observable` draft state + validation + `build()` |
| `WeeklyPlanner/Features/EventDetail/EditableFields/InkTextField.swift` | Handwriting-styled `TextField` atom (also used by Phase 23) |
| `WeeklyPlanner/Features/EventDetail/EditableFields/PaperDateTimeRow.swift` | Date+time picker styled to match handwriting |
| `WeeklyPlanner/Features/EventDetail/EditableFields/CategorySwatchRow.swift` | 4-color ink swatch picker |
| `WeeklyPlanner/Features/EventDetail/EditableFields/LocationField.swift` | Location text field with pin glyph |
| `WeeklyPlanner/Features/EventDetail/PaperEventSheet+Edit.swift` | Editable cardContent variant for `.edit`/`.create` modes |
| `WeeklyPlanner/Features/DayPage/FloatingInkButton.swift` | Bottom-right ink "+" FAB with long-press menu |
| `WeeklyPlannerTests/EventDetail/EventComposerStateTests.swift` | Unit tests for composer state machine |
| `WeeklyPlannerTests/EventDetail/PaperEventSheetEditTests.swift` | Sheet behavior tests |
| `WeeklyPlannerUITests/EventCreateFlowUITests.swift` | End-to-end create-event test |

### Modified files

| Path | Why |
|------|-----|
| `WeeklyPlanner/Features/EventDetail/PaperEventSheet.swift` | Accept `SheetMode`, dispatch to editable variant, replace close-X with Save/Cancel in editable modes, discard-confirm |
| `WeeklyPlanner/Features/EventDetail/EventDetailViewModel.swift` | `composer` property, `save()`, `cancel()` |
| `WeeklyPlanner/Navigation/AppShell.swift` | Mount `FloatingInkButton`, expose `\.isAnySheetOpen` env, drive `creatingEvent` state |
| `WeeklyPlanner/Features/DayPage/DayPageView.swift` | Honor `creatingEvent` env to open sheet in `.create(at: focusedDate)` |

---

## Conventions for this plan

- Tests run via:
  ```bash
  xcodebuild test \
    -project WeeklyPlanner.xcodeproj \
    -scheme WeeklyPlanner \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
    -only-testing:WeeklyPlannerTests/<ClassName>/<methodName> \
    CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -30
  ```
- All `@Model` / `@Observable` / view code lives on `@MainActor`.
- After each task: `xcodegen generate` is **not** required unless you add a file outside the existing source roots — XcodeGen picks up new `.swift` files under `WeeklyPlanner/` automatically on the next build.
- Each task ends with `git add <files> && git commit -m "feat(phase-22): ..."` on `milestone-j-completeness`.

---

## Task 1: `EventComposerState` — draft state + validation

**Files:**
- Create: `WeeklyPlanner/Features/EventDetail/EventComposerState.swift`
- Test: `WeeklyPlannerTests/EventDetail/EventComposerStateTests.swift`

**Why:** Foundation for Tasks 2-7. Independent of UI so we can TDD it first.

- [ ] **Step 1: Write the failing tests**

Create `WeeklyPlannerTests/EventDetail/EventComposerStateTests.swift`:

```swift
import Foundation
import XCTest
@testable import WeeklyPlanner

@MainActor
final class EventComposerStateTests: XCTestCase {
    func testEmptyDefaults_startNextHour_endPlusOne() {
        let now = Date(timeIntervalSince1970: 1_780_000_000) // 2026-06-04 19:13:20 UTC
        let calendar = WeekMath.mondayCalendar()
        let state = EventComposerState.empty(at: now, calendar: calendar)

        XCTAssertEqual(state.title, "")
        XCTAssertEqual(state.category, .personal)
        XCTAssertTrue(state.end > state.start)
        XCTAssertEqual(state.end.timeIntervalSince(state.start), 3600, accuracy: 0.5)

        // start should be the next hour boundary after `now`.
        let components = calendar.dateComponents([.minute, .second], from: state.start)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)
    }

    func testFromEvent_roundTrips() {
        let start = Date(timeIntervalSince1970: 1_780_000_000)
        let end = start.addingTimeInterval(7200)
        let event = Event(title: "Standup",
                          start: start,
                          end: end,
                          location: "HQ",
                          category: .work,
                          reminders: [.timeBefore(minutes: 30)])
        let state = EventComposerState.from(event)
        XCTAssertEqual(state.title, "Standup")
        XCTAssertEqual(state.start, start)
        XCTAssertEqual(state.end, end)
        XCTAssertEqual(state.location, "HQ")
        XCTAssertEqual(state.category, .work)
        XCTAssertTrue(state.alertOn)
        XCTAssertEqual(state.alertMinutes, 30)
    }

    func testCanSave_falseWhenTitleEmpty() {
        let state = EventComposerState.empty(at: Date(), calendar: .current)
        XCTAssertFalse(state.canSave)
        state.title = "   "
        XCTAssertFalse(state.canSave)
        state.title = "Lunch"
        XCTAssertTrue(state.canSave)
    }

    func testCanSave_falseWhenEndBeforeStart() {
        let state = EventComposerState.empty(at: Date(), calendar: .current)
        state.title = "Lunch"
        state.end = state.start.addingTimeInterval(-60)
        XCTAssertFalse(state.canSave)
    }

    func testBuild_setsSourceManual() {
        let state = EventComposerState.empty(at: Date(), calendar: .current)
        state.title = "Lunch"
        let event = state.build()
        XCTAssertEqual(event.title, "Lunch")
        XCTAssertEqual(event.source, .manual)
        XCTAssertEqual(event.attendeesCount, 0)
        XCTAssertNil(event.location)
    }

    func testBuild_preservesProvidedID() {
        let state = EventComposerState.empty(at: Date(), calendar: .current)
        state.title = "Lunch"
        let id = UUID()
        let event = state.build(id: id)
        XCTAssertEqual(event.id, id)
    }

    func testIsDirty_detectsTitleChange() {
        let baseline = EventComposerState.empty(at: Date(), calendar: .current)
        baseline.title = "Lunch"
        let current = EventComposerState.empty(at: baseline.start, calendar: .current)
        current.title = "Lunch"
        XCTAssertFalse(current.isDirty(against: baseline))
        current.title = "Dinner"
        XCTAssertTrue(current.isDirty(against: baseline))
    }
}
```

- [ ] **Step 2: Run tests — verify they fail with "Cannot find 'EventComposerState'"**

```bash
xcodebuild test \
  -project WeeklyPlanner.xcodeproj \
  -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/EventComposerStateTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -30
```
Expected: BUILD FAILED, "Cannot find 'EventComposerState' in scope".

- [ ] **Step 3: Create `EventComposerState`**

Create `WeeklyPlanner/Features/EventDetail/EventComposerState.swift`:

```swift
import Foundation
import Observation

/// Editable draft for a new or existing `Event`. Carries the visible
/// composer fields, validation predicates, and helpers to round-trip
/// to/from `Event`.
///
/// Held by `EventDetailViewModel` while the sheet is in `.edit` or
/// `.create` mode; nil in `.view` mode. The view binds to fields via
/// `@Bindable` so `TextField` / `DatePicker` two-way bindings work.
@MainActor
@Observable
final class EventComposerState {
    var title: String
    var start: Date
    var end: Date
    var category: Category
    var location: String
    var alertOn: Bool
    var alertMinutes: Int
    var locationAlertOn: Bool

    init(title: String,
         start: Date,
         end: Date,
         category: Category,
         location: String,
         alertOn: Bool,
         alertMinutes: Int,
         locationAlertOn: Bool)
    {
        self.title = title
        self.start = start
        self.end = end
        self.category = category
        self.location = location
        self.alertOn = alertOn
        self.alertMinutes = alertMinutes
        self.locationAlertOn = locationAlertOn
    }

    /// `start` snapped to the next hour boundary after `date`; `end` =
    /// `start + 1h`; everything else empty/default.
    static func empty(at date: Date, calendar: Calendar) -> EventComposerState {
        let nextHour = calendar.nextDate(after: date,
                                          matching: DateComponents(minute: 0, second: 0),
                                          matchingPolicy: .nextTime) ?? date.addingTimeInterval(3600)
        return EventComposerState(title: "",
                                  start: nextHour,
                                  end: nextHour.addingTimeInterval(3600),
                                  category: .personal,
                                  location: "",
                                  alertOn: false,
                                  alertMinutes: 15,
                                  locationAlertOn: false)
    }

    /// Hydrate from an existing `Event`. The composer reads the time-before
    /// minutes off the first `.timeBefore` reminder, mirroring the same
    /// logic `EventDetailViewModel.load()` uses.
    static func from(_ event: Event) -> EventComposerState {
        var alertOn = false
        var alertMinutes = 15
        for reminder in event.reminders {
            if case let .timeBefore(minutes) = reminder {
                alertOn = true
                alertMinutes = minutes
                break
            }
        }
        let locationAlertOn = event.reminders.contains {
            if case .onArrive = $0 { true } else { false }
        }
        return EventComposerState(title: event.title,
                                  start: event.start,
                                  end: event.end,
                                  category: event.category,
                                  location: event.location ?? "",
                                  alertOn: alertOn,
                                  alertMinutes: alertMinutes,
                                  locationAlertOn: locationAlertOn)
    }

    var titleIsValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var timesAreValid: Bool { end > start }

    var canSave: Bool { titleIsValid && timesAreValid }

    /// Snapshot used by `isDirty(against:)`. Field-by-field comparison;
    /// we don't compare object identity.
    func isDirty(against other: EventComposerState) -> Bool {
        title != other.title
            || start != other.start
            || end != other.end
            || category != other.category
            || location != other.location
            || alertOn != other.alertOn
            || alertMinutes != other.alertMinutes
            || locationAlertOn != other.locationAlertOn
    }

    /// Build a fresh `Event` from the current draft. Caller supplies the
    /// ID (defaults to a new UUID for `.create`; pass the existing event's
    /// ID for `.edit`).
    func build(id: UUID = UUID()) -> Event {
        var reminders: [Reminder] = []
        if alertOn {
            reminders.append(.timeBefore(minutes: alertMinutes))
        }
        // Note: `.onArrive` reminders are NOT built here. They require a
        // geocoded coordinate and live on `EventDetailViewModel.toggleLocationAlert`.
        // Composer-driven creates skip the location alert at first save;
        // the user can flip it on after the event exists.
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        return Event(id: id,
                     title: trimmedTitle,
                     start: start,
                     end: end,
                     location: trimmedLocation.isEmpty ? nil : trimmedLocation,
                     category: category,
                     source: .manual,
                     reminders: reminders)
    }
}
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
xcodebuild test \
  -project WeeklyPlanner.xcodeproj \
  -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/EventComposerStateTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -30
```
Expected: TEST SUCCEEDED, 7 tests passed.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Features/EventDetail/EventComposerState.swift \
       WeeklyPlannerTests/EventDetail/EventComposerStateTests.swift
git commit -m "feat(phase-22): EventComposerState — draft + validation + round-trip

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: `InkTextField` atom

**Files:**
- Create: `WeeklyPlanner/Features/EventDetail/EditableFields/InkTextField.swift`

**Why:** Handwriting-styled `TextField` reused by Tasks 4, 5, and Phase 23. No standalone unit test — visual atom; covered by `PaperEventSheetEditTests` and the UITest later.

- [ ] **Step 1: Create the file**

Create `WeeklyPlanner/Features/EventDetail/EditableFields/InkTextField.swift`:

```swift
import SwiftUI

/// Handwriting-styled `TextField` atom used by every editable field in
/// the event composer (Phase 22) and the task composer (Phase 23). No
/// border, ink-blue caret, italic placeholder in `theme.ink2`, blue
/// wavy underline beneath the baseline when focused.
///
/// Two preset sizes:
///   - `.title` — 22pt, used for the event title in the composer header.
///   - `.body` — 17pt, used for body fields (location, task title, …).
struct InkTextField: View {
    enum Variant { case title, body }

    @Binding var text: String
    let placeholder: String
    let variant: Variant

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    @FocusState private var focused: Bool

    init(_ placeholder: String,
         text: Binding<String>,
         variant: Variant = .body)
    {
        self.placeholder = placeholder
        self._text = text
        self.variant = variant
    }

    var body: some View {
        let basePoint: CGFloat = variant == .title ? 22 : 17
        let scaledPoint = basePoint * size.scale
        let weight: Font.Weight = variant == .title ? .bold : .regular

        return TextField(
            "",
            text: $text,
            prompt: Text(placeholder)
                .font(font.font(at: scaledPoint, weight: weight))
                .foregroundStyle(theme.ink2)
        )
        .font(font.font(at: scaledPoint, weight: weight))
        .foregroundStyle(theme.ink)
        .tint(theme.blueInk)
        .textFieldStyle(.plain)
        .focused($focused)
        .overlay(alignment: .bottom) {
            if focused {
                WavyUnderline(color: theme.blueInk.opacity(0.6))
                    .frame(height: 2)
                    .offset(y: 4)
                    .allowsHitTesting(false)
            }
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
xcodebuild build \
  -project WeeklyPlanner.xcodeproj \
  -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -10
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Features/EventDetail/EditableFields/InkTextField.swift
git commit -m "feat(phase-22): InkTextField atom — handwriting TextField with focus underline

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: `PaperDateTimeRow` atom

**Files:**
- Create: `WeeklyPlanner/Features/EventDetail/EditableFields/PaperDateTimeRow.swift`

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

/// One row of the editable event composer: handwriting label on the
/// leading edge, compact date+time picker on the trailing. Used twice
/// per composer — once for `start`, once for `end`.
///
/// The label flips to `theme.redInk` when `invalidHint == true` so the
/// "end before start" condition is visible without a separate banner.
struct PaperDateTimeRow: View {
    let label: String
    @Binding var date: Date
    var invalidHint: Bool = false

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(font.font(at: 15 * size.scale, weight: .regular))
                .foregroundStyle(invalidHint ? theme.redInk : theme.ink2)
                .frame(width: 72, alignment: .leading)

            DatePicker("",
                       selection: $date,
                       displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(theme.blueInk)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.ink3)
                .frame(height: 0.5)
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
xcodebuild build \
  -project WeeklyPlanner.xcodeproj \
  -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -10
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Features/EventDetail/EditableFields/PaperDateTimeRow.swift
git commit -m "feat(phase-22): PaperDateTimeRow atom — compact date+time picker with paper chrome

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: `CategorySwatchRow` atom

**Files:**
- Create: `WeeklyPlanner/Features/EventDetail/EditableFields/CategorySwatchRow.swift`

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

/// Editable category picker: four ink dots with the selected swatch
/// drawing a 1.5pt ink ring around it. The four dots correspond to the
/// `Category` cases that appear in the mocks; we expose all six on the
/// underlying enum but only display the four "primary" categories here.
///
/// Tapping a dot calls the binding setter. No mid-state — selection
/// commits immediately.
struct CategorySwatchRow: View {
    @Binding var selection: Category

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    private static let displayed: [Category] = [.personal, .work, .health, .family]

    var body: some View {
        HStack(spacing: 14) {
            Text("Category")
                .font(font.font(at: 15 * size.scale, weight: .regular))
                .foregroundStyle(theme.ink2)
                .frame(width: 72, alignment: .leading)

            HStack(spacing: 14) {
                ForEach(Self.displayed, id: \.self) { category in
                    swatch(for: category)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.ink3)
                .frame(height: 0.5)
        }
    }

    private func swatch(for category: Category) -> some View {
        let isSelected = selection == category
        return Button {
            selection = category
        } label: {
            ZStack {
                Circle()
                    .fill(CategoryPalette.dot(category))
                    .frame(width: 22, height: 22)

                if isSelected {
                    Circle()
                        .stroke(theme.ink, lineWidth: 1.5)
                        .frame(width: 30, height: 30)
                }
            }
            .contentShape(Rectangle().inset(by: -6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(CategoryPalette.displayName(category))
        .accessibilityValue(isSelected ? "Selected" : "")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -10
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Features/EventDetail/EditableFields/CategorySwatchRow.swift
git commit -m "feat(phase-22): CategorySwatchRow atom — 4-color ink swatch picker

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: `LocationField` atom

**Files:**
- Create: `WeeklyPlanner/Features/EventDetail/EditableFields/LocationField.swift`

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

/// Editable location row: leading `mappin.circle` glyph + handwriting
/// label, trailing `InkTextField` bound to the composer's location
/// string. Optional — empty location is valid.
struct LocationField: View {
    @Binding var text: String

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "mappin.circle")
                    .font(.system(size: 15))
                    .foregroundStyle(theme.ink3)
                Text("Location")
                    .font(font.font(at: 15 * size.scale, weight: .regular))
                    .foregroundStyle(theme.ink2)
            }
            .frame(width: 110, alignment: .leading)

            InkTextField("Add a place…", text: $text, variant: .body)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.ink3)
                .frame(height: 0.5)
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -10
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Features/EventDetail/EditableFields/LocationField.swift
git commit -m "feat(phase-22): LocationField atom — mappin glyph + InkTextField row

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Extend `EventDetailViewModel` with composer wiring

**Files:**
- Modify: `WeeklyPlanner/Features/EventDetail/EventDetailViewModel.swift`
- Test: `WeeklyPlannerTests/EventDetail/EventDetailViewModelTests.swift` (existing — append two tests)

- [ ] **Step 1: Append failing tests**

Open `WeeklyPlannerTests/EventDetail/EventDetailViewModelTests.swift` and add the following methods inside the class (anywhere — convention is alphabetical but the suite isn't strict):

```swift
func testSaveCommitsComposerDraft() async throws {
    let event = Event(title: "Old title",
                      start: Date(timeIntervalSince1970: 1_780_000_000),
                      end: Date(timeIntervalSince1970: 1_780_003_600),
                      category: .work)
    try await eventStore.upsert(event)

    let vm = EventDetailViewModel(eventID: event.id, eventStore: eventStore, geocoder: fakeGeocoder)
    await vm.load()
    vm.beginEditing()
    XCTAssertNotNil(vm.composer)

    vm.composer?.title = "New title"
    vm.composer?.category = .health
    await vm.save()

    let reloaded = try await eventStore.event(id: event.id)
    XCTAssertEqual(reloaded?.title, "New title")
    XCTAssertEqual(reloaded?.category, .health)
    XCTAssertNil(vm.composer, "composer should clear after a successful save")
}

func testSaveInCreateModeUpsertsBrandNewEvent() async throws {
    let vm = EventDetailViewModel(eventID: UUID(),
                                  eventStore: eventStore,
                                  geocoder: fakeGeocoder)
    vm.beginCreating(at: Date(timeIntervalSince1970: 1_780_000_000),
                     calendar: WeekMath.mondayCalendar())
    vm.composer?.title = "Lunch with Jamie"
    await vm.save()

    let all = try await eventStore.events(forWeekOffset: 0,
                                          today: Date(timeIntervalSince1970: 1_780_000_000))
    XCTAssertEqual(all.filter { $0.title == "Lunch with Jamie" }.count, 1)
}
```

- [ ] **Step 2: Run those two tests — verify FAIL with "Value of type 'EventDetailViewModel' has no member 'beginEditing'"**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/EventDetailViewModelTests/testSaveCommitsComposerDraft \
  -only-testing:WeeklyPlannerTests/EventDetailViewModelTests/testSaveInCreateModeUpsertsBrandNewEvent \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -25
```
Expected: BUILD FAILED, "has no member 'beginEditing'" / "'beginCreating'".

- [ ] **Step 3: Extend `EventDetailViewModel`**

Open `WeeklyPlanner/Features/EventDetail/EventDetailViewModel.swift`. Below the existing `var liveSuggestion: String?` declaration, add:

```swift
    /// Active composer draft, or `nil` when the sheet is in `.view` mode.
    /// Mutating `composer` mid-edit (e.g., user types in the title field)
    /// triggers the surrounding `@Observable` propagation.
    var composer: EventComposerState?

    /// Snapshot of the composer at the time editing began. Used to detect
    /// dirty state for the discard-confirm dialog.
    private(set) var composerBaseline: EventComposerState?
```

Then below the existing `func delete() async` method, append:

```swift
    /// Switch into `.edit` mode by hydrating a composer from the loaded
    /// event. No-op if the event hasn't loaded yet.
    func beginEditing() {
        guard let event else { return }
        composer = EventComposerState.from(event)
        composerBaseline = EventComposerState.from(event)
    }

    /// Switch into `.create` mode with an empty composer anchored at
    /// `date` (the page's focused day).
    func beginCreating(at date: Date, calendar: Calendar) {
        composer = EventComposerState.empty(at: date, calendar: calendar)
        composerBaseline = EventComposerState.empty(at: date, calendar: calendar)
    }

    /// `true` iff `composer` differs from `composerBaseline`. Drives the
    /// discard-confirm dialog when the user taps Cancel.
    var composerIsDirty: Bool {
        guard let composer, let composerBaseline else { return false }
        return composer.isDirty(against: composerBaseline)
    }

    /// Commit the composer draft. In `.edit` mode this updates the
    /// existing event by id; in `.create` mode it inserts a new event.
    /// Clears the composer on success so the sheet flips back to `.view`.
    func save() async {
        guard let composer, composer.canSave else { return }
        let built = composer.build(id: event?.id ?? UUID())
        // Preserve eventKitIdentifier on edit so the mirror updates the
        // existing iOS calendar row instead of inserting a duplicate.
        built.eventKitIdentifier = event?.eventKitIdentifier
        do {
            try await eventStore.upsert(built)
            event = try await eventStore.event(id: built.id)
            // Re-seed reminder mirrors from the saved event so the alert
            // rows reflect what's on disk.
            if let event {
                alertOn = event.reminders.contains {
                    if case .timeBefore = $0 { true } else { false }
                }
                locationAlertOn = event.reminders.contains {
                    if case .onArrive = $0 { true } else { false }
                }
            }
            self.composer = nil
            composerBaseline = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// Discard composer changes. Caller is responsible for the
    /// confirmation prompt; this method just clears state.
    func cancelEditing() {
        composer = nil
        composerBaseline = nil
    }
```

- [ ] **Step 4: Run the two new tests — verify PASS, and re-run the existing suite to confirm no regressions**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/EventDetailViewModelTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -40
```
Expected: TEST SUCCEEDED — full `EventDetailViewModelTests` class green (existing + 2 new).

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Features/EventDetail/EventDetailViewModel.swift \
       WeeklyPlannerTests/EventDetail/EventDetailViewModelTests.swift
git commit -m "feat(phase-22): EventDetailViewModel — composer + save/cancel

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: `PaperEventSheet` — `SheetMode` + editable card content

**Files:**
- Modify: `WeeklyPlanner/Features/EventDetail/PaperEventSheet.swift`
- Create: `WeeklyPlanner/Features/EventDetail/PaperEventSheet+Edit.swift`
- Test: `WeeklyPlannerTests/EventDetail/PaperEventSheetEditTests.swift`

**Why:** Wire the composer + atoms into the sheet. The biggest task; pure UI integration of the prior pieces.

- [ ] **Step 1: Write failing tests**

Create `WeeklyPlannerTests/EventDetail/PaperEventSheetEditTests.swift`:

```swift
import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class PaperEventSheetEditTests: XCTestCase {
    private var container: ModelContainer!
    private var eventStore: SwiftDataEventStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        eventStore = SwiftDataEventStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        eventStore = nil
        container = nil
        try await super.tearDown()
    }

    /// Editing an existing event and saving should overwrite the title
    /// in the store and clear the composer.
    func testEditMode_saveUpdatesExistingEvent() async throws {
        let event = Event(title: "Lunch",
                          start: Date(timeIntervalSince1970: 1_780_000_000),
                          end: Date(timeIntervalSince1970: 1_780_003_600),
                          category: .personal)
        try await eventStore.upsert(event)

        let vm = EventDetailViewModel(eventID: event.id, eventStore: eventStore)
        await vm.load()
        vm.beginEditing()
        vm.composer?.title = "Lunch with Jamie"
        await vm.save()

        let reloaded = try await eventStore.event(id: event.id)
        XCTAssertEqual(reloaded?.title, "Lunch with Jamie")
        XCTAssertNil(vm.composer)
    }

    /// Composer dirtied → composerIsDirty true; reverted → false.
    func testCancelWithDirtyComposer_isDirtyDetected() async throws {
        let event = Event(title: "Lunch",
                          start: Date(timeIntervalSince1970: 1_780_000_000),
                          end: Date(timeIntervalSince1970: 1_780_003_600),
                          category: .personal)
        try await eventStore.upsert(event)

        let vm = EventDetailViewModel(eventID: event.id, eventStore: eventStore)
        await vm.load()
        vm.beginEditing()
        XCTAssertFalse(vm.composerIsDirty)
        vm.composer?.title = "Renamed"
        XCTAssertTrue(vm.composerIsDirty)
        vm.cancelEditing()
        XCTAssertNil(vm.composer)
    }

    /// canSave should require non-empty title AND end > start.
    func testCanSave_falseWhenTitleEmptyOrTimesInvalid() async throws {
        let vm = EventDetailViewModel(eventID: UUID(), eventStore: eventStore)
        vm.beginCreating(at: Date(), calendar: WeekMath.mondayCalendar())
        XCTAssertFalse(vm.composer?.canSave ?? true)
        vm.composer?.title = "Lunch"
        XCTAssertTrue(vm.composer?.canSave ?? false)
        vm.composer?.end = vm.composer!.start.addingTimeInterval(-60)
        XCTAssertFalse(vm.composer?.canSave ?? true)
    }
}
```

- [ ] **Step 2: Run — verify the three tests fail with linker / compile errors only because `PaperEventSheet+Edit.swift` doesn't exist yet (the tests target the VM, not the view, so they should actually PASS already if Task 6 is correctly committed).**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/PaperEventSheetEditTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -25
```
Expected: TEST SUCCEEDED, 3 passed. (These tests verify the VM contract that the view will rely on.)

- [ ] **Step 3: Add `SheetMode` to `PaperEventSheet`**

Open `WeeklyPlanner/Features/EventDetail/PaperEventSheet.swift`. Replace the `let eventID: UUID` declaration (currently line ~32) and the `init` if any with:

```swift
    /// What the sheet is showing/doing.
    enum SheetMode: Equatable {
        case view(UUID)
        case edit(UUID)
        case create(at: Date)

        var existingEventID: UUID? {
            switch self {
            case let .view(id), let .edit(id): return id
            case .create: return nil
            }
        }
    }

    /// Mode-driven entry. `existingEventID` returns the id for view/edit;
    /// in create mode the sheet generates an id once the composer is built.
    let mode: SheetMode
```

Replace any `eventID:` references inside the file with `mode.existingEventID ?? UUID()` for `.task(id:)` (so a different event tapped while open still re-fetches) and `mode` for state-machine branches.

Replace the `.task(id: eventID)` block with:

```swift
        .task(id: mode) {
            switch mode {
            case .view(let id), .edit(let id):
                if viewModel == nil || viewModel?.eventID != id {
                    let generator = intelligenceService.map {
                        EventSuggestionGenerator(intelligence: $0)
                    }
                    viewModel = EventDetailViewModel(eventID: id,
                                                     eventStore: eventStore,
                                                     suggestionGenerator: generator)
                }
                await viewModel?.load()
                await viewModel?.refreshAISuggestion()
                if case .edit = mode { viewModel?.beginEditing() }
            case .create(let date):
                if viewModel == nil {
                    viewModel = EventDetailViewModel(eventID: UUID(),
                                                     eventStore: eventStore)
                }
                viewModel?.beginCreating(at: date,
                                         calendar: WeekMath.mondayCalendar())
            }
        }
```

Then replace the `private var cardContent: some View` body with a dispatcher:

```swift
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch mode {
            case .view:
                EventHeader(event: viewModel?.event ?? Self.placeholderEvent,
                            onClose: { isOpen = false })
                if let event = viewModel?.event, let viewModel {
                    bodyRows(event: event, viewModel: viewModel)
                        .padding(.horizontal, 18)
                } else {
                    Spacer().frame(height: 200)
                }
            case .edit, .create:
                if let viewModel, let composer = viewModel.composer {
                    EditableEventContent(composer: composer,
                                         canSave: composer.canSave,
                                         isCreate: { if case .create = mode { true } else { false } }(),
                                         showsDelete: { if case .edit = mode { true } else { false } }(),
                                         onSave: { await viewModel.save(); if viewModel.composer == nil { isOpen = false } },
                                         onCancel: {
                                             if viewModel.composerIsDirty {
                                                 showCancelConfirm = true
                                             } else {
                                                 viewModel.cancelEditing()
                                                 isOpen = false
                                             }
                                         },
                                         onDelete: { showDeleteConfirm = true })
                } else {
                    Spacer().frame(height: 200)
                }
            }
        }
    }
```

Add a new state property near `@State private var showDeleteConfirm = false`:

```swift
    @State private var showCancelConfirm = false
```

Add inside `body` after the existing `.alert("Delete this event?", ...)`:

```swift
        .alert("Discard changes?", isPresented: $showCancelConfirm) {
            Button("Discard", role: .destructive) {
                viewModel?.cancelEditing()
                isOpen = false
            }
            Button("Keep editing", role: .cancel) {}
        }
```

Update the preview at the bottom of the file:

```swift
#Preview("PaperEventSheet · Cream") {
    PaperEventSheetPreviewHost()
        .paperTheme(.cream)
}

private struct PaperEventSheetPreviewHost: View {
    @State private var isOpen = true
    private let eventID = UUID()
    private let store = PreviewSeededStore()

    init() {
        // ... (same body as before, but the final `PaperEventSheet(...)`
        // call below changes to use SheetMode):
        let calendar = WeekMath.mondayCalendar()
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 16
        components.hour = 20
        let eightPM = calendar.date(from: components) ?? Date()
        let event = Event(id: eventID,
                          title: "Sara's birthday",
                          start: eightPM,
                          end: calendar.date(byAdding: .hour, value: 3, to: eightPM) ?? eightPM,
                          location: "Trick Dog, Mission",
                          category: .family,
                          attendeesCount: 4,
                          travelMinutes: 22)
        store.seed(event)
    }

    var body: some View {
        ZStack {
            BookCover()
            PaperEventSheet(mode: .view(eventID), isOpen: $isOpen)
        }
        .environment(\.eventStore, store)
    }
}
```

Also: any existing `PaperEventSheet(eventID:, isOpen:)` call-site (currently `DayPageContent` body in `DayPageView.swift`) must change. Update `DayPageView.swift` to:

```swift
            if let id = openEventID {
                PaperEventSheet(mode: .view(id),
                                isOpen: Binding(get: { openEventID != nil },
                                                set: { if !$0 { openEventID = nil } }))
            }
```

(The mode stays `.view` here; Task 9 will add the FAB and create-mode wiring.)

- [ ] **Step 4: Create `PaperEventSheet+Edit.swift`** (the `EditableEventContent` subview)

Create `WeeklyPlanner/Features/EventDetail/PaperEventSheet+Edit.swift`:

```swift
import SwiftUI

/// Editable card content used by `PaperEventSheet` when `mode` is
/// `.edit` or `.create`. Renders a Save / Cancel header bar above
/// `InkTextField` (title) + `PaperDateTimeRow` (start, end) +
/// `CategorySwatchRow` + `LocationField` + the existing alert rows,
/// plus an optional Delete button at the bottom (only in edit mode).
struct EditableEventContent: View {
    @Bindable var composer: EventComposerState
    let canSave: Bool
    let isCreate: Bool
    let showsDelete: Bool
    let onSave: () async -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(EdgeInsets(top: 38, leading: 44, bottom: 14, trailing: 18))

            VStack(alignment: .leading, spacing: 0) {
                InkTextField(isCreate ? "New event" : "Title",
                             text: $composer.title,
                             variant: .title)
                    .padding(.bottom, 12)

                PaperDateTimeRow(label: "Starts", date: $composer.start)
                PaperDateTimeRow(label: "Ends",
                                 date: $composer.end,
                                 invalidHint: !composer.timesAreValid)
                CategorySwatchRow(selection: $composer.category)
                LocationField(text: $composer.location)

                if showsDelete {
                    Button(action: onDelete) {
                        Text("Delete event")
                            .font(font.font(at: 15 * size.scale, weight: .regular))
                            .foregroundStyle(theme.redInk)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .onChange(of: composer.start) { _, newStart in
            // Auto-bump end if user advances start past end.
            if newStart >= composer.end {
                composer.end = newStart.addingTimeInterval(3600)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            Button("Cancel", action: onCancel)
                .font(font.font(at: 15 * size.scale, weight: .regular))
                .foregroundStyle(theme.ink2)
                .buttonStyle(.plain)

            Spacer()

            Text(isCreate ? "New event" : "Edit event")
                .font(font.font(at: 15 * size.scale, weight: .regular))
                .foregroundStyle(theme.ink2)

            Spacer()

            Button {
                Task { await onSave() }
            } label: {
                Text("Save")
                    .font(font.font(at: 15 * size.scale, weight: .bold))
                    .foregroundStyle(canSave ? theme.blueInk : theme.ink3)
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .accessibilityIdentifier("paperEventSheet.save")
        }
    }
}
```

- [ ] **Step 5: Run the full sheet test suite**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/PaperEventSheetEditTests \
  -only-testing:WeeklyPlannerTests/EventDetailViewModelTests \
  -only-testing:WeeklyPlannerTests/EventComposerStateTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -25
```
Expected: All three classes pass.

- [ ] **Step 6: Run the WHOLE app test suite to catch regressions from changing `PaperEventSheet(eventID:)` → `PaperEventSheet(mode:)`**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -20
```
Expected: All 302 + 9 baseline + 7 new (Task 1 + Task 6 + Task 7) tests pass — totaling ~309 unit tests green.

- [ ] **Step 7: Commit**

```bash
git add WeeklyPlanner/Features/EventDetail/PaperEventSheet.swift \
       WeeklyPlanner/Features/EventDetail/PaperEventSheet+Edit.swift \
       WeeklyPlanner/Features/DayPage/DayPageView.swift \
       WeeklyPlannerTests/EventDetail/PaperEventSheetEditTests.swift
git commit -m "feat(phase-22): PaperEventSheet SheetMode + editable variant

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: `FloatingInkButton` + `isAnySheetOpen` environment key

**Files:**
- Create: `WeeklyPlanner/Features/DayPage/FloatingInkButton.swift`
- Modify: `WeeklyPlanner/Navigation/AppShell.swift`

- [ ] **Step 1: Create `FloatingInkButton.swift`**

```swift
import SwiftUI

/// Bottom-trailing floating "+" ink button. Mounted at the AppShell
/// level so Calendar (Day + Week pages) surfaces it; hidden when any
/// sheet/overlay is open via `\.isAnySheetOpen`.
struct FloatingInkButton: View {
    let onTap: () -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.isAnySheetOpen) private var isAnySheetOpen

    var body: some View {
        if !isAnySheetOpen {
            Button(action: onTap) {
                ZStack {
                    Circle()
                        .fill(theme.cream.opacity(0.96))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle()
                                .stroke(theme.ink, lineWidth: 1.4)
                        )
                        .shadow(color: Color.black.opacity(0.18),
                                radius: 4, x: 0, y: 2)

                    PlusGlyph()
                        .stroke(theme.ink, style: StrokeStyle(lineWidth: 3,
                                                              lineCap: .round))
                        .frame(width: 22, height: 22)
                }
                .contentShape(Rectangle().inset(by: -8))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add event")
            .accessibilityHint("Opens new event composer")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("appshell.fab.add")
        }
    }
}

/// Hand-drawn "+" rendered as two perpendicular ink strokes via SwiftUI
/// `Shape`. Slight off-center on the vertical so it reads as inked, not
/// printed.
private struct PlusGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let midX = rect.midX
        path.move(to: CGPoint(x: rect.minX + 1, y: midY))
        path.addLine(to: CGPoint(x: rect.maxX - 1, y: midY))
        path.move(to: CGPoint(x: midX + 0.5, y: rect.minY + 1))
        path.addLine(to: CGPoint(x: midX + 0.5, y: rect.maxY - 1))
        return path
    }
}

// MARK: - Environment key

private struct IsAnySheetOpenKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// True when any modal sheet/overlay is open. Set by `AppShell`.
    var isAnySheetOpen: Bool {
        get { self[IsAnySheetOpenKey.self] }
        set { self[IsAnySheetOpenKey.self] = newValue }
    }
}
```

- [ ] **Step 2: Mount the FAB in `AppShell`**

In `WeeklyPlanner/Navigation/AppShell.swift`, near the other `@State` declarations, add:

```swift
    @State private var creatingEvent: Bool = false
    @State private var createAnchorDate: Date = Date()
```

Inside `body`'s outer `ZStack`, after the `WeekPickerSheet` and before the `if isAISearchOpen` line, add:

```swift
            FloatingInkButton {
                createAnchorDate = focusedDayDate()
                creatingEvent = true
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity,
                   alignment: .bottomTrailing)
            .padding(.trailing, 24)
            .padding(.bottom, Spacing.tabBarHeight + 20)
            .allowsHitTesting(selection.current == .calendar)
            .opacity(selection.current == .calendar ? 1 : 0)
```

After the `body`'s outer `ZStack` closes and before the `.onReceive(...)`, add the `isAnySheetOpen` propagation by injecting it on the outer view chain. Append this modifier alongside the existing `.environment(\.intelligenceService, ...)`:

```swift
        .environment(\.isAnySheetOpen,
                     isPickerOpen || isAISearchOpen || creatingEvent)
```

Inside the existing `calendarTab` `BookContainer` `content:` closure where `DayPageView(controller:)` is constructed, pass the creating-event binding by:

1. Add a new env key for the creation trigger above the `IsAnySheetOpenKey`:

   ```swift
   private struct EventCreationRequestKey: EnvironmentKey {
       static let defaultValue: EventCreationRequest = .init()
   }

   extension EnvironmentValues {
       var eventCreationRequest: EventCreationRequest {
           get { self[EventCreationRequestKey.self] }
           set { self[EventCreationRequestKey.self] = newValue }
       }
   }

   /// Observable carrier for "open a fresh create-event sheet anchored
   /// at this date". `AppShell` writes, `DayPageContent` reads.
   @MainActor
   @Observable
   final class EventCreationRequest {
       var anchorDate: Date?
       func request(at date: Date) { anchorDate = date }
       func consume() { anchorDate = nil }
   }
   ```

2. In `AppShell`, replace `@State private var creatingEvent: Bool` with:

   ```swift
   @State private var creationRequest = EventCreationRequest()
   ```

3. Replace the FAB tap action with:

   ```swift
   FloatingInkButton {
       creationRequest.request(at: focusedDayDate())
   }
   ```

4. Replace the `.environment(\.isAnySheetOpen, ...)` to include the request:

   ```swift
   .environment(\.isAnySheetOpen,
                isPickerOpen || isAISearchOpen || creationRequest.anchorDate != nil)
   .environment(\.eventCreationRequest, creationRequest)
   ```

5. Add a helper at the bottom of `AppShell`:

   ```swift
   /// Day currently visible in the Calendar tab. Used as the default
   /// anchor when the user taps "+". Falls back to "now" if WeekMath
   /// returns no days for the current offset (shouldn't happen).
   private func focusedDayDate() -> Date {
       let today = Date()
       let days = WeekMath.weekDays(forOffset: controller.current.week,
                                     today: today)
       guard days.indices.contains(controller.current.day) else { return today }
       return days[controller.current.day].date
   }
   ```

- [ ] **Step 3: Wire `DayPageContent` to honor the creation request**

In `WeeklyPlanner/Features/DayPage/DayPageView.swift`, in the `DayPageContent` struct, add:

```swift
    @Environment(\.eventCreationRequest) private var creationRequest

    @State private var creatingEventAt: Date?
```

In the `.task { ... }` block (existing), after setting `viewModel`, append `.onChange(of: creationRequest.anchorDate)`:

```swift
        .onChange(of: creationRequest.anchorDate) { _, new in
            guard let anchor = new else { return }
            creatingEventAt = anchor
            creationRequest.consume()
        }
```

Replace the existing sheet section:

```swift
            if let id = openEventID {
                PaperEventSheet(mode: .view(id),
                                isOpen: Binding(get: { openEventID != nil },
                                                set: { if !$0 { openEventID = nil } }))
            }
            if let anchor = creatingEventAt {
                PaperEventSheet(mode: .create(at: anchor),
                                isOpen: Binding(get: { creatingEventAt != nil },
                                                set: { if !$0 { creatingEventAt = nil } }))
            }
```

- [ ] **Step 4: Build + run the existing suite**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -15
```
Expected: All ~309 unit tests still green. No new tests yet (UITest comes in Task 9).

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Features/DayPage/FloatingInkButton.swift \
       WeeklyPlanner/Navigation/AppShell.swift \
       WeeklyPlanner/Features/DayPage/DayPageView.swift
git commit -m "feat(phase-22): FloatingInkButton + isAnySheetOpen env + creation request routing

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: UITest — end-to-end create flow

**Files:**
- Create: `WeeklyPlannerUITests/EventCreateFlowUITests.swift`

- [ ] **Step 1: Create the UITest**

```swift
import XCTest

/// End-to-end create-event flow: launch app → tap FAB → fill title →
/// tap Save → verify a row labeled with that title appears on the Day
/// page.
final class EventCreateFlowUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testCreateEvent_endToEnd() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestSeedEmptyStore"]
        app.launch()

        // Make sure we land on Calendar tab; PaperTabBar default is calendar.
        let fab = app.buttons["appshell.fab.add"]
        XCTAssertTrue(fab.waitForExistence(timeout: 5))
        fab.tap()

        // The composer's title field is the first focused text field on
        // the sheet. We type a unique title so we can find the resulting
        // row deterministically.
        let title = "UITest Lunch \(UUID().uuidString.prefix(6))"
        let titleField = app.textFields.firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        titleField.typeText(String(title))

        let save = app.buttons["paperEventSheet.save"]
        XCTAssertTrue(save.exists)
        save.tap()

        // After save, the sheet dismisses and the new event should be
        // visible in the Day page event list. Day page rows are not
        // currently accessibility-identifiable by title, so we rely on
        // the title appearing somewhere in the visible static text.
        let predicate = NSPredicate(format: "label CONTAINS %@",
                                    String(title))
        let result = app.staticTexts.matching(predicate).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5),
                      "New event title should be visible on the Day page after save")
    }
}
```

- [ ] **Step 2: Run it — expected FAIL because `-UITestSeedEmptyStore` isn't honored yet (the app will launch with real seed data, which is fine for this test, but verify the rest)**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerUITests/EventCreateFlowUITests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -30
```
Expected: TEST SUCCEEDED. (The launch arg is harmless — the app ignores unknown args. The seed data already includes events for some days, which is fine; the test verifies the new title appears, not that the page was empty.)

If the test fails because the title field doesn't get focus, change `titleField.tap()` to also briefly wait: insert `Thread.sleep(forTimeInterval: 0.3)` before `typeText`. Document the timing on the spot.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlannerUITests/EventCreateFlowUITests.swift
git commit -m "test(phase-22): EventCreateFlowUITests — end-to-end create flow

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: Tap-event-row-to-edit wiring + retrospective

**Files:**
- Modify: `WeeklyPlanner/Features/DayPage/DayPageView.swift` (tap behavior)
- Modify: `README.md` + `docs/phases/README.md` (mark Phase 22 ✅)
- Append: `docs/phases/README.md` retrospective section

- [ ] **Step 1: Add a long-press on event rows to enter edit mode**

The simplest no-regression edit affordance: keep "tap = view" (existing behavior) and add "long-press = edit" via `.contextMenu` on the existing `EventEntryRow`. This avoids the risk of the page-flip horizontal swipe gesture eating the tap.

In `WeeklyPlanner/Features/DayPage/DayPageView.swift`, change the `EventEntryList(events:onTap:)` call site:

```swift
                if hasEvents {
                    EventEntryList(events: viewModel.events,
                                   onTap: { event in openEventID = event.id },
                                   onEdit: { event in editingEventID = event.id })
                }
```

Add a new state property in `DayPageContent`:

```swift
    @State private var editingEventID: UUID?
```

Add the edit sheet alongside the view + create sheets:

```swift
            if let id = editingEventID {
                PaperEventSheet(mode: .edit(id),
                                isOpen: Binding(get: { editingEventID != nil },
                                                set: { if !$0 { editingEventID = nil } }))
            }
```

In `WeeklyPlanner/Features/DayPage/EventEntryList.swift` (existing file from Phase 06; if the file/struct name differs, use the actual one — `git grep "struct EventEntryList"`), add an optional `onEdit:` parameter to the initializer and attach `.contextMenu` to each rendered row:

```swift
struct EventEntryList: View {
    let events: [Event]
    var onTap: (Event) -> Void
    var onEdit: ((Event) -> Void)? = nil

    // body: in the ForEach, wrap each row with:
    //   .contextMenu {
    //       if let onEdit {
    //           Button("Edit") { onEdit(event) }
    //       }
    //   }
}
```

(If the existing implementation already destructures the `ForEach` differently, follow that pattern. Don't restructure the file beyond adding the menu — this is a leaf change.)

- [ ] **Step 2: Run full suite — confirm no regressions**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -15
```
Expected: All tests pass.

- [ ] **Step 3: Update READMEs to mark Phase 22 done**

In `docs/phases/README.md` phase map, change `| 22 | Manual Event CRUD | J — Completeness | ⏳ |` to `| 22 | Manual Event CRUD | J — Completeness | ✅ |`.

In `README.md` milestone table, change the J row note from `⏳ pending (Manual Event CRUD, Manual Task CRUD, AI Sticky v2)` to `⏳ in progress (Phase 22 ✅; 23 + 24 pending)`.

Append to `docs/phases/README.md` under the existing "Retrospectives" section a new entry titled `### Phase 22 — Manual Event CRUD`, briefly describing what shipped (composer state, atoms, sheet edit mode, FAB), plus any deviations encountered.

- [ ] **Step 4: Commit**

```bash
git add WeeklyPlanner/Features/DayPage/DayPageView.swift \
       WeeklyPlanner/Features/DayPage/EventEntryList.swift \
       README.md docs/phases/README.md
git commit -m "feat(phase-22): long-press edit + Phase 22 ✅ retrospective

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage check** (from `docs/phases/phase-22-event-crud.md`):

| Spec requirement | Implemented in |
|------------------|----------------|
| `EventComposerState` (`@Observable`, validation, build) | Task 1 |
| `InkTextField` atom | Task 2 |
| `PaperDateTimeRow` atom | Task 3 |
| `CategorySwatchRow` atom | Task 4 |
| `LocationField` atom | Task 5 |
| Composer wiring on `EventDetailViewModel` (save/cancel/beginEditing/beginCreating) | Task 6 |
| `SheetMode` on `PaperEventSheet` (`.view`/`.edit`/`.create`) | Task 7 |
| Save/Cancel header in editable modes | Task 7 |
| Discard confirm on dirty cancel | Task 7 |
| End auto-bumps when start advances past end | Task 7 |
| `FloatingInkButton` mounted at AppShell, hidden when any sheet open | Task 8 |
| `\.isAnySheetOpen` environment key | Task 8 |
| FAB default anchor = current focused day | Task 8 |
| Tap event → edit (via long-press menu) | Task 10 |
| UITest for end-to-end create | Task 9 |
| EventKit mirror roundtrip (free via Phase 04 decorator) | implicit — `EventStore.upsert` already routes through `EventKitMirroringEventStore` |
| Notification reschedule on save (free via Phase 19 observer) | implicit |
| Accessibility labels on FAB + Save button | Task 8 + Task 7 |
| Phase 22 marked ✅ in READMEs | Task 10 |

Acceptance criteria from the phase doc — all covered. The phase doc also mentions a long-press context menu on the FAB ("New event"/"New task") — Task 8 wires only the tap; Phase 23 will add the menu options when the task composer is built.

**Placeholder scan:** No TBD/TODO/FIXME in the plan. Every step has either complete code or an exact command.

**Type consistency check:**
- `EventComposerState.build(id:)` returns `Event` — used by Task 6 `vm.save()` with `composer.build(id: event?.id ?? UUID())`. ✓
- `SheetMode.existingEventID` returns `UUID?` — referenced in Task 7. ✓
- `creationRequest.anchorDate: Date?` — written by `request(at:)`, consumed by `.onChange` in `DayPageContent`. ✓
- `EventCreationRequest` is `@Observable` so SwiftUI tracks `anchorDate` changes. ✓

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-05-22-phase-22-event-crud.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration. Best for a 10-task plan with shared types.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints. Slower iteration but full visibility into every step.

**Which approach?**
