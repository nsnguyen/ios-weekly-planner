# Phase 32 — AI Surfaces & Review Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Review page never fabricates AI content (no hardcoded "Morning run" streak, no canned summary bullets) and the AI surface is named "Ask the planner" in all user-facing copy (UX copy only — no code symbols renamed).

**Architecture:** `WeekSummaryGenerator` stops returning canned `WeekSummary.fallback(...)` and instead returns a `WeekSummaryOutcome` enum (`generated` / `unavailable` / `noContent`). `ReviewViewModel` maps that to a three-state `SummaryState` (`real` / `aiOff` / `hidden`) that `PaperReviewView` renders. The rename is copy-only: string literals and `String(localized:)` constants change; `appleIntelligenceEnabled`, `PlannerLanguageModel`, log subsystems, bundle IDs all stay.

**Tech Stack:** SwiftUI, Swift 6 strict concurrency, XCTest (NOT Swift Testing), XcodeGen, iOS 26.5 simulator.

---

## The three Review states (decision record)

| State | Trigger | Renders |
|---|---|---|
| **A. Real AI content** | generator exists, availability OK, week has data, model returns non-empty text | `ReviewSummaryBlock` with the model headline; `AINotesList` only if bullets exist (none in v1.1 — model emits headline only); no canned bullets ever |
| **B. AI off** | generator is `nil` (no intelligence service) OR availability `.unavailable(...)` (incl. planner toggle off) | One-line prompt: "Turn on Ask the planner for a weekly summary" |
| **C. Genuinely empty / no content** | AI on but week has zero events AND zero tasks (model not called), or model errored / returned empty text | Summary + notes blocks omitted entirely |

Streaks: `ReviewViewModel.streaks` stays `[]` (no real `StreakStore` yet) → the Streaks section renders nothing. No fabricated rows in any state.

## Pre-flight (worktree setup)

- [ ] `cp /Users/nguyen-mini/Documents/dev/ios-weekly-planner/Secrets.xcconfig ./Secrets.xcconfig` (worktree has none)
- [ ] `xcodegen generate` (xcodeproj is gitignored; rerun after adding `AISearchTopBarTests.swift`)
- [ ] Pick simulator: `xcrun simctl list devices available` → use an iOS 26.5 iPhone
- [ ] Baseline build: `xcodebuild build-for-testing -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=<device>' CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO`

---

### Task 1: WeekSummaryGenerator — honest outcomes, no placeholder bullets

**Files:**
- Modify: `WeeklyPlanner/Intelligence/Tasks/WeekSummaryGenerator.swift`
- Modify: `WeeklyPlanner/Intelligence/WeekSummary.swift` (delete `fallback`)
- Test: `WeeklyPlannerTests/Intelligence/Tasks/WeekSummaryGeneratorTests.swift`

- [ ] **Step 1: Rewrite the generator tests (failing — `WeekSummaryOutcome` doesn't exist yet)**

Replace `testGenerateProducesSummaryWhenAvailable` and `testGenerateFallsBackWhenAIDisabled` with:

```swift
func testGenerateProducesRealSummaryWhenAvailable() async throws {
    let monday = Self.may16_2026().addingTimeInterval(-3600 * 24)
    try await eventStore.upsert(Event(title: "Standup",
                                      start: monday,
                                      end: monday.addingTimeInterval(1800),
                                      category: .work))
    let service = StubIntelligenceService(eventStore: eventStore)
    let generator = WeekSummaryGenerator(intelligence: service,
                                         events: eventStore,
                                         tasks: taskStore)
    let outcome = await generator.generate(weekOffset: 0, today: Self.may16_2026())
    guard case .generated(let summary) = outcome else {
        return XCTFail("expected .generated, got \(outcome)")
    }
    XCTAssertFalse(summary.headline.isEmpty)
    XCTAssertTrue(summary.bullets.isEmpty,
                  "real AI output must not carry design-placeholder bullets")
    XCTAssertFalse(summary.headline.contains("balanced week"),
                   "canned fallback copy must not leak into real output")
}

func testGenerateReturnsUnavailableWhenAIDisabled() async {
    let service = StubIntelligenceService(eventStore: eventStore)
    let generator = WeekSummaryGenerator(intelligence: service,
                                         events: eventStore,
                                         tasks: taskStore,
                                         settings: { false })
    let outcome = await generator.generate(weekOffset: 0, today: Self.may16_2026())
    XCTAssertEqual(outcome, .unavailable)
}

func testGenerateReturnsNoContentForGenuinelyEmptyWeek() async {
    let service = StubIntelligenceService(eventStore: eventStore)
    let generator = WeekSummaryGenerator(intelligence: service,
                                         events: eventStore,
                                         tasks: taskStore)
    let outcome = await generator.generate(weekOffset: 0, today: Self.may16_2026())
    XCTAssertEqual(outcome, .noContent,
                   "an empty week must not invoke the model or fabricate a summary")
}
```

Keep `testPromptIncludesWeekStatsLines` unchanged.

- [ ] **Step 2: Run — verify failure (compile error: `WeekSummaryOutcome` / non-throwing `generate` missing)**

Run: `xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner -destination '...' -only-testing:WeeklyPlannerTests/WeekSummaryGeneratorTests CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO`
Expected: FAIL (does not compile).

- [ ] **Step 3: Implement `WeekSummaryOutcome` + new `generate`**

In `WeekSummaryGenerator.swift`, above the class:

```swift
/// Result of a week-summary generation attempt. Phase 32 (#38): the
/// generator no longer fabricates canned summaries — callers receive an
/// honest outcome and decide how to degrade.
enum WeekSummaryOutcome: Equatable, Sendable {
    /// The on-device model produced a real summary.
    case generated(WeekSummary)
    /// AI is off or unavailable (planner toggle, device eligibility,
    /// model state). Callers may invite the user to enable it.
    case unavailable
    /// AI is available but there is nothing to summarize (genuinely empty
    /// week) or the model returned no usable text.
    case noContent
}
```

Replace `generate` (non-throwing now; availability check FIRST so AI-off wins over empty-week):

```swift
func generate(weekOffset: Int, today: Date) async -> WeekSummaryOutcome {
    let weekEvents = (try? await events.events(forWeekOffset: weekOffset, today: today)) ?? []
    let weekTasks = (try? await tasks.tasks(forWeekOffset: weekOffset, today: today)) ?? []

    var hoursByCategory: [String: Double] = [:]
    for event in weekEvents {
        let hours = event.end.timeIntervalSince(event.start) / 3600.0
        hoursByCategory[event.categoryRaw, default: 0] += hours
    }
    let tasksDone = weekTasks.filter(\.done).count
    let tasksTotal = weekTasks.count
    let pct = tasksTotal == 0 ? 0.0 : Double(tasksDone) / Double(tasksTotal)

    let context = PlannerContext(
        now: today,
        viewedWeekOffset: weekOffset,
        maxResponseTokens: 256,
        appleIntelligenceEnabled: settings()
    )
    let availability = await intelligence.availability(context: context)
    guard availability.isAvailable else { return .unavailable }

    // Genuinely empty week: nothing to summarize — don't ask the model to
    // reflect on zero data (that's how fabricated content happens).
    guard !(weekEvents.isEmpty && weekTasks.isEmpty) else { return .noContent }

    let prompt = Self.prompt(weekOffset: weekOffset,
                             tasksDone: tasksDone,
                             tasksTotal: tasksTotal,
                             hoursByCategory: hoursByCategory)
    do {
        let answer = try await intelligence.ask(query: prompt, context: context)
        let trimmed = answer.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .noContent }
        // Phase 32 (#38): the model emits a single headline; bullets stay
        // empty until real per-line structuring ships. No design
        // placeholders alongside live output.
        return .generated(WeekSummary(headline: trimmed,
                                      bullets: [],
                                      completionPercent: pct))
    } catch {
        return .noContent
    }
}
```

Update the class doc comment (drop the "Falls back to `WeekSummary.fallback`" sentence; describe the three outcomes).

- [ ] **Step 4: Delete `WeekSummary.fallback`**

In `WeekSummary.swift`, delete the whole `extension WeekSummary { static func fallback ... }` block (the "kept Wednesday's run / Sara's gift / Health up 40%" fabrications). Update the struct doc comment if it references the fallback. NOTE: `ReviewViewModel` still references `.fallback` at this point — Task 2 fixes it; build both tasks' code before running the suite (Tasks 1+2 share one red→green cycle for compile reasons, but commit separately is impossible — so Task 1 and Task 2 commit together at end of Task 2 if the intermediate state doesn't compile. Preferred: do Task 2's ReviewViewModel edits in the same change-set, then run, then make the two commits via `git add -p` split: generator+WeekSummary+generator-tests first, review files second.)

- [ ] **Step 5: Run generator tests — green** (after Task 2's view-model edit compiles)

### Task 2: ReviewViewModel — three states, no Morning run

**Files:**
- Modify: `WeeklyPlanner/Features/Review/ReviewViewModel.swift`
- Test: `WeeklyPlannerTests/Features/Review/ReviewViewModelTests.swift`

- [ ] **Step 1: Rewrite review view-model tests (failing)**

Delete `testHardcodedMorningRunStreakAlwaysPresent` and `testFallbackSummaryUsedWhenGeneratorNil`. Add:

```swift
func testSummaryStateIsAIOffWhenGeneratorNil() async {
    let vm = ReviewViewModel(weekOffset: 0,
                              eventStore: eventStore,
                              taskStore: taskStore,
                              summaryGenerator: nil,
                              clock: { Self.may18_2026(hour: 12) })
    await vm.refresh()
    XCTAssertEqual(vm.summaryState, .aiOff)
}

func testSummaryStateIsAIOffWhenSettingsToggleOff() async {
    let generator = WeekSummaryGenerator(
        intelligence: StubIntelligenceService(eventStore: eventStore),
        events: eventStore,
        tasks: taskStore,
        settings: { false })
    let vm = ReviewViewModel(weekOffset: 0,
                              eventStore: eventStore,
                              taskStore: taskStore,
                              summaryGenerator: generator,
                              clock: { Self.may18_2026(hour: 12) })
    await vm.refresh()
    XCTAssertEqual(vm.summaryState, .aiOff)
}

func testSummaryStateHiddenForEmptyWeekWithAIOn() async {
    let generator = WeekSummaryGenerator(
        intelligence: StubIntelligenceService(eventStore: eventStore),
        events: eventStore,
        tasks: taskStore)
    let vm = ReviewViewModel(weekOffset: 0,
                              eventStore: eventStore,
                              taskStore: taskStore,
                              summaryGenerator: generator,
                              clock: { Self.may18_2026(hour: 12) })
    await vm.refresh()
    XCTAssertEqual(vm.summaryState, .hidden)
}

func testSummaryStateRealCarriesModelOutputAndNoPlaceholders() async throws {
    let monday = Self.may18_2026(hour: 9)
    try await eventStore.upsert(Event(title: "Standup",
                                      start: monday,
                                      end: monday.addingTimeInterval(1800),
                                      category: .work))
    let generator = WeekSummaryGenerator(
        intelligence: StubIntelligenceService(eventStore: eventStore),
        events: eventStore,
        tasks: taskStore)
    let vm = ReviewViewModel(weekOffset: 0,
                              eventStore: eventStore,
                              taskStore: taskStore,
                              summaryGenerator: generator,
                              clock: { Self.may18_2026(hour: 12) })
    await vm.refresh()
    guard case .real(let summary) = vm.summaryState else {
        return XCTFail("expected .real, got \(vm.summaryState)")
    }
    XCTAssertFalse(summary.headline.isEmpty)
    XCTAssertTrue(summary.bullets.isEmpty)
}

func testNoFabricatedStreaksInAnyState() async {
    let vm = ReviewViewModel(weekOffset: 0,
                              eventStore: eventStore,
                              taskStore: taskStore,
                              summaryGenerator: nil,
                              clock: { Self.may18_2026(hour: 12) })
    await vm.refresh()
    XCTAssertTrue(vm.streaks.isEmpty,
                  "no real StreakStore exists yet — streaks must never be fabricated")
    XCTAssertFalse(vm.streaks.contains { $0.name == "Morning run" })
}

func testAIOffPromptCopyNamesAskThePlanner() {
    XCTAssertEqual(ReviewAIOffPrompt.promptText,
                   "Turn on Ask the planner for a weekly summary")
}
```

(The last test goes red until Task 3 adds `ReviewAIOffPrompt`.)

- [ ] **Step 2: Implement `SummaryState` in ReviewViewModel**

```swift
/// What the AI summary area should render. Phase 32 (#38): three honest
/// states — real model output, an "AI off" invitation, or nothing at all.
/// No state fabricates streaks or notes.
enum SummaryState: Equatable {
    /// Real on-device model output — render it.
    case real(WeekSummary)
    /// AI is off/unavailable — render the one-line enable prompt.
    case aiOff
    /// AI is on but there's nothing to show (empty week, model failure)
    /// — omit the block entirely.
    case hidden
}

var summaryState: SummaryState = .hidden
```

- Delete `var summary: WeekSummary`, the `self.summary = WeekSummary.fallback(...)` init line, both `refresh()` fallback branches, the `streaks = [Self.morningRunStreak()]` line, and the whole `morningRunStreak()` func.
- `refresh()` summary section becomes:

```swift
if let summaryGenerator {
    switch await summaryGenerator.generate(weekOffset: weekOffset, today: now) {
    case .generated(let produced): summaryState = .real(produced)
    case .unavailable: summaryState = .aiOff
    case .noContent: summaryState = .hidden
    }
} else {
    summaryState = .aiOff
}
```

- `streaks` keeps its declaration with an honest comment: real streak tracking is a later phase; empty array → section hidden.
- Update the class doc comment (no more "hardcoded Morning run streak").

- [ ] **Step 3: Run ReviewViewModelTests + WeekSummaryGeneratorTests — all green except `testAIOffPromptCopyNamesAskThePlanner` (needs Task 3)**

- [ ] **Step 4: Commit (split):**

```bash
git add WeeklyPlanner/Intelligence/Tasks/WeekSummaryGenerator.swift WeeklyPlanner/Intelligence/WeekSummary.swift WeeklyPlannerTests/Intelligence/Tasks/WeekSummaryGeneratorTests.swift
git commit -m "feat(intelligence): WeekSummaryGenerator returns honest outcomes, no canned fallback (Phase 32 #38)"
git add WeeklyPlanner/Features/Review/ReviewViewModel.swift WeeklyPlannerTests/Features/Review/ReviewViewModelTests.swift
git commit -m "feat(review): three honest summary states; drop hardcoded Morning run streak (Phase 32 #38)"
```

(If the Task-1-only state can't compile alone, these two commits still land as a pair — each is self-coherent for review.)

### Task 3: Review views — render the three states

**Files:**
- Modify: `WeeklyPlanner/Features/Review/PaperReviewView.swift`
- Modify: `WeeklyPlanner/Features/Review/ReviewSummaryBlock.swift` (add `ReviewAIOffPrompt`)
- Modify: `WeeklyPlanner/Features/Review/AINotesList.swift` (empty guard)
- Modify: `WeeklyPlanner/Features/Review/StreaksBlock.swift` (empty guard)

- [ ] **Step 1: Add `ReviewAIOffPrompt` to ReviewSummaryBlock.swift**

```swift
/// Honest AI-off state for the Review page (Phase 32 #38): one quiet line
/// inviting the user to enable Ask the planner — in place of the old
/// canned summary, which read as fake.
struct ReviewAIOffPrompt: View {
    /// Exposed for tests; also the VoiceOver label.
    static let promptText = String(localized: "Turn on Ask the planner for a weekly summary")

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 10))
                .foregroundStyle(theme.ink3)
            Text(Self.promptText)
                .font(font.font(at: 15, weight: .regular).italic())
                .foregroundStyle(theme.ink3)
        }
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Self.promptText)
    }
}
```

- [ ] **Step 2: Empty guards in AINotesList + StreaksBlock**

Both views: first line of `body` becomes a `if bullets.isEmpty { EmptyView() } else { ...existing VStack... }` (resp. `streaks.isEmpty`) so neither section ever renders a lone header above zero rows.

- [ ] **Step 3: PaperReviewView switches on state + wires the settings toggle**

Replace the fixed block column:

```swift
ReviewHeader(...unchanged...)
switch viewModel.summaryState {
case .real(let summary):
    ReviewSummaryBlock(summaryBody: summary.headline)
case .aiOff:
    ReviewAIOffPrompt()
case .hidden:
    EmptyView()
}
TimeSpentBarChart(timeByCategory: viewModel.timeByCategory,
                  maxHours: viewModel.maxHours)
if case .real(let summary) = viewModel.summaryState {
    AINotesList(bullets: summary.bullets)   // self-hides when empty
}
StreaksBlock(streaks: viewModel.streaks)    // self-hides when empty
```

Add `@Environment(\.settingsStore) private var settingsStore` and wire the planner's own toggle into the generator (the generator already had the hook; Review just never passed it):

```swift
let generator = intelligenceService.map { service in
    WeekSummaryGenerator(intelligence: service,
                          events: eventStore,
                          tasks: taskStore,
                          settings: { [settingsStore] in
                              (try? settingsStore.current())?.appleIntelligenceEnabled ?? true
                          })
}
```

- [ ] **Step 4: Run ReviewViewModelTests (incl. prompt-copy test) — green. Build the app target.**

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Features/Review/
git commit -m "feat(review): render real/AI-off/empty states honestly; hide empty notes and streaks (Phase 32 #38)"
```

### Task 4: Rename — AI search surface + availability copy

**Files:**
- Modify: `WeeklyPlanner/Features/AISearch/AISearchTopBar.swift`
- Modify: `WeeklyPlanner/Features/AISearch/AskInputField.swift`
- Modify: `WeeklyPlanner/Accessibility/AccessibilityModifiers.swift`
- Modify: `WeeklyPlanner/Intelligence/Availability.swift` (strings only — enum cases stay)
- Create: `WeeklyPlannerTests/AISearch/AISearchTopBarTests.swift` (then `xcodegen generate`)
- Modify: `WeeklyPlannerTests/Intelligence/AvailabilityTests.swift`

- [ ] **Step 1: Write failing tests**

New `WeeklyPlannerTests/AISearch/AISearchTopBarTests.swift`:

```swift
import XCTest
@testable import WeeklyPlanner

/// Phase 32 (#49): the AI surface is named "Ask the planner" in all
/// user-facing copy. These asserts lock the rename so "Apple Intelligence"
/// can't drift back into UX strings (the framework name stays in code).
@MainActor
final class AISearchTopBarTests: XCTestCase {
    func testTitleReadsAskThePlanner() {
        XCTAssertEqual(AISearchTopBar.titleText, "Ask the planner")
    }

    func testEyebrowDoesNotDuplicateTitleOrLeakAppleBranding() {
        XCTAssertEqual(AISearchTopBar.eyebrowText, "ON-DEVICE AI")
        XCTAssertFalse(AISearchTopBar.eyebrowText.localizedCaseInsensitiveContains("apple"))
    }

    func testCloseAccessibilityLabelNamesAskThePlanner() {
        XCTAssertEqual(AISearchTopBar.closeAccessibilityLabel, "Close Ask the planner")
        XCTAssertFalse(AISearchTopBar.closeAccessibilityLabel.contains("Apple Intelligence"))
    }

    func testAskInputFieldAccessibilityLabelNamesAskThePlanner() {
        XCTAssertEqual(AskInputField.inputAccessibilityLabel, "Ask the planner")
        XCTAssertFalse(AskInputField.inputAccessibilityLabel.contains("Apple Intelligence"))
    }
}
```

In `AvailabilityTests.swift`, update/extend the message asserts:

```swift
func testFallbackMessages_areHonestAndUseProductVoice() {
    XCTAssertEqual(
        AvailabilityState.unavailable(.deviceNotEligible).fallbackMessage,
        "On-device AI isn't available on this device. Showing canned suggestions.")
    XCTAssertEqual(
        AvailabilityState.unavailable(.modelNotReady).fallbackMessage,
        "On-device AI is still warming up. Showing canned suggestions.")
    XCTAssertEqual(
        AvailabilityState.unavailable(.userDisabled).fallbackMessage,
        "Ask the planner is turned off in Settings. Showing canned suggestions.")
    // Intentional exception: this case points at the REAL iOS Settings
    // toggle, which Apple names "Apple Intelligence". Flagged for Phase 40.
    XCTAssertEqual(
        AvailabilityState.unavailable(.appleIntelligenceNotEnabled).fallbackMessage,
        "Enable Apple Intelligence in iOS Settings to get personalized answers. Showing canned suggestions.")
}
```

Run `xcodegen generate`, then run both classes → FAIL (constants don't exist; strings differ).

- [ ] **Step 2: Implement**

`AISearchTopBar.swift` — add constants + use them:

```swift
/// Phase 32 (#49) UX copy: the surface is the product's own "Ask the
/// planner"; Apple's framework branding stays out of user-facing strings.
static let eyebrowText = String(localized: "ON-DEVICE AI")
static let titleText = String(localized: "Ask the planner")
static let closeAccessibilityLabel = String(localized: "Close Ask the planner")
```

Body: eyebrow `Text(Self.eyebrowText)`, title `Text(Self.titleText)`, close button `.accessibilityLabel(Self.closeAccessibilityLabel)`.

`AskInputField.swift`:

```swift
/// Phase 32 (#49): VoiceOver name for the query field.
static let inputAccessibilityLabel = String(localized: "Ask the planner")
```

`.accessibilityLabel(Self.inputAccessibilityLabel)` replaces `"Ask Apple Intelligence"`.

`AccessibilityModifiers.swift` `accessibleAIButton()`: label `"Apple Intelligence search"` → `"Ask the planner"` (hint unchanged); update the doc comment.

`Availability.swift` `fallbackMessage`: the four strings from Step 1's asserts. Enum case names (`appleIntelligenceNotEnabled` etc.) are code symbols — unchanged. Comments on the cases may keep "Apple Intelligence" (real system requirement).

- [ ] **Step 3: Run AISearchTopBarTests + AvailabilityTests + AnswerBlockCleanBodyTests + AISearchViewModelTests — green**

- [ ] **Step 4: Commit**

```bash
git add WeeklyPlanner/Features/AISearch/ WeeklyPlanner/Accessibility/AccessibilityModifiers.swift WeeklyPlanner/Intelligence/Availability.swift WeeklyPlannerTests/AISearch/AISearchTopBarTests.swift WeeklyPlannerTests/Intelligence/AvailabilityTests.swift
git commit -m "feat(ai-search): rename Apple Intelligence to Ask the planner in UX copy + a11y labels (Phase 32 #49)"
```

### Task 5: Rename — Settings toggle + string catalog

**Files:**
- Modify: `WeeklyPlanner/Features/Settings/PaperSettingsView.swift`
- Modify: `WeeklyPlanner/Resources/Localizable.xcstrings`
- Test: `WeeklyPlannerTests/Features/Settings/PaperSettingsViewTests.swift`

- [ ] **Step 1: Failing test in PaperSettingsViewTests**

```swift
func testAIToggleLabelReadsAskThePlanner() {
    XCTAssertEqual(PaperSettingsView.askThePlannerToggleLabel, "Ask the planner")
    XCTAssertFalse(PaperSettingsView.askThePlannerToggleLabel.contains("Apple Intelligence"))
}
```

- [ ] **Step 2: Implement**

`PaperSettingsView`:

```swift
/// Phase 32 (#49): user-facing name of the on-device AI toggle. The
/// stored setting stays `appleIntelligenceEnabled` (code symbol).
static let askThePlannerToggleLabel = String(localized: "Ask the planner")
```

`ToggleRow(label: Self.askThePlannerToggleLabel, detail: "On-device only · keeps data private", ...)` (adjust `Self.` to `PaperSettingsView.` if the call site is in a nested type).

`Localizable.xcstrings` (JSON edit, keep alphabetical key order):
- Remove keys: `"Apple Intelligence"`, `"Apple Intelligence search"`, `"Ask Apple Intelligence"`, `"Close Apple Intelligence search"`.
- Add keys: `"Ask the planner"`, `"ON-DEVICE AI"`, `"Close Ask the planner"`, `"Turn on Ask the planner for a weekly summary"` (entries may be `{ }` or carry a manual comment; mirror neighboring style).
- Update the comment on `"Double tap to ask about your week."` → "A hint for the Ask the planner search button."

- [ ] **Step 3: Run PaperSettingsViewTests + LocalizationTests — green**

- [ ] **Step 4: Commit**

```bash
git add WeeklyPlanner/Features/Settings/PaperSettingsView.swift WeeklyPlanner/Resources/Localizable.xcstrings WeeklyPlannerTests/Features/Settings/PaperSettingsViewTests.swift
git commit -m "feat(settings): Ask the planner toggle label + string catalog rename (Phase 32 #49)"
```

### Task 6: Completeness sweep + full-suite verification

- [ ] **Step 1:** `grep -rn "Apple Intelligence" WeeklyPlanner/ WeeklyPlannerTests/ WeeklyPlannerUITests/` — every remaining hit must be either (a) a code comment describing the real framework/device requirement, (b) the `appleIntelligenceNotEnabled` iOS-Settings message (intentional, flagged), or (c) a code symbol (`appleIntelligenceEnabled`). NO user-facing string hits.
- [ ] **Step 2:** `grep -rn "Morning run" WeeklyPlanner/Features/ WeeklyPlannerTests/` — only the seed-data EVENT in `seed-week-0.json` remains (legit calendar event, not a streak).
- [ ] **Step 3:** Full unit suite: `xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=<device>' CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO` → expect ~387+ tests, 0 failures. Capture the final "Executed N tests" line for the report.
- [ ] **Step 4:** If any unexpected failure → superpowers:systematic-debugging before touching fixes.

## Self-review checklist
- Spec coverage: (38) streak ✓ Task 2; (38) placeholder bullets ✓ Tasks 1–3; three states ✓; (49) settings toggle ✓ Task 5; top bar title + a11y ✓ Task 4; AskInputField a11y ✓ Task 4; AnswerBlock fallback wording ✓ Task 4 (via `Availability.fallbackMessage` — the strings AnswerBlock renders); xcstrings ✓ Task 5; no dangling canned-streak refs ✓ Tasks 2/6; Phase 21 a11y audits ✓ (labels changed in place, audits are formatter-based).
- Out of scope honored: no symbol renames, no model wiring changes (the `settings:` closure in PaperReviewView wires EXISTING gating into an existing hook — flag in report), no WeekPage/WeekPicker files.
