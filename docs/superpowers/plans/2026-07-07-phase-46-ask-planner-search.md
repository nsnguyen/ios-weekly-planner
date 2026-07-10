# Phase 46 — Ask the Planner Search Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Questions retrieve from ALL user content (events incl. location/notes, to-dos, free-text annotations, Notes-tab notes); a literal keyword mode works without Apple Intelligence; the canned-answer fallback becomes content-backed; the "Answered on-device · N s" footer is removed (suggestions #81, #82, #83).

**Architecture:** One retrieval core — `KeywordSearchService` — sits under three consumers: (1) a new `searchPlanner` FoundationModels tool the LLM can call, (2) a literal "Find a word" mode in the Ask sheet, (3) the `StubIntelligenceService` fallback, which stops returning canned prose and starts formatting real matches. Store layer grows the minimal fetch surface the service needs (`allAnnotations()`, richer event keyword matching, week-window task fetch). `elapsedSeconds` and its footer are deleted end-to-end.

**Tech Stack:** SwiftUI, SwiftData, FoundationModels (`#if canImport` gated), XCTest, XcodeGen.

## Global Constraints

- iOS 26.0+, Swift 6 strict concurrency. `xcodegen generate` after adding files. Canonical test command:

```bash
xcodegen generate
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=<available iPhone, iOS 26.5>' \
  -only-testing:<filter> \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO
```

- The dated-content search window is **±8 weeks** (matches `LastInteractionTool`'s look-back); notes and annotations are searched unbounded.
- "Ask the planner" branding (Phase 32) is locked — `AISearchTopBarTests` pins the copy; don't touch titles.
- Keyword-mode copy: pill label **"Find a word"**, placeholder **"Type a word — e.g. swim"**, group headers **"Events" / "To-dos" / "Notes" / "Free text"**.
- Lint: changed files only, no new violations.

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `WeeklyPlanner/Intelligence/KeywordSearchService.swift` | NEW | cross-store literal retrieval core |
| `WeeklyPlanner/Stores/AnnotationStore.swift` | MODIFY | `allAnnotations()` |
| `WeeklyPlanner/Stores/EventStore.swift` | MODIFY | keyword match covers location+notes |
| `WeeklyPlanner/Stores/TaskStore.swift` | MODIFY | `tasks(inWeekOffsets:today:)` |
| `WeeklyPlanner/Intelligence/Tools/SearchPlannerTool.swift` | NEW | LLM-facing tool over the service |
| `WeeklyPlanner/Intelligence/FoundationModelTools.swift` | MODIFY | `@Generable` adapter for the tool |
| `WeeklyPlanner/Intelligence/Tools/ToolRegistry.swift` | MODIFY | + annotation/note stores |
| `WeeklyPlanner/Intelligence/SystemPrompt.swift` | MODIFY | + capability line |
| `WeeklyPlanner/Intelligence/PlannerLanguageModel.swift` | MODIFY | register 6th tool; drop elapsed stamp |
| `WeeklyPlanner/Intelligence/StubIntelligenceService.swift` | MODIFY | content-backed fallback |
| `WeeklyPlanner/Features/AISearch/AISearchModels.swift` | MODIFY | drop `elapsedSeconds`; retire canned content answers |
| `WeeklyPlanner/Features/AISearch/AnswerBlock.swift` | MODIFY | footer removal |
| `WeeklyPlanner/Features/AISearch/AISearchViewModel.swift` | MODIFY | keyword mode |
| `WeeklyPlanner/Features/AISearch/AISearchPaperSheet.swift` | MODIFY | mode pill + results list host |
| `WeeklyPlanner/Features/AISearch/KeywordResultsList.swift` | NEW | grouped results UI |
| `WeeklyPlanner/Navigation/AppShell.swift` | MODIFY | registry/service wiring |
| `WeeklyPlanner/Accessibility/AccessibilityIDs.swift` | MODIFY | new ids |
| tests | NEW/MODIFY | per task |

---

### Task 1: Store fetch surface

**Files:**
- Modify: `WeeklyPlanner/Stores/AnnotationStore.swift` (protocol ~:5 + impl + stub), `WeeklyPlanner/Stores/EventStore.swift` (`events(matching:)` ~:121–143), `WeeklyPlanner/Stores/TaskStore.swift` (protocol ~:5)
- Test: extend `WeeklyPlannerTests/Annotations/AnnotationStoreTests.swift`, `WeeklyPlannerTests/Stores/EventStoreTests.swift` (+ task-store suite — grep its name)

- [ ] **Step 1: Write the failing tests.**

`AnnotationStoreTests` (append; reuse the file's in-memory fixtures):

```swift
    func testAllAnnotationsReturnsEveryDayKey() async throws {
        _ = try await store.upsert(makeAnnotation(dayKey: "0:1", text: "swim laps"))
        _ = try await store.upsert(makeAnnotation(dayKey: "2:4", text: "call mom"))
        let all = try await store.allAnnotations()
        XCTAssertEqual(Set(all.map(\.dayKey)), ["0:1", "2:4"])
    }
```

`EventStoreTests` (append; use the file's `may16_2026`-style fixtures):

```swift
    func testKeywordMatchesLocationAndNotes() throws {
        try store.add(makeEvent(title: "Morning workout", location: "Swim center"))
        try store.add(makeEvent(title: "Sync", notes: "bring swim gear for after"))
        try store.add(makeEvent(title: "Dinner"))

        let query = EventQuery(dateRange: wideRange(), categories: [], keywords: ["swim"], personName: nil)
        let hits = try store.events(matching: query)
        XCTAssertEqual(hits.count, 2, "keyword must match title, location, AND notes")
    }
```

Task store: add a test that `tasks(inWeekOffsets: -1...1, today:)` unions the three weeks (mirror the store's existing single-week test fixtures).

⚠️ Match each store's real method/fixture shapes — `upsert` vs `add`, throwing vs async — read the test file's existing cases first; assertion INTENT is fixed.

- [ ] **Step 2: Run to verify failure.** Expected: compile failures.

- [ ] **Step 3: Implement.**

`AnnotationStoring` gains `func allAnnotations() async throws -> [Annotation]`; SwiftData impl = unfiltered `FetchDescriptor<Annotation>(sortBy: [SortDescriptor(\.createdAt)])`; `StubAnnotationStore` returns its backing array.

`EventStore.events(matching:)` in-memory filter (~:133–140) extends from title-only to:

```swift
            let haystack = [event.title, event.location ?? "", event.notes ?? ""]
                .joined(separator: " ")
                .lowercased()
            return query.keywords.allSatisfy { haystack.contains($0.lowercased()) }
```

(fit into the existing keyword/person filter structure; person matching unchanged).

`TaskStoring` gains `func tasks(inWeekOffsets: ClosedRange<Int>, today: Date) throws -> [TaskItem]` implemented as a union of the existing per-week fetch (loop, like `LastInteractionTool` does for events).

- [ ] **Step 4: Run to verify pass** — the three store suites. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Stores/ WeeklyPlannerTests/
git commit -m "feat(stores): allAnnotations, location/notes keyword match, multi-week tasks (Phase 46 #81)"
```

---

### Task 2: `KeywordSearchService` — the retrieval core

**Files:**
- Create: `WeeklyPlanner/Intelligence/KeywordSearchService.swift`
- Test: `WeeklyPlannerTests/Intelligence/KeywordSearchServiceTests.swift` (NEW)

**Interfaces:**
- Consumes: `EventStoring.events(matching:)`, `TaskStoring.tasks(inWeekOffsets:today:)`, `AnnotationStoring.allAnnotations()`, `NoteStoring.notes()` (already exists).
- Produces:

```swift
struct KeywordMatch: Identifiable, Equatable {
    enum Kind: String, CaseIterable { case event, task, note, annotation }
    let id: String            // "<kind>:<underlying id>"
    let kind: Kind
    let title: String         // display line (event title, task title, note title, annotation excerpt)
    let detail: String?       // date line / note body excerpt
    let eventID: UUID?        // set for events → citation navigation
    let date: Date?           // for sorting; nil = undated (notes)
}

@MainActor
final class KeywordSearchService {
    init(events: any EventStoring, tasks: any TaskStoring,
         annotations: any AnnotationStoring, notes: any NoteStoring)
    /// Case-insensitive literal search across all content.
    /// Dated content bounded to ±8 weeks around `now`.
    func search(_ term: String, now: Date) async throws -> [KeywordMatch]
}
```

- [ ] **Step 1: Write the failing tests** (stub stores from `Environment+Stores.swift` / test fakes already exist for all four — reuse):

```swift
import XCTest
@testable import WeeklyPlanner

@MainActor
final class KeywordSearchServiceTests: XCTestCase {
    // setUp: build service over Stub stores seeded with:
    //  event "Swim meet" (location "Pool"), event "Dinner",
    //  task "Buy swim goggles", note (title "Training", body "swim drills"),
    //  annotation "swim with kids Saturday"

    func testFindsMatchesAcrossAllFourKinds() async throws {
        let matches = try await service.search("swim", now: fixedNow)
        XCTAssertEqual(Set(matches.map(\.kind)), [.event, .task, .note, .annotation])
        XCTAssertEqual(matches.filter { $0.kind == .event }.count, 1)
    }

    func testCaseInsensitiveAndTrimmed() async throws {
        let matches = try await service.search("  SWIM ", now: fixedNow)
        XCTAssertFalse(matches.isEmpty)
    }

    func testEmptyTermReturnsNothing() async throws {
        let matches = try await service.search("   ", now: fixedNow)
        XCTAssertTrue(matches.isEmpty)
    }

    func testEventMatchCarriesEventIDForNavigation() async throws {
        let event = try XCTUnwrap(try await service.search("swim", now: fixedNow)
            .first { $0.kind == .event })
        XCTAssertNotNil(event.eventID)
    }

    func testDatedMatchesSortedAscendingUndatedLast() async throws {
        let matches = try await service.search("swim", now: fixedNow)
        let dates = matches.compactMap(\.date)
        XCTAssertEqual(dates, dates.sorted())
        XCTAssertNil(matches.last?.date, "undated notes sort after dated content")
    }
}
```

- [ ] **Step 2: Run to verify failure.** Expected: compile failure.

- [ ] **Step 3: Implement**:

```swift
import Foundation

/// Literal cross-content retrieval (Phase 46 #81/#82). One core under
/// three consumers: the searchPlanner LLM tool, the "Find a word" UI, and
/// the no-AI fallback answer.
@MainActor
final class KeywordSearchService {
    private let events: any EventStoring
    private let tasks: any TaskStoring
    private let annotations: any AnnotationStoring
    private let notes: any NoteStoring

    /// Dated content window, in weeks around today.
    static let weekWindow = -8...8

    init(events: any EventStoring, tasks: any TaskStoring,
         annotations: any AnnotationStoring, notes: any NoteStoring) {
        self.events = events
        self.tasks = tasks
        self.annotations = annotations
        self.notes = notes
    }

    func search(_ term: String, now: Date) async throws -> [KeywordMatch] {
        let needle = term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return [] }

        var matches: [KeywordMatch] = []

        let range = Self.dateRange(around: now)
        let query = EventQuery(dateRange: range, categories: [], keywords: [needle], personName: nil)
        for event in try events.events(matching: query) {
            matches.append(KeywordMatch(id: "event:\(event.id)", kind: .event,
                                        title: event.title,
                                        detail: Self.dayLine(for: event.start),
                                        eventID: event.id, date: event.start))
        }

        for task in try tasks.tasks(inWeekOffsets: Self.weekWindow, today: now)
        where Self.hit(needle, in: [task.title, task.reminderText ?? ""]) {
            matches.append(KeywordMatch(id: "task:\(task.id)", kind: .task,
                                        title: task.title,
                                        detail: task.due.map(Self.dayLine(for:)),
                                        eventID: nil, date: task.due))
        }

        for note in try await notes.notes()
        where Self.hit(needle, in: [note.title, note.body]) {
            matches.append(KeywordMatch(id: "note:\(note.id)", kind: .note,
                                        title: note.title.isEmpty ? String(note.body.prefix(40)) : note.title,
                                        detail: String(note.body.prefix(80)),
                                        eventID: nil, date: nil))
        }

        for annotation in try await annotations.allAnnotations()
        where Self.hit(needle, in: [annotation.text]) {
            matches.append(KeywordMatch(id: "annotation:\(annotation.id)", kind: .annotation,
                                        title: annotation.text,
                                        detail: Self.dayLine(forDayKey: annotation.dayKey, now: now),
                                        eventID: nil,
                                        date: Self.date(forDayKey: annotation.dayKey, now: now)))
        }

        return matches.sorted { lhs, rhs in
            switch (lhs.date, rhs.date) {
            case let (l?, r?): return l < r
            case (nil, _?): return false
            case (_?, nil): return true
            case (nil, nil): return lhs.title < rhs.title
            }
        }
    }

    private static func hit(_ needle: String, in fields: [String]) -> Bool {
        fields.contains { $0.lowercased().contains(needle) }
    }

    private static func dateRange(around now: Date) -> ClosedRange<Date> {
        let cal = WeekMath.preferredCalendar
        let lower = cal.date(byAdding: .weekOfYear, value: weekWindow.lowerBound, to: now) ?? now
        let upper = cal.date(byAdding: .weekOfYear, value: weekWindow.upperBound, to: now) ?? now
        return lower...upper
    }

    // dayLine(for:), dayLine(forDayKey:now:), date(forDayKey:now:):
    // format via the app's existing date helpers (WeekMath / DayKey utils —
    // grep "dayKey" in Stores/ for the canonical parser) as short lines
    // like "Sat 11 Jul". Reuse, don't reinvent.
}
```

⚠️ Adaptation points, all mechanical: `EventQuery.dateRange`'s exact type (range vs pair — mirror `FoundationModelTools.swift:64-85`), `TaskItem.due` optionality, `Note.id` type, the dayKey→Date parser location, and 36b interaction (`WeekMath.preferredCalendar` exists only after 36b — if 36b hasn't landed, use `WeekMath.mondayCalendar()` and leave a `// 36b: sweep to preferredCalendar` comment).

- [ ] **Step 4: Run to verify pass** — `-only-testing:WeeklyPlannerTests/KeywordSearchServiceTests`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Intelligence/KeywordSearchService.swift WeeklyPlannerTests/Intelligence/KeywordSearchServiceTests.swift
git commit -m "feat(search): KeywordSearchService — literal retrieval across all content (Phase 46 #81 #82)"
```

---

### Task 3: `searchPlanner` tool + registry + system prompt

**Files:**
- Create: `WeeklyPlanner/Intelligence/Tools/SearchPlannerTool.swift`
- Modify: `WeeklyPlanner/Intelligence/Tools/ToolRegistry.swift` (~:21), `WeeklyPlanner/Intelligence/FoundationModelTools.swift`, `WeeklyPlanner/Intelligence/SystemPrompt.swift` (~:27–32), `WeeklyPlanner/Intelligence/PlannerLanguageModel.swift` (~:85–96), `WeeklyPlanner/Navigation/AppShell.swift` (~:207–211)
- Test: `WeeklyPlannerTests/Intelligence/SearchPlannerToolTests.swift` (NEW), update `ToolRegistryTests.swift`, `SystemPromptTests.swift`

- [ ] **Step 1: Write the failing tests.**

`SearchPlannerToolTests` (mirror `FindEventsToolTests`' structure — stub stores in, formatted result out):

```swift
    func testReturnsMatchesGroupedByKind() async throws {
        let result = try await tool.run(term: "swim")
        XCTAssertTrue(result.contains("Swim meet"), "event hit")
        XCTAssertTrue(result.contains("Buy swim goggles"), "task hit")
        XCTAssertTrue(result.contains("swim drills"), "note hit")
        XCTAssertTrue(result.contains("swim with kids"), "annotation hit")
    }

    func testNoMatchesSaysSoPlainly() async throws {
        let result = try await tool.run(term: "zebra")
        XCTAssertTrue(result.localizedCaseInsensitiveContains("no matches"))
    }
```

`ToolRegistryTests`: update construction to `ToolRegistry(events:tasks:inbox:annotations:notes:)` (all call sites). `SystemPromptTests`: pin the new capability line:

```swift
    func testPromptAdvertisesSearchPlanner() {
        XCTAssertTrue(SystemPrompt.default.contains("searchPlanner"))
    }
```

- [ ] **Step 2: Run to verify failure.** Expected: compile failures.

- [ ] **Step 3: Implement.**

`SearchPlannerTool.swift` — plain tool the FM adapter wraps (mirror `FindEventsTool`'s split):

```swift
import Foundation

/// LLM-facing literal search over ALL planner content (Phase 46 #81).
@MainActor
struct SearchPlannerTool {
    let service: KeywordSearchService
    let now: () -> Date

    func run(term: String) async throws -> String {
        let matches = try await service.search(term, now: now())
        guard !matches.isEmpty else { return "No matches for \"\(term)\" anywhere in the planner." }
        let grouped = Dictionary(grouping: matches, by: \.kind)
        return KeywordMatch.Kind.allCases.compactMap { kind -> String? in
            guard let hits = grouped[kind], !hits.isEmpty else { return nil }
            let lines = hits.map { "- \($0.title)\($0.detail.map { d in " (\(d))" } ?? "")" }
            return "\(label(for: kind)):\n" + lines.joined(separator: "\n")
        }.joined(separator: "\n\n")
    }

    private func label(for kind: KeywordMatch.Kind) -> String {
        switch kind {
        case .event: "Events"
        case .task: "To-dos"
        case .note: "Notes"
        case .annotation: "Free text"
        }
    }
}
```

`FoundationModelTools.swift` — add the `@Generable` adapter beside the five (copy `FoundationScanInboxTool`'s shape):

```swift
@available(iOS 26.0, *)
struct FoundationSearchPlannerTool: Tool {
    let name = "searchPlanner"
    let description = """
        Literal search across EVERYTHING the user wrote: event titles,
        locations and notes; to-dos; Notes-tab notes; handwritten free text
        on day pages. Use for any 'what did I write/note/plan about X' or
        'find X' question.
        """

    @Generable
    struct Arguments {
        @Guide(description: "The word or phrase to search for, e.g. 'swim'")
        var term: String
    }

    let tool: SearchPlannerTool

    func call(arguments: Arguments) async throws -> ToolOutput {
        ToolOutput(try await tool.run(term: arguments.term))
    }
}
```

⚠️ Copy the EXACT `Tool` conformance shape from the neighboring five (Phase 18 lesson: `ToolOutput`/`Guide` API names drift between SDK seeds — the neighbors are ground truth, not this sketch; `@Generable` structs also have the Optional gotcha from `phase-18-deviations`: avoid optional properties, require `term`).

`ToolRegistry` — init gains `annotations: any AnnotationStoring, notes: any NoteStoring`; expose a built `searchPlannerTool`. `PlannerLanguageModel.makeSession()` registers the sixth tool. `SystemPrompt.default`'s capability list (~:27–32) gains:

```
- searchPlanner(term): literal search across events, to-dos, notes, and
  handwritten free text. ALWAYS call this for "find/what did I write about
  X" questions before answering.
```

`AppShell.makeIntelligenceService()` — build the service + pass the stores:

```swift
        let keywordSearch = KeywordSearchService(events: eventStore, tasks: taskStore,
                                                 annotations: annotationStore, notes: noteStore)
        let registry = ToolRegistry(events: eventStore, tasks: taskStore, inbox: inboxStore,
                                    annotations: annotationStore, notes: noteStore)
```

(match the real store property names in `AppShell`).

- [ ] **Step 4: Run to verify pass** — `-only-testing:WeeklyPlannerTests/SearchPlannerToolTests -only-testing:WeeklyPlannerTests/ToolRegistryTests -only-testing:WeeklyPlannerTests/SystemPromptTests`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/ WeeklyPlannerTests/
git commit -m "feat(search): searchPlanner LLM tool over all content + prompt routing (Phase 46 #81)"
```

---

### Task 4: Content-backed fallback (kill canned answers)

**Files:**
- Modify: `WeeklyPlanner/Intelligence/StubIntelligenceService.swift` (`ask`, ~:27), `WeeklyPlanner/Features/AISearch/AISearchModels.swift` (`AISearchCannedData`, ~:94–139)
- Test: `WeeklyPlannerTests/Intelligence/StubIntelligenceServiceTests.swift`, `WeeklyPlannerTests/AISearch/AISearchViewModelTests.swift`

- [ ] **Step 1: Write the failing tests.** In `StubIntelligenceServiceTests`, replace canned-mapping tests with content-backed pins:

```swift
    func testAskReturnsRealMatchesNotCannedProse() async throws {
        seedEvent(title: "Swim meet")          // use the file's store-seeding helpers
        seedTask(title: "Buy swim goggles")

        let answer = try await stub.ask(query: "what's happening with swim?", context: makeContext())

        XCTAssertTrue(answer.body.contains("Swim meet"))
        XCTAssertTrue(answer.body.contains("Buy swim goggles"))
        XCTAssertFalse(answer.body.contains("order"), "no invented content")
    }

    func testAskWithNoMatchesIsHonest() async throws {
        let answer = try await stub.ask(query: "zebra migration?", context: makeContext())
        XCTAssertTrue(answer.body.localizedCaseInsensitiveContains("couldn't find"))
    }
```

- [ ] **Step 2: Run to verify failure.** Expected: FAIL (canned table still answers).

- [ ] **Step 3: Implement.** `StubIntelligenceService` gains a `keywordSearch: KeywordSearchService` dependency (inject in `AppShell.makeIntelligenceService()` and test setup). `ask` extracts content words from the query (reuse its existing >3-char tokenizer at ~:67–73), searches each, dedupes matches, and formats via the same grouped-lines shape as `SearchPlannerTool.run` (extract that formatter into `KeywordMatch.groupedSummary(_:)` so both share it — DRY). No matches → `"I couldn't find anything about \"<terms>\" in your planner."`. Delete `AISearchCannedData`'s canned content table; keep only whatever non-content strings other code still references (grep first — `AISearchViewModelTests` references it; rewrite those tests to the new behavior, don't delete coverage). Citation resolution (±4-week title match) stays.

- [ ] **Step 4: Run to verify pass** — `-only-testing:WeeklyPlannerTests/StubIntelligenceServiceTests -only-testing:WeeklyPlannerTests/AISearchViewModelTests`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/ WeeklyPlannerTests/
git commit -m "feat(search): fallback answers from real content — canned table retired (Phase 46 #81)"
```

---

### Task 5: "Find a word" mode in the Ask sheet

**Files:**
- Modify: `WeeklyPlanner/Features/AISearch/AISearchViewModel.swift`, `AISearchPaperSheet.swift`, `PaperAISearchView.swift` (service injection)
- Create: `WeeklyPlanner/Features/AISearch/KeywordResultsList.swift`
- Modify: `WeeklyPlanner/Accessibility/AccessibilityIDs.swift`
- Test: extend `AISearchViewModelTests.swift`; NEW `WeeklyPlannerUITests/AskPlannerKeywordUITests.swift`

**Interfaces:**
- Produces: `AISearchViewModel.mode: SearchMode` (`enum SearchMode { case ask, find }`), `keywordResults: [KeywordMatch]`, `func findWord(_ term: String) async`; a11y ids `AccessibilityIDs.askFindModePill = "asksheet.mode.find"`, `askKeywordResults = "asksheet.keyword.results"`, `askKeywordRow(_ id: String) -> "asksheet.keyword.row.<id>"`.

- [ ] **Step 1: VM tests first** (append to `AISearchViewModelTests`, stub `KeywordSearchService` behind seeded stub stores):

```swift
    func testFindWordPopulatesGroupedResults() async throws {
        seedEvent(title: "Swim meet")
        viewModel.mode = .find
        await viewModel.findWord("swim")
        XCTAssertEqual(viewModel.keywordResults.count, 1)
        XCTAssertNil(viewModel.answer, "find mode does not produce an LLM answer")
    }

    func testSwitchingModesClearsResults() async throws {
        seedEvent(title: "Swim meet")
        viewModel.mode = .find
        await viewModel.findWord("swim")
        viewModel.mode = .ask
        XCTAssertTrue(viewModel.keywordResults.isEmpty)
    }
```

- [ ] **Step 2: Run → FAIL → implement the VM:** `mode` (didSet clears `keywordResults`/`answer`), `findWord` calls the injected `KeywordSearchService` directly (never the LLM — this is why it works with AI off), errors → empty results + reuse the existing error surface. `PaperAISearchView.init` gains the service param (built in the same place the VM gets `eventStore`).

- [ ] **Step 3: UI.** `AISearchPaperSheet`: below the input area, a pill row hosting the mode toggle:

```swift
            QuickActionPill(label: viewModel.mode == .ask ? "Find a word" : "Ask a question",
                            systemImage: "magnifyingglass") {
                viewModel.mode = viewModel.mode == .ask ? .find : .ask
            }
            .accessibilityIdentifier(AccessibilityIDs.askFindModePill)
```

(reuse the existing `QuickActionPill` component; match its real init). In `.find` mode: `AskInputField` placeholder becomes "Type a word — e.g. swim", submit routes to `findWord`, and the state switch renders `KeywordResultsList(results:onTapEvent:)` instead of answer/suggestions. `KeywordResultsList` groups by `kind` with the four locked headers, rows show `title` + `detail` in the paper style (`font.font(at: 15 * size.scale)`), event rows call `onTapEvent(eventID)` → wire to the sheet's existing `onTapCitation` path.

- [ ] **Step 4: UI test** (`AskPlannerKeywordUITests.swift`): launch → open Ask sheet (grep the opener's a11y id in `PaperAISearchView`/top bar) → tap `asksheet.mode.find` → type "swim" → submit → assert `asksheet.keyword.results` exists. Seed determinism: create a "Swim test" event through the UI first (reuse `EventCreateFlowUITests`' helper steps), and delete it at the end (UI-test residue lesson).

- [ ] **Step 5: Run** — `-only-testing:WeeklyPlannerTests/AISearchViewModelTests -only-testing:WeeklyPlannerUITests/AskPlannerKeywordUITests`. Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add WeeklyPlanner/ WeeklyPlannerTests/ WeeklyPlannerUITests/
git commit -m "feat(search): 'Find a word' literal mode in the Ask sheet (Phase 46 #82)"
```

---

### Task 6: Remove the "Answered on-device · N s" footer

**Files:**
- Modify: `WeeklyPlanner/Features/AISearch/AnswerBlock.swift` (footer, ~:113–124; doc :5), `AISearchModels.swift` (`AIAnswer.elapsedSeconds`, ~:35–36), `AISearchViewModel.swift` (~:88, :98), `PlannerLanguageModel.swift` (~:71), `StubIntelligenceService.swift` (~:36)
- Test: `AnswerBlockCleanBodyTests.swift`, `AISearchViewModelTests.swift`

- [ ] **Step 1: Sweep** — `grep -rn "elapsedSeconds\|on-device\|Answered on" WeeklyPlanner/ WeeklyPlannerTests/`. Inventory above; fix anything new.

- [ ] **Step 2: Implement.** In `AnswerBlock.footer`: delete the elapsed-text branch (~:116); KEEP the `unavailableReason.fallbackMessage` branch (availability copy must survive — render it whenever `unavailableReason` warrants, no `else` needed). Remove `AIAnswer.elapsedSeconds` and every writer (five sites above). Update tests that constructed `AIAnswer(elapsedSeconds:)`.

- [ ] **Step 3: Run** — `-only-testing:WeeklyPlannerTests/AnswerBlockCleanBodyTests -only-testing:WeeklyPlannerTests/AISearchViewModelTests -only-testing:WeeklyPlannerTests/StubIntelligenceServiceTests`. Expected: PASS; grep from Step 1 returns zero production hits.

- [ ] **Step 4: Commit**

```bash
git add WeeklyPlanner/ WeeklyPlannerTests/
git commit -m "feat(search): drop 'Answered on-device · Ns' footer (Phase 46 #83)"
```

---

### Task 7: Full verification (superpowers:verification-before-completion)

- [ ] **Step 1: Full unit suite.** Expected: `** TEST SUCCEEDED **`.
- [ ] **Step 2: UI suites** — `AskPlannerKeywordUITests` + existing AISearch-adjacent suites + `SmokeUITests`. Expected: PASS.
- [ ] **Step 3: Simulator manual pass (no Apple Intelligence):** Find-a-word "swim" surfaces seeded event/task/note/annotation; asking a question yields a factual content-backed answer; no footer.
- [ ] **Step 4: On-device pass (Apple Intelligence ON):** ask "what did I note about swim?" — confirm via logs the model calls `searchPlanner` (add a one-line `Logger` in the tool's `call` under the app's existing subsystem — `phase-18-deviations` Logger convention) and the answer cites real content.
- [ ] **Step 5: Phase-doc checklist sweep** — `docs/phases/phase-46-ask-planner-search.md`. Report branch, diffstat, deviations (esp. FM Tool API drift).

---

## Self-review notes

- **Spec coverage:** #81 (T1–T4 + T7 device check), #82 (T2, T5), #83 (T6).
- **Type consistency:** `KeywordMatch`/`KeywordSearchService.search(_:now:)` signatures identical T2/T3/T4/T5; `ToolRegistry(events:tasks:inbox:annotations:notes:)` consistent T3 + AppShell; grouped-summary formatter shared T3/T4 (`KeywordMatch.groupedSummary`); a11y ids match T5 UI↔test.
- **Deliberate choices:** one retrieval core under three consumers (LLM tool, UI mode, fallback) so "works without AI" is structural, not special-cased; ±8-week window mirrors `LastInteractionTool`; canned data dies but its tests are rewritten (coverage preserved); footer removal keeps availability messaging.
- **Known adaptation points (flagged inline):** FM `Tool`/`ToolOutput`/`@Generable` exact shapes (copy neighbors), `EventQuery.dateRange` type, dayKey parser location, store fixture shapes, Ask-sheet opener id, 36b `preferredCalendar` availability.
