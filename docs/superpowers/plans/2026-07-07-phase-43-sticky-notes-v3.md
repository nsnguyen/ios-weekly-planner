# Phase 43 — Sticky Notes v3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** AI sticky notes become grounded-or-silent (built ONLY from the day's real events/to-dos/free-text; empty day → no sticky), never truncate mid-sentence, and become draggable; users can create their own movable sticky notes (suggestions #61, #66).

**Architecture:** `DayContext` (the sole input every insight generator sees) gains `tasks` and `annotationTexts`; `StickyOrchestrator` early-returns on a content-free day instead of falling back to encouragement. Truncation is fixed at both ends: `GenerationOptions(maximumResponseTokens:)` finally gets applied, and the hard `.prefix(n)` chops become a sentence-boundary clip helper. Position: `AIInsight` gains optional `unitX`/`unitY` (nil = legacy top-trailing slot), carried across regeneration by the orchestrator; the stack gets a long-press-drag reposition (horizontal swipe keeps cycling the cascade). User stickies are a new SwiftData model + store + view, mirroring the Phase 34 annotation drag/persist/empty-commit-deletes patterns, independent of the AI toggle.

**Tech Stack:** SwiftUI, SwiftData, FoundationModels (`#if canImport` gated), XCTest, XcodeGen.

## Global Constraints

- iOS 26.0+, Swift 6 strict concurrency, SwiftUI only.
- `xcodegen generate` after adding/deleting files. Canonical test command:

```bash
xcodegen generate
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=<available iPhone, iOS 26.5>' \
  -only-testing:<filter> \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO
```

- AI Sticky Notes stay **opt-in default-off** (`UserSettings.aiStickyNotesEnabled = false`).
- Phase 28 contract: page-flip swipe is suppressed while `stickyDragActive` — every new drag must keep that gate; run `StickySwipeUITests` after any gesture change.
- Lint: changed files only, no new violations.

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `WeeklyPlanner/Intelligence/String+SentenceClip.swift` | NEW | sentence-boundary clip helper |
| `WeeklyPlanner/Intelligence/InsightGenerator.swift` | MODIFY | `DayContext` + `tasks`/`annotationTexts`/`hasContent` |
| `WeeklyPlanner/Intelligence/StickyOrchestrator.swift` | MODIFY | empty-day guard; position carry-over |
| `WeeklyPlanner/Intelligence/Tasks/KeywordInsightGenerator.swift` | MODIFY | grounded prompt; sentence clip |
| `WeeklyPlanner/Intelligence/Tasks/EncouragementInsightGenerator.swift` | MODIFY | grounded prompt; sentence clip |
| `WeeklyPlanner/Intelligence/PlannerLanguageModel.swift` | MODIFY | apply `GenerationOptions` |
| `WeeklyPlanner/Models/AIInsight.swift` | MODIFY | optional `unitX`/`unitY` |
| `WeeklyPlanner/Models/UserStickyNote.swift` | NEW | user sticky model |
| `WeeklyPlanner/Stores/UserStickyStore.swift` | NEW | `UserStickyStoring` + SwiftData impl |
| `WeeklyPlanner/Stores/SwiftDataStack.swift` | MODIFY | register `UserStickyNote` |
| `WeeklyPlanner/Stores/Environment+Stores.swift` | MODIFY | `@Entry userStickyStore` |
| `WeeklyPlanner/WeeklyPlannerApp.swift` + `Navigation/AppShell.swift` | MODIFY | wiring |
| `WeeklyPlanner/Features/DayPage/DayPageViewModel.swift` | MODIFY | context build; sticky position; user-sticky CRUD |
| `WeeklyPlanner/Features/DayPage/DayPageView.swift` | MODIFY | positionable overlay; sticky pad; user layer |
| `WeeklyPlanner/Features/DayPage/AIStickyStack.swift` | MODIFY | long-press-drag reposition |
| `WeeklyPlanner/Features/DayPage/UserStickyView.swift` | NEW | user sticky render/edit/drag |
| `WeeklyPlanner/Accessibility/AccessibilityIDs.swift` | MODIFY | new ids |

**Test-isolation rule:** generator/orchestrator tests build `DayContext` explicitly — every existing `DayContext(...)` call site in tests gains the new parameters (give them defaults so old fixtures compile unchanged).

---

### Task 1: Sentence-boundary clip helper

**Files:**
- Create: `WeeklyPlanner/Intelligence/String+SentenceClip.swift`
- Test: `WeeklyPlannerTests/Intelligence/SentenceClipTests.swift` (NEW)

**Interfaces:**
- Produces: `extension String { func clippedToSentence(maxLength: Int) -> String }` — never cuts mid-word/mid-sentence; returns whole string if within limit; else trims to the last sentence terminator (`.`, `!`, `?`) within `maxLength`; if none, trims to the last whole word and appends "…".

- [ ] **Step 1: Write the failing tests**:

```swift
import XCTest
@testable import WeeklyPlanner

final class SentenceClipTests: XCTestCase {
    func testShortStringUnchanged() {
        XCTAssertEqual("Buy milk.".clippedToSentence(maxLength: 80), "Buy milk.")
    }

    func testClipsAtLastSentenceBoundaryWithinLimit() {
        let s = "Dentist at 3pm. Leave by 2:30 to make it. Traffic is heavy on Fridays."
        XCTAssertEqual(s.clippedToSentence(maxLength: 45), "Dentist at 3pm. Leave by 2:30 to make it.")
    }

    func testNoBoundaryFallsBackToWholeWordEllipsis() {
        let s = "A very long single sentence that keeps going without any terminator at all"
        let clipped = s.clippedToSentence(maxLength: 30)
        XCTAssertTrue(clipped.hasSuffix("…"))
        XCTAssertLessThanOrEqual(clipped.count, 31)
        XCTAssertFalse(clipped.dropLast().hasSuffix(" "), "no trailing space before ellipsis")
        // Never cuts mid-word: the fragment minus the ellipsis is a prefix ending at a word edge.
        XCTAssertTrue(s.hasPrefix(String(clipped.dropLast())))
    }

    func testWhitespaceTrimmed() {
        XCTAssertEqual("  Buy milk.  ".clippedToSentence(maxLength: 80), "Buy milk.")
    }
}
```

- [ ] **Step 2: Run to verify failure** — `-only-testing:WeeklyPlannerTests/SentenceClipTests`. Expected: compile failure.

- [ ] **Step 3: Implement**:

```swift
import Foundation

extension String {
    /// Clip for sticky-note display without mid-sentence/mid-word cuts
    /// (Phase 43 #61). Prefers the last sentence terminator within
    /// `maxLength`; falls back to the last whole word + ellipsis.
    func clippedToSentence(maxLength: Int) -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }

        let window = String(trimmed.prefix(maxLength))
        if let boundary = window.lastIndex(where: { ".!?".contains($0) }) {
            return String(window[...boundary]).trimmingCharacters(in: .whitespaces)
        }
        if let space = window.lastIndex(of: " ") {
            return String(window[..<space]).trimmingCharacters(in: .whitespaces) + "…"
        }
        return window + "…"
    }
}
```

- [ ] **Step 4: Run to verify pass** — `-only-testing:WeeklyPlannerTests/SentenceClipTests`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Intelligence/String+SentenceClip.swift WeeklyPlannerTests/Intelligence/SentenceClipTests.swift
git commit -m "feat(sticky): sentence-boundary clip helper (Phase 43 #61)"
```

---

### Task 2: `DayContext` carries the whole day + `hasContent`

**Files:**
- Modify: `WeeklyPlanner/Intelligence/InsightGenerator.swift` (`DayContext`, ~line 60)
- Modify: `WeeklyPlanner/Features/DayPage/DayPageViewModel.swift` (context construction, ~lines 188–208)
- Test: `WeeklyPlannerTests/Intelligence/DayContextContentTests.swift` (NEW)

**Interfaces:**
- Produces: `DayContext` gains `let tasks: [TaskItem]`, `let annotationTexts: [String]`, computed `var hasContent: Bool` (any of events/tasks/annotationTexts/inbox non-empty). Both new stored properties get default `= []` in the memberwise init so every existing call site compiles unchanged.
- Consumes (VM side): the day's tasks — reuse however `TodoBlock` gets them via the VM (grep `tasks(forWeekOffset` in `DayPageViewModel.swift`); annotations via `AnnotationStoring.annotations(dayKey:)` (already used by the VM for the annotation layer).

- [ ] **Step 1: Write the failing tests**:

```swift
import XCTest
@testable import WeeklyPlanner

final class DayContextContentTests: XCTestCase {
    private func context(events: [Event] = [], tasks: [TaskItem] = [],
                         annotations: [String] = [], inbox: [InboxSuggestion] = []) -> DayContext {
        DayContext(weekOffset: 0, dayIdx: 0, events: events, inbox: inbox,
                   now: Date(timeIntervalSince1970: 1_780_000_000),
                   appleIntelligenceEnabled: true,
                   tasks: tasks, annotationTexts: annotations)
    }

    func testEmptyDayHasNoContent() {
        XCTAssertFalse(context().hasContent)
    }

    func testEachSourceCountsAsContent() {
        let event = Event(title: "Dentist", start: Date(timeIntervalSince1970: 1_780_000_000),
                          end: Date(timeIntervalSince1970: 1_780_003_600), category: .personal)
        let task = TaskItem(title: "Buy milk", due: nil, category: .personal)
        XCTAssertTrue(context(events: [event]).hasContent)
        XCTAssertTrue(context(tasks: [task]).hasContent)
        XCTAssertTrue(context(annotations: ["call mom"]).hasContent)
    }
}
```

⚠️ Match `Event`/`TaskItem`/`InboxSuggestion` real initializers (copy from existing fixtures in `StickyOrchestratorTests.swift`); parameter order of `DayContext` follows the actual declaration — new params go last with defaults.

- [ ] **Step 2: Run to verify failure** — `-only-testing:WeeklyPlannerTests/DayContextContentTests`. Expected: compile failure.

- [ ] **Step 3: Implement.** In `InsightGenerator.swift`, extend `DayContext`:

```swift
    /// To-dos shown on this day page (Phase 43 #61 — generators must see them).
    let tasks: [TaskItem]
    /// Raw free-text annotation strings on this day page (Phase 43 #61).
    let annotationTexts: [String]

    /// Whether the day has ANY user content. When false, no sticky is
    /// generated at all — grounded-or-silent (Phase 43 #61).
    var hasContent: Bool {
        !events.isEmpty || !tasks.isEmpty || !annotationTexts.isEmpty || !inbox.isEmpty
    }
```

Give both new init params `= []` defaults. In `DayPageViewModel.refresh()` (the block that builds `DayContext`, ~line 201): pass the day's real tasks and annotation texts, and replace the hardcoded `appleIntelligenceEnabled: true` with the actual setting:

```swift
        let annotationTexts = ((try? await annotationStore?.annotations(dayKey: dayKey)) ?? [])
            .map(\.text)
        let aiEnabled = ((try? settingsStore?.current())?.appleIntelligenceEnabled) ?? true
        let context = DayContext(weekOffset: weekOffset, dayIdx: dayIdx,
                                 events: dayEvents, inbox: dayInbox, now: now,
                                 appleIntelligenceEnabled: aiEnabled,
                                 tasks: dayTasks, annotationTexts: annotationTexts)
```

⚠️ Use the VM's actual property/store names (`annotationStore` accessor, the day's task list variable, `dayKey` derivation) — read the surrounding function first; the requirement is: real tasks in, real annotation texts in, real AI flag in.

- [ ] **Step 4: Run to verify pass** — `-only-testing:WeeklyPlannerTests/DayContextContentTests -only-testing:WeeklyPlannerTests/InsightGeneratorProtocolTests -only-testing:WeeklyPlannerTests/DayPageViewModelTests`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Intelligence/InsightGenerator.swift WeeklyPlanner/Features/DayPage/DayPageViewModel.swift WeeklyPlannerTests/
git commit -m "feat(sticky): DayContext sees tasks + free text; real AI flag (Phase 43 #61)"
```

---

### Task 3: Grounded-or-silent orchestrator

**Files:**
- Modify: `WeeklyPlanner/Intelligence/StickyOrchestrator.swift` (`run(for:into:)`, ~line 41)
- Test: extend `WeeklyPlannerTests/Intelligence/StickyOrchestratorTests.swift`

- [ ] **Step 1: Write the failing tests** (append; reuse the file's existing fixtures/fakes):

```swift
    func testEmptyDayProducesNoInsightAndSkipsFallback() async throws {
        let fallbackSpy = SpyGenerator() // reuse/adapt the file's existing spy/fake generator type
        let orchestrator = makeOrchestrator(generators: [], fallback: fallbackSpy)
        let emptyDay = makeContext(events: [], inbox: [], tasks: [], annotationTexts: [])

        let insights = try await orchestrator.run(for: emptyDay, into: context)

        XCTAssertTrue(insights.isEmpty, "Empty day → no sticky at all")
        XCTAssertFalse(fallbackSpy.wasInvoked, "Fallback must not fire on an empty day")
    }

    func testDayWithOnlyATaskStillRunsGenerators() async throws {
        let spy = SpyGenerator(returning: makeDraft(text: "Buy milk today."))
        let orchestrator = makeOrchestrator(generators: [spy], fallback: SpyGenerator())
        let day = makeContext(tasks: [TaskItem(title: "Buy milk", due: nil, category: .personal)])

        let insights = try await orchestrator.run(for: day, into: context)

        XCTAssertEqual(insights.count, 1)
    }
```

⚠️ This file already has factories for orchestrator/context/drafts — reuse their real names (`makeOrchestrator`, fake generator class, `into:` parameter type). The two assertions' INTENT is fixed: empty → `[]` + fallback untouched; any single content source → generators run.

- [ ] **Step 2: Run to verify failure** — `-only-testing:WeeklyPlannerTests/StickyOrchestratorTests`. Expected: new tests FAIL (fallback currently fires unconditionally).

- [ ] **Step 3: Implement.** In `StickyOrchestrator.run`, immediately after the cache check:

```swift
        // Grounded-or-silent (Phase 43 #61): a day with no user content
        // gets no sticky — not even encouragement. Persist the empty set
        // so stale insights from a previously-non-empty day disappear.
        guard day.hasContent else {
            try persist([], for: day, into: context)
            return []
        }
```

⚠️ Match `persist`'s real signature (it currently deletes non-dismissed rows for the day then inserts — passing `[]` must still perform the delete; verify and adapt).

- [ ] **Step 4: Run to verify pass** — `-only-testing:WeeklyPlannerTests/StickyOrchestratorTests`. Expected: PASS, including all pre-existing cases.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Intelligence/StickyOrchestrator.swift WeeklyPlannerTests/Intelligence/StickyOrchestratorTests.swift
git commit -m "feat(sticky): empty day generates nothing — no fallback filler (Phase 43 #61)"
```

---

### Task 4: Grounded prompts + real token cap + sentence clip

**Files:**
- Modify: `WeeklyPlanner/Intelligence/Tasks/KeywordInsightGenerator.swift` (prompt ~lines 82–92, clip ~line 70, bare session ~line 109)
- Modify: `WeeklyPlanner/Intelligence/Tasks/EncouragementInsightGenerator.swift` (prompt ~lines 68–84, clip ~line 50)
- Modify: `WeeklyPlanner/Intelligence/PlannerLanguageModel.swift` (`respond` call ~line 62)
- Test: extend `KeywordInsightGeneratorTests.swift`, `EncouragementInsightGeneratorTests.swift`

- [ ] **Step 1: Write the failing tests.** Both generator test files already pin prompt contents (grep `prompt` in each). Append, adapting to each file's prompt-capture mechanism:

```swift
    func testPromptIncludesTasksAndAnnotations() {
        let day = makeContext(
            events: [makeEvent(title: "Dentist")],
            tasks: [TaskItem(title: "Buy milk", due: nil, category: .personal)],
            annotationTexts: ["call mom after lunch"]
        )
        let prompt = KeywordInsightGenerator.prompt(for: day) // use the file's real prompt accessor
        XCTAssertTrue(prompt.contains("Buy milk"))
        XCTAssertTrue(prompt.contains("call mom after lunch"))
    }

    func testPromptForbidsInvention() {
        let prompt = KeywordInsightGenerator.prompt(for: makeContext(events: [makeEvent(title: "Gym")]))
        XCTAssertTrue(prompt.localizedCaseInsensitiveContains("only"),
                      "Prompt must restrict the model to the listed items")
    }

    func testDraftTextEndsAtSentenceBoundary() {
        // Feed an over-long model reply through the generator's clipping path.
        let long = "Remember the dentist at three. Bring the insurance card because they asked for it last time."
        let clipped = long.clippedToSentence(maxLength: 60)
        XCTAssertTrue(clipped.hasSuffix(".") || clipped.hasSuffix("…"))
        XCTAssertFalse(clipped.hasSuffix(" "))
    }
```

- [ ] **Step 2: Run to verify failure** — the two generator suites. Expected: FAIL (prompts don't mention tasks/annotations yet).

- [ ] **Step 3: Implement.**

3.1 — **Keyword prompt** (`KeywordInsightGenerator`): extend the prompt builder to enumerate all three sources and forbid invention. Shape (adapt to the existing prompt string):

```swift
        Today's calendar events: \(eventLines)
        Today's to-dos: \(day.tasks.map(\.title).joined(separator: "; "))
        Today's handwritten notes: \(day.annotationTexts.joined(separator: "; "))

        If one of these items contains a meaningful detail worth a sticky-note
        reminder (a deadline, a person, a preparation step), write ONE short
        complete sentence about it. Use ONLY the items listed above — do not
        invent errands, purchases, or suggestions that are not listed. If
        nothing qualifies, return null.
```

3.2 — **Encouragement prompt** (`EncouragementInsightGenerator`): same enumeration; instruction becomes "Write one warm, specific sentence about the day above, mentioning at least one listed item by name. One complete sentence, no more than 20 words."

3.3 — **Replace the hard chops** in both generators:

```swift
        text: d.text.clippedToSentence(maxLength: 90)      // was String(d.text.prefix(60))
```
```swift
        let text = trimmed.clippedToSentence(maxLength: 110) // was String(trimmed.prefix(80))
```

3.4 — **Apply the token cap.** In `PlannerLanguageModel` where `session.respond(to:)` is called (~line 62), and in `LiveKeywordInsightModel.generateKeyword` (~line 111):

```swift
        let options = GenerationOptions(maximumResponseTokens: context.maxResponseTokens)
        let response = try await session.respond(to: prompt, options: options)
```

(For the bare keyword session, pass a literal budget, e.g. `GenerationOptions(maximumResponseTokens: 60)`.) Keep both under the existing `#if canImport(FoundationModels)` gates. ⚠️ Verify the exact `GenerationOptions` initializer label against the SDK — Phase 18's lesson: FoundationModels API names drift; if the label differs (e.g. `maximumTokens`), adapt and note the deviation.

- [ ] **Step 4: Run to verify pass** — `-only-testing:WeeklyPlannerTests/KeywordInsightGeneratorTests -only-testing:WeeklyPlannerTests/EncouragementInsightGeneratorTests -only-testing:WeeklyPlannerTests/StickyOrchestratorTests`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Intelligence/ WeeklyPlannerTests/Intelligence/
git commit -m "feat(sticky): grounded prompts, real token cap, sentence-safe clipping (Phase 43 #61)"
```

---

### Task 5: `AIInsight` position + orchestrator carry-over + draggable stack

**Files:**
- Modify: `WeeklyPlanner/Models/AIInsight.swift` (optional `unitX`/`unitY`)
- Modify: `WeeklyPlanner/Intelligence/StickyOrchestrator.swift` (`persist`)
- Modify: `WeeklyPlanner/Features/DayPage/AIStickyStack.swift` (reposition drag)
- Modify: `WeeklyPlanner/Features/DayPage/DayPageView.swift` (`stickyNoteOverlay` positioning, ~lines 177–179 and 472–487)
- Modify: `WeeklyPlanner/Features/DayPage/DayPageViewModel.swift` (`setStickyPosition`)
- Test: extend `AIInsightV2MigrationTests.swift`, `StickyOrchestratorTests.swift`, `DayPageViewModelTests.swift`

**Interfaces:**
- Produces: `AIInsight.unitX: Double?`, `unitY: Double?` (nil = legacy fixed slot); `DayPageViewModel.setStickyPosition(unitX: Double, unitY: Double) async` writes the position to every non-dismissed `AIInsight` row of the current day; orchestrator `persist` copies the previous rows' position onto freshly generated rows.

- [ ] **Step 1: Write the failing tests**:

`AIInsightV2MigrationTests` (append):

```swift
    func testPositionDefaultsToNilForLegacyRows() throws {
        let insight = AIInsight(dayKey: "0:0", text: "hi", colorHex: "#FFF59D",
                                tiltDegrees: -2, kindRaw: "encouragement", priority: 9)
        XCTAssertNil(insight.unitX)
        XCTAssertNil(insight.unitY)
    }
```

`StickyOrchestratorTests` (append):

```swift
    func testRegenerationCarriesStickyPositionForward() async throws {
        // First run, then simulate a user drag by stamping a position…
        _ = try await orchestrator.run(for: day, into: context)
        for row in try fetchInsights(dayKey: day.dayKeyForTest) { row.unitX = 0.2; row.unitY = 0.7 }
        try context.save()
        bustCache() // advance the injected clock past TTL, or use the file's cache-bypass hook

        let regenerated = try await orchestrator.run(for: day, into: context)

        XCTAssertEqual(regenerated.first?.unitX, 0.2, "position must survive regeneration")
        XCTAssertEqual(regenerated.first?.unitY, 0.7)
    }
```

⚠️ Match the `AIInsight` init and this test file's context/fetch/cache helpers; the file already tests persist-and-delete cycles — extend the same machinery.

- [ ] **Step 2: Run to verify failure.** Expected: compile failure (`unitX` missing).

- [ ] **Step 3: Implement model + carry-over.**

`AIInsight.swift` — add stored properties with property-level defaults (lightweight migration):

```swift
    /// Unit-space sticky position (0…1 of the page). nil = the legacy
    /// fixed top-trailing slot (Phase 43 #61 — user can move the sticky).
    var unitX: Double?
    var unitY: Double?
```

`StickyOrchestrator.persist` — before deleting the day's old rows, capture their position; after inserting fresh rows, stamp it:

```swift
        let previousPosition = existingRows.compactMap { row -> (Double, Double)? in
            guard let x = row.unitX, let y = row.unitY else { return nil }
            return (x, y)
        }.first
        // …existing delete + insert…
        if let (x, y) = previousPosition {
            for row in freshRows { row.unitX = x; row.unitY = y }
        }
```

(fit into the function's real local names).

`DayPageViewModel` — add:

```swift
    /// Persist a dragged sticky position onto every live insight row of
    /// this day (the cascade moves as one unit).
    func setStickyPosition(unitX: Double, unitY: Double) async {
        for insight in insights {
            insight.unitX = unitX
            insight.unitY = unitY
        }
        try? modelContext?.save()
    }
```

⚠️ Use the VM's real persistence handle (it may go through a store rather than a raw context — mirror how `compactNotes` saves annotations).

- [ ] **Step 4: Positionable overlay + reposition drag.**

`DayPageView.stickyNoteOverlay` — wrap the existing stack in a `GeometryReader` sibling of the annotation layer and offset by unit position, defaulting to the legacy slot when nil:

```swift
        GeometryReader { geo in
            AIStickyStack(/* existing params */)
                .offset(stickyOffset(in: geo.size))
        }

    private func stickyOffset(in size: CGSize) -> CGSize {
        guard let x = viewModel.insights.first?.unitX,
              let y = viewModel.insights.first?.unitY else {
            return legacySlotOffset(in: size) // reproduce today's topTrailing + 96/16 padding
        }
        return CGSize(width: x * size.width, height: y * size.height)
    }
```

`AIStickyStack` — add a reposition gesture that does not fight the swipe-cycle: long-press (0.3 s) lifts, then drag moves; mirrors `stickyDragActive` exactly like the existing swipe gesture does:

```swift
        .gesture(
            LongPressGesture(minimumDuration: 0.3)
                .sequenced(before: DragGesture(coordinateSpace: .named("dayPage")))
                .onChanged { value in
                    if case .second(true, let drag?) = value {
                        repositionTranslation = drag.translation
                        flipController.stickyDragActive = true
                    }
                }
                .onEnded { value in
                    defer { flipController.stickyDragActive = false; repositionTranslation = .zero }
                    guard case .second(true, let drag?) = value else { return }
                    onReposition?(drag.location) // parent converts to unit space + persists
                }
        )
```

Parent (`DayPageView`) supplies `onReposition`, converting the drop point to clamped unit coordinates (reuse `Annotation.clampUnit`-style clamping) and calling `await viewModel.setStickyPosition(...)`. ⚠️ Phase 34 lesson (`phase-34-gesture-a11y-lessons`): use **simultaneous**-style composition carefully — the sequenced long-press→drag recipe here is intentional so plain horizontal swipes still cycle the cascade; verify on-device that both gestures coexist, and keep the existing `swipeGesture` untouched.

- [ ] **Step 5: Run** — `-only-testing:WeeklyPlannerTests/AIInsightV2MigrationTests -only-testing:WeeklyPlannerTests/StickyOrchestratorTests -only-testing:WeeklyPlannerTests/DayPageViewModelTests -only-testing:WeeklyPlannerTests/AIStickyStackTests`, then UI regressions `-only-testing:WeeklyPlannerUITests/StickySwipeUITests -only-testing:WeeklyPlannerUITests/AIStickyStackUITests`. Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add WeeklyPlanner/ WeeklyPlannerTests/
git commit -m "feat(sticky): persisted unit-space position + long-press-drag reposition (Phase 43 #61)"
```

---

### Task 6: `UserStickyNote` model + store

**Files:**
- Create: `WeeklyPlanner/Models/UserStickyNote.swift`, `WeeklyPlanner/Stores/UserStickyStore.swift`
- Modify: `WeeklyPlanner/Stores/SwiftDataStack.swift` (schema), `Environment+Stores.swift` (`@Entry` + stub), `WeeklyPlannerApp.swift`/`AppShell.swift` (wiring)
- Test: `WeeklyPlannerTests/Stores/UserStickyStoreTests.swift` (NEW)

**Interfaces:**
- Produces:
  - `@Model final class UserStickyNote` — `id: UUID`, `dayKey: String`, `text: String`, `colorHex: String` (default `"#FFF59D"`), `tiltDegrees: Double`, `unitX: Double`, `unitY: Double`, `createdAt: Date`.
  - `@MainActor protocol UserStickyStoring: AnyObject { func stickies(dayKey: String) throws -> [UserStickyNote]; func add(dayKey: String, atUnitX: Double, unitY: Double) throws -> UserStickyNote; func update(_ sticky: UserStickyNote) throws; func delete(id: UUID) throws }`
  - `Notification.Name.userStickyStoreDidChange` posted on mutation.
  - `StubUserStickyStore` for previews/tests (mirror `StubAnnotationStore`).

- [ ] **Step 1: Write the failing tests** (same in-memory-container pattern as `AnnotationStoreTests.swift` — copy its setup):

```swift
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class UserStickyStoreTests: XCTestCase {
    private var store: SwiftDataUserStickyStore!
    // setUp: in-memory ModelContainer(for: UserStickyNote.self), store = .init(context:)

    func testAddCreatesStickyAtPosition() throws {
        let sticky = try store.add(dayKey: "0:2", atUnitX: 0.6, unitY: 0.3)
        XCTAssertEqual(sticky.dayKey, "0:2")
        XCTAssertEqual(sticky.unitX, 0.6)
        XCTAssertEqual(try store.stickies(dayKey: "0:2").count, 1)
    }

    func testStickiesFilteredByDayKeySortedByCreation() throws {
        _ = try store.add(dayKey: "0:2", atUnitX: 0.5, unitY: 0.5)
        _ = try store.add(dayKey: "0:3", atUnitX: 0.5, unitY: 0.5)
        XCTAssertEqual(try store.stickies(dayKey: "0:2").count, 1)
        XCTAssertEqual(try store.stickies(dayKey: "0:3").count, 1)
    }

    func testUpdatePersistsTextAndPosition() throws {
        let sticky = try store.add(dayKey: "0:2", atUnitX: 0.5, unitY: 0.5)
        sticky.text = "pack lunch"
        sticky.unitY = 0.8
        try store.update(sticky)
        XCTAssertEqual(try store.stickies(dayKey: "0:2").first?.text, "pack lunch")
        XCTAssertEqual(try store.stickies(dayKey: "0:2").first?.unitY, 0.8)
    }

    func testDeleteRemoves() throws {
        let sticky = try store.add(dayKey: "0:2", atUnitX: 0.5, unitY: 0.5)
        try store.delete(id: sticky.id)
        XCTAssertTrue(try store.stickies(dayKey: "0:2").isEmpty)
    }
}
```

- [ ] **Step 2: Run to verify failure.** Expected: compile failure.

- [ ] **Step 3: Implement** model + store following `Annotation.swift`/`AnnotationStore.swift` verbatim patterns (clamped unit values via the same `clampUnit`-style guard, `@Attribute(.unique)` id, fetch sorted by `createdAt`, `NotificationCenter` post on save, `StubUserStickyStore` in `Environment+Stores.swift`). Register `UserStickyNote.self` in `SwiftDataStack`. Wire `@Entry var userStickyStore: (any UserStickyStoring)?`, construct in `WeeklyPlannerApp` beside the annotation store, inject in `AppShell` beside `\.annotationStore`. New sticky defaults: `colorHex "#FFF59D"`, `tiltDegrees` random-looking but deterministic per id (e.g. `Double(id.hashValue % 5) - 2` — matches the AI sticky's stable-tilt approach).

- [ ] **Step 4: Run to verify pass** — `-only-testing:WeeklyPlannerTests/UserStickyStoreTests`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/ WeeklyPlannerTests/Stores/UserStickyStoreTests.swift
git commit -m "feat(sticky): UserStickyNote model + store (Phase 43 #66)"
```

---

### Task 7: User sticky UI — pad, editor, drag

**Files:**
- Create: `WeeklyPlanner/Features/DayPage/UserStickyView.swift`
- Modify: `WeeklyPlanner/Features/DayPage/DayPageView.swift` (user-sticky layer + pad button)
- Modify: `WeeklyPlanner/Features/DayPage/DayPageViewModel.swift` (CRUD passthroughs)
- Modify: `WeeklyPlanner/Accessibility/AccessibilityIDs.swift`
- Test: `WeeklyPlannerUITests/UserStickyUITests.swift` (NEW); extend `DayPageViewModelTests.swift`

**Interfaces:**
- Consumes: `UserStickyStoring` (Task 6); `AIStickyNote`'s paper/tape chrome (extract, don't duplicate).
- Produces: a11y ids `AccessibilityIDs.stickyPad = "daypage.sticky.pad"`, `userSticky(_ id:) -> "daypage.sticky.user.<uuid>"`, `userStickyEditor = "daypage.sticky.editor"`.

- [ ] **Step 1: VM unit tests first** (append to `DayPageViewModelTests`):

```swift
    func testAddUserStickyCreatesAtDefaultPad() async throws {
        let created = await viewModel.addUserSticky()
        XCTAssertNotNil(created)
        XCTAssertEqual(viewModel.userStickies.count, 1)
    }

    func testCommittingEmptyUserStickyDeletesIt() async throws {
        let created = try XCTUnwrap(await viewModel.addUserSticky())
        await viewModel.commitUserStickyText(id: created.id, text: "   ")
        XCTAssertTrue(viewModel.userStickies.isEmpty, "empty commit deletes — matches annotation behavior")
    }

    func testDragUpdatesUnitPosition() async throws {
        let created = try XCTUnwrap(await viewModel.addUserSticky())
        await viewModel.moveUserSticky(id: created.id, toUnitX: 0.25, unitY: 0.75)
        XCTAssertEqual(viewModel.userStickies.first?.unitX ?? 0, 0.25, accuracy: 0.001)
    }
```

Implement in the VM: `userStickies: [UserStickyNote]` refreshed in `refresh()` from the store; `addUserSticky()` (default spawn at unit (0.72, 0.12) — just under the AI slot), `commitUserStickyText(id:text:)` (trimmed-empty → delete, else save), `moveUserSticky(id:toUnitX:unitY:)` (clamped, save). Mirror the annotation CRUD methods' structure (~lines 331–392).

- [ ] **Step 2: Run VM tests** — `-only-testing:WeeklyPlannerTests/DayPageViewModelTests`. Expected: FAIL → implement → PASS.

- [ ] **Step 3: Build `UserStickyView`.** First extract the sticky chrome from `AIStickyNote.swift` (paper rect + masking tape + tilt) into a reusable `StickyPaper<Content: View>` container in the same file, refactor `AIStickyNote` onto it, then:

```swift
/// A user-created movable sticky (Phase 43 #66). Tap = edit, drag = move,
/// empty commit = delete. Independent of the AI toggle.
struct UserStickyView: View {
    let sticky: UserStickyNote
    @Binding var editingID: UUID?
    let onCommit: (String) -> Void
    let onMove: (CGPoint) -> Void   // location in the day-page coordinate space

    @Environment(\.paperFont) private var font
    @State private var draft = ""
    @GestureState private var dragOffset: CGSize = .zero
    @FocusState private var focused: Bool

    var body: some View {
        StickyPaper(colorHex: sticky.colorHex, tiltDegrees: sticky.tiltDegrees) {
            if editingID == sticky.id {
                TextField("Sticky note", text: $draft, axis: .vertical)
                    .focused($focused)
                    .onSubmit { onCommit(draft) }
                    .accessibilityIdentifier(AccessibilityIDs.userStickyEditor)
                    .task { focused = true }
            } else {
                Text(sticky.text)
                    .font(font.font(at: 15, weight: .regular))
            }
        }
        .offset(dragOffset)
        .onTapGesture {
            draft = sticky.text
            editingID = sticky.id
        }
        .highPriorityGesture(
            DragGesture(minimumDistance: 6, coordinateSpace: .named("dayPage"))
                .updating($dragOffset) { value, state, _ in state = value.translation }
                .onEnded { value in onMove(value.location) }
        )
        .accessibilityIdentifier(AccessibilityIDs.userSticky(sticky.id))
    }
}
```

⚠️ Mirror `AnnotationView`'s two hard-won patterns exactly: (a) mirror drag activity onto `flipController.stickyDragActive` in `.updating`/`.onEnded` so page-flip stays suppressed; (b) commit-on-editorship-loss — commit the draft when `editingID` changes away (see `AnnotationView.swift` ~lines 37–45) so taps elsewhere don't lose text.

- [ ] **Step 4: Host layer + pad.** In `DayPageView`, add alongside the annotation layer overlay:

```swift
        .overlay(alignment: .topLeading) {
            GeometryReader { geo in
                ForEach(viewModel.userStickies, id: \.id) { sticky in
                    UserStickyView(
                        sticky: sticky,
                        editingID: $editingUserStickyID,
                        onCommit: { text in
                            Task { await viewModel.commitUserStickyText(id: sticky.id, text: text) }
                        },
                        onMove: { point in
                            Task {
                                await viewModel.moveUserSticky(
                                    id: sticky.id,
                                    toUnitX: min(max(point.x / geo.size.width, 0), 1),
                                    unitY: min(max(point.y / geo.size.height, 0), 1))
                            }
                        })
                        .offset(x: sticky.unitX * geo.size.width,
                                y: sticky.unitY * geo.size.height)
                }
            }
        }
```

Pad button — a small sticky-pad icon pinned near the top-trailing corner (below the AI slot), always visible:

```swift
        Button {
            Task {
                if let created = await viewModel.addUserSticky() {
                    editingUserStickyID = created.id
                }
            }
        } label: {
            Image(systemName: "note.text.badge.plus")
                .font(.system(size: 18))
                .foregroundStyle(theme.ink2)
        }
        .accessibilityLabel("Add sticky note")
        .accessibilityIdentifier(AccessibilityIDs.stickyPad)
```

⚠️ Phase 34 lesson: a container a11y-ID cascade clobbers child IDs — do not put an `accessibilityIdentifier` on the GeometryReader/overlay container, only on leaves. And name the coordinate space `"dayPage"` on the content node if not already present.

- [ ] **Step 5: UI test** (`WeeklyPlannerUITests/UserStickyUITests.swift`):

```swift
import XCTest

final class UserStickyUITests: XCTestCase {
    func testCreateTypeDragPersist() {
        let app = XCUIApplication()
        app.launch()

        let pad = app.buttons["daypage.sticky.pad"]
        XCTAssertTrue(pad.waitForExistence(timeout: 5))
        pad.tap()

        let editor = app.textFields["daypage.sticky.editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        editor.typeText("pack lunch")
        app.keyboards.buttons["return"].tap()

        let sticky = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'daypage.sticky.user.'")).firstMatch
        XCTAssertTrue(sticky.waitForExistence(timeout: 3))

        // Drag it down-left and confirm it stays a sticky (frame moved).
        let before = sticky.frame
        sticky.press(forDuration: 0.1,
                     thenDragTo: app.otherElements.firstMatch.coordinate(
                        withNormalizedOffset: CGVector(dx: 0.3, dy: 0.7)))
        XCTAssertNotEqual(sticky.frame.origin, before.origin)

        // Clean up: empty the text to delete (leave simulator state clean).
        sticky.tap()
        let editAgain = app.textFields["daypage.sticky.editor"]
        XCTAssertTrue(editAgain.waitForExistence(timeout: 3))
        editAgain.doubleTap()
        app.keys["delete"].press(forDuration: 1.5)
        app.keyboards.buttons["return"].tap()
    }
}
```

⚠️ Stack-from-top lesson (`stack-from-top-lessons`): UI-test residue causes false failures in later suites — the delete-at-end cleanup is mandatory. Keyboard-clearing recipes vary; a select-all + delete via the edit menu is an acceptable substitute.

- [ ] **Step 6: Run** — `-only-testing:WeeklyPlannerUITests/UserStickyUITests -only-testing:WeeklyPlannerUITests/AnnotationsUITests -only-testing:WeeklyPlannerUITests/StickySwipeUITests`. Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add WeeklyPlanner/ WeeklyPlannerUITests/UserStickyUITests.swift WeeklyPlannerTests/
git commit -m "feat(sticky): user-created movable sticky notes (Phase 43 #66)"
```

---

### Task 8: Full verification (superpowers:verification-before-completion)

- [ ] **Step 1: Full unit suite** — `-only-testing:WeeklyPlannerTests`. Expected: `** TEST SUCCEEDED **`.
- [ ] **Step 2: UI suites** — `UserStickyUITests`, `AIStickyStackUITests`, `StickySwipeUITests`, `AnnotationsUITests`, `SmokeUITests`. Expected: all PASS.
- [ ] **Step 3: On-device/signed-sim smoke** (see `tooling-run-app-needs-signing`): enable AI Sticky Notes; empty day → no sticky; day with a to-do + free text → sticky references them; drag sticky, flip away and back → position kept; create user sticky with AI toggle OFF → works.
- [ ] **Step 4: Phase-doc checklist sweep** — `docs/phases/phase-43-sticky-notes-v3.md`.
- [ ] **Step 5: Report** — branch, diffstat, deviations (esp. any FoundationModels API-name drift found in Task 4).

---

## Self-review notes

- **Spec coverage:** #61 grounded (T2–T4), silent-when-empty (T3), truncation (T1, T4), movable AI sticky (T5); #66 user stickies + movable (T6–T7).
- **Type consistency:** `clippedToSentence(maxLength:)` used identically T1/T4; `DayContext(tasks:annotationTexts:)` param names identical T2/T3/T4 tests; `UserStickyStoring` method set identical T6/T7; `setStickyPosition(unitX:unitY:)` T5 only.
- **Deliberate choices:** empty-day guard lives in the orchestrator (single choke point) rather than per-generator; one position for the whole cascade; user stickies get their own model instead of overloading `Annotation` (annotations are a vertical-only compacted list — stickies are free 2-D and must not participate in compaction) or `AIInsight` (regenerated rows would eat user content).
- **Known adaptation points (flagged inline):** fixture/factory names in orchestrator tests, VM store handles, `GenerationOptions` initializer label, keyboard-clearing recipe in the UI test.
