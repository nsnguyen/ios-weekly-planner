# Phase 33 — Notes Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a fourth tab — **Notes** — a persistent free-form space for misc notes and goals, in the paper aesthetic, with full CRUD.

**Architecture:** A `Note` SwiftData `@Model` behind a `NoteStoring` protocol (SwiftData impl + stub, environment-injected — exact `TaskStore` pattern). An `@Observable NotesViewModel` drives a `PaperNotesView` paper page (same `BookPage`/`PaperSurface` chrome as Settings). The `Tab` enum gains a `.notes` case — `PaperTabBar` renders via `ForEach(Tab.allCases)` so the 4th tab appears automatically; tab persistence rides the existing `lastTabRaw` mechanism unchanged.

**Tech Stack:** SwiftUI, SwiftData, `@Observable`, XCTest (NOT swift-testing), XcodeGen (`xcodegen generate` before any Xcode build).

**User decisions (2026-06-04):** Tab order **Calendar · Review · Notes · Settings**. Goals are a light `kind` flag on Note (no separate surface).

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `WeeklyPlanner/Models/Note.swift` | NEW | `@Model`: id, title, body, kindRaw (misc/goal), optional dayKey (reserved, always nil), timestamps |
| `WeeklyPlanner/Stores/NoteStore.swift` | NEW | `NoteStoring` protocol + `SwiftDataNoteStore` + `StubNoteStore` + `.noteStoreDidChange` |
| `WeeklyPlanner/Stores/SwiftDataStack.swift` | MODIFY | register `Note.self` in `allModels` |
| `WeeklyPlanner/Stores/Environment+Stores.swift` | MODIFY | `@Entry var noteStore` |
| `WeeklyPlanner/WeeklyPlannerApp.swift` (or wherever `.environment(\.taskStore, …)` is injected) | MODIFY | inject production `SwiftDataNoteStore` |
| `WeeklyPlanner/Features/Notes/NotesViewModel.swift` | NEW | `@Observable`: load/create/update/delete, most-recent-first |
| `WeeklyPlanner/Features/Notes/NotesHeader.swift` | NEW | "Notes" page banner (mirrors `SettingsHeader`) |
| `WeeklyPlanner/Features/Notes/NewNoteRow.swift` | NEW | "+ New note" affordance row |
| `WeeklyPlanner/Features/Notes/NotesListView.swift` | NEW | list of `NoteRow` + empty state |
| `WeeklyPlanner/Features/Notes/NoteRow.swift` | NEW | preview row: title, body line, goal tag |
| `WeeklyPlanner/Features/Notes/NoteEditorView.swift` | NEW | create/edit: title `InkTextField`, kind chips, `TextEditor` body, delete |
| `WeeklyPlanner/Features/Notes/PaperNotesView.swift` | NEW | paper page hosting list ⟷ editor |
| `WeeklyPlanner/Navigation/TabSelection.swift` | MODIFY | `case notes` (between review and settings) |
| `WeeklyPlanner/Navigation/PaperTab.swift` | MODIFY | icon `note.text`, label "Notes" |
| `WeeklyPlanner/Navigation/AppShell.swift` | MODIFY | route `.notes → PaperNotesView()` |
| `WeeklyPlanner/Accessibility/AccessibilityIDs.swift` | MODIFY | notes IDs |
| `WeeklyPlanner/Accessibility/AccessibilityModifiers.swift` | MODIFY | `accessibleNote(_:)` + `noteLabel(_:)` |
| `WeeklyPlannerTests/Notes/NoteStoreTests.swift` | NEW | persistence round-trip |
| `WeeklyPlannerTests/Notes/NotesViewModelTests.swift` | NEW | CRUD + ordering + empty-draft discard |
| `WeeklyPlannerTests/Navigation/TabSelectionNotesTests.swift` | NEW | tab order + persistence of `.notes` |
| `WeeklyPlannerUITests/NotesTabUITests.swift` | NEW | create → relaunch → persists → delete |

`UserSettings.lastTabRaw` needs **no change** — it stores the raw String and `TabSelection.init` already falls back to `.calendar` for unknown values.

**Canonical test command** (referenced as "the test command" below; pick the device from `xcrun simctl list devices available`):

```bash
xcodegen generate
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=<available iPhone, iOS 26.5>' \
  -only-testing:<filter> \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO
```

---

### Task 1: `Note` model + `NoteStoring` + `SwiftDataNoteStore`

**Files:**
- Create: `WeeklyPlanner/Models/Note.swift`
- Create: `WeeklyPlanner/Stores/NoteStore.swift`
- Modify: `WeeklyPlanner/Stores/SwiftDataStack.swift` (the `allModels` array)
- Test: `WeeklyPlannerTests/Notes/NoteStoreTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class NoteStoreTests: XCTestCase {
    private var container: ModelContainer!
    private var store: SwiftDataNoteStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        store = SwiftDataNoteStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        store = nil
        container = nil
        try await super.tearDown()
    }

    func testUpsertNewNoteInsertsIt() async throws {
        let note = Note(title: "Marathon", body: "Sub-4 this year", kind: .goal)
        try await store.upsert(note)

        let fetched = try await store.note(id: note.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.title, "Marathon")
        XCTAssertEqual(fetched?.kind, .goal)
        XCTAssertNil(fetched?.dayKey, "dayKey is reserved and must default to nil")
    }

    func testUpsertExistingNoteUpdatesInPlace() async throws {
        let id = UUID()
        try await store.upsert(Note(id: id, title: "Old", body: "old body"))
        try await store.upsert(Note(id: id, title: "New", body: "new body", kind: .goal))

        let count = try container.mainContext.fetch(FetchDescriptor<Note>()).count
        XCTAssertEqual(count, 1, "Upsert should update, not insert a second row")
        let fetched = try await store.note(id: id)
        XCTAssertEqual(fetched?.title, "New")
        XCTAssertEqual(fetched?.kind, .goal)
    }

    func testNotesSortedMostRecentlyUpdatedFirst() async throws {
        try await store.upsert(Note(title: "Old", body: "", updatedAt: Date(timeIntervalSince1970: 1_000)))
        try await store.upsert(Note(title: "New", body: "", updatedAt: Date(timeIntervalSince1970: 2_000)))

        let notes = try await store.notes()
        XCTAssertEqual(notes.map(\.title), ["New", "Old"])
    }

    func testDeleteRemovesNote() async throws {
        let note = Note(title: "Bye", body: "")
        try await store.upsert(note)
        try await store.delete(id: note.id)

        let fetched = try await store.note(id: note.id)
        XCTAssertNil(fetched)
        let remaining = try await store.notes()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testMutationsPostChangeNotification() async throws {
        let exp = expectation(forNotification: .noteStoreDidChange, object: nil)
        try await store.upsert(Note(title: "Ping", body: ""))
        await fulfillment(of: [exp], timeout: 1)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: the test command with `-only-testing:WeeklyPlannerTests/NoteStoreTests`
Expected: **compile failure** — `Note` / `SwiftDataNoteStore` / `.noteStoreDidChange` don't exist. (Compile failure is the red state for new types.)

- [ ] **Step 3: Implement model + store**

`WeeklyPlanner/Models/Note.swift`:

```swift
import Foundation
import SwiftData

/// Kind flag for a note: a loose miscellaneous note or a standing goal.
/// Stored as a raw String (SwiftData-predicate friendly) and mirrored by
/// the typed accessor below — same pattern as `TaskItem.priority`.
enum NoteKind: String, CaseIterable, Codable, Sendable {
    case misc
    case goal
}

/// Free-form note on the Notes tab (Phase 33). Not tied to a day —
/// `dayKey` is reserved for a future "note for a specific day" link and
/// is always `nil` for now.
@Model
final class Note {
    @Attribute(.unique) var id: UUID
    var title: String
    var body: String
    var kindRaw: String
    /// Reserved: `"<weekOffset>:<dayIdx>"` if a note is ever pinned to a day.
    var dayKey: String?
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(),
         title: String,
         body: String,
         kind: NoteKind = .misc,
         dayKey: String? = nil,
         createdAt: Date = .init(),
         updatedAt: Date = .init())
    {
        self.id = id
        self.title = title
        self.body = body
        kindRaw = kind.rawValue
        self.dayKey = dayKey
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension Note {
    var kind: NoteKind {
        get { NoteKind(rawValue: kindRaw) ?? .misc }
        set { kindRaw = newValue.rawValue }
    }
}
```

`WeeklyPlanner/Stores/NoteStore.swift`:

```swift
import Foundation
import SwiftData

/// CRUD surface for Notes-tab notes. Mirrors `TaskStoring`.
@MainActor
protocol NoteStoring: AnyObject {
    /// All notes, most-recently-updated first.
    func notes() async throws -> [Note]
    func note(id: UUID) async throws -> Note?
    func upsert(_ note: Note) async throws
    func delete(id: UUID) async throws
}

@MainActor
final class SwiftDataNoteStore: NoteStoring {
    private let context: ModelContext
    private let changeSubject = NotificationCenter.default

    init(context: ModelContext) {
        self.context = context
    }

    func notes() async throws -> [Note] {
        try context.fetch(FetchDescriptor<Note>(
            sortBy: [SortDescriptor(\Note.updatedAt, order: .reverse)]))
    }

    func note(id: UUID) async throws -> Note? {
        try context.fetch(FetchDescriptor<Note>(predicate: #Predicate<Note> { $0.id == id })).first
    }

    func upsert(_ note: Note) async throws {
        let id = note.id
        let existing = try context.fetch(FetchDescriptor<Note>(predicate: #Predicate<Note> { $0.id == id })).first

        if let existing {
            existing.title = note.title
            existing.body = note.body
            existing.kindRaw = note.kindRaw
            existing.dayKey = note.dayKey
            existing.updatedAt = .init()
        } else {
            context.insert(note)
        }
        try context.save()
        changeSubject.post(name: .noteStoreDidChange, object: nil)
    }

    func delete(id: UUID) async throws {
        guard let note = try await note(id: id) else { return }
        context.delete(note)
        try context.save()
        changeSubject.post(name: .noteStoreDidChange, object: nil)
    }
}

extension Notification.Name {
    static let noteStoreDidChange = Notification.Name("WeeklyPlanner.NoteStore.didChange")
}
```

In `WeeklyPlanner/Stores/SwiftDataStack.swift`, add `Note.self` to the array:

```swift
    static let allModels: [any PersistentModel.Type] = [
        Event.self,
        TaskItem.self,
        InboxSuggestion.self,
        AIInsight.self,
        Streak.self,
        UserSettings.self,
        Note.self,
    ]
```

- [ ] **Step 4: Run to verify pass**

Run: the test command with `-only-testing:WeeklyPlannerTests/NoteStoreTests`
Expected: PASS — 5 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Models/Note.swift WeeklyPlanner/Stores/NoteStore.swift WeeklyPlanner/Stores/SwiftDataStack.swift WeeklyPlannerTests/Notes/NoteStoreTests.swift
git commit -m "feat(notes): Note model + NoteStoring/SwiftDataNoteStore with change notification (Phase 33)"
```

---

### Task 2: `StubNoteStore` + environment key + production wiring

**Files:**
- Modify: `WeeklyPlanner/Stores/NoteStore.swift` (append stub)
- Modify: `WeeklyPlanner/Stores/Environment+Stores.swift`
- Modify: the app root where production stores are injected (grep `environment(\.taskStore` — it's `WeeklyPlannerApp.swift` / the root view builder)

- [ ] **Step 1: Append the stub to `NoteStore.swift`**

```swift
/// Inert default for previews and unwired subtrees.
@MainActor
final class StubNoteStore: NoteStoring {
    nonisolated init() {}

    func notes() async throws -> [Note] { [] }
    func note(id _: UUID) async throws -> Note? { nil }
    func upsert(_: Note) async throws {}
    func delete(id _: UUID) async throws {}
}
```

- [ ] **Step 2: Add the environment key**

In `WeeklyPlanner/Stores/Environment+Stores.swift`, alongside the existing entries:

```swift
    /// The active `NoteStoring` for this subtree. Defaults to `StubNoteStore`.
    @Entry var noteStore: any NoteStoring = StubNoteStore()
```

- [ ] **Step 3: Inject the production store**

At the app root, find where `.environment(\.taskStore, …)` is set and add the sibling line, constructing the store the same way the task store is constructed (same `ModelContext`):

```swift
.environment(\.noteStore, SwiftDataNoteStore(context: SwiftDataStack.production.mainContext))
```

⚠️ Match the existing construction exactly — if the app builds stores once in `init` and passes properties, do the same (a `let noteStore: SwiftDataNoteStore` property next to the existing ones), not an inline construction per render.

- [ ] **Step 4: Build to verify**

Run: the test command with `-only-testing:WeeklyPlannerTests/NoteStoreTests` (re-running the smallest suite is the cheapest full-compile check)
Expected: PASS — compile clean, 5 tests green.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Stores/NoteStore.swift WeeklyPlanner/Stores/Environment+Stores.swift WeeklyPlanner/WeeklyPlannerApp.swift
git commit -m "feat(notes): StubNoteStore + noteStore environment key + production wiring (Phase 33)"
```

(Adjust the staged app-root filename if injection lives elsewhere.)

---

### Task 3: `NotesViewModel`

**Files:**
- Create: `WeeklyPlanner/Features/Notes/NotesViewModel.swift`
- Test: `WeeklyPlannerTests/Notes/NotesViewModelTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class NotesViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var store: SwiftDataNoteStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        store = SwiftDataNoteStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        store = nil
        container = nil
        try await super.tearDown()
    }

    func testLoadStartsEmpty() async throws {
        let vm = NotesViewModel(store: store)
        await vm.load()
        XCTAssertTrue(vm.notes.isEmpty)
    }

    func testCreatePersistsTrimmedNoteAndReloads() async throws {
        let vm = NotesViewModel(store: store)
        await vm.load()

        let created = await vm.create(title: "  Groceries  ", body: "milk, eggs\n", kind: .misc)

        XCTAssertNotNil(created)
        XCTAssertEqual(vm.notes.count, 1)
        XCTAssertEqual(vm.notes.first?.title, "Groceries")
        XCTAssertEqual(vm.notes.first?.body, "milk, eggs")
        XCTAssertEqual(vm.notes.first?.kind, .misc)
    }

    func testCreateDiscardsEmptyDraft() async throws {
        let vm = NotesViewModel(store: store)
        await vm.load()

        let created = await vm.create(title: "   ", body: "\n  ", kind: .misc)

        XCTAssertNil(created, "An all-whitespace draft must not be persisted")
        XCTAssertTrue(vm.notes.isEmpty)
    }

    func testUpdateEditsExistingNoteAndPersists() async throws {
        let vm = NotesViewModel(store: store)
        let created = await vm.create(title: "Draft", body: "v1", kind: .misc)
        let id = try XCTUnwrap(created?.id)

        await vm.update(id: id, title: "Draft", body: "v2", kind: .goal)

        XCTAssertEqual(vm.notes.first?.body, "v2")
        XCTAssertEqual(vm.notes.first?.kind, .goal)
        let persisted = try await store.note(id: id)
        XCTAssertEqual(persisted?.body, "v2")
        XCTAssertEqual(persisted?.kind, .goal)
    }

    func testDeleteRemovesNoteFromListAndStore() async throws {
        let vm = NotesViewModel(store: store)
        let created = await vm.create(title: "Bye", body: "", kind: .misc)
        let id = try XCTUnwrap(created?.id)

        await vm.delete(id: id)

        XCTAssertTrue(vm.notes.isEmpty)
        let persisted = try await store.note(id: id)
        XCTAssertNil(persisted)
    }

    func testOrderingMostRecentFirst() async throws {
        try await store.upsert(Note(title: "Old", body: "", updatedAt: Date(timeIntervalSince1970: 1_000)))
        try await store.upsert(Note(title: "New", body: "", updatedAt: Date(timeIntervalSince1970: 2_000)))

        let vm = NotesViewModel(store: store)
        await vm.load()

        XCTAssertEqual(vm.notes.map(\.title), ["New", "Old"])
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: the test command with `-only-testing:WeeklyPlannerTests/NotesViewModelTests`
Expected: compile failure — `NotesViewModel` doesn't exist.

- [ ] **Step 3: Implement**

`WeeklyPlanner/Features/Notes/NotesViewModel.swift`:

```swift
import Foundation
import Observation

/// Drives the Notes tab. Loads through `NoteStoring` so tests/previews
/// inject `SwiftDataNoteStore` (in-memory) / `StubNoteStore`.
@MainActor
@Observable
final class NotesViewModel {
    private let store: any NoteStoring

    var notes: [Note] = []
    var loadError: String?

    init(store: any NoteStoring) {
        self.store = store
    }

    func load() async {
        do {
            notes = try await store.notes()
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// Persists a new note. Returns `nil` (and persists nothing) when both
    /// trimmed title and body are empty — an abandoned editor draft.
    @discardableResult
    func create(title: String, body: String, kind: NoteKind) async -> Note? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !(trimmedTitle.isEmpty && trimmedBody.isEmpty) else { return nil }

        let note = Note(title: trimmedTitle, body: trimmedBody, kind: kind)
        do {
            try await store.upsert(note)
            await load()
            return note
        } catch {
            loadError = error.localizedDescription
            return nil
        }
    }

    func update(id: UUID, title: String, body: String, kind: NoteKind) async {
        do {
            guard let existing = try await store.note(id: id) else { return }
            existing.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.body = body.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.kind = kind
            try await store.upsert(existing)
            await load()
        } catch {
            loadError = error.localizedDescription
        }
    }

    func delete(id: UUID) async {
        do {
            try await store.delete(id: id)
            await load()
        } catch {
            loadError = error.localizedDescription
        }
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: the test command with `-only-testing:WeeklyPlannerTests/NotesViewModelTests`
Expected: PASS — 6 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Features/Notes/NotesViewModel.swift WeeklyPlannerTests/Notes/NotesViewModelTests.swift
git commit -m "feat(notes): NotesViewModel with CRUD, trimming, and recency ordering (Phase 33)"
```

---

### Task 4: Accessibility IDs, formatter, and `accessibleNote` modifier

**Files:**
- Modify: `WeeklyPlanner/Accessibility/AccessibilityIDs.swift`
- Modify: `WeeklyPlanner/Accessibility/AccessibilityModifiers.swift`
- Test: extend the existing accessibility-formatter test file (grep `AccessibilityFormatters` under `WeeklyPlannerTests/`; if no formatter test file exists, create `WeeklyPlannerTests/Accessibility/NoteAccessibilityTests.swift`)

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import WeeklyPlanner

final class NoteAccessibilityTests: XCTestCase {
    func testNoteLabelIncludesTitleAndKind() {
        let goal = Note(title: "Marathon", body: "x", kind: .goal)
        XCTAssertEqual(AccessibilityFormatters.noteLabel(goal), "Marathon, goal")

        let misc = Note(title: "Groceries", body: "x", kind: .misc)
        XCTAssertEqual(AccessibilityFormatters.noteLabel(misc), "Groceries, note")
    }

    func testNoteLabelFallsBackForUntitled() {
        let untitled = Note(title: "", body: "body only", kind: .misc)
        XCTAssertEqual(AccessibilityFormatters.noteLabel(untitled), "Untitled, note")
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: the test command with `-only-testing:WeeklyPlannerTests/NoteAccessibilityTests`
Expected: compile failure — `noteLabel` doesn't exist.

- [ ] **Step 3: Implement**

In `AccessibilityIDs.swift`, add inside the enum:

```swift
    // MARK: Notes tab (Phase 33)
    static let notesAddRow = "notes.addRow"
    static func notesRow(_ id: UUID) -> String { "notes.row.\(id)" }
    static let notesEditorBody = "notes.editor.body"
    static let notesEditorDone = "notes.editor.done"
    static let notesEditorBack = "notes.editor.back"
    static let notesEditorDelete = "notes.editor.delete"
```

In `AccessibilityModifiers.swift`, add to the `View` extension:

```swift
    /// Phase 33: combined label for a Notes-tab row.
    func accessibleNote(_ note: Note) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(AccessibilityFormatters.noteLabel(note))
            .accessibilityHint("Double tap to open the note.")
            .accessibilityAddTraits(.isButton)
    }
```

And to `AccessibilityFormatters`:

```swift
    static func noteLabel(_ note: Note) -> String {
        let kind = note.kind == .goal ? "goal" : "note"
        let title = note.title.isEmpty ? "Untitled" : note.title
        return "\(title), \(kind)"
    }
```

- [ ] **Step 4: Run to verify pass**

Run: the test command with `-only-testing:WeeklyPlannerTests/NoteAccessibilityTests`
Expected: PASS — 2 tests.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Accessibility/ WeeklyPlannerTests/Accessibility/
git commit -m "feat(notes): accessibility IDs, noteLabel formatter, accessibleNote modifier (Phase 33)"
```

---

### Task 5: Leaf components — header, add-row, list, row, editor

**Files:**
- Create: `WeeklyPlanner/Features/Notes/NotesHeader.swift`
- Create: `WeeklyPlanner/Features/Notes/NewNoteRow.swift`
- Create: `WeeklyPlanner/Features/Notes/NotesListView.swift`
- Create: `WeeklyPlanner/Features/Notes/NoteRow.swift`
- Create: `WeeklyPlanner/Features/Notes/NoteEditorView.swift`

No new logic beyond what Tasks 1–4 tested — these are declarative views. Verification is compile + previews; behavior is covered by Task 8's UI test. String literals auto-extract into `Localizable.xcstrings` at build (repo convention — `isCommentAutoGenerated` entries); do not hand-edit the catalog.

- [ ] **Step 1: `NotesHeader.swift`** (mirrors `SettingsHeader` exactly — same paddings, gradient rule)

```swift
import SwiftUI

/// Top-of-page banner for the Notes tab. Mirrors `SettingsHeader`.
struct NotesHeader: View {
    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Notes")
                .font(font.font(at: 30 * size.scale, weight: .bold))
                .foregroundStyle(theme.ink)
                .padding(EdgeInsets(top: 14, leading: 18, bottom: 4, trailing: 18))

            Text("Goals, scraps, anything.")
                .font(.custom("Cochin-Italic", size: 12))
                .foregroundStyle(theme.ink2)
                .italic()
                .padding(EdgeInsets(top: 0, leading: 18, bottom: 6, trailing: 18))

            LinearGradient(stops: [
                .init(color: theme.ink, location: 0.0),
                .init(color: theme.ink, location: 0.6),
                .init(color: .clear, location: 1.0),
            ], startPoint: .leading, endPoint: .trailing)
                .opacity(0.4)
                .frame(height: 2)
                .padding(EdgeInsets(top: 6, leading: 18, bottom: 8, trailing: 18))
        }
    }
}

#Preview("NotesHeader · cream") {
    NotesHeader()
        .padding(.leading, 32)
        .background(PaperTheme.cream.cream)
        .paperTheme(.cream)
}
```

- [ ] **Step 2: `NewNoteRow.swift`**

```swift
import SwiftUI

/// "+ New note" affordance under the header.
struct NewNoteRow: View {
    let action: () -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                Text("New note")
                    .font(font.font(at: 17 * size.scale, weight: .regular))
            }
            .foregroundStyle(theme.blueInk)
            .padding(.vertical, 10)
            .padding(.leading, 18)
            .padding(.trailing, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New note")
        .accessibilityHint("Double tap to write a new note.")
        .accessibilityIdentifier(AccessibilityIDs.notesAddRow)
    }
}

#Preview("NewNoteRow · cream") {
    NewNoteRow {}
        .background(PaperTheme.cream.cream)
        .paperTheme(.cream)
}
```

- [ ] **Step 3: `NoteRow.swift`**

```swift
import SwiftUI

/// One note preview row: bold title line, single faint body line, and a
/// red-ink "goal" tag for goal-kind notes.
struct NoteRow: View {
    let note: Note
    let action: () -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(note.title.isEmpty ? "Untitled" : note.title)
                        .font(font.font(at: 18 * size.scale, weight: .bold))
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)
                    if note.kind == .goal {
                        Text("goal")
                            .font(font.font(at: 12 * size.scale, weight: .regular))
                            .foregroundStyle(theme.redInk)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(theme.redInk.opacity(0.5), lineWidth: 0.5)
                            )
                    }
                }
                if !note.body.isEmpty {
                    Text(note.body)
                        .font(font.font(at: 14 * size.scale, weight: .regular))
                        .foregroundStyle(theme.ink2)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 9)
            .padding(.leading, 18)
            .padding(.trailing, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Rectangle().fill(theme.ruleSoft).frame(height: 0.5)
            }
        }
        .buttonStyle(.plain)
        .accessibleNote(note)
        .accessibilityIdentifier(AccessibilityIDs.notesRow(note.id))
    }
}

#Preview("NoteRow · goal + misc") {
    VStack(spacing: 0) {
        NoteRow(note: Note(title: "Marathon", body: "Sub-4 this year", kind: .goal)) {}
        NoteRow(note: Note(title: "Groceries", body: "milk, eggs, bread", kind: .misc)) {}
    }
    .background(PaperTheme.cream.cream)
    .paperTheme(.cream)
}
```

- [ ] **Step 4: `NotesListView.swift`**

```swift
import SwiftUI

/// The notes list (or its empty state). Delete is exposed as a context
/// menu on each row — same affordance events use.
struct NotesListView: View {
    let notes: [Note]
    let onOpen: (Note) -> Void
    let onDelete: (Note) -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    var body: some View {
        if notes.isEmpty {
            Text("No notes yet — goals, lists, anything.")
                .font(font.font(at: 16 * size.scale, weight: .regular).italic())
                .foregroundStyle(theme.ink2)
                .padding(.vertical, 18)
                .padding(.leading, 18)
                .padding(.trailing, 18)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(notes, id: \.id) { note in
                    NoteRow(note: note) { onOpen(note) }
                        .contextMenu {
                            Button(role: .destructive) {
                                onDelete(note)
                            } label: {
                                Label("Delete note", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }
}
```

- [ ] **Step 5: `NoteEditorView.swift`**

```swift
import SwiftUI

/// Which note the editor is showing.
enum NoteEditorMode: Equatable {
    case new
    case existing(UUID)
}

/// Create/edit a note: ink title field, kind chips, ruled-paper body.
/// Back and Done both commit (auto-save semantics); an all-empty new
/// draft is discarded by `NotesViewModel.create`.
struct NoteEditorView: View {
    let mode: NoteEditorMode
    let viewModel: NotesViewModel
    let onClose: () -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    @State private var title = ""
    @State private var bodyText = ""
    @State private var kind: NoteKind = .misc
    @FocusState private var titleFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                InkTextField("Title", text: $title, variant: .title, focus: $titleFocused)
                    .padding(.trailing, 18)
                    .padding(.bottom, 10)

                kindPicker

                TextEditor(text: $bodyText)
                    .font(font.font(at: 17 * size.scale, weight: .regular))
                    .foregroundStyle(theme.ink)
                    .tint(theme.blueInk)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 180)
                    .padding(.trailing, 14)
                    .accessibilityLabel("Note body")
                    .accessibilityIdentifier(AccessibilityIDs.notesEditorBody)

                if case .existing = mode {
                    deleteButton
                }
            }
            .padding(.leading, 32)
            .padding(.bottom, 92)
        }
        .scrollDismissesKeyboard(.interactively)
        .task { await hydrate() }
    }

    private var header: some View {
        HStack {
            Button {
                Task { await commit() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Notes")
                        .font(font.font(at: 16 * size.scale, weight: .regular))
                }
                .foregroundStyle(theme.blueInk)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to notes")
            .accessibilityIdentifier(AccessibilityIDs.notesEditorBack)

            Spacer()

            Button {
                Task { await commit() }
            } label: {
                Text("Done")
                    .font(font.font(at: 16 * size.scale, weight: .bold))
                    .foregroundStyle(theme.blueInk)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityIDs.notesEditorDone)
        }
        .padding(.top, 14)
        .padding(.trailing, 18)
        .padding(.bottom, 10)
    }

    private var kindPicker: some View {
        HStack(spacing: 10) {
            kindChip(.misc, label: "Note")
            kindChip(.goal, label: "Goal")
            Spacer(minLength: 0)
        }
        .padding(.bottom, 10)
        .padding(.trailing, 18)
    }

    private func kindChip(_ value: NoteKind, label: String) -> some View {
        Button { kind = value } label: {
            Text(label)
                .font(font.font(at: 14 * size.scale, weight: kind == value ? .bold : .regular))
                .foregroundStyle(kind == value ? theme.redInk : theme.ink2)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(kind == value ? theme.redInk : theme.ink3,
                                      lineWidth: kind == value ? 1 : 0.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(kind == value ? [.isButton, .isSelected] : .isButton)
    }

    private var deleteButton: some View {
        Button {
            Task {
                if case let .existing(id) = mode {
                    await viewModel.delete(id: id)
                }
                onClose()
            }
        } label: {
            Text("Delete note")
                .font(font.font(at: 15 * size.scale, weight: .regular))
                .foregroundStyle(theme.redInk)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
        .accessibilityIdentifier(AccessibilityIDs.notesEditorDelete)
    }

    private func hydrate() async {
        switch mode {
        case .new:
            titleFocused = true
        case let .existing(id):
            if let note = viewModel.notes.first(where: { $0.id == id }) {
                title = note.title
                bodyText = note.body
                kind = note.kind
            }
        }
    }

    private func commit() async {
        switch mode {
        case .new:
            await viewModel.create(title: title, body: bodyText, kind: kind)
        case let .existing(id):
            await viewModel.update(id: id, title: title, body: bodyText, kind: kind)
        }
        onClose()
    }
}
```

⚠️ If `InkTextField`'s focus parameter spelling differs (`focus:` is correct per `EditableFields/InkTextField.swift` — `init(_:text:variant:focus:)`), match the actual signature.

- [ ] **Step 6: Compile check**

Run: the test command with `-only-testing:WeeklyPlannerTests/NotesViewModelTests`
Expected: PASS (everything compiles; prior tests stay green).

- [ ] **Step 7: Commit**

```bash
git add WeeklyPlanner/Features/Notes/
git commit -m "feat(notes): header, add-row, list, row, and editor components (Phase 33)"
```

---

### Task 6: `PaperNotesView` page

**Files:**
- Create: `WeeklyPlanner/Features/Notes/PaperNotesView.swift`

- [ ] **Step 1: Implement** (chrome composition copied from `PaperSettingsView`)

```swift
import SwiftUI

/// The Notes tab page: standard paper-book chrome hosting the notes list,
/// which swaps to the editor in place (no sheet).
struct PaperNotesView: View {
    @Environment(\.noteStore) private var noteStore
    @Environment(\.paperTheme) private var theme

    @State private var viewModel: NotesViewModel?
    @State private var editing: NoteEditorMode?

    var body: some View {
        BookPage {
            PaperSurface {
                ZStack(alignment: .topLeading) {
                    PaperGrain()
                    RuledLines()
                    RedMarginLine()
                    HolePunches()

                    if let viewModel {
                        if let editing {
                            NoteEditorView(mode: editing, viewModel: viewModel) {
                                self.editing = nil
                            }
                        } else {
                            list(viewModel)
                        }
                    } else {
                        ProgressView().padding(.top, 60)
                    }
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = NotesViewModel(store: noteStore)
            }
            await viewModel?.load()
        }
    }

    private func list(_ vm: NotesViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                NotesHeader()
                NewNoteRow { editing = .new }
                NotesListView(notes: vm.notes,
                              onOpen: { editing = .existing($0.id) },
                              onDelete: { note in
                                  Task { await vm.delete(id: note.id) }
                              })
            }
            .padding(.leading, 32) // clear the red margin
            .padding(.bottom, 92)  // PaperTabBar clearance
        }
    }
}

#Preview("PaperNotesView · stub store") {
    PaperNotesView()
        .environment(\.noteStore, StubNoteStore())
        .paperTheme(.cream)
}
```

- [ ] **Step 2: Compile check**

Run: the test command with `-only-testing:WeeklyPlannerTests/NotesViewModelTests`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Features/Notes/PaperNotesView.swift
git commit -m "feat(notes): PaperNotesView paper page with in-place list/editor swap (Phase 33)"
```

---

### Task 7: Tab plumbing — `.notes` case, icon/label, route

**Files:**
- Modify: `WeeklyPlanner/Navigation/TabSelection.swift`
- Modify: `WeeklyPlanner/Navigation/PaperTab.swift`
- Modify: `WeeklyPlanner/Navigation/AppShell.swift`
- Test: `WeeklyPlannerTests/Navigation/TabSelectionNotesTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class TabSelectionNotesTests: XCTestCase {
    private var container: ModelContainer!
    private var settings: SwiftDataSettingsStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        settings = SwiftDataSettingsStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        settings = nil
        container = nil
        try await super.tearDown()
    }

    func testTabOrderIsCalendarReviewNotesSettings() {
        // User decision 2026-06-04: Notes sits between Review and Settings.
        XCTAssertEqual(Tab.allCases, [.calendar, .review, .notes, .settings])
    }

    func testNotesSelectionPersistsAcrossRelaunch() throws {
        let selection = TabSelection(settings: settings)
        selection.current = .notes
        XCTAssertEqual(try settings.current().lastTabRaw, "notes")

        let relaunched = TabSelection(settings: settings)
        XCTAssertEqual(relaunched.current, .notes)
    }

    func testUnknownRawValueFallsBackToCalendar() throws {
        try settings.update { $0.lastTabRaw = "garbage" }
        let selection = TabSelection(settings: settings)
        XCTAssertEqual(selection.current, .calendar)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: the test command with `-only-testing:WeeklyPlannerTests/TabSelectionNotesTests`
Expected: FAIL — `Tab` has no member `notes` (compile failure).

- [ ] **Step 3: Implement**

`TabSelection.swift` — add the case in declaration order (order drives both the bar and `allCases`):

```swift
enum Tab: String, CaseIterable, Hashable, Sendable {
    case calendar
    case review
    case notes
    case settings
}
```

`PaperTab.swift` — extend both computed switches:

```swift
    private var iconName: String {
        switch tab {
        case .calendar: return "calendar"
        case .review: return "tray"
        case .notes: return "note.text"
        case .settings: return "gearshape"
        }
    }

    private var label: String {
        switch tab {
        case .calendar: return "Calendar"
        case .review: return "Review"
        case .notes: return "Notes"
        case .settings: return "Settings"
        }
    }
```

`AppShell.swift` — extend the routing switch (around line 76):

```swift
            switch selection.current {
            case .calendar:
                calendarTab
            case .review:
                PaperReviewView(weekOffset: controller.current.week)
            case .notes:
                PaperNotesView()
            case .settings:
                PaperSettingsView()
            }
```

`PaperTabBar` needs **no change** (`ForEach(Tab.allCases)`).

- [ ] **Step 4: Run to verify pass**

Run: the test command with `-only-testing:WeeklyPlannerTests/TabSelectionNotesTests`
Expected: PASS — 3 tests.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Navigation/ WeeklyPlannerTests/Navigation/
git commit -m "feat(notes): 4th Notes tab — enum case, icon/label, AppShell route (Phase 33)"
```

---

### Task 8: UI test — create, relaunch, persist, delete

**Files:**
- Create: `WeeklyPlannerUITests/NotesTabUITests.swift`

- [ ] **Step 1: Write the UI test**

```swift
import XCTest

final class NotesTabUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testCreateNotePersistsAcrossRelaunchAndDeletes() {
        let app = XCUIApplication()
        app.launch()

        let notesTab = app.buttons["tabbar.tab.notes"]
        XCTAssertTrue(notesTab.waitForExistence(timeout: 5), "Notes tab missing from tab bar")
        notesTab.tap()

        let addRow = app.buttons["notes.addRow"]
        XCTAssertTrue(addRow.waitForExistence(timeout: 3))
        addRow.tap()

        let title = "UITest Note \(UUID().uuidString.prefix(6))"
        let titleField = app.textFields.firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 2)
        titleField.typeText(String(title))

        app.buttons["notes.editor.done"].tap()

        let predicate = NSPredicate(format: "label CONTAINS %@", String(title))
        let row = app.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "New note row not visible after Done")

        // Relaunch — the note must persist (and lastTab restores Notes).
        app.terminate()
        app.launch()
        let notesTabAgain = app.buttons["tabbar.tab.notes"]
        if notesTabAgain.waitForExistence(timeout: 5) { notesTabAgain.tap() }
        let rowAfterRelaunch = app.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(rowAfterRelaunch.waitForExistence(timeout: 5), "Note did not survive relaunch")

        // Cleanup: open and delete via the editor.
        rowAfterRelaunch.tap()
        let delete = app.buttons["notes.editor.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        delete.tap()
        XCTAssertTrue(rowAfterRelaunch.waitForNonExistence(timeout: 5), "Deleted note still visible")
    }
}
```

- [ ] **Step 2: Run it**

Run: the test command with `-only-testing:WeeklyPlannerUITests/NotesTabUITests`
Expected: PASS — 1 test. (Uses a unique title, so leftover simulator data from other suites can't collide.)

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlannerUITests/NotesTabUITests.swift
git commit -m "test(notes): UI flow — create, relaunch persistence, delete (Phase 33)"
```

---

### Task 9: Full-suite verification (superpowers:verification-before-completion)

- [ ] **Step 1: Run the FULL unit suite**

```bash
xcodegen generate
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=<available iPhone, iOS 26.5>' \
  -only-testing:WeeklyPlannerTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO
```

Expected: `** TEST SUCCEEDED **`, 0 failures (Phase 21 accessibility audits included).

- [ ] **Step 2: Run the UI suites touched**

Same command with `-only-testing:WeeklyPlannerUITests/NotesTabUITests -only-testing:WeeklyPlannerUITests/SmokeUITests`
Expected: PASS.

- [ ] **Step 3: Spec checklist sweep** — re-read `docs/phases/phase-33-notes-tab.md` checkboxes against the diff. Confirm: 4th tab renders with index-tab treatment (inherited from `PaperTab` automatically), notes persist across tab switches and relaunch, paper aesthetic (handwriting + ruled lines) respected, kind flag works, `dayKey` stays nil, store mutations post `.noteStoreDidChange`.

- [ ] **Step 4: Screenshot** the Notes page (list with 2–3 notes + editor) for the acceptance record; compare visual tone against `docs/mock/` pages.

- [ ] **Step 5: Commit any stragglers and report** — branch, files, test counts, deviations.

---

## Self-review notes

- **Spec coverage:** model+store (Task 1–2), VM (3), a11y (4), views incl. empty state + ink styling (5–6), 4th tab + persistence (7), UI persistence test (8), full suite (9). Out-of-scope items (rich text, sync, folders) untouched. Tab order locked by test.
- **Type consistency:** `NoteStoring.notes()/note(id:)/upsert/delete`, `NotesViewModel.create(title:body:kind:)/update(id:title:body:kind:)/delete(id:)`, `NoteEditorMode.new/.existing(UUID)` used identically across Tasks 1–8. `Note.body` property name is safe (model class, not a View).
- **Known intermediate states:** none — each task compiles standalone (views land before the tab routes to them).
- **Risk:** `body` as a stored-property name on an `@Model` — if the macro chokes (it shouldn't), rename to `bodyText` everywhere including tests in the same task.
