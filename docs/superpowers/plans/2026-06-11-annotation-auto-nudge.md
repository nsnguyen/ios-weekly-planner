# Annotation Auto-Nudge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When the content column grows into a machine-placed note (create a note, then create an event), the note restacks below the new content; user-dragged notes never move.

**Architecture:** A persisted `autoPlaced` flag on `Annotation` (set by stacking creation, cleared by drag-commit) marks which notes the machine may move. A pure `DayPageLayout.nudgesForContentGrowth` computes the restack from plain values; `DayPageViewModel.nudgeAutoPlacedNotes` applies it with animation and persists WITHOUT touching the flag; `DayPageView` triggers it from `.onChange(of: contentBottomY)` on growth only.

**Tech Stack:** Swift / SwiftUI, SwiftData (additive `@Model` field), XCTest + XCUITest, XcodeGen (no new app files; one decision: tests append to existing files).

**Spec:** `docs/superpowers/specs/2026-06-11-annotation-auto-nudge-design.md`

---

## File Structure

| File | Responsibility | Action |
|------|----------------|--------|
| `WeeklyPlanner/Models/Annotation.swift` | `autoPlaced: Bool = false` stored field + init param | Modify |
| `WeeklyPlanner/Stores/AnnotationStore.swift` | copy `autoPlaced` in `upsert`'s update branch (field-by-field copy — forgetting this silently drops the flag on every update) | Modify |
| `WeeklyPlanner/Features/DayPage/DayPageLayout.swift` | nested `AnnotationNudge` struct + pure `nudgesForContentGrowth` | Modify |
| `WeeklyPlanner/Features/DayPage/DayPageViewModel.swift` | `autoPlaced: true` on create; `= false` on drag-commit; new `nudgeAutoPlacedNotes` | Modify (`:324-339`, `:365-372`, append) |
| `WeeklyPlanner/Features/DayPage/DayPageView.swift` | `.onChange(of: contentBottomY)` growth trigger | Modify (after `:208`) |
| `WeeklyPlannerTests/Annotations/AnnotationStoreTests.swift` | flag persistence tests | Modify (append) |
| `WeeklyPlannerTests/Annotations/DayPageLayoutTests.swift` | pure-helper tests | Modify (append) |
| `WeeklyPlannerUITests/AnnotationsUITests.swift` | note-then-event end-to-end test | Modify (append) |

**Conventions captured from the codebase:**
- `SwiftDataStack.inMemoryContainer()` + `SwiftDataAnnotationStore(context: container.mainContext)` is the store-test fixture (`AnnotationStoreTests.swift:10-14`).
- `SwiftDataAnnotationStore.upsert` updates by copying EVERY field onto the fetched row (`AnnotationStore.swift:32-39`) — new model fields must be added to that copy block.
- `DayPageViewModel` is `@MainActor @Observable`, imports `Foundation/Observation/SwiftData` — Task 3 adds `import SwiftUI` for `withAnimation`.
- VM-level flag-lifecycle tests are intentionally skipped: the VM has no test fixture in this repo, the glue is three lines, and the UI test covers the chain end-to-end. Store tests + pure tests + UI test are the coverage.
- The existing UI-test helpers (`launchOnTestDayPage`, `purgeAllAnnotations`, `createAnnotation`, `deleteAnnotationIfPresent`, `ID.*`) and the event-creation recipe (`daypage.events.addRow` → first text field → type → Return → `paperEventSheet.save`) are reused verbatim — do not reinvent.
- NEVER pass `CODE_SIGNING_ALLOWED=NO` to unit-test runs (it breaks keychain-entitlement tests); it IS required for UI-test runs.
- Worktree setup needs the repo-root gitignored `Secrets.xcconfig` copied in before `xcodegen generate`.

**Test/destination command used throughout** (substitute any available iPhone simulator; disambiguate with `,OS=26.5` if needed):

```bash
DEST='platform=iOS Simulator,name=iPhone 17'
```

---

## Task 0: Worktree + baseline

**Files:** none (environment setup)

- [ ] **Step 1: Create the worktree** (if running as a spawned agent, verify isolation yourself and work in the worktree path explicitly)

```bash
git -C /Users/nguyen-mini/Documents/dev/ios-weekly-planner worktree add \
  ../wp-auto-nudge -b annotation-auto-nudge
cp /Users/nguyen-mini/Documents/dev/ios-weekly-planner/Secrets.xcconfig \
   /Users/nguyen-mini/Documents/dev/wp-auto-nudge/
cd /Users/nguyen-mini/Documents/dev/wp-auto-nudge && xcodegen generate
```

Expected: `Created project at .../wp-auto-nudge/WeeklyPlanner.xcodeproj`.

- [ ] **Step 2: Baseline unit-test run**

```bash
xcodebuild test -scheme WeeklyPlanner -destination "$DEST" \
  -only-testing:WeeklyPlannerTests 2>&1 | tail -5
```

Expected: `** TEST SUCCEEDED **`, 515 tests, 0 failures. Do not proceed on red — report instead.

---

## Task 1: `autoPlaced` model field + store persistence (TDD)

**Files:**
- Modify: `WeeklyPlanner/Models/Annotation.swift`
- Modify: `WeeklyPlanner/Stores/AnnotationStore.swift:32-39`
- Test: `WeeklyPlannerTests/Annotations/AnnotationStoreTests.swift` (append)

- [ ] **Step 1: Write the failing tests** — append inside the `AnnotationStoreTests` class:

```swift
    func testAutoPlacedFlagRoundTrips() async throws {
        let a = Annotation(dayKey: "0:5", text: "stacked", colorToken: .ink,
                           isBold: false, autoPlaced: true, unitX: 0.1, unitY: 0.2)
        try await store.upsert(a)

        let fetched = try await store.annotations(dayKey: "0:5").first
        XCTAssertEqual(fetched?.autoPlaced, true)
    }

    func testUpsertExistingUpdatesAutoPlaced() async throws {
        let id = UUID()
        try await store.upsert(Annotation(id: id, dayKey: "0:5", text: "v1", colorToken: .ink,
                                          isBold: false, autoPlaced: true, unitX: 0.5, unitY: 0.5))
        // Drag-commit path writes the same row with the flag cleared — the
        // store's field-by-field update copy must include it.
        try await store.upsert(Annotation(id: id, dayKey: "0:5", text: "v1", colorToken: .ink,
                                          isBold: false, autoPlaced: false, unitX: 0.5, unitY: 0.6))

        let fetched = try await store.annotations(dayKey: "0:5").first
        XCTAssertEqual(fetched?.autoPlaced, false)
    }
```

- [ ] **Step 2: Run to verify failure**

```bash
xcodebuild test -scheme WeeklyPlanner -destination "$DEST" \
  -only-testing:WeeklyPlannerTests/AnnotationStoreTests 2>&1 | tail -20
```

Expected: COMPILE FAILURE — `extra argument 'autoPlaced' in call` / no member `autoPlaced`.

- [ ] **Step 3: Implement.** In `WeeklyPlanner/Models/Annotation.swift`, add the stored property below `isBold` and the init param; existing rows decode the default `false` (= pinned), which is exactly the intended migration:

```swift
    var isBold: Bool
    /// True while the note sits where the stacking gesture placed it — the
    /// machine may restack it when content grows underneath. A user drag
    /// clears it forever (the machine never moves what the user placed).
    /// The property-level `= false` is load-bearing: SwiftData lightweight
    /// migration takes the schema default from the declaration (not the
    /// init), so pre-feature rows decode as pinned instead of crashing the
    /// container open (same lesson as AIInsight, commit 1d48e6d).
    var autoPlaced: Bool = false
```

and in the initializer (parameter inserted after `isBold`, before `unitX`; assignment alongside the others):

```swift
    init(id: UUID = UUID(),
         dayKey: String,
         text: String,
         colorToken: InkColorToken = .ink,
         isBold: Bool = false,
         autoPlaced: Bool = false,
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
        self.autoPlaced = autoPlaced
        self.unitX = unitX
        self.unitY = unitY
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
```

In `WeeklyPlanner/Stores/AnnotationStore.swift`, extend the update copy block (the line order mirrors the model):

```swift
        if let existing {
            existing.dayKey = annotation.dayKey
            existing.text = annotation.text
            existing.colorTokenRaw = annotation.colorTokenRaw
            existing.isBold = annotation.isBold
            existing.autoPlaced = annotation.autoPlaced
            existing.unitX = annotation.unitX
            existing.unitY = annotation.unitY
            existing.updatedAt = .init()
        } else {
            context.insert(annotation)
        }
```

- [ ] **Step 4: Run to verify pass** — same command. Expected: `** TEST SUCCEEDED **` (existing store tests + 2 new).

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Models/Annotation.swift \
        WeeklyPlanner/Stores/AnnotationStore.swift \
        WeeklyPlannerTests/Annotations/AnnotationStoreTests.swift
git commit -m "feat(annotations): autoPlaced flag — additive field, persisted through upsert"
```

---

## Task 2: Pure reflow helper (TDD)

**Files:**
- Modify: `WeeklyPlanner/Features/DayPage/DayPageLayout.swift` (append inside the enum)
- Test: `WeeklyPlannerTests/Annotations/DayPageLayoutTests.swift` (append inside the class)

- [ ] **Step 1: Write the failing tests** — append inside `DayPageLayoutTests` (note `import Foundation` may be needed for `UUID`; add it below `import CoreGraphics` if the file lacks it):

```swift
    // MARK: - Auto-nudge on content growth

    private func note(_ id: UUID, unitY: Double, autoPlaced: Bool = true)
        -> (id: UUID, unitY: Double, autoPlaced: Bool)
    {
        (id: id, unitY: unitY, autoPlaced: autoPlaced)
    }

    func testNoCollisionsYieldsNoNudges() {
        let id = UUID()
        // Note top (0.5 × 800 = 400) is below the content bottom (200).
        let nudges = DayPageLayout.nudgesForContentGrowth(
            notes: [note(id, unitY: 0.5)], editingID: nil, contentBottom: 200,
            noteHeights: [id: 20], layerSize: CGSize(width: 400, height: 800))
        XCTAssertTrue(nudges.isEmpty)
    }

    func testPinnedCollidingNoteIsNotNudged() {
        let id = UUID()
        let nudges = DayPageLayout.nudgesForContentGrowth(
            notes: [note(id, unitY: 0.1, autoPlaced: false)], editingID: nil,
            contentBottom: 200, noteHeights: [id: 20],
            layerSize: CGSize(width: 400, height: 800))
        XCTAssertTrue(nudges.isEmpty)
    }

    func testEditingNoteIsNotNudged() {
        let id = UUID()
        let nudges = DayPageLayout.nudgesForContentGrowth(
            notes: [note(id, unitY: 0.1)], editingID: id, contentBottom: 200,
            noteHeights: [id: 20], layerSize: CGSize(width: 400, height: 800))
        XCTAssertTrue(nudges.isEmpty)
    }

    func testCollidingNoteRestacksBelowContent() {
        let id = UUID()
        let nudges = DayPageLayout.nudgesForContentGrowth(
            notes: [note(id, unitY: 0.1)], editingID: nil, contentBottom: 200,
            noteHeights: [id: 20], layerSize: CGSize(width: 400, height: 800))
        XCTAssertEqual(nudges.map(\.id), [id])
        XCTAssertEqual(nudges[0].unitY * 800, 200 + DayPageLayout.stackSpacing, accuracy: 0.0001)
    }

    func testMultipleCollidingNotesRestackInVerticalOrder() {
        let a = UUID(), b = UUID()
        // Passed b-first to prove ordering comes from unitY, not input order.
        let nudges = DayPageLayout.nudgesForContentGrowth(
            notes: [note(b, unitY: 0.15), note(a, unitY: 0.05)], editingID: nil,
            contentBottom: 200, noteHeights: [a: 20, b: 20],
            layerSize: CGSize(width: 400, height: 800))
        XCTAssertEqual(nudges.map(\.id), [a, b])
        XCTAssertEqual(nudges[0].unitY * 800, 212, accuracy: 0.0001) // 200 + 12
        XCTAssertEqual(nudges[1].unitY * 800, 244, accuracy: 0.0001) // 212 + 20 + 12
    }

    func testNudgedNoteLandsBelowPinnedNoteUnderTheContent() {
        let moving = UUID(), pinned = UUID()
        // Pinned note sits below the content (top 320, bottom 340) — the
        // nudged note must clear it, not just the content bottom.
        let nudges = DayPageLayout.nudgesForContentGrowth(
            notes: [note(moving, unitY: 0.1), note(pinned, unitY: 0.4, autoPlaced: false)],
            editingID: nil, contentBottom: 200,
            noteHeights: [moving: 20, pinned: 20],
            layerSize: CGSize(width: 400, height: 800))
        XCTAssertEqual(nudges.map(\.id), [moving])
        XCTAssertEqual(nudges[0].unitY * 800, 340 + DayPageLayout.stackSpacing, accuracy: 0.0001)
    }

    func testDegenerateLayerYieldsNoNudges() {
        let id = UUID()
        let nudges = DayPageLayout.nudgesForContentGrowth(
            notes: [note(id, unitY: 0.1)], editingID: nil, contentBottom: 200,
            noteHeights: [id: 20], layerSize: .zero)
        XCTAssertTrue(nudges.isEmpty)
    }
```

- [ ] **Step 2: Run to verify failure**

```bash
xcodebuild test -scheme WeeklyPlanner -destination "$DEST" \
  -only-testing:WeeklyPlannerTests/DayPageLayoutTests 2>&1 | tail -20
```

Expected: COMPILE FAILURE — no member `nudgesForContentGrowth`.

- [ ] **Step 3: Implement** — append inside the `DayPageLayout` enum (needs `import Foundation` added below `import CoreGraphics` at the top of `DayPageLayout.swift` for `UUID`):

```swift
    /// One computed auto-nudge: move note `id` so its top sits at `unitY`.
    struct AnnotationNudge: Equatable {
        let id: UUID
        let unitY: Double
    }

    /// Restack plan for content growth: machine-placed (`autoPlaced`) notes
    /// whose tops the content column has grown past are restacked below it —
    /// in their current vertical order, each clearing the content, every
    /// pinned/editing/non-colliding note, and every note already restacked.
    /// Pinned (user-dragged), editing, and below-content notes never move.
    /// Pure: plain values in, nudges out — unit-testable without SwiftUI.
    static func nudgesForContentGrowth(notes: [(id: UUID, unitY: Double, autoPlaced: Bool)],
                                       editingID: UUID?,
                                       contentBottom: CGFloat,
                                       noteHeights: [UUID: CGFloat],
                                       layerSize: CGSize) -> [AnnotationNudge] {
        guard layerSize.width > 0, layerSize.height > 0 else { return [] }
        let colliding = notes
            .filter { $0.autoPlaced && $0.id != editingID
                && CGFloat($0.unitY) * layerSize.height < contentBottom }
            .sorted { $0.unitY < $1.unitY }
        guard !colliding.isEmpty else { return [] }

        let collidingIDs = Set(colliding.map(\.id))
        var bottoms = notes
            .filter { !collidingIDs.contains($0.id) }
            .map { CGFloat($0.unitY) * layerSize.height + (noteHeights[$0.id] ?? 0) }

        var nudges: [AnnotationNudge] = []
        for note in colliding {
            let unit = stackedAnnotationUnit(contentBottom: contentBottom,
                                             annotationBottoms: bottoms,
                                             layerSize: layerSize)
            nudges.append(AnnotationNudge(id: note.id, unitY: unit.y))
            bottoms.append(CGFloat(unit.y) * layerSize.height + (noteHeights[note.id] ?? 0))
        }
        return nudges
    }
```

- [ ] **Step 4: Run to verify pass** — same command. Expected: `** TEST SUCCEEDED **`, 13 layout tests (6 existing + 7 new).

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Features/DayPage/DayPageLayout.swift \
        WeeklyPlannerTests/Annotations/DayPageLayoutTests.swift
git commit -m "feat(annotations): pure nudgesForContentGrowth reflow helper"
```

---

## Task 3: VM nudge + flag lifecycle + view trigger

**Files:**
- Modify: `WeeklyPlanner/Features/DayPage/DayPageViewModel.swift` (`:1-3` imports, `:324-339` create, `:365-372` drag, append method)
- Modify: `WeeklyPlanner/Features/DayPage/DayPageView.swift` (after the `.coordinateSpace(.named(...))` line, ~`:208`)

- [ ] **Step 1: VM — add `import SwiftUI`** below the existing imports at the top of `DayPageViewModel.swift` (needed for `withAnimation`):

```swift
import Foundation
import Observation
import SwiftData
import SwiftUI
```

- [ ] **Step 2: VM — mark stacking creations.** In `addAnnotation(atUnit:)` (line ~326), the `Annotation` init call gains `autoPlaced: true` (this method's only caller is the stacking gesture):

```swift
        let annotation = Annotation(dayKey: dayKey,
                                    text: "",
                                    colorToken: .ink,
                                    isBold: false,
                                    autoPlaced: true,
                                    unitX: clamped.x,
                                    unitY: clamped.y)
```

- [ ] **Step 3: VM — drag pins.** In `moveAnnotation(id:toUnit:)` (line ~365), clear the flag alongside the position write:

```swift
    func moveAnnotation(id: UUID, toUnit point: CGPoint) async {
        guard let annotation = annotations.first(where: { $0.id == id }) else { return }
        let clamped = Annotation.clampUnit(point)
        annotation.unitX = clamped.x
        annotation.unitY = clamped.y
        // A drag pins the note: the user placed it, so content growth must
        // never auto-move it again (autoPlaced gates nudgesForContentGrowth).
        annotation.autoPlaced = false
        try? await annotationStore.upsert(annotation)
        await refreshAnnotations()
    }
```

- [ ] **Step 4: VM — the nudge method.** Append after `moveAnnotation`:

```swift
    /// Auto-nudge: restack machine-placed notes the content column has grown
    /// into (note first, event second — the event would overlap the note).
    /// Persists via upsert WITHOUT touching `autoPlaced`: only a user drag
    /// pins a note; a nudge must leave it nudgeable for the next growth.
    func nudgeAutoPlacedNotes(contentBottom: CGFloat,
                              layerSize: CGSize,
                              noteHeights: [UUID: CGFloat],
                              editingID: UUID?) async {
        let nudges = DayPageLayout.nudgesForContentGrowth(
            notes: annotations.map { (id: $0.id, unitY: $0.unitY, autoPlaced: $0.autoPlaced) },
            editingID: editingID,
            contentBottom: contentBottom,
            noteHeights: noteHeights,
            layerSize: layerSize)
        guard !nudges.isEmpty else { return }
        // Animated so the restack reads as deliberate, not a glitch.
        withAnimation {
            for nudge in nudges {
                annotations.first(where: { $0.id == nudge.id })?.unitY = nudge.unitY
            }
        }
        for nudge in nudges {
            if let annotation = annotations.first(where: { $0.id == nudge.id }) {
                try? await annotationStore.upsert(annotation)
            }
        }
        await refreshAnnotations()
    }
```

- [ ] **Step 5: View trigger.** In `DayPageView.swift`, append directly after `.coordinateSpace(.named(Self.layerSpaceName))` (same modifier chain):

```swift
                                .onChange(of: contentBottomY) { oldValue, newValue in
                                    // Content column grew (event/inbox row
                                    // arrived): restack machine-placed notes
                                    // it now overlaps. Growth only — content
                                    // shrinking never pulls notes back up.
                                    // The initial 0 → first-layout fire is
                                    // harmless: notes below the content
                                    // bottom don't collide, and an actually
                                    // overlapped note self-heals on appear.
                                    guard newValue > oldValue, let viewModel else { return }
                                    let layer = annotationLayerSize
                                    let heights = noteHeights
                                    let editing = editingAnnotationID
                                    Task {
                                        await viewModel.nudgeAutoPlacedNotes(
                                            contentBottom: newValue,
                                            layerSize: layer,
                                            noteHeights: heights,
                                            editingID: editing)
                                    }
                                }
```

- [ ] **Step 6: Run the full unit suite**

```bash
xcodebuild test -scheme WeeklyPlanner -destination "$DEST" \
  -only-testing:WeeklyPlannerTests 2>&1 | tail -5
```

Expected: `** TEST SUCCEEDED **`, 524 tests (515 baseline + 2 store + 7 layout), 0 failures.

- [ ] **Step 7: Commit**

```bash
git add WeeklyPlanner/Features/DayPage/DayPageViewModel.swift \
        WeeklyPlanner/Features/DayPage/DayPageView.swift
git commit -m "feat(annotations): auto-nudge undragged notes when content grows"
```

---

## Task 4: UI test — note, then event, no overlap

**Files:**
- Modify: `WeeklyPlannerUITests/AnnotationsUITests.swift` (append one test)

- [ ] **Step 1: Append the test** after `testNewNotesStackFromTopOfEmptyDay`, inside the class:

```swift
    @MainActor
    func testEventCreatedAfterNoteNudgesNoteBelowIt() {
        let app = launchOnTestDayPage()
        purgeAllAnnotations(app)

        XCTAssertTrue(createAnnotation(in: app, text: "nudge me"),
                      "Annotation editor did not appear after long-press attempts")
        app.buttons[ID.styleDone].tap()
        let note = app.staticTexts["nudge me"]
        XCTAssertTrue(note.waitForExistence(timeout: 4), "Note not rendered")
        let topBefore = note.frame.minY

        // Create an event on the same day — the content column grows into
        // the band the note occupies (same recipe as EventCreateFlowUITests).
        let addLink = app.buttons["daypage.events.addRow"]
        XCTAssertTrue(addLink.waitForExistence(timeout: 5))
        addLink.tap()
        let titleField = app.textFields.firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 2)
        titleField.typeText("nudge event")
        if app.keyboards.firstMatch.exists {
            app.keyboards.buttons["Return"].tap()
            _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 2)
        }
        let save = app.buttons["paperEventSheet.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 2))
        save.tap()
        _ = save.waitForNonExistence(timeout: 5)

        let eventRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "nudge event")).firstMatch
        XCTAssertTrue(eventRow.waitForExistence(timeout: 5), "Event row not visible")
        sleep(1) // let the nudge animation settle before reading frames

        // The note must have moved below the event row — no overlap.
        XCTAssertTrue(note.waitForExistence(timeout: 4), "Note vanished after event creation")
        XCTAssertGreaterThanOrEqual(note.frame.minY, eventRow.frame.maxY,
                                    "Note should be nudged below the event row")
        XCTAssertGreaterThan(note.frame.minY, topBefore,
                             "Note should have moved down from its pre-event position")

        // Cleanup (mandatory — persistent store): note first, then the event
        // via its row → sheet delete (confirmation dialog may appear).
        deleteAnnotationIfPresent(app, text: "nudge me")
        if eventRow.exists {
            eventRow.tap()
            let del = app.buttons["eventsheet.delete"]
            if del.waitForExistence(timeout: 3) {
                del.tap()
                let confirm = app.buttons["Delete"].firstMatch
                if confirm.waitForExistence(timeout: 2) { confirm.tap() }
            }
        }
    }
```

- [ ] **Step 2: Run the new test** (signing flag required and fine for UI tests)

```bash
xcodebuild test -scheme WeeklyPlanner -destination "$DEST" \
  -only-testing:WeeklyPlannerUITests/AnnotationsUITests/testEventCreatedAfterNoteNudgesNoteBelowIt \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10
```

Expected: `** TEST SUCCEEDED **`, 1 test, 0 failures. If it fails, distinguish test-logic flake (timing/queries — fix minimally, never weaken the no-overlap assertions) from the app not nudging (report BLOCKED with the measured frames; suspect residue contamination first — see the generic purge — and only then the implementation).

- [ ] **Step 3: Run the whole annotations UI suite (regression)**

```bash
xcodebuild test -scheme WeeklyPlanner -destination "$DEST" \
  -only-testing:WeeklyPlannerUITests/AnnotationsUITests \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10
```

Expected: `** TEST SUCCEEDED **`, 4 tests, 0 failures.

- [ ] **Step 4: Commit**

```bash
git add WeeklyPlannerUITests/AnnotationsUITests.swift
git commit -m "test(annotations): UI coverage — event created after note nudges it below"
```

---

## Task 5: Full verification + merge handoff

**Files:** none

- [ ] **Step 1: Full unit suite** — expected 524 tests, 0 failures (command as in Task 3 Step 6).

- [ ] **Step 2: Manual spot-check (drag pinning is not UI-tested):** build + launch on the simulator, create a note on an empty day, DRAG it somewhere, then create an event — the dragged note must NOT move. Screenshot for the record:

```bash
xcodebuild build -scheme WeeklyPlanner -destination "$DEST" 2>&1 | tail -3
APP=$(find ~/Library/Developer/Xcode/DerivedData -name "WeeklyPlanner.app" \
      -path "*iphonesimulator*" -not -path "*Tests*" | head -1)
xcrun simctl install booted "$APP"
xcrun simctl launch booted com.weeklyplanner.WeeklyPlanner
xcrun simctl io booted screenshot /tmp/nudge-pin-check.png
```

(Drive the create/drag/event steps by hand or report them for the controller's visual-driver flow; the assertion is "dragged note stayed put".)

- [ ] **Step 3: Hand off for merge** — superpowers:finishing-a-development-branch (merge `annotation-auto-nudge` to main fast-forward from the main checkout, verify suite on merged main, remove worktree, delete branch).
