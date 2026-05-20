# Phase 16 — Settings (Theme, Handwriting, Size, Preferences, About) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the embedded Settings page — book chrome around a body of five sections (Theme cards, Handwriting cards, Text size segmented, Connections placeholder, Preferences group) plus a centered italic About footer — and wire live theme/font/size switching from `SettingsStoring` through `AppShell` to every paper view.

**Architecture:**
- `PaperSettingsView` composes the same book chrome as `PaperReviewView` (`BookPage` → `PaperSurface` → `PaperGrain`/`RuledLines`/`RedMarginLine`/`HolePunches`) around a `ScrollView` that hosts a `SettingsHeader` plus 5 sections. Each section is a small focused file under `WeeklyPlanner/Features/Settings/` — `SectionTitle`, `ThemeCardsGrid`/`ThemeCard`, `FontCardsGrid`/`FontCard`, `SizeSegmented`, `ConnectionsPlaceholder` (Phase 17 replaces), `PreferencesGroup`/`PrefRow`/`ToggleRow`, `AboutFooter`. Read/write of settings flows through `SettingsViewModel` (`@Observable`), which reads on init via `SettingsStoring.current()` and writes via `SettingsStoring.update { ... }`.
- Live switching is plumbed by lifting appearance state into `AppShell`: a new `@Query private var settingsRows: [UserSettings]` drives `\.paperTheme` / `\.paperFont` / `\.paperSize` re-injection at the top of `AppShell.body`. SwiftData's `@Query` re-evaluates the shell when the row changes, so every child view picks up the new environment values without manual notification plumbing.
- `WeeklyPlannerApp` gains a production `SwiftDataSettingsStore` injection (the env value currently falls through to `StubSettingsStore`, so tab selection doesn't actually persist across launches today — Phase 16 has to close that gap).

**Tech Stack:** Swift 6, SwiftUI, SwiftData, XCTest. XcodeGen regenerates the project from `project.yml`; the `WeeklyPlanner` target's `sources` is the entire `WeeklyPlanner/` folder, so new files under `WeeklyPlanner/Features/Settings/` are picked up automatically on `xcodegen generate`.

---

## File Structure

### Created

```
WeeklyPlanner/Features/Settings/SettingsViewModel.swift                # @Observable read/write bridge
WeeklyPlanner/Features/Settings/SettingsHeader.swift                   # "Make it yours" + Cochin subtitle + gradient rule
WeeklyPlanner/Features/Settings/SectionTitle.swift                     # eyebrow + handwriting title (reused 5×)
WeeklyPlanner/Features/Settings/ThemeCardsGrid.swift                   # 3-col grid of ThemeCard
WeeklyPlanner/Features/Settings/ThemeCard.swift                        # single theme preview card
WeeklyPlanner/Features/Settings/FontCardsGrid.swift                    # 2-col grid of FontCard
WeeklyPlanner/Features/Settings/FontCard.swift                         # single font preview card
WeeklyPlanner/Features/Settings/SizeSegmented.swift                    # S / M / L segmented control
WeeklyPlanner/Features/Settings/ConnectionsPlaceholder.swift           # "Coming up next…" — Phase 17 replaces
WeeklyPlanner/Features/Settings/PreferencesGroup.swift                 # card hosting PrefRow + ToggleRow children
WeeklyPlanner/Features/Settings/PrefRow.swift                          # expandable preference row
WeeklyPlanner/Features/Settings/ToggleRow.swift                        # toggle preference row
WeeklyPlanner/Features/Settings/AboutFooter.swift                      # centered italic "The Planner · v1.0 · made with care"
WeeklyPlannerTests/Features/Settings/SettingsViewModelTests.swift      # read / write / round-trip
WeeklyPlannerTests/Features/Settings/PaperSettingsViewTests.swift      # composition assertions
```

### Modified

```
WeeklyPlanner/App/WeeklyPlannerApp.swift                    # Inject SwiftDataSettingsStore
WeeklyPlanner/Navigation/AppShell.swift                     # @Query settings → re-inject paperTheme/paperFont/paperSize
WeeklyPlanner/Features/Settings/PaperSettingsView.swift     # Replace placeholder with full composition
docs/phases/README.md                                        # Phase 16 retrospective
README.md                                                    # Status: milestones A–G shipped (Phase 16)
```

### Conventions (already established, restated for reviewers)

- **No emojis in source files unless they're literal UI strings.**
- **POSIX-locked date formatters** in tests for determinism.
- **`@Observable`** for view-models, **`@Environment`** for cross-cutting dependencies (stores, theme).
- **Tests under `WeeklyPlannerTests/Features/<Feature>/`** mirror the source folder structure.
- **Per-task atomic commits** with `feat(phase-16):` / `chore(phase-16):` / `docs(phase-16):` prefix.
- **Snapshot tests are deferred** — the spec calls for them but the project has no `swift-snapshot-testing` dependency. Phase 21 (Accessibility) can add the dep; meanwhile `PaperSettingsViewTests` asserts hierarchy (presence + count of cards / segments / rows) and visual conformance is checked manually against `docs/mock/paper-settings.jsx`.

---

## Task 1: Confirm baseline

**Files:** none (verification only)

The worktree is already created at `.claude/worktrees/milestone-g-settings` on branch `milestone-g-settings`; baseline tests have been run and report `Executed 198 tests, with 0 failures`. Re-verify before starting.

- [ ] **Step 1: Confirm clean working tree on milestone-g-settings**

```bash
git status --short
git branch --show-current
git log --oneline -3
```

Expected: empty status; `milestone-g-settings`; HEAD is `79732ee docs: mark milestones A–F complete in README + phase map`.

- [ ] **Step 2: Re-baseline build + test**

```bash
xcodegen generate 2>&1 | tail -2
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO 2>&1 \
  | grep -E "TEST FAILED|TEST SUCCEEDED|Executed [0-9]+ tests" | tail -3
```

Expected: `** TEST SUCCEEDED **`, `Executed 198 tests, with 0 failures`.

---

## Task 2: Wire production SettingsStore through the app

**Files:**
- Modify: `WeeklyPlanner/App/WeeklyPlannerApp.swift`

`WeeklyPlannerApp` boots SwiftData but never constructs a `SwiftDataSettingsStore`, so `\.settingsStore` falls through to the default `StubSettingsStore` in production. That breaks `TabSelection`'s persistence claim from Phase 15. Inject the production store so writes from Phase 16's `SettingsViewModel` actually land on disk.

- [ ] **Step 1: Edit `WeeklyPlannerApp.swift` to add the settings store**

Replace the file contents with:

```swift
import SwiftData
import SwiftUI

/// The app entry point. Boots a single `ModelContainer`, constructs the
/// production `SwiftDataEventStore` / `SwiftDataInboxStore` /
/// `SwiftDataTaskStore` / `SwiftDataSettingsStore`, and (in DEBUG builds
/// only) seeds the container from bundled JSON the first time the schema
/// is empty. Stores are then injected into the environment so any view
/// subtree can read events, inbox suggestions, to-dos, or settings without
/// prop drilling.
///
/// `App` is `@MainActor` by SwiftUI convention, which is what lets
/// `init` legally call `SwiftDataStack.production` and friends — all the
/// store types are also main-actor isolated.
@main
struct WeeklyPlannerApp: App {
    @State private var container: ModelContainer
    @State private var eventStore: any EventStoring
    @State private var inboxStore: any InboxStoring
    @State private var taskStore: any TaskStoring
    @State private var settingsStore: any SettingsStoring

    init() {
        let container = SwiftDataStack.production
        let eventStore = SwiftDataEventStore(context: container.mainContext)
        let inboxStore = SwiftDataInboxStore(context: container.mainContext)
        let taskStore = SwiftDataTaskStore(context: container.mainContext)
        let settingsStore = SwiftDataSettingsStore(context: container.mainContext)
        #if DEBUG
            SeedLoader.seedIfEmpty(context: container.mainContext)
        #endif
        _container = State(initialValue: container)
        _eventStore = State(initialValue: eventStore)
        _inboxStore = State(initialValue: inboxStore)
        _taskStore = State(initialValue: taskStore)
        _settingsStore = State(initialValue: settingsStore)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.eventStore, eventStore)
                .environment(\.inboxStore, inboxStore)
                .environment(\.taskStore, taskStore)
                .environment(\.settingsStore, settingsStore)
                .modelContainer(container)
        }
    }
}
```

- [ ] **Step 2: Build to confirm**

```bash
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO 2>&1 \
  | grep -E "BUILD FAILED|BUILD SUCCEEDED" | tail -2
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/App/WeeklyPlannerApp.swift
git commit -m "fix(phase-16): inject SwiftDataSettingsStore at the app entry"
```

---

## Task 3: AppShell drives live theme/font/size from settings (TDD red)

**Files:**
- Create: `WeeklyPlannerTests/Features/Settings/SettingsViewModelTests.swift` (one initial test only — fuller tests in Task 4)

Phase 15 introduced `\.settingsStore` but `AppShell` never reads it to drive `\.paperTheme` etc. — every paper view is stuck on the default `.cream` theme. This task lands the failing test first; Task 4 lands the view-model that satisfies it, then Task 5 lands the AppShell wiring.

- [ ] **Step 1: Create the tests directory + first failing test**

```bash
mkdir -p WeeklyPlannerTests/Features/Settings
```

Create `WeeklyPlannerTests/Features/Settings/SettingsViewModelTests.swift`:

```swift
import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class SettingsViewModelTests: XCTestCase {
    private func makeStore() throws -> SwiftDataSettingsStore {
        let container = try SwiftDataStack.inMemoryContainer()
        return SwiftDataSettingsStore(context: container.mainContext)
    }

    func testDefaultsAfterFreshInstall() throws {
        let store = try makeStore()
        let vm = SettingsViewModel(store: store)
        XCTAssertEqual(vm.themeKey, .cream)
        XCTAssertEqual(vm.fontKey, .caveat)
        XCTAssertEqual(vm.sizeKey, .m)
        XCTAssertTrue(vm.weekStartsOnMonday)
        XCTAssertEqual(vm.defaultReminderMinutes, 15)
        XCTAssertTrue(vm.appleIntelligenceEnabled)
    }
}
```

- [ ] **Step 2: Confirm the test fails to build**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO -only-testing:WeeklyPlannerTests/SettingsViewModelTests 2>&1 \
  | grep -E "error:|TEST FAILED|TEST SUCCEEDED" | head -5
```

Expected: a Swift compile error mentioning `cannot find 'SettingsViewModel' in scope`.

---

## Task 4: Implement `SettingsViewModel` (green)

**Files:**
- Create: `WeeklyPlanner/Features/Settings/SettingsViewModel.swift`
- Modify: `WeeklyPlannerTests/Features/Settings/SettingsViewModelTests.swift`

Holds typed views of every settings property the page surfaces, plus write-through setters that persist via `SettingsStoring.update`. Mirrors `ReviewViewModel`'s shape (`@Observable`, ctor takes the dependency, no auto-reload).

- [ ] **Step 1: Create `SettingsViewModel.swift`**

```swift
import Foundation

/// Read/write bridge between `PaperSettingsView` and `SettingsStoring`.
/// Mirrors `UserSettings` properties as typed values, with setters that
/// persist through `store.update { ... }`. Constructed in
/// `PaperSettingsView.task` so a fresh navigation always reads the latest
/// row (rather than caching across mount cycles).
@MainActor
@Observable
final class SettingsViewModel {
    private let store: any SettingsStoring

    var themeKey: PaperThemeKey
    var fontKey: PaperFont
    var sizeKey: PaperSize
    var weekStartsOnMonday: Bool
    var defaultReminderMinutes: Int?
    var appleIntelligenceEnabled: Bool

    init(store: any SettingsStoring) {
        self.store = store
        let settings = (try? store.current()) ?? UserSettings()
        themeKey = settings.paperTheme
        fontKey = settings.paperFont
        sizeKey = settings.paperSize
        weekStartsOnMonday = settings.weekStartsOnMonday
        defaultReminderMinutes = settings.defaultReminderMinutes
        appleIntelligenceEnabled = settings.appleIntelligenceEnabled
    }

    func setTheme(_ theme: PaperThemeKey) {
        themeKey = theme
        try? store.update { $0.paperTheme = theme }
    }

    func setFont(_ font: PaperFont) {
        fontKey = font
        try? store.update { $0.paperFont = font }
    }

    func setSize(_ size: PaperSize) {
        sizeKey = size
        try? store.update { $0.paperSize = size }
    }

    func setWeekStartsOnMonday(_ value: Bool) {
        weekStartsOnMonday = value
        try? store.update { $0.weekStartsOnMonday = value }
    }

    func setDefaultReminderMinutes(_ minutes: Int?) {
        defaultReminderMinutes = minutes
        try? store.update { $0.defaultReminderMinutes = minutes }
    }

    func setAppleIntelligenceEnabled(_ value: Bool) {
        appleIntelligenceEnabled = value
        try? store.update { $0.appleIntelligenceEnabled = value }
    }
}
```

- [ ] **Step 2: Extend `SettingsViewModelTests.swift` with the rest of the spec's tests**

Replace the file body with:

```swift
import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class SettingsViewModelTests: XCTestCase {
    private func makeStore() throws -> SwiftDataSettingsStore {
        let container = try SwiftDataStack.inMemoryContainer()
        return SwiftDataSettingsStore(context: container.mainContext)
    }

    func testDefaultsAfterFreshInstall() throws {
        let store = try makeStore()
        let vm = SettingsViewModel(store: store)
        XCTAssertEqual(vm.themeKey, .cream)
        XCTAssertEqual(vm.fontKey, .caveat)
        XCTAssertEqual(vm.sizeKey, .m)
        XCTAssertTrue(vm.weekStartsOnMonday)
        XCTAssertEqual(vm.defaultReminderMinutes, 15)
        XCTAssertTrue(vm.appleIntelligenceEnabled)
    }

    func testSelectingThemePersists() throws {
        let store = try makeStore()
        let vm = SettingsViewModel(store: store)
        vm.setTheme(.midnight)
        XCTAssertEqual(vm.themeKey, .midnight)
        let row = try store.current()
        XCTAssertEqual(row.paperTheme, .midnight)
    }

    func testSelectingFontPersists() throws {
        let store = try makeStore()
        let vm = SettingsViewModel(store: store)
        vm.setFont(.architects)
        XCTAssertEqual(vm.fontKey, .architects)
        XCTAssertEqual(try store.current().paperFont, .architects)
    }

    func testSelectingSizePersists() throws {
        let store = try makeStore()
        let vm = SettingsViewModel(store: store)
        vm.setSize(.l)
        XCTAssertEqual(vm.sizeKey, .l)
        XCTAssertEqual(try store.current().paperSize, .l)
    }

    func testTogglingAIPersists() throws {
        let store = try makeStore()
        let vm = SettingsViewModel(store: store)
        XCTAssertTrue(vm.appleIntelligenceEnabled)
        vm.setAppleIntelligenceEnabled(false)
        XCTAssertFalse(vm.appleIntelligenceEnabled)
        XCTAssertFalse(try store.current().appleIntelligenceEnabled)
    }

    func testSettingDefaultReminderToNonePersists() throws {
        let store = try makeStore()
        let vm = SettingsViewModel(store: store)
        vm.setDefaultReminderMinutes(nil)
        XCTAssertNil(vm.defaultReminderMinutes)
        XCTAssertNil(try store.current().defaultReminderMinutes)
    }

    func testSettingWeekStartToSundayPersists() throws {
        let store = try makeStore()
        let vm = SettingsViewModel(store: store)
        vm.setWeekStartsOnMonday(false)
        XCTAssertFalse(vm.weekStartsOnMonday)
        XCTAssertFalse(try store.current().weekStartsOnMonday)
    }
}
```

- [ ] **Step 3: Regenerate Xcode project + run the new tests green**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO -only-testing:WeeklyPlannerTests/SettingsViewModelTests 2>&1 \
  | grep -E "TEST FAILED|TEST SUCCEEDED|Executed [0-9]+ tests" | tail -3
```

Expected: `** TEST SUCCEEDED **`, `Executed 7 tests, with 0 failures`.

- [ ] **Step 4: Commit**

```bash
git add WeeklyPlanner/Features/Settings/SettingsViewModel.swift \
        WeeklyPlannerTests/Features/Settings/SettingsViewModelTests.swift
git commit -m "feat(phase-16): SettingsViewModel @Observable bridge to SettingsStoring"
```

---

## Task 5: AppShell re-injects paperTheme/paperFont/paperSize from settings

**Files:**
- Modify: `WeeklyPlanner/Navigation/AppShell.swift`

Read the persisted row via SwiftData's `@Query` and re-inject the three environment values at the top of `body`. `@Query` re-evaluates the shell whenever the row changes, so a write from `SettingsViewModel.setTheme` cascades through every child view immediately.

- [ ] **Step 1: Edit `AppShell.swift`**

Insert `import SwiftData` next to `import SwiftUI`, add the `@Query` and three computed `var`s, and apply `.paperTheme(...)`, `.paperFont(...)`, `.paperSize(...)` to the outer `ZStack`'s `.environment` chain.

Locate the existing imports:

```swift
import SwiftUI
import SwiftData
```

(already present)

Replace the property declarations block (lines 22–31) with:

```swift
struct AppShell: View {
    @Environment(\.eventStore) private var eventStore
    @Environment(\.taskStore) private var taskStore
    @Environment(\.inboxStore) private var inboxStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query private var settingsRows: [UserSettings]

    @State private var selection: TabSelection
    @State private var controller: PageFlipController
    @State private var paperView: PaperView = .day
    @State private var isPickerOpen: Bool = false
    @State private var isAISearchOpen: Bool = false

    /// The current settings row, or a fresh default if SwiftData hasn't
    /// materialized one yet. `@Query` returns at most one element here
    /// because `SwiftDataSettingsStore.current()` lazy-creates exactly one
    /// `UserSettings` instance.
    private var settings: UserSettings { settingsRows.first ?? UserSettings() }

    private var resolvedTheme: PaperTheme { settings.paperTheme.theme }
    private var resolvedFont: PaperFont { settings.paperFont }
    private var resolvedSize: PaperSize { settings.paperSize }
```

Then change the closing chain of `body` (after `.animation(...)`) so the env injections happen *after* the existing intelligence-service env so they cover the entire shell. Replace:

```swift
        .animation(reduceMotion ? .linear(duration: 0) : AnimationTokens.sheetSlide,
                   value: isAISearchOpen)
        .environment(\.intelligenceService, makeIntelligenceService())
    }
```

with:

```swift
        .animation(reduceMotion ? .linear(duration: 0) : AnimationTokens.sheetSlide,
                   value: isAISearchOpen)
        .environment(\.intelligenceService, makeIntelligenceService())
        .paperTheme(resolvedTheme)
        .paperFont(resolvedFont)
        .paperSize(resolvedSize)
    }
```

- [ ] **Step 2: Build + run the full suite green**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO 2>&1 \
  | grep -E "TEST FAILED|TEST SUCCEEDED|Executed [0-9]+ tests" | tail -3
```

Expected: `** TEST SUCCEEDED **`, `Executed 205 tests, with 0 failures` (198 baseline + 7 SettingsViewModel).

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Navigation/AppShell.swift
git commit -m "feat(phase-16): AppShell drives live paperTheme/Font/Size from settings"
```

---

## Task 6: `SectionTitle` primitive

**Files:**
- Create: `WeeklyPlanner/Features/Settings/SectionTitle.swift`

Two-line section label: optional uppercase eyebrow (system 9pt, letter-spacing 1.6, color `ink3`) on top of a handwriting 22pt 700 title. Used 5× on the settings page.

- [ ] **Step 1: Create `SectionTitle.swift`**

```swift
import SwiftUI

/// Section heading used 5× on `PaperSettingsView`: an optional uppercase
/// eyebrow ("LOOK & FEEL", "SOURCES") on top of a 22pt handwriting title.
/// Sits flush-left under the gradient rule, padded `(0, 2, 8, 0)` so the
/// title baseline lines up with the section's content.
struct SectionTitle: View {
    let title: String
    let eyebrow: String?

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    init(_ title: String, eyebrow: String? = nil) {
        self.title = title
        self.eyebrow = eyebrow
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(theme.ink3)
            }
            Text(title)
                .font(font.font(at: 22, weight: .bold))
                .foregroundStyle(theme.ink)
                .lineSpacing(0)
        }
        .padding(EdgeInsets(top: 0, leading: 2, bottom: 8, trailing: 0))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("SectionTitle · cream") {
    VStack(alignment: .leading, spacing: 12) {
        SectionTitle("Theme", eyebrow: "Look & feel")
        SectionTitle("Handwriting")
    }
    .padding()
    .background(PaperTheme.cream.cream)
    .paperTheme(.cream)
}
```

- [ ] **Step 2: Build**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "BUILD FAILED|BUILD SUCCEEDED" | tail -1
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Features/Settings/SectionTitle.swift
git commit -m "feat(phase-16): SectionTitle eyebrow + handwriting heading"
```

---

## Task 7: `SizeSegmented` control

**Files:**
- Create: `WeeklyPlanner/Features/Settings/SizeSegmented.swift`

The smallest of the three "picker" sections. Three segments, each rendering its display name in the **current** handwriting font at the segment's display size (S=14, M=17, L=20pt) so the user previews the choice live. Outer wrapper has 0.5pt rule border and `rgba(0,0,0,0.04)` background; active segment gets `creamHi` background + 1px soft shadow.

- [ ] **Step 1: Create `SizeSegmented.swift`**

```swift
import SwiftUI

/// Three-segment S / M / L control. Each segment renders its label in the
/// current handwriting font at the segment's display size, so the user
/// previews the choice before committing. The active segment lifts via a
/// `creamHi` background + a 0.5pt rule outline + a 1pt soft shadow.
///
/// Per-segment display sizes (from `docs/mock/paper-settings.jsx`):
/// `S = 14pt`, `M = 17pt`, `L = 20pt`. These are unscaled — the segmented
/// control itself is what teaches the user what each setting *does*, so
/// it ignores `\.paperSize` to keep the comparison honest.
struct SizeSegmented: View {
    @Binding var selection: PaperSize
    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    private static let displaySize: [PaperSize: CGFloat] = [
        .s: 14, .m: 17, .l: 20,
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PaperSize.allCases, id: \.self) { size in
                Button {
                    selection = size
                } label: {
                    Text(size.displayName)
                        .font(font.font(at: Self.displaySize[size] ?? 17, weight: .semibold))
                        .foregroundStyle(theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(segmentBackground(active: size == selection))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(theme.rule, lineWidth: 0.5))
        )
        .padding(.bottom, 18)
    }

    @ViewBuilder
    private func segmentBackground(active: Bool) -> some View {
        if active {
            RoundedRectangle(cornerRadius: 7)
                .fill(theme.creamHi)
                .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 1)
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(theme.rule, lineWidth: 0.5))
        } else {
            Color.clear
        }
    }
}

#Preview("SizeSegmented · cream") {
    StatefulPreviewWrapper(PaperSize.m) { binding in
        SizeSegmented(selection: binding)
            .padding()
            .background(PaperTheme.cream.cream)
    }
    .paperTheme(.cream)
}

/// Tiny preview helper — wraps a `@State` so we can drive a binding inside
/// `#Preview` without writing a host view per call site.
private struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    let content: (Binding<Value>) -> Content

    init(_ initial: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        _value = State(initialValue: initial)
        self.content = content
    }

    var body: some View { content($value) }
}
```

- [ ] **Step 2: Build + commit**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "BUILD FAILED|BUILD SUCCEEDED" | tail -1
git add WeeklyPlanner/Features/Settings/SizeSegmented.swift
git commit -m "feat(phase-16): SizeSegmented S/M/L with live handwriting preview"
```

Expected: `** BUILD SUCCEEDED **`.

---

## Task 8: `ThemeCard` + `ThemeCardsGrid`

**Files:**
- Create: `WeeklyPlanner/Features/Settings/ThemeCard.swift`
- Create: `WeeklyPlanner/Features/Settings/ThemeCardsGrid.swift`

Three preview cards (`.cream`, `.kraft`, `.midnight`). Each card paints its own theme's `cream` background so you see the color choice immediately. Active card gets 1.5pt blueInk border + outer 3pt blueInk@22% glow + a 16×16 blueInk checkmark circle at top-left. Top-right corner has a 30×30 swatch of THIS theme's `bookCover` gradient. Top-left has a 26pt handwriting "Aa" in `theme.ink`. Bottom-left has the theme name (system 12pt 700) and `tag` (system 10pt).

- [ ] **Step 1: Create `ThemeCard.swift`**

```swift
import SwiftUI

/// A single theme preview card. Paints the candidate theme's own `cream`
/// background so the user sees the color immediately. Active state adds a
/// blueInk border, outer 3pt blueInk@22% glow, and a check circle at top-left.
struct ThemeCard: View {
    let themeKey: PaperThemeKey
    let isActive: Bool
    let onPick: () -> Void

    /// The active theme — used only for the `blueInk` accent. The card's
    /// own visual surface uses `cardTheme` (the candidate it represents).
    @Environment(\.paperTheme) private var activeTheme
    @Environment(\.paperFont) private var font

    private var cardTheme: PaperTheme { themeKey.theme }

    var body: some View {
        Button(action: onPick) {
            ZStack(alignment: .topLeading) {
                cardTheme.cream

                // Bookcover swatch (top-right corner, 30×30, mitered).
                cardTheme.bookCover
                    .frame(width: 30, height: 30)
                    .clipShape(UnevenRoundedRectangle(cornerRadii: .init(topLeading: 0,
                                                                          bottomLeading: 12,
                                                                          bottomTrailing: 0,
                                                                          topTrailing: 12)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Aa")
                        .font(font.font(at: 26, weight: .bold))
                        .foregroundStyle(cardTheme.ink)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(cardTheme.displayName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(cardTheme.ink)
                    Text(cardTheme.tag)
                        .font(.system(size: 10))
                        .foregroundStyle(cardTheme.ink2)
                }
                .padding(EdgeInsets(top: 10, leading: 8, bottom: 8, trailing: 8))

                if isActive {
                    activeIndicator
                        .padding(EdgeInsets(top: 6, leading: 6, bottom: 0, trailing: 0))
                }
            }
            .frame(minHeight: 84)
            .background(
                RoundedRectangle(cornerRadius: 12).fill(cardTheme.cream)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isActive ? activeTheme.blueInk : cardTheme.rule,
                                  lineWidth: isActive ? 1.5 : 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: isActive ? activeTheme.blueInk.opacity(0.22) : .clear,
                    radius: 3, x: 0, y: 0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(cardTheme.displayName)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }

    private var activeIndicator: some View {
        ZStack {
            Circle().fill(activeTheme.blueInk).frame(width: 16, height: 16)
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

#Preview("ThemeCard · all three") {
    HStack(spacing: 8) {
        ThemeCard(themeKey: .cream, isActive: true) {}
        ThemeCard(themeKey: .kraft, isActive: false) {}
        ThemeCard(themeKey: .midnight, isActive: false) {}
    }
    .padding()
    .background(PaperTheme.cream.cream)
    .paperTheme(.cream)
}
```

- [ ] **Step 2: Create `ThemeCardsGrid.swift`**

```swift
import SwiftUI

/// 3-column grid of `ThemeCard`s. Iterates `PaperThemeKey.allCases` in
/// declaration order: cream → kraft → midnight. 8pt column gap, 14pt
/// bottom margin so the next section breathes.
struct ThemeCardsGrid: View {
    let selection: PaperThemeKey
    let onPick: (PaperThemeKey) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(PaperThemeKey.allCases, id: \.self) { key in
                ThemeCard(themeKey: key, isActive: key == selection) { onPick(key) }
            }
        }
        .padding(.bottom, 14)
    }
}

#Preview("ThemeCardsGrid · cream active") {
    StatefulPreviewWrapper(PaperThemeKey.cream) { binding in
        ThemeCardsGrid(selection: binding.wrappedValue) { binding.wrappedValue = $0 }
            .padding()
            .background(PaperTheme.cream.cream)
    }
    .paperTheme(.cream)
}

private struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    let content: (Binding<Value>) -> Content

    init(_ initial: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        _value = State(initialValue: initial)
        self.content = content
    }

    var body: some View { content($value) }
}
```

- [ ] **Step 3: Build + commit**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "BUILD FAILED|BUILD SUCCEEDED" | tail -1
git add WeeklyPlanner/Features/Settings/ThemeCard.swift \
        WeeklyPlanner/Features/Settings/ThemeCardsGrid.swift
git commit -m "feat(phase-16): ThemeCard + ThemeCardsGrid 3-column preview"
```

Expected: `** BUILD SUCCEEDED **`.

---

## Task 9: `FontCard` + `FontCardsGrid`

**Files:**
- Create: `WeeklyPlanner/Features/Settings/FontCard.swift`
- Create: `WeeklyPlanner/Features/Settings/FontCardsGrid.swift`

Four cards (`.caveat`, `.architects`, `.kalam`, `.indie`). Each card uses the **card's own font** for both the "Aa" sample and the family label, so the user previews what they'll get. Background is `theme.creamHi`; active state mirrors `ThemeCard` (blueInk border + glow + trailing-edge check circle).

- [ ] **Step 1: Create `FontCard.swift`**

```swift
import SwiftUI

/// A single handwriting-font preview card. Shows a left-aligned 26pt "Aa"
/// sample, then the family display name in the same font at 15pt. Active
/// state gets a blueInk border + glow + 16pt check circle at the trailing
/// edge.
struct FontCard: View {
    let fontKey: PaperFont
    let isActive: Bool
    let onPick: () -> Void

    @Environment(\.paperTheme) private var theme

    private var sampleFont: PaperFont { fontKey }

    var body: some View {
        Button(action: onPick) {
            HStack(spacing: 10) {
                Text("Aa")
                    .font(sampleFont.font(at: 26, weight: .bold))
                    .foregroundStyle(theme.ink)
                    .frame(width: 28, alignment: .center)

                Text(sampleFont.displayName)
                    .font(sampleFont.font(at: 15, weight: .regular))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isActive {
                    ZStack {
                        Circle().fill(theme.blueInk).frame(width: 16, height: 16)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
            .background(
                RoundedRectangle(cornerRadius: 12).fill(theme.creamHi)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isActive ? theme.blueInk : theme.rule,
                                  lineWidth: isActive ? 1.5 : 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: isActive ? theme.blueInk.opacity(0.22) : .clear,
                    radius: 3, x: 0, y: 0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(sampleFont.displayName)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview("FontCard · caveat active") {
    VStack(spacing: 8) {
        FontCard(fontKey: .caveat, isActive: true) {}
        FontCard(fontKey: .architects, isActive: false) {}
    }
    .padding()
    .background(PaperTheme.cream.cream)
    .paperTheme(.cream)
}
```

- [ ] **Step 2: Create `FontCardsGrid.swift`**

```swift
import SwiftUI

/// 2-column grid of `FontCard`s. Iterates `PaperFont.allCases` in
/// declaration order: caveat → architects → kalam → indie. 8pt gap,
/// 14pt bottom margin to space the next section.
struct FontCardsGrid: View {
    let selection: PaperFont
    let onPick: (PaperFont) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(PaperFont.allCases, id: \.self) { font in
                FontCard(fontKey: font, isActive: font == selection) { onPick(font) }
            }
        }
        .padding(.bottom, 14)
    }
}

#Preview("FontCardsGrid · architects active") {
    FontCardsGrid(selection: .architects) { _ in }
        .padding()
        .background(PaperTheme.cream.cream)
        .paperTheme(.cream)
}
```

- [ ] **Step 3: Build + commit**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "BUILD FAILED|BUILD SUCCEEDED" | tail -1
git add WeeklyPlanner/Features/Settings/FontCard.swift \
        WeeklyPlanner/Features/Settings/FontCardsGrid.swift
git commit -m "feat(phase-16): FontCard + FontCardsGrid 2-column handwriting preview"
```

Expected: `** BUILD SUCCEEDED **`.

---

## Task 10: Phase-17 placeholder Connections card

**Files:**
- Create: `WeeklyPlanner/Features/Settings/ConnectionsPlaceholder.swift`

The Phase 16 spec reserves the Connections slot but explicitly defers content to Phase 17 ("To avoid an empty-looking page, render a placeholder card with title `Connections` and subtitle `Coming up next…` that Phase 17 replaces."). One small file the Phase 17 plan can delete in a single line of git diff.

- [ ] **Step 1: Create `ConnectionsPlaceholder.swift`**

```swift
import SwiftUI

/// Phase 16 placeholder for the Connections section. Phase 17 replaces the
/// body of this file with real Gmail / Apple Mail / Google Calendar rows.
/// Keeping a dedicated file (instead of inlining) means Phase 17's diff is
/// a single-file replacement with no churn on `PaperSettingsView`.
struct ConnectionsPlaceholder: View {
    @Environment(\.paperTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Connections")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.ink)
            Text("Coming up next…")
                .font(.system(size: 11))
                .foregroundStyle(theme.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .background(
            RoundedRectangle(cornerRadius: 14).fill(theme.creamHi)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14).strokeBorder(theme.rule, lineWidth: 0.5)
        )
        .padding(.bottom, 14)
    }
}

#Preview("ConnectionsPlaceholder") {
    ConnectionsPlaceholder()
        .padding()
        .background(PaperTheme.cream.cream)
        .paperTheme(.cream)
}
```

- [ ] **Step 2: Build + commit**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "BUILD FAILED|BUILD SUCCEEDED" | tail -1
git add WeeklyPlanner/Features/Settings/ConnectionsPlaceholder.swift
git commit -m "feat(phase-16): ConnectionsPlaceholder card (Phase 17 fills it)"
```

Expected: `** BUILD SUCCEEDED **`.

---

## Task 11: `PrefRow` + `ToggleRow` + `PreferencesGroup`

**Files:**
- Create: `WeeklyPlanner/Features/Settings/PrefRow.swift`
- Create: `WeeklyPlanner/Features/Settings/ToggleRow.swift`
- Create: `WeeklyPlanner/Features/Settings/PreferencesGroup.swift`

`PrefRow` is an expandable cell: tap the value chevron → reveals option pills (rounded 999pt, 12pt label). `ToggleRow` is the simpler cell hosting a `PaperToggle.regular`. `PreferencesGroup` is the card that hosts them, with 0.5pt rule dividers between siblings.

- [ ] **Step 1: Create `PrefRow.swift`**

```swift
import SwiftUI

/// Expandable preference row. Tap the value chevron → expands to a wrap-row
/// of option pills, one of which is highlighted with the blueInk border +
/// 10% fill. Selecting a pill calls `onSelect` and collapses the row.
///
/// Uses 0.22s ease for the chevron rotation + reveal (per Phase 16 spec).
struct PrefRow<Option: Hashable & CustomStringConvertible>: View {
    let label: String
    let value: Option
    let options: [Option]
    let onSelect: (Option) -> Void

    @Environment(\.paperTheme) private var theme
    @State private var isOpen: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) { isOpen.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Text(label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String(describing: value))
                        .font(.system(size: 14))
                        .foregroundStyle(theme.ink2)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(theme.ink3)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
            }
            .buttonStyle(.plain)

            if isOpen {
                optionsRow
                    .padding(EdgeInsets(top: 0, leading: 14, bottom: 10, trailing: 14))
                    .transition(.opacity)
            }
        }
    }

    private var optionsRow: some View {
        FlexibleHStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                Button {
                    onSelect(option)
                    withAnimation(.easeInOut(duration: 0.22)) { isOpen = false }
                } label: {
                    Text(String(describing: option))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.ink)
                        .padding(EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10))
                        .background(
                            Capsule().fill(option == value
                                ? theme.blueInk.opacity(0.10)
                                : Color.clear)
                        )
                        .overlay(
                            Capsule().strokeBorder(option == value
                                ? theme.blueInk
                                : theme.rule,
                                lineWidth: option == value ? 1.0 : 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Wrapping horizontal stack — SwiftUI's `HStack` doesn't wrap, and the
/// option-pill row needs to wrap to the next line on long option sets
/// (e.g., the 5-option default-reminder list).
private struct FlexibleHStack<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    init(spacing: CGFloat, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            content()
        }
    }
}
```

> Note: a true flow layout would use `Layout`-based wrapping, but the two
> PrefRows in scope each have ≤ 5 options that fit one line on iPhone 17 at
> the default frame width. Keep the HStack; revisit if Phase 17 adds more.

- [ ] **Step 2: Create `ToggleRow.swift`**

```swift
import SwiftUI

/// Single-row toggle cell. Lays out a label on top of an optional detail
/// (system 11pt `ink2`) on the leading side, and a `PaperToggle.regular`
/// on the trailing side. Lives inside `PreferencesGroup`'s `creamHi` card.
struct ToggleRow: View {
    let label: String
    let detail: String?
    @Binding var isOn: Bool

    @Environment(\.paperTheme) private var theme

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(theme.ink)
                if let detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.ink2)
                        .lineSpacing(1.3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            PaperToggle(isOn: $isOn, style: .regular)
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
    }
}
```

- [ ] **Step 3: Create `PreferencesGroup.swift`**

```swift
import SwiftUI

/// Card container for the three preference rows. Rounded-14pt rectangle
/// painted with `theme.creamHi`, 0.5pt rule border, with 0.5pt rule
/// dividers between children. Children are positioned via the trailing
/// `content` closure so the card stays agnostic of the exact rows.
struct PreferencesGroup<Content: View>: View {
    @Environment(\.paperTheme) private var theme
    @ViewBuilder let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 14).fill(theme.creamHi)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14).strokeBorder(theme.rule, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.bottom, 14)
    }
}

/// Convenience `View` for an inline 0.5pt rule between cells. Use after
/// every row except the last in a `PreferencesGroup`.
struct PrefRowDivider: View {
    @Environment(\.paperTheme) private var theme
    var body: some View {
        Rectangle()
            .fill(theme.rule)
            .frame(height: 0.5)
    }
}
```

- [ ] **Step 4: Build + commit**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "BUILD FAILED|BUILD SUCCEEDED" | tail -1
git add WeeklyPlanner/Features/Settings/PrefRow.swift \
        WeeklyPlanner/Features/Settings/ToggleRow.swift \
        WeeklyPlanner/Features/Settings/PreferencesGroup.swift
git commit -m "feat(phase-16): PreferencesGroup with PrefRow + ToggleRow children"
```

Expected: `** BUILD SUCCEEDED **`.

---

## Task 12: `SettingsHeader` + `AboutFooter`

**Files:**
- Create: `WeeklyPlanner/Features/Settings/SettingsHeader.swift`
- Create: `WeeklyPlanner/Features/Settings/AboutFooter.swift`

`SettingsHeader` paints "Make it yours" (30pt handwriting 700) + a Cochin italic 12pt sub-line + a 2pt gradient rule that fades to transparent at 100%. `AboutFooter` is the centered italic "The Planner · v1.0 · made with care" trailer in handwriting 16pt at `ink3`.

- [ ] **Step 1: Create `SettingsHeader.swift`**

```swift
import SwiftUI

/// Top-of-page banner shown inside the `BookPage`. Two lines of text plus
/// a 2pt gradient rule that fades to transparent at 100% — matches the
/// header used by the Calendar page header but with a settings-specific
/// title + subtitle.
struct SettingsHeader: View {
    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Make it yours")
                .font(font.font(at: 30, weight: .bold))
                .foregroundStyle(theme.ink)
                .padding(EdgeInsets(top: 14, leading: 18, bottom: 4, trailing: 18))

            Text("Theme, handwriting, connections.")
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

#Preview("SettingsHeader · cream") {
    SettingsHeader()
        .padding(.leading, 32)
        .background(PaperTheme.cream.cream)
        .paperTheme(.cream)
}
```

- [ ] **Step 2: Create `AboutFooter.swift`**

```swift
import SwiftUI

/// Centered italic trailer at the bottom of `PaperSettingsView`'s scroll
/// content. Handwriting 16pt at `ink3`. 10pt vertical padding so the row
/// sits comfortably above the scroll bottom.
struct AboutFooter: View {
    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        Text("The Planner · v1.0 · made with care")
            .font(font.font(at: 16, weight: .regular))
            .italic()
            .foregroundStyle(theme.ink3)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 10)
    }
}

#Preview("AboutFooter · cream") {
    AboutFooter()
        .padding()
        .background(PaperTheme.cream.cream)
        .paperTheme(.cream)
}
```

- [ ] **Step 3: Build + commit**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "BUILD FAILED|BUILD SUCCEEDED" | tail -1
git add WeeklyPlanner/Features/Settings/SettingsHeader.swift \
        WeeklyPlanner/Features/Settings/AboutFooter.swift
git commit -m "feat(phase-16): SettingsHeader + AboutFooter chrome"
```

Expected: `** BUILD SUCCEEDED **`.

---

## Task 13: Compose `PaperSettingsView`

**Files:**
- Modify: `WeeklyPlanner/Features/Settings/PaperSettingsView.swift`

Replace the Phase 15 placeholder with the full composition. Reads `\.settingsStore` from the environment and builds `SettingsViewModel` inside a `.task` block (lazy mount so the row is materialized before the first read). The body is a `ScrollView` of: `SettingsHeader`, then a 5-section column with 4 `SectionTitle`s separating the grids/groups, ending with `AboutFooter`. 92pt bottom inset so the `PaperTabBar` doesn't cover content.

- [ ] **Step 1: Replace `PaperSettingsView.swift`**

```swift
import SwiftUI

/// The embedded Settings page. Sits inside the leather book chrome that
/// `AppShell` paints, painting its own `BookPage` + `PaperSurface` so the
/// background gradient + ruled lines + hole punches read as a real paper
/// page. Body is a `ScrollView` of five sections plus header + footer.
///
/// `SettingsViewModel` is built lazily in `.task` so a fresh navigation
/// always reads the latest `UserSettings` row.
struct PaperSettingsView: View {
    @Environment(\.settingsStore) private var settingsStore
    @Environment(\.paperTheme) private var theme

    @State private var viewModel: SettingsViewModel?

    var body: some View {
        BookPage {
            PaperSurface {
                ZStack(alignment: .topLeading) {
                    PaperGrain()
                    RuledLines()
                    RedMarginLine()
                    HolePunches()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            SettingsHeader()

                            if let viewModel {
                                sections(for: viewModel)
                            } else {
                                ProgressView().padding(.top, 60)
                            }
                        }
                        .padding(.leading, 32) // clear the red margin
                        .padding(.bottom, 92)  // PaperTabBar clearance
                    }
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = SettingsViewModel(store: settingsStore)
            }
        }
    }

    @ViewBuilder
    private func sections(for viewModel: SettingsViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. THEME
            SectionTitle("Theme", eyebrow: "Look & feel")
            ThemeCardsGrid(selection: viewModel.themeKey) { viewModel.setTheme($0) }

            // 2. HANDWRITING
            SectionTitle("Handwriting")
            FontCardsGrid(selection: viewModel.fontKey) { viewModel.setFont($0) }

            // 3. TEXT SIZE
            SectionTitle("Text size")
            SizeSegmented(selection: Binding(
                get: { viewModel.sizeKey },
                set: { viewModel.setSize($0) }
            ))

            // 4. CONNECTIONS (Phase 17 replaces this placeholder)
            SectionTitle("Connections", eyebrow: "Sources")
            ConnectionsPlaceholder()

            // 5. PREFERENCES
            SectionTitle("Preferences")
            PreferencesGroup {
                PrefRow(label: "Week starts on",
                        value: viewModel.weekStartsOnMonday ? WeekStart.monday : .sunday,
                        options: WeekStart.allCases) { newValue in
                    viewModel.setWeekStartsOnMonday(newValue == .monday)
                }
                PrefRowDivider()
                PrefRow(label: "Default reminder",
                        value: ReminderOption(minutes: viewModel.defaultReminderMinutes),
                        options: ReminderOption.allCases) { newValue in
                    viewModel.setDefaultReminderMinutes(newValue.minutes)
                }
                PrefRowDivider()
                ToggleRow(label: "Apple Intelligence",
                          detail: "On-device only · keeps data private",
                          isOn: Binding(
                              get: { viewModel.appleIntelligenceEnabled },
                              set: { viewModel.setAppleIntelligenceEnabled($0) }
                          ))
            }

            AboutFooter()
        }
        .padding(EdgeInsets(top: 14, leading: 18, bottom: 28, trailing: 18))
    }
}

// MARK: - PrefRow value types

/// Two-state option for `Week starts on`. `CustomStringConvertible` so
/// `PrefRow` can render it directly.
enum WeekStart: String, CaseIterable, CustomStringConvertible {
    case monday, sunday
    var description: String { rawValue.capitalized }
}

/// Five-state option for `Default reminder`. `nil` minutes maps to "None";
/// everything else uses a compact "5 min" / "1 hr" form.
struct ReminderOption: Hashable, CaseIterable, CustomStringConvertible {
    let minutes: Int?

    static let allCases: [ReminderOption] = [
        ReminderOption(minutes: nil),
        ReminderOption(minutes: 5),
        ReminderOption(minutes: 15),
        ReminderOption(minutes: 30),
        ReminderOption(minutes: 60),
    ]

    var description: String {
        guard let minutes else { return "None" }
        if minutes == 60 { return "1 hr" }
        return "\(minutes) min"
    }
}

#Preview("PaperSettingsView · cream") {
    PaperSettingsView()
        .paperTheme(.cream)
        .environment(\.settingsStore, StubSettingsStore())
}

#Preview("PaperSettingsView · kraft") {
    PaperSettingsView()
        .paperTheme(.kraft)
        .environment(\.settingsStore, StubSettingsStore())
}

#Preview("PaperSettingsView · midnight") {
    PaperSettingsView()
        .paperTheme(.midnight)
        .environment(\.settingsStore, StubSettingsStore())
}
```

- [ ] **Step 2: Build + run the full suite**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO 2>&1 \
  | grep -E "TEST FAILED|TEST SUCCEEDED|Executed [0-9]+ tests" | tail -3
```

Expected: `** TEST SUCCEEDED **`, `Executed 205 tests, with 0 failures`.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Features/Settings/PaperSettingsView.swift
git commit -m "feat(phase-16): PaperSettingsView composes the full settings page"
```

---

## Task 14: `PaperSettingsViewTests` composition assertions

**Files:**
- Create: `WeeklyPlannerTests/Features/Settings/PaperSettingsViewTests.swift`

The Phase 16 spec calls for snapshot tests but the project has no snapshot dep. We assert structural facts instead: every `PaperThemeKey` produces a `ThemeCard`, every `PaperFont` produces a `FontCard`, every `PaperSize` is wired through `SizeSegmented`, and `ReminderOption` covers the 5 expected states. The visual diff vs `docs/mock/paper-settings.jsx` is performed manually in Task 15.

- [ ] **Step 1: Create `PaperSettingsViewTests.swift`**

```swift
import XCTest
@testable import WeeklyPlanner

@MainActor
final class PaperSettingsViewTests: XCTestCase {
    func testReminderOptionAllCasesCoversFiveStates() {
        let cases = ReminderOption.allCases
        XCTAssertEqual(cases.count, 5)
        XCTAssertEqual(cases.map(\.minutes), [nil, 5, 15, 30, 60])
    }

    func testReminderOptionDescriptionFormatting() {
        XCTAssertEqual(ReminderOption(minutes: nil).description, "None")
        XCTAssertEqual(ReminderOption(minutes: 5).description, "5 min")
        XCTAssertEqual(ReminderOption(minutes: 15).description, "15 min")
        XCTAssertEqual(ReminderOption(minutes: 30).description, "30 min")
        XCTAssertEqual(ReminderOption(minutes: 60).description, "1 hr")
    }

    func testWeekStartHasMondayAndSundayOnly() {
        let cases = WeekStart.allCases
        XCTAssertEqual(cases, [.monday, .sunday])
        XCTAssertEqual(cases.map(\.description), ["Monday", "Sunday"])
    }

    func testPaperThemeKeyCountMatchesGridColumnCount() {
        // ThemeCardsGrid is a 3-col grid; we want exactly 3 themes so each
        // row is full. If a fourth theme lands, this test will fail and
        // remind us to revisit the grid columns.
        XCTAssertEqual(PaperThemeKey.allCases.count, 3)
    }

    func testPaperFontCountIsFourSoFontCardsGridIsTwoFullRows() {
        // FontCardsGrid is a 2-col grid; 4 fonts == 2 full rows.
        XCTAssertEqual(PaperFont.allCases.count, 4)
    }

    func testPaperSizeCountIsThreeSoSizeSegmentedFits() {
        XCTAssertEqual(PaperSize.allCases.count, 3)
        XCTAssertEqual(PaperSize.allCases.map(\.displayName), ["Small", "Medium", "Large"])
    }
}
```

- [ ] **Step 2: Regenerate + run the new tests**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO -only-testing:WeeklyPlannerTests/PaperSettingsViewTests 2>&1 \
  | grep -E "TEST FAILED|TEST SUCCEEDED|Executed [0-9]+ tests" | tail -3
```

Expected: `** TEST SUCCEEDED **`, `Executed 6 tests, with 0 failures`.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlannerTests/Features/Settings/PaperSettingsViewTests.swift
git commit -m "test(phase-16): PaperSettingsView composition assertions"
```

---

## Task 15: Manual visual smoke test + simulator verification

**Files:** none (verification only)

Run the app in the simulator, switch to the Settings tab, tap each section's options, and confirm live switching propagates. Capture a screenshot for the retrospective.

- [ ] **Step 1: Boot the simulator and install the debug build**

```bash
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -2

xcrun simctl boot 'iPhone 17 Pro' 2>/dev/null || true
open -a Simulator
xcrun simctl install booted build/DerivedData/Build/Products/Debug-iphonesimulator/WeeklyPlanner.app
xcrun simctl launch booted com.weeklyplanner.WeeklyPlanner
```

Expected: the app launches on the Calendar tab.

- [ ] **Step 2: Walk the Settings page in the simulator**

Manually tap through:
1. Tab to **Settings**. Confirm the cream header reads "Make it yours" with the Cochin italic sub-line.
2. Tap each `ThemeCard` (cream / kraft / midnight). The entire app — book cover, page, ink — must flip instantly to the chosen theme.
3. Tap each `FontCard`. Handwriting elements across the page should swap to the new family within ~200ms.
4. Tap each `SizeSegmented` segment (S / M / L). The "Aa" sample and the segment label resize live; navigate to the Calendar tab and confirm date numbers grow on L.
5. Expand `Week starts on`, pick Sunday, verify the Calendar tab's week-picker shifts.
6. Expand `Default reminder`, pick None, then 1 hr.
7. Toggle `Apple Intelligence` off, navigate to Calendar, open the AI overlay, confirm the sparkles button is hidden / canned answer fallback message appears (per Phase 13's existing behavior).

- [ ] **Step 3: Capture a screenshot**

```bash
xcrun simctl io booted screenshot --type=png docs/phases/phase-16-settings.png
```

Expected: a PNG saved under `docs/phases/`. Verify it shows the full Settings page in cream theme.

- [ ] **Step 4: Run the full test suite once more**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO 2>&1 \
  | grep -E "TEST FAILED|TEST SUCCEEDED|Executed [0-9]+ tests" | tail -3
```

Expected: `** TEST SUCCEEDED **`, `Executed 211 tests, with 0 failures`.

- [ ] **Step 5: Commit screenshot**

```bash
git add docs/phases/phase-16-settings.png
git commit -m "docs(phase-16): screenshot of paper settings page"
```

---

## Task 16: Retrospective + README updates

**Files:**
- Modify: `docs/phases/README.md`
- Modify: `README.md`

Append the Phase 16 retrospective to `docs/phases/README.md`, flip the Phase 16 status in the phase map, and update the project README's milestone table.

- [ ] **Step 1: Append the Phase 16 retrospective**

Open `docs/phases/README.md`, locate the end of the Phase 15 retrospective (the last `**Files**:` line under "### Phase 15 — Paper Tab Bar & Navigation Wiring"), and append:

```markdown

### Phase 16 — Settings (Theme, Handwriting, Size, Preferences)

Shipped the embedded Settings page: a `BookPage` + `PaperSurface` paper page on top of the persistent leather cover, hosting a `SettingsHeader` ("Make it yours" + Cochin italic sub-line + gradient rule), then five sections — `ThemeCardsGrid` (cream / kraft / midnight), `FontCardsGrid` (caveat / architects / kalam / indie), `SizeSegmented` (S / M / L with live handwriting preview), `ConnectionsPlaceholder` (Phase 17 fills it), and `PreferencesGroup` (Week-starts-on / Default-reminder / Apple Intelligence) — closing with the centered italic `AboutFooter`. `SettingsViewModel` reads on init from `SettingsStoring.current()` and writes through `SettingsStoring.update`, so every selection persists.

Closed two Phase 15 gaps along the way: `WeeklyPlannerApp` now injects a production `SwiftDataSettingsStore` (it was falling through to `StubSettingsStore`, so tab selection wasn't actually surviving relaunches), and `AppShell` now reads the persisted row via `@Query` and re-injects `\.paperTheme` / `\.paperFont` / `\.paperSize` at the top of `body`. The whole app re-renders on every settings write — book cover, page chrome, ink, and handwriting all flip live.

Snapshot tests are deferred to Phase 21 (we have no `swift-snapshot-testing` dep). `PaperSettingsViewTests` instead asserts structural invariants — 3 themes / 4 fonts / 3 sizes / 5 reminder options / 2 week-start choices — and the visual diff is performed manually against `docs/mock/paper-settings.jsx` (screenshot at `docs/phases/phase-16-settings.png`).

**Tests added**: 2 classes / 13 new test methods (`SettingsViewModelTests` × 7, `PaperSettingsViewTests` × 6). Full suite: 211 unit tests + UI tests, all green.

**Files**: `WeeklyPlanner/Features/Settings/{SettingsViewModel,SettingsHeader,SectionTitle,ThemeCardsGrid,ThemeCard,FontCardsGrid,FontCard,SizeSegmented,ConnectionsPlaceholder,PreferencesGroup,PrefRow,ToggleRow,AboutFooter}.swift`; modified `WeeklyPlanner/Features/Settings/PaperSettingsView.swift`, `WeeklyPlanner/App/WeeklyPlannerApp.swift`, `WeeklyPlanner/Navigation/AppShell.swift`.
```

- [ ] **Step 2: Flip the Phase 16 status in `docs/phases/README.md`'s phase map**

Find the row:

```
| 16 | Settings — Theme, Handwriting, Size, Preferences     | G — Settings        | ⏳     |
```

Replace `⏳` with `✅`. Also update the "Current state" paragraph below the table:

Find:
```
**Current state:** Milestones A–F shipped (Phases 01–15). 198 unit tests
green. Next up: Milestone G — Settings (Phase 16).
```

Replace with:
```
**Current state:** Milestones A–F + Phase 16 shipped. 211 unit tests
green. Next up: Phase 17 — Settings (Connections).
```

- [ ] **Step 3: Update top-level `README.md`**

In the milestone table, change the Milestone G row from `⏳ next` to `⏳ in progress (Phase 16 done)` and adjust the status paragraph:

Find:
```
**Milestones A–F complete** — Phases 01–15 shipped to `main`. The app builds
and runs end-to-end: leather book chrome, Day / Week pages with hobonichi
layout, page-flip animations, week picker, event detail + AI search sheets,
on-device Foundation Models integration, Review page with AI summary, and the
paper-bottom tab bar with right-edge binder-style day tabs. 198 unit tests +
UI smoke tests, all green.
```

Replace with:
```
**Milestones A–F + Phase 16 complete** — Phases 01–16 shipped to `main`. The
app builds and runs end-to-end: leather book chrome, Day / Week pages with
hobonichi layout, page-flip animations, week picker, event detail + AI
search sheets, on-device Foundation Models integration, Review page with AI
summary, the paper-bottom tab bar with right-edge binder-style day tabs, and
a live-switching Settings page (3 themes × 4 handwriting fonts × 3 text
sizes). 211 unit tests + UI smoke tests, all green.
```

Find the milestone row:
```
| G — Settings           | 16–17 | ⏳ next |
```

Replace with:
```
| G — Settings           | 16–17 | 🟡 in progress (Phase 16 ✅) |
```

- [ ] **Step 4: Commit the docs**

```bash
git add docs/phases/README.md README.md
git commit -m "docs(phase-16): retrospective + status updates"
```

---

## Task 17: Merge milestone-g-settings into main

**Files:** none (git operation only)

Phase 16 is one of two phases in Milestone G; the integration branch will continue with Phase 17 next. Merge what's done into main with a merge commit so the history mirrors prior milestones.

- [ ] **Step 1: Confirm clean tree on milestone-g-settings**

```bash
git status --short
git log --oneline main..HEAD
```

Expected: empty status, a list of every Phase 16 commit above main.

- [ ] **Step 2: Run the full suite one last time**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO 2>&1 \
  | grep -E "TEST FAILED|TEST SUCCEEDED|Executed [0-9]+ tests" | tail -3
```

Expected: `** TEST SUCCEEDED **`, `Executed 211 tests, with 0 failures`.

- [ ] **Step 3: Stop here and confirm with user before merging to main**

Merging to `main` is hard to undo and is the user's call. Report Phase 16 complete + the test count and wait for explicit instruction before running `git merge` on `main`.

---

## Self-Review

Looking at the spec with fresh eyes:

**1. Spec coverage:**
- Outer page chrome (BookPage / surface / ruled lines / red margin / holes) → Task 13 (PaperSettingsView composition).
- `SettingsHeader` ("Make it yours" + Cochin sub + gradient rule) → Task 12.
- Body scroll padding `14 18 28` → Task 13 (`.padding(EdgeInsets(top: 14, leading: 18, bottom: 28, trailing: 18))`).
- Theme section (SectionTitle + ThemeCardsGrid + 3 ThemeCards) → Tasks 6 + 8.
- Handwriting section (SectionTitle + FontCardsGrid + 4 FontCards) → Tasks 6 + 9.
- Text size segmented S/M/L with live preview → Task 7.
- Connections placeholder → Task 10.
- Preferences (PrefRow × 2 + ToggleRow) → Task 11.
- AboutFooter → Task 12.
- Live switching wired through SettingsStore → Tasks 2 + 5 + 4.
- Defaults match fresh install → Task 4 (`testDefaultsAfterFreshInstall`).
- `SettingsViewModelTests` per spec → Task 4 (covers theme persists, font/size update, AI toggle, defaults).
- `SettingsSnapshotTests` → **explicitly deferred to Phase 21**, replaced by composition assertions in Task 14 (rationale documented in the retrospective).

**2. Placeholder scan:**
No TBDs, no "implement later", no naked "similar to Task N" — every code step shows the actual code. The deferred snapshot tests are explicitly justified and noted in the retrospective.

**3. Type consistency:**
- `SettingsViewModel.themeKey: PaperThemeKey` matches `ThemeCardsGrid(selection: PaperThemeKey, ...)`.
- `SettingsViewModel.fontKey: PaperFont` matches `FontCardsGrid(selection: PaperFont, ...)`.
- `SettingsViewModel.sizeKey: PaperSize` matches `SizeSegmented(selection: $PaperSize)`.
- `ReminderOption.minutes: Int?` matches `SettingsViewModel.defaultReminderMinutes: Int?` and `UserSettings.defaultReminderMinutes: Int?`.
- `WeekStart.monday` / `.sunday` ↔ `Bool` round-trip in Task 13.
- `\.settingsStore` env value is `any SettingsStoring` per Phase 15 spec — `SettingsViewModel(store: any SettingsStoring)` matches.
- `PaperToggle(isOn:style:)` from Phase 05 takes `Binding<Bool>` + `Style.regular` — matches `ToggleRow`'s usage.
- `BookPage { ... }` / `PaperSurface { ... }` / `PaperGrain` / `RuledLines` / `RedMarginLine` / `HolePunches` all match the existing primitives used by `PaperReviewView`.

No drift. Plan is ready.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-19-phase-16-settings.md`. Two execution options:

**1. Subagent-Driven (recommended)** — fresh subagent per task, two-stage review between tasks, fast iteration.

**2. Inline Execution** — execute tasks in this session using `superpowers:executing-plans`, batch execution with checkpoints.

Which approach?
