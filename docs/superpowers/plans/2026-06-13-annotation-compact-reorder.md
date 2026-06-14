# Annotation Compact-Reorder Stack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Day-page notes always pack gaplessly below the content; dragging a note reorders it (drop-Y → sort by `unitY` → re-pack tight).

**Architecture:** One pure `compactedStack` function packs all notes below the content in `unitY` order, bidirectionally and idempotently — replacing the down-only auto-nudge. A drag writes the drop-`unitY` then bumps a VM compaction token; `DayPageView` (which owns the measured anchors) observes the token and content-bottom changes and runs `compactNotes`, which persists only the notes that moved. The old `nudgesForContentGrowth` / `moveAnnotation` / `autoPlaced`-pin path is deleted.

**Tech Stack:** Swift, SwiftUI, SwiftData, XCTest. Build/test via `xcodebuild` against the iPhone 17 Pro simulator.

**Spec:** `docs/superpowers/specs/2026-06-13-annotation-compact-reorder-design.md`

---

## Pre-flight: branch

```bash
git checkout -b annotation-compact-reorder
```

No files are created (all edits to existing files), so **no `xcodegen generate`** is needed.

**Build/test commands** (reused every task):

```bash
# Targeted unit test
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/DayPageLayoutTests CODE_SIGNING_ALLOWED=NO

# Build only
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' CODE_SIGNING_ALLOWED=NO
```

> **Lint note:** `swiftformat --lint .` / `swiftlint --strict` are NOT clean gates in this repo (large pre-existing baseline incl. SPM deps; per-file linting bypasses config excludes → false positives). Verify only that *your changed files* add no new swiftlint violation: run `swiftlint --strict` from root and grep for your files. Judge new lines by eye against neighbors + `--maxwidth 120`. The real gate is xcodebuild.

## File Structure

| File | Responsibility | Change |
|------|----------------|--------|
| `WeeklyPlanner/Features/DayPage/DayPageLayout.swift` | Pure day-page geometry | Add `compactedStack` + `AnnotationPlacement`; (Task 4) remove `nudgesForContentGrowth` + `AnnotationNudge` |
| `WeeklyPlanner/Features/DayPage/DayPageViewModel.swift` | Day VM, annotation CRUD | Add `compactNotes` + `compactionRequest`/`requestCompaction`; bump token in `refreshAnnotations`; (Task 4) remove `nudgeAutoPlacedNotes` + `moveAnnotation` |
| `WeeklyPlanner/Features/DayPage/DayPageView.swift` | Day page view + triggers | `contentBottomY` onChange both directions → `compactNotes`; observe `compactionRequest` |
| `WeeklyPlanner/Features/DayPage/Annotations/AnnotationView.swift` | One note's drag | `onEnded` writes drop-`unitY` then `requestCompaction()` |
| `WeeklyPlannerTests/Annotations/DayPageLayoutTests.swift` | Pure geometry tests | Add `compactedStack` tests; (Task 4) remove nudge tests |
| `WeeklyPlannerTests/Annotations/AnnotationLayerTests.swift` | VM tests | Add `compactNotes` tests; (Task 4) remove `testMoveClampsAndPersists` |

---

## Task 1: Pure `compactedStack` (TDD, additive)

Add the new function *alongside* the existing nudge so the build stays green.

**Files:**
- Test: `WeeklyPlannerTests/Annotations/DayPageLayoutTests.swift`
- Modify: `WeeklyPlanner/Features/DayPage/DayPageLayout.swift`

- [ ] **Step 1: Write the failing tests**

Append inside `DayPageLayoutTests` (before its closing `}`):

```swift
    // MARK: - Compact-reorder stack

    func testCompactPacksTwoNotesTightBelowContent() {
        let a = UUID(), b = UUID()
        let layer = CGSize(width: 400, height: 800)
        let placements = DayPageLayout.compactedStack(
            notes: [(id: a, unitY: 0.3, height: 20), (id: b, unitY: 0.6, height: 20)],
            contentBottom: 100, layerSize: layer)
        XCTAssertEqual(placements.map(\.id), [a, b])
        XCTAssertEqual(placements[0].unitY * 800, 112, accuracy: 0.0001) // 100 + stackSpacing(12)
        XCTAssertEqual(placements[1].unitY * 800, 144, accuracy: 0.0001) // 112 + 20 + 12
    }

    func testCompactIsIdempotent() {
        let a = UUID(), b = UUID()
        let layer = CGSize(width: 400, height: 800)
        let first = DayPageLayout.compactedStack(
            notes: [(id: a, unitY: 0.3, height: 20), (id: b, unitY: 0.6, height: 20)],
            contentBottom: 100, layerSize: layer)
        let second = DayPageLayout.compactedStack(
            notes: first.map { (id: $0.id, unitY: $0.unitY, height: CGFloat(20)) },
            contentBottom: 100, layerSize: layer)
        XCTAssertEqual(first, second)
    }

    func testCompactOrdersByUnitYNotInputOrder() {
        let a = UUID(), b = UUID(), c = UUID()
        let layer = CGSize(width: 400, height: 800)
        // Input order b, a, c; unitY says a(0.1) < c(0.5) < b(0.9) → packed a, c, b.
        let placements = DayPageLayout.compactedStack(
            notes: [(id: b, unitY: 0.9, height: 20),
                    (id: a, unitY: 0.1, height: 20),
                    (id: c, unitY: 0.5, height: 20)],
            contentBottom: 100, layerSize: layer)
        XCTAssertEqual(placements.map(\.id), [a, c, b])
    }

    func testCompactReordersNoteDroppedBetweenTwo() {
        let a = UUID(), b = UUID(), moved = UUID()
        let layer = CGSize(width: 400, height: 800)
        // a(0.14), b(0.18); `moved` dropped at 0.16 (between) → a, moved, b.
        let placements = DayPageLayout.compactedStack(
            notes: [(id: a, unitY: 0.14, height: 20),
                    (id: b, unitY: 0.18, height: 20),
                    (id: moved, unitY: 0.16, height: 20)],
            contentBottom: 100, layerSize: layer)
        XCTAssertEqual(placements.map(\.id), [a, moved, b])
    }

    func testCompactClampsTallStackAtPageBottom() {
        let a = UUID(), b = UUID()
        let layer = CGSize(width: 400, height: 800)
        // contentBottom deep: both clamp at 800 - bottomHeadroom(60) = 740.
        let placements = DayPageLayout.compactedStack(
            notes: [(id: a, unitY: 0.95, height: 20), (id: b, unitY: 0.97, height: 20)],
            contentBottom: 760, layerSize: layer)
        XCTAssertEqual(placements[0].unitY * 800, 740, accuracy: 0.0001)
        XCTAssertEqual(placements[1].unitY * 800, 740, accuracy: 0.0001)
    }

    func testCompactDegenerateLayerReturnsEmpty() {
        XCTAssertTrue(DayPageLayout.compactedStack(
            notes: [(id: UUID(), unitY: 0.5, height: 20)],
            contentBottom: 100, layerSize: .zero).isEmpty)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the DayPageLayoutTests command (see Pre-flight).
Expected: **build failure** — `type 'DayPageLayout' has no member 'compactedStack'`.

- [ ] **Step 3: Implement `compactedStack` + `AnnotationPlacement`**

In `DayPageLayout.swift`, add immediately after the `verticalDragUnit(...)` function (before the `AnnotationNudge` struct):

```swift
    /// One note's computed slot in the compacted stack.
    struct AnnotationPlacement: Equatable {
        let id: UUID
        let unitY: Double
    }

    /// Pack every note into a gapless column directly below the content, in
    /// current vertical (`unitY`) order — the order key, so a note dropped
    /// between two others sorts into that slot. Bidirectional (closes gaps
    /// above and below) and idempotent (a settled stack returns identical
    /// positions, so the caller writes nothing). Page-full notes pile at the
    /// `bottomHeadroom` clamp, exactly as creation/auto-stacking do.
    /// `Annotation.clampUnit` keeps each slot on the page (NaN/inf net for a
    /// degenerate layer). Pure: plain values in, placements out.
    static func compactedStack(notes: [(id: UUID, unitY: Double, height: CGFloat)],
                               contentBottom: CGFloat,
                               layerSize: CGSize) -> [AnnotationPlacement] {
        guard layerSize.width > 0, layerSize.height > 0 else { return [] }
        let ordered = notes.sorted { $0.unitY < $1.unitY }
        var placements: [AnnotationPlacement] = []
        var cursor = contentBottom
        for note in ordered {
            let top = min(cursor + stackSpacing, layerSize.height - bottomHeadroom)
            let unitY = Annotation.clampUnit(CGPoint(x: 0, y: top / layerSize.height)).y
            placements.append(AnnotationPlacement(id: note.id, unitY: unitY))
            cursor = top + note.height
        }
        return placements
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run the DayPageLayoutTests command.
Expected: **TEST SUCCEEDED** — 6 new tests pass alongside the existing ones.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Features/DayPage/DayPageLayout.swift \
        WeeklyPlannerTests/Annotations/DayPageLayoutTests.swift
git commit -m "feat(annotations): pure compactedStack — gapless, order-by-unitY, idempotent

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: VM `compactNotes` + compaction token (TDD, additive)

**Files:**
- Test: `WeeklyPlannerTests/Annotations/AnnotationLayerTests.swift`
- Modify: `WeeklyPlanner/Features/DayPage/DayPageViewModel.swift`

- [ ] **Step 1: Write the failing tests**

Append inside `AnnotationLayerTests` (before its closing `}`):

```swift
    func testCompactNotesPacksGapBelowContent() async throws {
        try await annotationStore.upsert(
            Annotation(dayKey: "0:5", text: "a", unitX: 0.1, unitY: 0.3))
        try await annotationStore.upsert(
            Annotation(dayKey: "0:5", text: "b", unitX: 0.1, unitY: 0.6))
        let vm = makeViewModel()
        await vm.refresh()
        let heights = Dictionary(uniqueKeysWithValues: vm.annotations.map { ($0.id, CGFloat(20)) })

        await vm.compactNotes(contentBottom: 100,
                              layerSize: CGSize(width: 400, height: 800),
                              noteHeights: heights, editingID: nil)

        let sorted = vm.annotations.sorted { $0.unitY < $1.unitY }
        XCTAssertEqual(sorted[0].unitY * 800, 112, accuracy: 0.5) // 100 + 12
        XCTAssertEqual(sorted[1].unitY * 800, 144, accuracy: 0.5) // 112 + 20 + 12
    }

    func testCompactNotesDefersWhileEditing() async throws {
        try await annotationStore.upsert(
            Annotation(dayKey: "0:5", text: "a", unitX: 0.1, unitY: 0.3))
        let vm = makeViewModel()
        await vm.refresh()
        let id = vm.annotations[0].id
        let before = vm.annotations[0].unitY

        await vm.compactNotes(contentBottom: 100,
                              layerSize: CGSize(width: 400, height: 800),
                              noteHeights: [id: 20], editingID: id)

        XCTAssertEqual(vm.annotations[0].unitY, before, accuracy: 0.0001) // deferred: unchanged
    }

    func testRequestCompactionBumpsToken() async throws {
        let vm = makeViewModel()
        let before = vm.compactionRequest
        vm.requestCompaction()
        XCTAssertNotEqual(vm.compactionRequest, before)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run with `-only-testing:WeeklyPlannerTests/AnnotationLayerTests`.
Expected: **build failure** — no `compactNotes` / `compactionRequest` / `requestCompaction` members.

- [ ] **Step 3: Implement the VM additions**

In `DayPageViewModel.swift`, add a stored property near the other annotation state (after `var annotations: [Annotation] = []`, line ~45):

```swift
    /// Bumped whenever the note set or a drag asks the day view to re-pack the
    /// stack (the view owns the measured contentBottom/layerSize/heights).
    private(set) var compactionRequest = 0
```

Add these methods in the `// MARK: - Annotations` section (e.g. after `nudgeAutoPlacedNotes`, before `deleteAnnotation`):

```swift
    /// Ask the day view to re-compact (it holds the measured anchors). Bumped
    /// on a drag release; the view observes it and calls `compactNotes`.
    func requestCompaction() { compactionRequest &+= 1 }

    /// Pack notes into a gapless stack below the content, in current vertical
    /// (`unitY`) order. Persists ONLY the notes whose position changed (>0.5pt);
    /// a settled stack writes nothing. Deferred while a note is being edited —
    /// the open editor must not be yanked; it re-runs when editing ends.
    /// Mutates the live models in place (no refresh → no token loop).
    func compactNotes(contentBottom: CGFloat,
                      layerSize: CGSize,
                      noteHeights: [UUID: CGFloat],
                      editingID: UUID?) async {
        guard editingID == nil, layerSize.width > 0, layerSize.height > 0, contentBottom > 0
        else { return }
        let placements = DayPageLayout.compactedStack(
            notes: annotations.map { (id: $0.id, unitY: $0.unitY, height: noteHeights[$0.id] ?? 0) },
            contentBottom: contentBottom,
            layerSize: layerSize)
        let target = Dictionary(uniqueKeysWithValues: placements.map { ($0.id, $0.unitY) })
        let threshold = 0.5 / Double(layerSize.height)
        let moved = annotations.filter { note in
            guard let t = target[note.id] else { return false }
            return abs(t - note.unitY) > threshold
        }
        guard !moved.isEmpty else { return }
        // Animate so the re-pack reads as a deliberate snap, not a glitch.
        withAnimation {
            for note in moved { note.unitY = target[note.id] ?? note.unitY }
        }
        // Upsert re-inserts unknown ids; safe here for the same reason as the
        // old nudge — deletes flow through the editor and editing defers
        // compaction, so a concurrently-deleted note can't be resurrected.
        for note in moved {
            try? await annotationStore.upsert(note)
        }
    }
```

Then bump the token at the end of `refreshAnnotations()` so add/commit/delete trigger a compaction:

```swift
    private func refreshAnnotations() async {
        annotations = (try? await annotationStore.annotations(dayKey: dayKey)) ?? []
        compactionRequest &+= 1
    }
```

And route the full `refresh()`'s annotation load through that helper, so **appear / event-change refreshes also bump the token** (otherwise pre-existing gappy days never compact on load). In `refresh()`, replace the inline load (the line under the `// Phase 34: free-text annotations for this day cell.` comment):

```swift
        // Phase 34: free-text annotations for this day cell.
        annotations = (try? await annotationStore.annotations(dayKey: dayKey)) ?? []
```

with:

```swift
        // Phase 34: free-text annotations for this day cell. Routes through the
        // helper so the appear/event-change path also bumps the compaction token.
        await refreshAnnotations()
```

- [ ] **Step 4: Run the tests to verify they pass**

Run with `-only-testing:WeeklyPlannerTests/AnnotationLayerTests`.
Expected: **TEST SUCCEEDED**.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Features/DayPage/DayPageViewModel.swift \
        WeeklyPlannerTests/Annotations/AnnotationLayerTests.swift
git commit -m "feat(annotations): VM compactNotes + compaction-request token

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Rewire the drag and the triggers

Switch the drag and the content-growth trigger onto the new path. After this task the feature works end-to-end; the old methods are dead but still present (deleted in Task 4).

**Files:**
- Modify: `WeeklyPlanner/Features/DayPage/Annotations/AnnotationView.swift` (`onEnded`)
- Modify: `WeeklyPlanner/Features/DayPage/DayPageView.swift` (`onChange(of: contentBottomY)` + add `compactionRequest` observer)

- [ ] **Step 1: Drag writes drop-`unitY` then requests compaction**

In `AnnotationView.swift`, replace the `.onEnded` body of `moveGesture`:

```swift
            .onEnded { value in
                guard layerSize.width > 0, layerSize.height > 0 else { return }
                // Vertical-only: leading edge stays on the margin, only Y moves.
                // Re-bases on the live (possibly nudged) unitY plus the
                // translation, so the on-screen release position wins.
                let newUnit = DayPageLayout.verticalDragUnit(
                    currentUnitY: annotation.unitY,
                    translationHeight: value.translation.height,
                    layerSize: layerSize)
                // Commit to the live model in the same render transaction that
                // resets `dragOffset`, so the view never flashes back to its
                // pre-drag spot while persistence runs. Writing the margin X
                // here also self-heals any stale stored unitX on first drag.
                annotation.unitX = newUnit.x
                annotation.unitY = newUnit.y
                Task { await viewModel.moveAnnotation(id: annotation.id, toUnit: newUnit) }
            }
```

with:

```swift
            .onEnded { value in
                guard layerSize.width > 0, layerSize.height > 0 else { return }
                // Vertical-only: leading edge on the margin, only Y moves. Write
                // the drop position to the live model in the same transaction
                // that resets `dragOffset` (no flash-back), then request a
                // compaction: the note re-sorts into its slot by unitY and the
                // stack re-packs gapless. Persistence flows through compaction.
                let newUnit = DayPageLayout.verticalDragUnit(
                    currentUnitY: annotation.unitY,
                    translationHeight: value.translation.height,
                    layerSize: layerSize)
                annotation.unitX = newUnit.x
                annotation.unitY = newUnit.y
                viewModel.requestCompaction()
            }
```

- [ ] **Step 2: Content-bottom trigger fires both directions → `compactNotes`**

In `DayPageView.swift`, replace the entire `.onChange(of: contentBottomY) { ... }` block (the one that guards `newValue > oldValue` and calls `nudgeAutoPlacedNotes`) with:

```swift
                                .onChange(of: contentBottomY) { _, _ in
                                    // Content grew or shrank: re-pack the note
                                    // stack tight below it (bidirectional —
                                    // closes gaps both ways). compactNotes is a
                                    // no-op when nothing moved or while editing.
                                    runCompaction()
                                }
                                .onChange(of: viewModel?.compactionRequest) { _, _ in
                                    // A drag (or a note load/add/commit/delete via
                                    // refreshAnnotations) asked for a re-pack.
                                    runCompaction()
                                }
```

- [ ] **Step 3: Add the `runCompaction()` helper**

In `DayPageView.swift`, add a private method (next to the other helpers like `commitPendingTaskIfAny`):

```swift
    /// Re-pack the annotation stack using the currently measured anchors.
    /// Reads live `contentBottomY` (already updated when an onChange fires).
    private func runCompaction() {
        guard let viewModel else { return }
        let bottom = contentBottomY
        let layer = annotationLayerSize
        let heights = noteHeights
        let editing = editingAnnotationID
        Task {
            await viewModel.compactNotes(contentBottom: bottom,
                                         layerSize: layer,
                                         noteHeights: heights,
                                         editingID: editing)
        }
    }
```

- [ ] **Step 4: Build, then run the annotation suites**

Build (see Pre-flight) → **BUILD SUCCEEDED**. Then:

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/DayPageLayoutTests \
  -only-testing:WeeklyPlannerTests/AnnotationLayerTests \
  CODE_SIGNING_ALLOWED=NO
```
Expected: **TEST SUCCEEDED** (the old nudge/move tests still pass — those functions still exist this task).

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Features/DayPage/Annotations/AnnotationView.swift \
        WeeklyPlanner/Features/DayPage/DayPageView.swift
git commit -m "feat(annotations): drag reorders + content changes re-pack via compactNotes

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Delete the dead auto-nudge / pin path

Nothing references these after Task 3. Confirm, then remove (code + tests).

**Files:**
- Modify: `WeeklyPlanner/Features/DayPage/DayPageViewModel.swift`
- Modify: `WeeklyPlanner/Features/DayPage/DayPageLayout.swift`
- Modify: `WeeklyPlannerTests/Annotations/DayPageLayoutTests.swift`
- Modify: `WeeklyPlannerTests/Annotations/AnnotationLayerTests.swift`

- [ ] **Step 1: Confirm zero references**

Run:
```bash
grep -rn "nudgeAutoPlacedNotes\|nudgesForContentGrowth\|AnnotationNudge\|moveAnnotation" \
  WeeklyPlanner WeeklyPlannerTests
```
Expected: matches ONLY inside the definitions and the tests listed below (no production call sites). If a production call site remains, stop — Task 3 is incomplete.

- [ ] **Step 2: Delete the VM methods**

In `DayPageViewModel.swift`, delete the entire `moveAnnotation(id:toUnit:)` method and the entire `nudgeAutoPlacedNotes(contentBottom:layerSize:noteHeights:editingID:)` method.

- [ ] **Step 3: Delete the pure nudge code**

In `DayPageLayout.swift`, delete the `AnnotationNudge` struct and the entire `nudgesForContentGrowth(...)` function.

- [ ] **Step 4: Delete the stale tests**

In `DayPageLayoutTests.swift`, delete every test under the `// MARK: - Auto-nudge on content growth` section (the `note(...)` helper and all `testNoCollisions…` / `testPinned…` / `testEditing…` / `testColliding…` / `testMultiple…` / `testNudged…` / `testDegenerateLayerYieldsNoNudges` / `testCollidingNoteNearPageBottom…` / `testReapplyingPlan…` cases). Keep the stack-from-top and compact-reorder sections.

In `AnnotationLayerTests.swift`, delete `testMoveClampsAndPersists` (it exercised the removed `moveAnnotation`).

- [ ] **Step 5: Build, then run the full unit suite (minus keychain baseline)**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests \
  -skip-testing:WeeklyPlannerTests/GoogleAuthServiceTests \
  -skip-testing:WeeklyPlannerTests/TokenKeychainStoreTests \
  CODE_SIGNING_ALLOWED=NO
```
Expected: **TEST SUCCEEDED**, 0 failures. (The two skipped classes are the known `CODE_SIGNING_ALLOWED=NO` keychain baseline — see project memory.)

- [ ] **Step 6: Commit**

```bash
git add WeeklyPlanner/Features/DayPage/DayPageViewModel.swift \
        WeeklyPlanner/Features/DayPage/DayPageLayout.swift \
        WeeklyPlannerTests/Annotations/DayPageLayoutTests.swift \
        WeeklyPlannerTests/Annotations/AnnotationLayerTests.swift
git commit -m "refactor(annotations): delete down-only auto-nudge + moveAnnotation pin path

Superseded by bidirectional compactNotes. autoPlaced field kept (vestigial)
to avoid a SwiftData migration.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Full regression + lint + on-simulator verification

**Files:** `WeeklyPlannerUITests/AnnotationsUITests.swift` (throwaway driver, removed at the end)

- [ ] **Step 1: swiftlint — confirm no NEW violations in changed files**

Run:
```bash
swiftlint --strict 2>&1 | grep -E "DayPageLayout\.swift|DayPageViewModel\.swift|DayPageView\.swift|Annotations/AnnotationView\.swift|Annotations/DayPageLayoutTests\.swift|Annotations/AnnotationLayerTests\.swift" || echo "no new violations in changed files"
```
Expected: `no new violations in changed files` (pre-existing baseline elsewhere is out of scope).

- [ ] **Step 2: Add a throwaway reorder driver**

In `AnnotationsUITests.swift`, add before the class's closing `}`:

```swift
    // MARK: - THROWAWAY verification driver (compact-reorder) — remove after running

    @MainActor
    func testDRIVERReorderCompacts() {
        let app = launchOnTestDayPage()
        purgeAllAnnotations(app)
        purgeNudgeEvents(app)

        XCTAssertTrue(createAnnotation(in: app, text: "first note"))
        app.buttons[ID.styleDone].tap()
        XCTAssertTrue(createAnnotation(in: app, text: "second note"))
        app.buttons[ID.styleDone].tap()

        let first = app.staticTexts["first note"]
        let second = app.staticTexts["second note"]
        XCTAssertTrue(first.waitForExistence(timeout: 4))
        XCTAssertTrue(second.waitForExistence(timeout: 4))
        // Initially first is above second, packed tight.
        XCTAssertLessThan(first.frame.minY, second.frame.minY)
        let gapBefore = second.frame.minY - first.frame.maxY

        // Drag the SECOND note up above the first → they should swap order, and
        // the stack stays tight (no large gap opens up).
        let mid = second.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        mid.press(forDuration: 0.1, thenDragTo: mid.withOffset(CGVector(dx: 0, dy: -80)))
        usleep(700_000) // let the re-pack animation settle

        XCTAssertLessThan(second.frame.minY, first.frame.minY,
                          "Dragging the second note up should put it above the first")
        let gapAfter = first.frame.minY - second.frame.maxY
        XCTAssertLessThan(gapAfter, gapBefore + 12,
                          "Re-packed stack should stay tight (no large gap): \(gapAfter)pt")

        deleteAnnotationIfPresent(app, text: "first note")
        deleteAnnotationIfPresent(app, text: "second note")
    }
```

- [ ] **Step 3: Run the driver**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerUITests/AnnotationsUITests/testDRIVERReorderCompacts \
  CODE_SIGNING_ALLOWED=NO
```
Expected: **TEST SUCCEEDED**. If it flakes twice on residue/timing (not a real failure), rely on manual sim verification instead and note it.

- [ ] **Step 4: Remove the driver**

Delete the `testDRIVERReorderCompacts` method and its MARK comment. Confirm `git diff WeeklyPlannerUITests/AnnotationsUITests.swift` is empty.

- [ ] **Step 5: Manual sim check (record actual result)**

Open the app on the sim, a Day page. Confirm: create two notes (pack tight below content); drag the lower above the upper (they swap, stay tight); drag a note far down and release (it snaps back into the gapless stack); delete a middle note (the one below closes the gap). Record pass/fail per item — do not claim passed without running.

- [ ] **Step 6: Commit (only if any non-driver change remained; otherwise nothing to commit)**

The driver leaves no committed change. If Step 5 surfaced a fix, commit it with a clear message.

---

## Self-review notes

- **Spec coverage:** reorder+re-pack (Task 1 `compactedStack` order-by-`unitY` + Task 3 drag→`requestCompaction`); always gapless below content (Task 1 packing + Task 3 both-direction trigger + appear/load via `refreshAnnotations` token bump); no pinning (Task 4 deletes `moveAnnotation`/`autoPlaced`-clear); defer-while-editing (Task 2 `compactNotes` guard); below-content-only & events untouched (packing anchors on `contentBottom`, events not in the note set); retire down-only nudge (Task 4). All spec sections map to a task.
- **Type consistency:** `compactedStack(notes: [(id: UUID, unitY: Double, height: CGFloat)], contentBottom: CGFloat, layerSize: CGSize) -> [AnnotationPlacement]` defined in Task 1, called identically in Task 2's `compactNotes`. `AnnotationPlacement{ id: UUID; unitY: Double }`. `compactNotes(contentBottom:layerSize:noteHeights:editingID:)` defined in Task 2, called via `runCompaction()` in Task 3. `compactionRequest: Int` / `requestCompaction()` defined Task 2, used Task 3. `unitY` is `Double`; `clampUnit` works in `CGPoint`.
- **No placeholders:** every code/command step is concrete.
- **Build-green ordering:** Task 1–2 additive; Task 3 rewires onto new path; Task 4 deletes now-unreferenced code (grep-guarded). Each task builds and tests green.
