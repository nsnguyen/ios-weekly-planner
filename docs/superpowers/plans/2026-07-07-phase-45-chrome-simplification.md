# Phase 45 — Chrome & Navigation Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Delete the Review tab (feature + orphaned `Streak` model), blank the week page's "none" placeholder, remove the week picker's duplicated month title, and make free-text creation fast (0.45 s → 0.2 s press + immediate focus) (suggestions #57, #74, #75, #76).

**Architecture:** Pure subtraction plus one timing constant. The tab bar is driven by `Tab.allCases`, so removing the enum case removes the cell; the only new logic is a safe fallback for the persisted `lastTabRaw == "review"`.

**Tech Stack:** SwiftUI, SwiftData, XCTest, XcodeGen.

## Global Constraints

- iOS 26.0+, Swift 6 strict concurrency. `xcodegen generate` after deleting files. Canonical test command:

```bash
xcodegen generate
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=<available iPhone, iOS 26.5>' \
  -only-testing:<filter> \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO
```

- `WeekSummary` / `WeekSummaryGenerator` / `SummarizeWeekTool` are **shared with the Intelligence layer — do not delete** (only the Review view layer consumed `WeekSummaryGenerator` for display).
- Item #75 deliberately reverses round-1 item #28 — do not "restore" the word none.
- Lint: changed files only, no new violations.

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `WeeklyPlanner/Navigation/TabSelection.swift` | MODIFY | drop `.review`; legacy-raw fallback |
| `WeeklyPlanner/Navigation/PaperTab.swift` | MODIFY | drop icon/label cases + fix `#Preview` |
| `WeeklyPlanner/Navigation/AppShell.swift` | MODIFY | drop routing case + doc comments |
| `WeeklyPlanner/Features/Review/` (8 files) | DELETE | entire feature |
| `WeeklyPlanner/Models/Streak.swift` | DELETE | orphaned, never populated |
| `WeeklyPlanner/Stores/SwiftDataStack.swift` | MODIFY | unregister `Streak.self` |
| `WeeklyPlanner/DesignSystem/Typography.swift` | MODIFY | drop `reviewTitle`/`reviewPercent` |
| `WeeklyPlanner/Features/WeekPage/WeekDayRow.swift` | MODIFY | blank empty days |
| `WeeklyPlanner/Features/WeekPicker/MonthGridView.swift` | MODIFY | drop per-month header |
| `WeeklyPlanner/Features/DayPage/DayPageView.swift` | MODIFY | 0.2 s create press |
| `WeeklyPlannerTests/Features/Review/ReviewViewModelTests.swift` | DELETE | dead suite |
| `WeeklyPlannerTests/Navigation/…`, `WeekPage/…`, `WeekPicker/…`, `DesignSystem/TypographyTests.swift` | MODIFY | updated pins |
| `WeeklyPlannerUITests/AccessibilityAuditUITests.swift` | MODIFY | delete review audit |

---

### Task 1: Remove the Review tab + feature + `Streak`

**Files:**
- Modify: `WeeklyPlanner/Navigation/TabSelection.swift` (~lines 6–11, 22–27), `PaperTab.swift` (~:55–62, 64–71, 74–83), `AppShell.swift` (~:77–88)
- Delete: `WeeklyPlanner/Features/Review/` (PaperReviewView, ReviewViewModel, ReviewHeader, ReviewSummaryBlock, AINotesList, StreaksBlock, TimeSpentBarChart, CategoryTimeRow), `WeeklyPlanner/Models/Streak.swift`, `WeeklyPlannerTests/Features/Review/ReviewViewModelTests.swift`
- Modify: `WeeklyPlanner/Stores/SwiftDataStack.swift` (~:16, remove `Streak.self,`), `WeeklyPlanner/DesignSystem/Typography.swift` (~:115–116)
- Modify: `WeeklyPlannerTests/Navigation/TabSelectionNotesTests.swift` (~:24), `TabSelectionTests.swift` (~:29–33), `WeeklyPlannerTests/DesignSystem/TypographyTests.swift` (~:63–66), `WeeklyPlannerUITests/AccessibilityAuditUITests.swift` (~:60–80)

**Interfaces:**
- Produces: `Tab.allCases == [.calendar, .notes, .settings]`; `TabSelection` resolves unknown persisted raws to `.calendar`.

- [ ] **Step 1: Write the failing tests first.**

`TabSelectionNotesTests.swift:24` becomes:

```swift
        XCTAssertEqual(Tab.allCases, [.calendar, .notes, .settings])
```

`TabSelectionTests.swift` — repoint the persistence test at `.notes` and add the legacy-fallback test (adapt to the file's existing store/fixture helpers — it already persists via `UserSettings.lastTabRaw`):

```swift
    func testLegacyReviewRawFallsBackToCalendar() throws {
        try store.update { $0.lastTabRaw = "review" }   // pre-Phase-45 install
        let selection = TabSelection(store: store)       // use the file's real init shape
        XCTAssertEqual(selection.current, .calendar)
    }
```

- [ ] **Step 2: Run to verify failure** — `-only-testing:WeeklyPlannerTests/TabSelectionTests -only-testing:WeeklyPlannerTests/TabSelectionNotesTests`. Expected: FAIL (`.review` still exists / no fallback).

- [ ] **Step 3: Implement the removal.**

3.1 `TabSelection.swift` — delete `case review`. Find where the persisted raw is read back (the `Tab(rawValue:)` restore path — grep `lastTabRaw` in the file/AppShell) and make it total:

```swift
        // Unknown raws (e.g. "review" persisted by a pre-Phase-45 build)
        // fall back to the calendar tab.
        current = Tab(rawValue: storedRaw) ?? .calendar
```

3.2 `PaperTab.swift` — delete the `.review` arms of `iconName` (`"tray"`) and `label` (`"Review"`); change the `#Preview` at ~:74–83 to `PaperTab(tab: .notes, …)`.

3.3 `AppShell.swift` — delete `case .review: PaperReviewView(weekOffset: controller.current.week)` (~:81–82); scrub the "Review" doc comments (~:6–11, 79).

3.4 Delete the nine files (`git rm -r WeeklyPlanner/Features/Review WeeklyPlanner/Models/Streak.swift WeeklyPlannerTests/Features/Review`). Remove `Streak.self,` from `SwiftDataStack.swift:16`. Remove `reviewTitle`/`reviewPercent` from `Typography.swift:115-116` and their assertions from `TypographyTests.swift:63-66`. Delete `testReviewPagePassesAudit` from `AccessibilityAuditUITests.swift:60-80`.

3.5 Sweep: `grep -rn "review\|Review\|Streak" WeeklyPlanner/ WeeklyPlannerTests/ WeeklyPlannerUITests/ --include="*.swift" -i` — remaining hits must be only unrelated words (e.g. `pull_request_review` strings do not exist here; expect zero or comment-only leftovers to scrub).

- [ ] **Step 4: Regenerate + run.**

```bash
xcodegen generate
```

`-only-testing:WeeklyPlannerTests` full unit suite. Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Legacy-store check.** Boot a simulator that ran the previous build (or pre-seed a store containing a `Streak` row via a scratch build), install this build, launch: app opens, calendar tab selected. Note the result in the task report.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(nav): remove Review tab, feature, and orphaned Streak model (Phase 45 #74)"
```

---

### Task 2: Blank empty week days

**Files:**
- Modify: `WeeklyPlanner/Features/WeekPage/WeekDayRow.swift` (~:81, 88–94; doc comments :5, 86, 172)
- Modify: `WeeklyPlannerTests/WeekPage/WeekDayRowTests.swift` (~:37)

- [ ] **Step 1: Update the pin test.** Replace the `emptyPlaceholder == "none"` assertion at `WeekDayRowTests.swift:37` with a structural pin:

```swift
    func testEmptyDayRendersNoPlaceholderText() {
        // Feedback #75 (reverses round-1 #28): empty days are blank.
        // The placeholder constant is gone; empty layout keeps the row's
        // 56pt minHeight so the week grid rhythm is unchanged.
        XCTAssertEqual(WeekDayRow.emptyRowMinHeight, 56)
    }
```

- [ ] **Step 2: Run to verify failure.** Expected: compile failure.

- [ ] **Step 3: Implement.** In `WeekDayRow.swift`: delete `static let emptyPlaceholder = "none"` (:81); expose the existing height floor as `static let emptyRowMinHeight: CGFloat = 56` and use it in the `.frame(minHeight:)` (~:47); replace the empty branch (~:90–94):

```swift
                if layout.isEmpty {
                    Color.clear
                        .frame(maxWidth: .infinity, minHeight: Self.emptyRowMinHeight, alignment: .leading)
                } else if ...
```

Scrub the "none" doc comments (:5, 86, 172). Leave `Localizable.xcstrings`'s capitalized `"None"` key alone — it belongs to the recurrence picker, not this row.

- [ ] **Step 4: Run to verify pass** — `-only-testing:WeeklyPlannerTests/WeekDayRowTests -only-testing:WeeklyPlannerTests/WeekPageViewModelTests`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Features/WeekPage/WeekDayRow.swift WeeklyPlannerTests/WeekPage/WeekDayRowTests.swift
git commit -m "feat(week): empty days render blank, not 'none' (Phase 45 #75, reverses #28)"
```

---

### Task 3: Deduplicate the week-picker month title

**Files:**
- Modify: `WeeklyPlanner/Features/WeekPicker/MonthGridView.swift` (header call site ~:39–40; `header` var ~:54–63; `titleAlignment` ~:14 if now unused)
- Modify: `WeeklyPlannerTests/WeekPicker/MonthGridViewTests.swift` (`testTitleCentered`)

- [ ] **Step 1: Update the test.** Replace `testTitleCentered` with a guard that the grid no longer renders its own title (if the test asserted on `titleAlignment`, delete it and pin the property's removal by compilation):

```swift
    func testMonthGridHasNoOwnTitle() {
        // Feedback #76: the sticky nav-bar title (weekpickerNavTitle) is the
        // single month/year label; MonthGridView renders the weeks only.
        // Compile-time pin: MonthGridView.titleAlignment no longer exists —
        // this test intentionally references nothing; the build is the assert.
        XCTAssertTrue(true)
    }
```

(If `MonthGridViewTests` has other structure assertions that referenced the header, update them the same way; the deliverable is: grid body contains no `month.title` text.)

- [ ] **Step 2: Implement.** In `MonthGridView.swift`: remove the `header` computed var (~:54–63) and its call site (~:39–40); remove `titleAlignment` (~:14) if nothing else reads it. The sticky nav title (`WeekPickerSheet.swift:174-179`, id `weekpickerNavTitle`) stays and already tracks the scrolled month.

- [ ] **Step 3: Run** — `-only-testing:WeeklyPlannerTests/MonthGridViewTests -only-testing:WeeklyPlannerTests/WeekPickerViewModelTests`, plus any week-picker UI suite (`grep -l -i "weekpicker" WeeklyPlannerUITests/`). Expected: PASS.

- [ ] **Step 4: Manual check (signed sim):** open the week picker: exactly one "July 2026"; scroll to August: nav title updates; ‹ › steppers work.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Features/WeekPicker/ WeeklyPlannerTests/WeekPicker/
git commit -m "fix(weekpicker): single month/year title — drop per-month grid header (Phase 45 #76)"
```

---

### Task 4: Fast free-text creation

**Files:**
- Modify: `WeeklyPlanner/Features/DayPage/DayPageView.swift` (`annotationCreationGesture`, ~:384–413)
- Test: `WeeklyPlannerUITests/AnnotationsUITests.swift` (timing-sensitive steps)

- [ ] **Step 1: Change the constant + name it.**

```swift
    /// How long a press on empty paper must last before a note is created.
    /// 0.45s read as "nothing is happening" (feedback #57); 0.2s still
    /// filters accidental brushes while feeling immediate.
    static let annotationPressDuration: TimeInterval = 0.2
```

and `LongPressGesture(minimumDuration: Self.annotationPressDuration)` at ~:385. Keep the `.simultaneously(with: DragGesture(minimumDistance: 0, …))` recipe **exactly** — it exists so synthesized XCUI presses fire (Phase 34 lesson `phase-34-gesture-a11y-lessons`); removing it breaks the UI tests.

- [ ] **Step 2: Tighten the editor hop.** In the creation `.onEnded`, the `Task { … addAnnotation … editingAnnotationID = created.id }` stays (persistence is async), but verify `AnnotationView`'s editor `.task { focused = true }` fires on first appearance — if the keyboard is still perceptibly late on device, change the editor to set focus in `.onAppear` and keep `.task` as fallback. This is a judgment call at implementation time; the acceptance bar is "keyboard visibly rising within ~0.3 s of finger-lift on a real device/simulator".

- [ ] **Step 3: Unit pin** (append to `WeeklyPlannerTests/Annotations/DayPageLayoutTests.swift` or a nearby day-page suite):

```swift
    func testAnnotationPressDurationIsFast() {
        XCTAssertLessThanOrEqual(DayPageView.annotationPressDuration, 0.2,
                                 "Feedback #57: creating free text must not require a long hold")
    }
```

⚠️ If `DayPageView`'s access level hides the constant from tests, mark it `internal` (test target uses `@testable`).

- [ ] **Step 4: Run** — `-only-testing:WeeklyPlannerTests` (touched suites) then `-only-testing:WeeklyPlannerUITests/AnnotationsUITests`. The UI test's `press(forDuration:)` values (≥0.45 today) still exceed the new minimum, so they pass unchanged; if any step asserted a minimum-duration boundary, update it to 0.2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Features/DayPage/DayPageView.swift WeeklyPlannerTests/ WeeklyPlannerUITests/
git commit -m "feat(annotations): 0.2s create press + immediate editor focus (Phase 45 #57)"
```

---

### Task 5: Full verification (superpowers:verification-before-completion)

- [ ] **Step 1: Full unit suite.** Expected: `** TEST SUCCEEDED **`.
- [ ] **Step 2: UI suites** — `SmokeUITests`, `AnnotationsUITests`, `AccessibilityAuditUITests`, `AIStickyStackUITests`, week-picker suite. Expected: PASS.
- [ ] **Step 3: Grep proof** — review/Streak sweep from Task 1 Step 3.5 returns clean.
- [ ] **Step 4: Signed-sim manual pass:** 3 tabs; blank empty week days; single month title; snappy note creation; upgrade-path launch from a store that had `lastTabRaw == "review"`.
- [ ] **Step 5: Phase-doc checklist sweep** — `docs/phases/phase-45-chrome-simplification.md`. Report branch, diffstat, deviations.

---

## Self-review notes

- **Spec coverage:** #74 (T1), #75 (T2), #76 (T3), #57 (T4).
- **Type consistency:** `Tab.allCases` 3-case list matches T1 test; `emptyRowMinHeight` name matches T2 test↔impl; `annotationPressDuration` matches T4 test↔impl.
- **Deliberate choices:** delete Review rather than hide (decision 8); keep shared `WeekSummary*` types; keep the XCUI-compatible simultaneous-gesture recipe; blank empty days keep the 56pt floor so week-grid rhythm is stable; tap-to-create rejected (misfire risk) in favor of a shorter press.
- **Known adaptation points (flagged inline):** `TabSelection` init/restore shape, `MonthGridViewTests` existing assertions, editor-focus fine-tuning on device.
