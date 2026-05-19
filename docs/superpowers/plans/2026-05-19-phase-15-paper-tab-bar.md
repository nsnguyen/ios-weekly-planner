# Phase 15 — Paper Tab Bar & Navigation Wiring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the temporary three-segment Day/Week/Review toggle with the real leather-bound bottom tab bar (Calendar / Review / Settings), introduce an `AppShell` root container that keeps `BookCover` persistent across tab switches, and stub the Settings tab until Phase 16 builds it out.

**Architecture:**
- `TabSelection` (@Observable) owns the active tab and persists it through `UserSettings.lastTabRaw` via `SettingsStore.update`. A new top-level `AppShell` view renders a persistent `BookCover` at z=0, routes the active tab's content above it, and pins a `PaperTabBar` to the bottom via `.safeAreaInset(edge: .bottom)`. The existing `BookContainer` learns an `includesCover: Bool` flag (default `true`, non-breaking) so that the Calendar tab can suppress its own internal cover and let `AppShell`'s persistent cover show through.
- The `Day/Week/Review` 3-segment toggle from Phase 14 reverts to the 2-segment `Day/Week` it was before, and `PaperView.review` is removed from the enum — the Review screen is now reachable only via the tab bar.
- Modal overlays (`PaperAISearchView`, `WeekPickerSheet`) continue to live in `AppShell` (lifted from `RootView`) so they layer above both the active screen and the tab bar.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, XCTest. XcodeGen regenerates the project from `project.yml`; the `WeeklyPlanner` target's `sources` is the entire `WeeklyPlanner/` folder, so new files under `WeeklyPlanner/Navigation/` are picked up automatically on `xcodegen generate`.

---

## File Structure

### Created

```
WeeklyPlanner/Navigation/TabSelection.swift                       # Tab enum + @Observable selection
WeeklyPlanner/Navigation/PaperTab.swift                           # Single tab with bookmark
WeeklyPlanner/Navigation/PaperTabBar.swift                        # Bar with stitched seam
WeeklyPlanner/Navigation/AppShell.swift                           # Root container
WeeklyPlanner/Features/Settings/PaperSettingsView.swift           # Phase 16 stub
WeeklyPlannerTests/Models/UserSettingsLastTabTests.swift          # Round-trip test
WeeklyPlannerTests/Navigation/TabSelectionTests.swift             # Default + persistence
```

### Modified

```
WeeklyPlanner/Models/UserSettings.swift                # Add lastTabRaw + lastTab accessor
WeeklyPlanner/Models/AppStyle.swift                    # Remove case review from PaperView
WeeklyPlanner/Features/DayPage/DayWeekToggle.swift     # Revert to 2-segment Day/Week
WeeklyPlanner/Features/DayPage/BookContainer.swift     # Add includesCover: Bool = true
WeeklyPlanner/App/RootView.swift                       # Replace direct BookContainer composition with AppShell
docs/phases/README.md                                  # Phase 15 retrospective
```

### Conventions (already established, restated for reviewers)

- **No emojis in source files unless they're literal UI strings** (the streak emojis in `Streak`, etc.).
- **POSIX-locked date formatters** in tests for determinism.
- **`@Observable`** for view-models, **`@Environment`** for cross-cutting dependencies (stores, theme).
- **Tests under `WeeklyPlannerTests/<feature>/`** mirror the source folder structure.
- **Per-task atomic commits** with `feat(phase-15):` / `chore(phase-15):` / `docs(phase-15):` prefix.

---

## Task 1: Sync worktree with main

**Files:** none (git operation only)

The `milestone-f-other-screens` branch already exists with the Phase 14 commits but is missing the merge commit that landed Phase 14 in main. Sync the branch in its existing worktree at `/Users/nguyen-mini/Documents/dev/ios-weekly-planner-phase-13` (no new worktree needed — Phase 15 is a continuation of milestone F).

- [ ] **Step 1: Sync milestone-f-other-screens with main**

```bash
cd /Users/nguyen-mini/Documents/dev/ios-weekly-planner-phase-13
git fetch
git merge main --ff-only 2>&1 | tail -3
```

Expected: `Already up to date.` (no-op if main is at the merge of `milestone-f-other-screens`) **or** a fast-forward to pick up the `chore: untrack AGENTS.md` commit. If a non-FF merge would be needed, stop and ask — that means main has diverged.

- [ ] **Step 2: Confirm clean working tree**

```bash
cd /Users/nguyen-mini/Documents/dev/ios-weekly-planner-phase-13
git status --short
git log --oneline -5
```

Expected: empty status; HEAD shows the latest Phase 14 commits.

- [ ] **Step 3: Regenerate Xcode project + baseline build/test**

```bash
cd /Users/nguyen-mini/Documents/dev/ios-weekly-planner-phase-13
xcodegen generate 2>&1 | tail -2
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 \
  | grep -E "TEST FAILED|TEST SUCCEEDED|Executed [0-9]+ tests" | tail -3
```

Expected: `** TEST SUCCEEDED **` with `Executed 188 tests, with 0 failures`. This is the Phase 15 starting baseline.

---

## Task 2: UserSettings.lastTabRaw

**Files:**
- Modify: `WeeklyPlanner/Models/UserSettings.swift`
- Create: `WeeklyPlannerTests/Models/UserSettingsLastTabTests.swift`

Adds a persisted `lastTabRaw: String` property to the `@Model` `UserSettings` row plus an enum accessor. SwiftData will migrate existing rows by populating the default value (`"calendar"`).

- [ ] **Step 1: Write the failing test**

Create `WeeklyPlannerTests/Models/UserSettingsLastTabTests.swift`:

```swift
import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class UserSettingsLastTabTests: XCTestCase {
    func testDefaultLastTabIsCalendar() throws {
        let container = try SwiftDataStack.inMemoryContainer()
        let store = SwiftDataSettingsStore(context: container.mainContext)
        let settings = try store.current()
        XCTAssertEqual(settings.lastTabRaw, "calendar")
    }

    func testLastTabRoundTripsThroughStore() throws {
        let container = try SwiftDataStack.inMemoryContainer()
        let store = SwiftDataSettingsStore(context: container.mainContext)
        try store.update { $0.lastTabRaw = "review" }
        let reloaded = try store.current()
        XCTAssertEqual(reloaded.lastTabRaw, "review")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodegen generate
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:WeeklyPlannerTests/UserSettingsLastTabTests test 2>&1 | tail -5
```

Expected: build fails — `UserSettings` has no `lastTabRaw` member.

- [ ] **Step 3: Add `lastTabRaw` to UserSettings**

In `WeeklyPlanner/Models/UserSettings.swift`, locate the property block and the init parameters, then add the new field. Final relevant region:

```swift
    // Style
    var styleRaw: String
    var modernViewRaw: String
    var paperViewRaw: String
    var accentHex: String

    /// Active tab on the bottom paper tab bar (Phase 15). Stored as the
    /// `Tab.rawValue` String so SwiftData can index/predicate-filter it.
    /// Defaults to `"calendar"` on fresh installs.
    var lastTabRaw: String

    var updatedAt: Date

    init(id: UUID = UUID(),
         themeKey: String = PaperThemeKey.cream.rawValue,
         fontKey: String = PaperFont.caveat.rawValue,
         sizeKey: String = PaperSize.m.rawValue,
         weekStartsOnMonday: Bool = true,
         defaultReminderMinutes: Int? = 15,
         appleIntelligenceEnabled: Bool = true,
         gmailConnected: Bool = false,
         gmailAccountEmail: String? = nil,
         googleCalendarConnected: Bool = false,
         appleMailConnected: Bool = true,
         style: AppStyle = .paper,
         modernView: ModernView = .day,
         paperView: PaperView = .day,
         accentHex: String = "#0A84FF",
         lastTabRaw: String = "calendar",
         updatedAt: Date = .init())
    {
        self.id = id
        self.themeKey = themeKey
        self.fontKey = fontKey
        self.sizeKey = sizeKey
        self.weekStartsOnMonday = weekStartsOnMonday
        self.defaultReminderMinutes = defaultReminderMinutes
        self.appleIntelligenceEnabled = appleIntelligenceEnabled
        self.gmailConnected = gmailConnected
        self.gmailAccountEmail = gmailAccountEmail
        self.googleCalendarConnected = googleCalendarConnected
        self.appleMailConnected = appleMailConnected
        styleRaw = style.rawValue
        modernViewRaw = modernView.rawValue
        paperViewRaw = paperView.rawValue
        self.accentHex = accentHex
        self.lastTabRaw = lastTabRaw
        self.updatedAt = updatedAt
    }
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:WeeklyPlannerTests/UserSettingsLastTabTests test 2>&1 | tail -5
```

Expected: `Test Suite 'UserSettingsLastTabTests' passed`.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Models/UserSettings.swift \
        WeeklyPlannerTests/Models/UserSettingsLastTabTests.swift
git commit -m "feat(phase-15): UserSettings.lastTabRaw persists active paper tab"
```

---

## Task 3: TabSelection

**Files:**
- Create: `WeeklyPlanner/Navigation/TabSelection.swift`
- Create: `WeeklyPlannerTests/Navigation/TabSelectionTests.swift`

`TabSelection` is the `@Observable` source-of-truth for the active bottom tab. It loads the persisted tab from `SettingsStore` on init and writes back through `SettingsStore.update` on every change. The `Tab` enum exposes the three top-level destinations.

- [ ] **Step 1: Write the failing tests**

Create `WeeklyPlannerTests/Navigation/TabSelectionTests.swift`:

```swift
import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class TabSelectionTests: XCTestCase {
    private var container: ModelContainer!
    private var settingsStore: SwiftDataSettingsStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        settingsStore = SwiftDataSettingsStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        settingsStore = nil; container = nil
        try await super.tearDown()
    }

    func testDefaultTabIsCalendar() throws {
        let selection = TabSelection(settings: settingsStore)
        XCTAssertEqual(selection.current, .calendar)
    }

    func testSwitchingTabPersistsThroughSettingsStore() throws {
        let selection = TabSelection(settings: settingsStore)
        selection.current = .review
        let reloaded = try settingsStore.current()
        XCTAssertEqual(reloaded.lastTabRaw, "review")
    }

    func testFreshInstanceRestoresPersistedTab() throws {
        try settingsStore.update { $0.lastTabRaw = "settings" }
        let selection = TabSelection(settings: settingsStore)
        XCTAssertEqual(selection.current, .settings)
    }

    func testUnknownPersistedValueFallsBackToCalendar() throws {
        try settingsStore.update { $0.lastTabRaw = "garbage" }
        let selection = TabSelection(settings: settingsStore)
        XCTAssertEqual(selection.current, .calendar)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodegen generate
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:WeeklyPlannerTests/TabSelectionTests test 2>&1 | tail -5
```

Expected: build fails — `TabSelection` and `Tab` don't exist.

- [ ] **Step 3: Implement TabSelection**

Create `WeeklyPlanner/Navigation/TabSelection.swift`:

```swift
import Foundation
import Observation

/// The three destinations on the bottom paper tab bar. Raw values double as
/// the persisted-form string in `UserSettings.lastTabRaw`.
enum Tab: String, CaseIterable, Hashable, Sendable {
    case calendar
    case review
    case settings
}

/// Source-of-truth for the active tab. Loads from `SettingsStore` on init
/// and writes back on every mutation of `current`. Stays `@MainActor`-only
/// because mutating SwiftData via `SettingsStore` must happen on the main
/// context.
@MainActor
@Observable
final class TabSelection {
    /// The currently-visible tab. Writing this triggers a `SettingsStore.update`
    /// so the choice survives launches.
    var current: Tab {
        didSet {
            guard oldValue != current else { return }
            try? settings.update { $0.lastTabRaw = current.rawValue }
        }
    }

    private let settings: any SettingsStore

    init(settings: any SettingsStore) {
        self.settings = settings
        let raw = (try? settings.current().lastTabRaw) ?? Tab.calendar.rawValue
        current = Tab(rawValue: raw) ?? .calendar
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodegen generate
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:WeeklyPlannerTests/TabSelectionTests test 2>&1 | tail -5
```

Expected: `Test Suite 'TabSelectionTests' passed`.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Navigation/TabSelection.swift \
        WeeklyPlannerTests/Navigation/TabSelectionTests.swift
git commit -m "feat(phase-15): TabSelection @Observable backed by SettingsStore"
```

---

## Task 4: PaperSettingsView stub

**Files:**
- Create: `WeeklyPlanner/Features/Settings/PaperSettingsView.swift`

Phase 16 builds the full Settings page. Phase 15 only needs an embedded placeholder so the Settings tab has something to show. Reuses the existing `BookPage` + `PaperSurface` chrome so it doesn't look like a broken screen.

- [ ] **Step 1: Implement the stub**

Create `WeeklyPlanner/Features/Settings/PaperSettingsView.swift`:

```swift
import SwiftUI

/// Phase 16 lands the full settings page. Phase 15 ships this placeholder so
/// the Settings tab on the new paper tab bar has a destination that still
/// reads as part of the book — same `BookPage` + `PaperSurface` chrome as
/// every other paper screen, with a centered handwritten "Settings" label and
/// a Cochin sub-line announcing the Phase 16 wait.
struct PaperSettingsView: View {
    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        BookPage {
            PaperSurface {
                ZStack(alignment: .top) {
                    PaperGrain()
                    RuledLines()
                    RedMarginLine()
                    HolePunches()

                    VStack(spacing: 8) {
                        Spacer(minLength: 0)
                        Text("Settings")
                            .font(font.font(at: 36, weight: .bold))
                            .foregroundStyle(theme.ink)
                            .rotationEffect(.degrees(-2))
                        Text("Theme, font, and connections arrive in Phase 16.")
                            .font(.custom("Cochin-Italic", size: 14))
                            .foregroundStyle(theme.ink2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}

#Preview("PaperSettingsView · cream") {
    PaperSettingsView()
        .paperTheme(.cream)
}
```

- [ ] **Step 2: Verify it compiles**

```bash
xcodegen generate
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -quiet build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Features/Settings/PaperSettingsView.swift
git commit -m "feat(phase-15): PaperSettingsView placeholder (full page lands in Phase 16)"
```

---

## Task 5: PaperTab

**Files:**
- Create: `WeeklyPlanner/Navigation/PaperTab.swift`

A single tab cell: icon over label, with a cream "paper bookmark" rectangle popping up from the top of the bar when active. The bookmark sits *behind* the icon+label in a `ZStack`, per the spec's z-order requirement.

- [ ] **Step 1: Implement PaperTab**

Create `WeeklyPlanner/Navigation/PaperTab.swift`:

```swift
import SwiftUI

/// One cell of the `PaperTabBar`. Layers a cream "index-tab" bookmark behind
/// the icon+label when active, so the active tab reads as a paper bookmark
/// poking out of the leather book.
///
/// Geometry, per spec:
/// - Cell padding `top: 8`, column spacing `3`.
/// - Icon `22pt`, label `10pt` system, weight `.bold` active / `.medium` inactive.
/// - Active ink/icon `theme.ink`; inactive `theme.chromeMuted`.
/// - Bookmark `52×26pt` cream rectangle, rounded `4pt` at the top corners,
///   centered horizontally, vertical offset `-8pt` so it extends above the
///   tab area. Lives at the bottom of the `ZStack` so the icon/label paint
///   on top.
struct PaperTab: View {
    let tab: Tab
    let isActive: Bool
    let action: () -> Void

    @Environment(\.paperTheme) private var theme

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .top) {
                bookmark
                    .opacity(isActive ? 1 : 0)
                    .animation(.easeInOut(duration: 0.18), value: isActive)

                VStack(spacing: 3) {
                    Image(systemName: iconName)
                        .font(.system(size: 22, weight: isActive ? .semibold : .regular))
                        .foregroundStyle(isActive ? theme.ink : theme.chromeMuted)
                    Text(label)
                        .font(.system(size: 10, weight: isActive ? .bold : .medium))
                        .tracking(0.1)
                        .foregroundStyle(isActive ? theme.ink : theme.chromeMuted)
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }

    private var bookmark: some View {
        UnevenRoundedRectangle(cornerRadii: .init(topLeading: 4,
                                                    bottomLeading: 0,
                                                    bottomTrailing: 0,
                                                    topTrailing: 4),
                                style: .continuous)
            .fill(theme.cream)
            .frame(width: 52, height: 26)
            .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: -1)
            .offset(y: -8)
    }

    private var iconName: String {
        switch tab {
        case .calendar: return "calendar"
        case .review: return "tray.fill"
        case .settings: return "gearshape.fill"
        }
    }

    private var label: String {
        switch tab {
        case .calendar: return "Calendar"
        case .review: return "Review"
        case .settings: return "Settings"
        }
    }
}

#Preview("PaperTab · active + inactive") {
    HStack(spacing: 0) {
        PaperTab(tab: .calendar, isActive: true, action: {})
        PaperTab(tab: .review, isActive: false, action: {})
        PaperTab(tab: .settings, isActive: false, action: {})
    }
    .padding(.vertical, 8)
    .background(PaperTheme.cream.bookCover)
    .paperTheme(.cream)
}
```

- [ ] **Step 2: Verify it compiles**

```bash
xcodegen generate
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -quiet build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Navigation/PaperTab.swift
git commit -m "feat(phase-15): PaperTab cell with cream bookmark + SF Symbol icons"
```

---

## Task 6: PaperTabBar

**Files:**
- Create: `WeeklyPlanner/Navigation/PaperTabBar.swift`

The leather-bound bar that hosts the three `PaperTab` cells. Owns the dashed "stitched seam" line near the top, the leather background, and the top-edge hairline divider.

- [ ] **Step 1: Implement PaperTabBar**

Create `WeeklyPlanner/Navigation/PaperTabBar.swift`:

```swift
import SwiftUI

/// Bottom tab bar that lives over the leather book cover. Three `PaperTab`
/// cells laid out evenly, with a 0.5pt dashed "stitched seam" line near the
/// top edge and a hairline divider above it. The bar provides its own
/// `theme.bookCover` background even though it sits over `AppShell`'s
/// persistent `BookCover` — explicit paint keeps the gradient aligned with
/// the chrome on every screen and lets future tab-bar background tweaks
/// (e.g. a brighter "active book" hue) land in one place.
struct PaperTabBar: View {
    @Binding var selection: Tab

    @Environment(\.paperTheme) private var theme

    var body: some View {
        ZStack(alignment: .top) {
            theme.bookCover

            stitchedSeam
                .padding(.horizontal, 18)
                .padding(.top, 4)

            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    PaperTab(tab: tab, isActive: selection == tab) {
                        selection = tab
                    }
                }
            }
        }
        .frame(height: 70)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 0.5)
        }
        .shadow(color: .black.opacity(0.4), radius: 14, x: 0, y: -2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("PaperTabBar")
    }

    /// Dashed stitched-seam line near the top. Renders as a path so the
    /// 0.5pt dashes stay crisp on 3× displays.
    private var stitchedSeam: some View {
        GeometryReader { proxy in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0.5))
                path.addLine(to: CGPoint(x: proxy.size.width, y: 0.5))
            }
            .stroke(Color.white.opacity(0.08),
                    style: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
        }
        .frame(height: 1)
    }
}

#Preview("PaperTabBar · cream") {
    PaperTabBarPreviewHost()
        .paperTheme(.cream)
}

#Preview("PaperTabBar · midnight") {
    PaperTabBarPreviewHost()
        .paperTheme(.midnight)
}

private struct PaperTabBarPreviewHost: View {
    @State private var tab: Tab = .calendar
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            PaperTabBar(selection: $tab)
        }
        .background(Color.black)
    }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
xcodegen generate
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -quiet build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Navigation/PaperTabBar.swift
git commit -m "feat(phase-15): PaperTabBar with stitched seam + leather chrome"
```

---

## Task 7: BookContainer.includesCover

**Files:**
- Modify: `WeeklyPlanner/Features/DayPage/BookContainer.swift`

`BookContainer` currently always renders `BookCover()` inside its top-level `ZStack`. The new `AppShell` (next task) wants a persistent `BookCover` at z=0, so the Calendar tab's `BookContainer` must be able to suppress its own internal cover. Add a non-breaking `includesCover: Bool = true` parameter.

- [ ] **Step 1: Add the parameter**

In `WeeklyPlanner/Features/DayPage/BookContainer.swift`, after the `content` ViewBuilder property and before `@Environment`:

```swift
    /// The page content rendered between the top bar and the bottom controls.
    /// Typically a `DayPageView` (or, after Group T, a `WeekPageView`).
    @ViewBuilder let content: () -> Content

    /// When `true` (default), the container paints its own `BookCover` at
    /// the bottom of the ZStack. `AppShell` passes `false` so the persistent
    /// shell-owned cover can show through and avoid remounting on tab switch.
    var includesCover: Bool = true

    @Environment(\.paperTheme) private var theme
```

Then update `var body` to gate the cover:

```swift
    var body: some View {
        ZStack(alignment: .top) {
            if includesCover {
                BookCover()
            }

            VStack(spacing: 0) {
                BookTopBar(weekMeta: weekMeta,
                           paperView: $paperView,
                           isOnTodayPage: isOnTodayPage,
                           isPickerOpen: isPickerOpen,
                           onOpenAI: onOpenAI,
                           onOpenPicker: onOpenPicker,
                           onJumpToday: onJumpToday,
                           onPrevWeek: onPrevWeek,
                           onNextWeek: onNextWeek)

                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                BookBottomControls(prevLabel: prevLabel,
                                   nextLabel: nextLabel,
                                   onPrev: onPrev,
                                   onNext: onNext)
            }
        }
    }
```

- [ ] **Step 2: Verify the existing suite still passes**

```bash
xcodegen generate
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 \
  | grep -E "TEST FAILED|TEST SUCCEEDED|Executed [0-9]+ tests" | tail -3
```

Expected: 188 + 6 (new from Task 2/3) = 194 tests, all green. The `includesCover` defaulting to `true` keeps every existing call site working unchanged.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Features/DayPage/BookContainer.swift
git commit -m "feat(phase-15): BookContainer.includesCover lets AppShell own the cover"
```

---

## Task 8: AppShell

**Files:**
- Create: `WeeklyPlanner/Navigation/AppShell.swift`

The new root composition. Owns the persistent `BookCover`, the `TabSelection`, the per-tab content routing, the `PaperTabBar` via `.safeAreaInset`, and the modal overlays (lifted from `RootView`). This is the largest task — the prior `RootView` body migrates here.

Note: `WeekPickerSheet` and `PaperAISearchView` move into `AppShell`. The `PageFlipController` (Day/Week controller), `paperView` (Day vs Week within the Calendar tab), and the four open-flag `@State`s also move here. `RootView` (next task) becomes a thin wrapper that just supplies environment stores and hosts `AppShell`.

- [ ] **Step 1: Implement AppShell**

Create `WeeklyPlanner/Navigation/AppShell.swift`:

```swift
import SwiftUI
import SwiftData

/// Root composition for the paper app. Sits above `RootView` (which only
/// hosts the environment values) and below every page. Owns:
///
/// - `TabSelection` — which of Calendar / Review / Settings is active.
/// - `PageFlipController` + `paperView` — the Day-vs-Week state shared
///   inside the Calendar tab (lifted from `RootView` so a tab switch
///   doesn't reset the Day page's focused day or week offset).
/// - Modal-overlay flags — `isPickerOpen`, `isAISearchOpen` — also lifted
///   from `RootView` so the overlays render above both the active tab's
///   content and the bottom tab bar.
///
/// Renders a persistent `BookCover` at z=0 so tab switches cross-fade the
/// inside-the-book content without re-mounting the leather. The active tab
/// content layers on top with a 0.18s opacity transition; the
/// `PaperTabBar` pins to the bottom via `.safeAreaInset(edge: .bottom)`
/// so the active tab can use the full inner area and modal overlays float
/// above both layers.
struct AppShell: View {
    @Environment(\.eventStore) private var eventStore
    @Environment(\.taskStore) private var taskStore
    @Environment(\.inboxStore) private var inboxStore
    @Environment(\.settingsStore) private var settingsStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selection: TabSelection
    @State private var controller: PageFlipController
    @State private var paperView: PaperView = .day
    @State private var isPickerOpen: Bool = false
    @State private var isAISearchOpen: Bool = false

    init(settingsStore: any SettingsStore) {
        let today = Date()
        let days = WeekMath.weekDays(forOffset: 0, today: today)
        let todayIdx = WeekMath.todayIndex(in: days, for: today) ?? 0
        _controller = State(initialValue: PageFlipController(current: PageCoordinate(week: 0,
                                                                                     day: todayIdx)))
        _selection = State(initialValue: TabSelection(settings: settingsStore))
    }

    var body: some View {
        ZStack {
            BookCover()

            Group {
                switch selection.current {
                case .calendar:
                    calendarTab
                case .review:
                    PaperReviewView(weekOffset: controller.current.week)
                case .settings:
                    PaperSettingsView()
                }
            }
            .transition(.opacity)
            .animation(reduceMotion ? .linear(duration: 0) : .easeInOut(duration: 0.18),
                       value: selection.current)

            WeekPickerSheet(isOpen: $isPickerOpen,
                            initialWeekOffset: controller.current.week)
            { offset in
                controller.setWeek(offset)
                isPickerOpen = false
            }

            if isAISearchOpen {
                PaperAISearchView(isOpen: $isAISearchOpen,
                                  eventStore: eventStore,
                                  intelligence: makeIntelligenceService(),
                                  onTapCitation: { _ in
                                      // Phase 12 closes the overlay; routing the
                                      // citation tap to the matching event detail
                                      // sheet stays out of scope until the shared
                                      // event-detail router lands.
                                  })
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PaperTabBar(selection: Binding(
                get: { selection.current },
                set: { selection.current = $0 }
            ))
        }
        .animation(reduceMotion ? .linear(duration: 0) : AnimationTokens.sheetSlide,
                   value: isAISearchOpen)
        .environment(\.intelligenceService, makeIntelligenceService())
    }

    @ViewBuilder
    private var calendarTab: some View {
        let today = Date()
        let currentWeek = controller.current.week
        let weekMeta = WeekMath.weekMeta(forOffset: currentWeek, today: today)
        let isCurrentWeek = currentWeek == 0
        let currentWeekDays = WeekMath.weekDays(forOffset: 0, today: today)
        let todayIdx = WeekMath.todayIndex(in: currentWeekDays, for: today)
        let isOnTodayPage = isCurrentWeek && controller.current.day == todayIdx

        BookContainer(paperView: $paperView,
                      weekMeta: weekMeta,
                      isOnTodayPage: isOnTodayPage,
                      isPickerOpen: isPickerOpen,
                      onOpenAI: { isAISearchOpen = true },
                      onOpenPicker: { isPickerOpen.toggle() },
                      onJumpToday: {
                          if let idx = todayIdx {
                              controller.setWeek(0)
                              controller.flipToDay(idx: idx)
                          }
                      },
                      onPrevWeek: {
                          if paperView == .day {
                              controller.setWeek(controller.current.week - 1)
                          } else {
                              controller.flipWeek(direction: .prev)
                          }
                      },
                      onNextWeek: {
                          if paperView == .day {
                              controller.setWeek(controller.current.week + 1)
                          } else {
                              controller.flipWeek(direction: .next)
                          }
                      },
                      onPrevDay: { controller.flipDay(direction: .prev) },
                      onNextDay: { controller.flipDay(direction: .next) },
                      content: {
                          switch paperView {
                          case .day:
                              DayPageView(controller: controller)
                          case .week:
                              WeekPageView(weekOffset: controller.current.week)
                          }
                      },
                      includesCover: false)
    }

    private func makeIntelligenceService() -> any IntelligenceService {
        let registry = ToolRegistry(events: eventStore, tasks: taskStore, inbox: inboxStore)
        let fallback = StubIntelligenceService(eventStore: eventStore)
        return PlannerLanguageModel(registry: registry, fallback: fallback)
    }
}
```

- [ ] **Step 2: Verify the file compiles**

`AppShell` references `settingsStore` from the environment. Confirm that key already exists by grepping:

```bash
grep -n "settingsStore" WeeklyPlanner/Stores/Environment+Stores.swift
```

Expected: at least one match — the env key + key path. If the key does not exist, add it in the next step (see Step 2a). Otherwise skip Step 2a.

- [ ] **Step 2a (conditional): Add settingsStore env key if missing**

Open `WeeklyPlanner/Stores/Environment+Stores.swift` and append, following the same pattern as `eventStore` / `taskStore`:

```swift
private struct SettingsStoreKey: EnvironmentKey {
    static let defaultValue: any SettingsStore = StubSettingsStore()
}

extension EnvironmentValues {
    var settingsStore: any SettingsStore {
        get { self[SettingsStoreKey.self] }
        set { self[SettingsStoreKey.self] = newValue }
    }
}
```

If a matching `StubSettingsStore` does not exist, add one alongside the file:

```swift
struct StubSettingsStore: SettingsStore {
    func current() throws -> UserSettings { UserSettings() }
    func update(_ apply: (UserSettings) -> Void) throws { apply(UserSettings()) }
}
```

(Match the existing stub-store naming/style in the same file.)

- [ ] **Step 3: Verify it builds**

```bash
xcodegen generate
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -quiet build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`. `AppShell` is not yet referenced from `RootView`, so it builds standalone.

- [ ] **Step 4: Commit**

```bash
git add WeeklyPlanner/Navigation/AppShell.swift \
        WeeklyPlanner/Stores/Environment+Stores.swift   # only if Step 2a edited it
git commit -m "feat(phase-15): AppShell root with persistent BookCover + safeAreaInset tab bar"
```

---

## Task 9: Wire AppShell into RootView

**Files:**
- Modify: `WeeklyPlanner/App/RootView.swift`

`RootView` shrinks down to an environment-injecting shell. Almost all of its prior body has migrated into `AppShell`.

- [ ] **Step 1: Replace RootView body**

Replace the entire contents of `WeeklyPlanner/App/RootView.swift` with:

```swift
import SwiftUI

/// The root scene the user lands on when the app launches. In Phase 15 this
/// view's job is intentionally tiny: read the environment-injected
/// `SettingsStore` and hand it to `AppShell`, which owns every piece of
/// nav state (tab selection, day/week controller, modal-overlay flags).
///
/// All of the prior in-line composition — `BookContainer` wiring, modal
/// overlays, intelligence-service construction — now lives in `AppShell`.
struct RootView: View {
    @Environment(\.settingsStore) private var settingsStore

    var body: some View {
        AppShell(settingsStore: settingsStore)
    }
}

#Preview {
    RootView()
        .environment(\.eventStore, StubEventStore())
        .environment(\.inboxStore, StubInboxStore())
        .environment(\.taskStore, StubTaskStore())
}
```

- [ ] **Step 2: Verify the suite passes**

```bash
xcodegen generate
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 \
  | grep -E "TEST FAILED|TEST SUCCEEDED|Executed [0-9]+ tests" | tail -3
```

Expected: still 194 tests green (no test was added in Task 9). If a `RootViewTests` file exists, it must still pass — the public surface (a `View` body that produces some view) is preserved.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/App/RootView.swift
git commit -m "feat(phase-15): RootView delegates to AppShell"
```

---

## Task 10: Revert PaperView + DayWeekToggle to 2-segment

**Files:**
- Modify: `WeeklyPlanner/Models/AppStyle.swift`
- Modify: `WeeklyPlanner/Features/DayPage/DayWeekToggle.swift`

Phase 14's temporary `.review` segment on the top-bar toggle is no longer needed — the tab bar now owns top-level routing. Remove the `.review` enum case and revert `DayWeekToggle` to the two-segment Day/Week it was before Phase 14 Task 11.

- [ ] **Step 1: Remove `.review` from PaperView**

In `WeeklyPlanner/Models/AppStyle.swift`:

```swift
/// Which day-spread the user is on inside `.paper` style.
enum PaperView: String, CaseIterable, Hashable, Codable {
    case day
    case week
}
```

- [ ] **Step 2: Revert DayWeekToggle**

In `WeeklyPlanner/Features/DayPage/DayWeekToggle.swift`, replace the segment HStack and the `.accessibilityValue` modifier:

```swift
        HStack(spacing: 2) {
            segment(for: .day, label: "Day")
            segment(for: .week, label: "Week")
        }
        .padding(2)
        .background(Color.black.opacity(0.3),
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("View")
        .accessibilityValue(selection == .day ? "Day" : "Week")
        .accessibilityAddTraits(.isButton)
```

- [ ] **Step 3: Verify the suite passes**

```bash
xcodegen generate
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 \
  | grep -E "TEST FAILED|TEST SUCCEEDED|Executed [0-9]+ tests" | tail -3
```

Expected: 194 tests, all green. The `case .review` switch arm in `AppShell.calendarTab` is gone (the `switch paperView` there now has only `.day` and `.week`), and `PaperReviewView` is reached only through `selection.current == .review` in `AppShell.body`. If the build flags any unreachable-switch or missing-arm warnings, fix them in place.

- [ ] **Step 4: Commit**

```bash
git add WeeklyPlanner/Models/AppStyle.swift \
        WeeklyPlanner/Features/DayPage/DayWeekToggle.swift
git commit -m "chore(phase-15): drop .review from PaperView — tab bar owns top-level routing"
```

---

## Task 11: Smoke-test in simulator + take verification screenshots

**Files:** none

- [ ] **Step 1: Build, install, launch**

```bash
cd /Users/nguyen-mini/Documents/dev/ios-weekly-planner-phase-13
xcodebuild -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug build 2>&1 | tail -3
xcrun simctl uninstall booted com.weeklyplanner.WeeklyPlanner
xcrun simctl install booted \
  "/Users/nguyen-mini/Library/Developer/Xcode/DerivedData/WeeklyPlanner-fkoavahbglmonqhezkuvhiynjwcq/Build/Products/Debug-iphonesimulator/WeeklyPlanner.app"
xcrun simctl launch booted com.weeklyplanner.WeeklyPlanner
```

Expected: `** BUILD SUCCEEDED **`, then a launched PID.

- [ ] **Step 2: Screenshot the launch state (Calendar tab)**

```bash
sleep 2
xcrun simctl io booted screenshot /tmp/phase-15-launch-calendar.png
```

Open the screenshot. Confirm:
- A leather tab bar pinned to the bottom of the screen.
- Three tabs: Calendar (active, cream bookmark sticking up), Review (icon `tray.fill`, muted), Settings (icon `gearshape.fill`, muted).
- The dashed stitched-seam line near the top edge of the bar.
- The Day/Week toggle at the top now has **only two segments** (Day, Week) — the temporary Review segment is gone.
- Day page content still renders correctly under the new bar (the `.safeAreaInset` keeps it from being clipped).

- [ ] **Step 3: Tap Review tab + screenshot**

The user taps Review in the tab bar. Expect a 0.18s cross-fade from the Day page to `PaperReviewView`. The bookmark cross-fades from under Calendar to under Review.

```bash
xcrun simctl io booted screenshot /tmp/phase-15-launch-review.png
```

- [ ] **Step 4: Tap Settings tab + screenshot**

The user taps Settings. Expect another 0.18s cross-fade to `PaperSettingsView` (centered "Settings" handwriting + Cochin italic sub-line).

```bash
xcrun simctl io booted screenshot /tmp/phase-15-launch-settings.png
```

No commit — these are verification-only screenshots.

---

## Task 12: Phase 15 retrospective

**Files:**
- Modify: `docs/phases/README.md`

- [ ] **Step 1: Append a Phase 15 retrospective**

Add the following block after the existing Phase 14 section in `docs/phases/README.md`:

```markdown
### Phase 15 — Paper Tab Bar & Navigation Wiring

Shipped the leather-bound bottom tab bar: `PaperTabBar` hosts three `PaperTab` cells (Calendar / Review / Settings) with the cream "index-tab" bookmark popping up behind the active tab, the dashed stitched-seam line near the top edge, and the leather `theme.bookCover` background. `AppShell` is the new root composition — it owns the persistent `BookCover` at z=0 so tab switches cross-fade the inside-the-book content (0.18s) without remounting the cover. Tab selection is held by `TabSelection` (`@Observable`) and persists across launches via the new `UserSettings.lastTabRaw` field.

The temporary three-segment Day/Week/Review toggle from Phase 14 is gone: `PaperView` reverts to two cases (`.day`, `.week`), `DayWeekToggle` is back to two segments, and the Review screen is reachable only through the tab bar. The Calendar tab's `BookContainer` now gets `includesCover: false` so the shell-owned cover shows through.

`PaperSettingsView` ships as a centered placeholder ("Theme, font, and connections arrive in Phase 16.") — Phase 16 builds the real settings page. Modal overlays (`WeekPickerSheet`, `PaperAISearchView`) migrated from `RootView` into `AppShell` so they continue to layer above both the active tab and the new bar.

**Tests added**: 2 classes / 6 new test methods (`UserSettingsLastTabTests`, `TabSelectionTests`). Full suite: 194 unit tests + UI tests, all green.

**Files**: `WeeklyPlanner/Navigation/{TabSelection,PaperTab,PaperTabBar,AppShell}.swift`, `WeeklyPlanner/Features/Settings/PaperSettingsView.swift`; modified `WeeklyPlanner/Models/{AppStyle,UserSettings}.swift`, `WeeklyPlanner/Features/DayPage/{BookContainer,DayWeekToggle}.swift`, `WeeklyPlanner/App/RootView.swift`.
```

- [ ] **Step 2: Commit**

```bash
git add docs/phases/README.md
git commit -m "docs(phase-15): retrospective for paper tab bar + AppShell"
```

- [ ] **Step 3: Final state check**

```bash
git log --oneline main..HEAD
git status --short
```

Expected: a clean working tree, ~10 commits on `milestone-f-other-screens` for Phase 15 (Tasks 2–10 + retro = 10 commits, not counting Task 1 which is sync-only).

---

## Self-Review

**1. Spec coverage:**
- `PaperTabBar` visual checklist (leather bg, stitched seam, top hairline, 70pt height, `bookCover`, dashed seam path) — Task 6.
- `PaperTab` checklist (icon+label, active vs inactive ink, cream bookmark 52×26 at `-8pt` offset, z-order behind icon+label, accessibility) — Task 5.
- Tab list (Calendar, Review, Settings with SF Symbol icons) — Task 5.
- 0.18s cross-fade between tabs — Task 8 (`.transition(.opacity)` + `.animation(.easeInOut(duration: 0.18))`).
- BookCover persistence across tab switches — Task 8 (Cover lifted to AppShell, BookContainer gets `includesCover: false` via Task 7).
- TabSelection enum + @Observable + persistence — Task 3, with the UserSettings field added in Task 2.
- Embedded Settings (not modal) preserving Day state — Task 8 (`PageFlipController` lives on AppShell, survives tab switches).
- Safe-area inset for tab bar — Task 8 (`.safeAreaInset(edge: .bottom)`).
- Modal overlays above tab bar — Task 8 (overlays sit in the AppShell ZStack above the safe-area inset's content).
- Remove temporary Day/Week/Review toggle — Task 10.
- Snapshot tests — explicitly skipped (no snapshot framework in repo, same precedent as Phase 14). `TabSelectionTests` covers the persistence logic that the snapshots would only verify visually.
- Settings tab "return to previous tab" via Done — out of scope for Phase 15. Phase 16 wires a per-sub-screen back affordance; the spec calls this out as a Phase-16 concern.

**2. Placeholder scan:** no TBD / TODO / "implement later" left. The Step 2a conditional in Task 8 is gated by an actual grep check, not a placeholder; if the environment key already exists, the step is a no-op.

**3. Type consistency:** `Tab` (Task 3) is the same enum referenced in `PaperTab` (Task 5), `PaperTabBar` (Task 6), and `AppShell` (Task 8). `SettingsStore` protocol is referenced in `TabSelection.init(settings:)` (Task 3) and via `@Environment(\.settingsStore)` in `AppShell.init(settingsStore:)` (Task 8) — both use `any SettingsStore`. `includesCover: Bool = true` defaults make the Task 7 change non-breaking for non-AppShell call sites. `PaperView` (Task 10) loses `.review` consistently in both `AppStyle.swift` and the `switch paperView` arm inside `AppShell.calendarTab` (already restricted to `.day`/`.week` in Task 8's code).
