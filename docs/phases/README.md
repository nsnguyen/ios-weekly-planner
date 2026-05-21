# iOS Weekly Planner — Phased Implementation Plan

> **Source of truth for visuals:** `docs/mock/` — pixel-perfect HTML/React prototype. Every phase must match it exactly.

## Product Summary

A weekly planner iOS app with a **paper-planner aesthetic** (leather book cover, cream pages, hole punches, handwritten ink, AI sticky notes, page-flip animations) layered on a modern production feature set:

- **EventKit** for calendar storage (events persist as real iOS calendar events).
- **Foundation Models** for on-device Apple Intelligence (RAG search, summaries, suggestions).
- **Gmail API + OAuth** for inbox-sourced event suggestions.
- **UserNotifications + Core Location** for time-based and location-based reminders.
- **3 themes × 4 handwriting fonts × 3 text sizes** — live-switchable.
- **Modern mode** fallback (stock iOS look) toggleable in Settings.

## Target Configuration

- **Platform:** iPhone (portrait only), iOS **26.0+**.
- **Language:** Swift 6, SwiftUI (no UIKit shells, no WebViews).
- **Persistence:** SwiftData (local app state) + EventKit (calendar events) + Keychain (OAuth tokens).
- **AI:** `FoundationModels` framework (on-device, private).
- **Build:** Xcode 17+, SPM dependencies only.
- **Distribution:** App Store (TestFlight first).

## Methodology

- **TDD throughout** — every phase ends with green tests (unit + UI where applicable).
- **One phase = one mergeable milestone.** Each phase produces a runnable app.
- **Pixel-perfect** — phase acceptance requires side-by-side compare with the HTML prototype.
- **No mocks shipped to prod** — when a phase says "Foundation Models," it means the real framework.

## Phase Map

| #  | Phase                                                | Milestone           | Status |
|----|------------------------------------------------------|---------------------|--------|
| 01 | Project Bootstrap & Tooling                          | A — Foundation      | ✅     |
| 02 | Design System (Theme, Fonts, Tokens)                 | A                   | ✅     |
| 03 | Data Models & SwiftData Persistence                  | A                   | ✅     |
| 04 | EventKit & Calendar Integration                      | A                   | ✅     |
| 05 | Paper Primitives & Book Chrome                       | B — Day Page        | ✅     |
| 06 | Paper Day Page (Static Layout + Events + Inbox)      | B                   | ✅     |
| 07 | Day Page To-Do Block & AI Sticky Note                | B                   | ✅     |
| 08 | Side Tabs & Page-Flip System                         | B                   | ✅     |
| 09 | Top Bar & Week Picker                                | C — Week Nav        | ✅     |
| 10 | Paper Week Page                                      | C                   | ✅     |
| 11 | Paper Event Detail Sheet                             | D — Sheets          | ✅     |
| 12 | Paper AI Search Overlay (UI)                         | D                   | ✅     |
| 13 | Foundation Models (Apple Intelligence) Integration   | E — Intelligence    | ✅     |
| 14 | Paper Review Page                                    | F — Other Screens   | ✅     |
| 15 | Paper Tab Bar & Navigation Wiring                    | F                   | ✅     |
| 16 | Settings — Theme, Handwriting, Size, Preferences     | G — Settings        | ✅     |
| 17 | Settings — Connections (Gmail OAuth, Google, Apple)  | G                   | ✅     |
| 18 | Gmail Inbox Pipeline & Event Suggestions             | H — Integrations    | ⏳     |
| 19 | Notifications (Time + Location Reminders)            | H                   | ⏳     |
| 20 | Modern Mode (Alternative Stock-iOS Theme)            | I — Polish          | ⏳     |
| 21 | Accessibility, Dynamic Type, Localization, RTL       | I                   | ⏳     |
| 22 | Final Polish, App Icon, Launch Screen, Privacy       | J — Ship            | ⏳     |
| 23 | App Store Submission & TestFlight                    | J                   | ⏳     |

**Current state:** Milestones A–F + Phases 16, 17 shipped. 234 unit
tests green. Next up: Phase 18 — Gmail Inbox Pipeline.

## Reading a Phase Doc

Every phase doc follows the same shape:

1. **Goal** — one sentence outcome.
2. **Prerequisites** — phases that must be complete first.
3. **Files** — exact paths created or modified.
4. **Visual & Interaction Checklist** — every element/behavior listed, copied from the mock. **This is where you "double-check."**
5. **Logic & Data Checklist** — non-visual behavior.
6. **Tests (TDD)** — what to write before the implementation.
7. **Acceptance Criteria** — definition of done.
8. **Out of Scope** — what's deferred.
9. **Risks & Notes**.

## How to Use This Plan

- Read this README + every phase doc top-to-bottom once. Confirm the feature list.
- Before starting Phase N, re-read its doc and `docs/mock/<related file>.jsx` side-by-side.
- Each phase doc is the **scope contract** — when execution begins, a task-level plan (with code) is written using `superpowers:writing-plans`.
- Mark a phase complete only when its acceptance criteria pass AND tests are green AND the screenshot diff vs. the mock is approved.

## File Layout (target)

```
ios-weekly-planner/
├── WeeklyPlanner.xcodeproj
├── WeeklyPlanner/
│   ├── App/                  # @main, root container
│   ├── DesignSystem/         # PaperTheme, fonts, tokens, primitives
│   ├── Models/               # Event, Task, InboxSuggestion, AIInsight, Settings
│   ├── Stores/               # SwiftData, EventKit, Gmail, Notifications, Settings
│   ├── Intelligence/         # Foundation Models RAG, tool definitions, prompts
│   ├── Features/
│   │   ├── DayPage/
│   │   ├── WeekPage/
│   │   ├── WeekPicker/
│   │   ├── EventDetail/
│   │   ├── AISearch/
│   │   ├── Review/
│   │   ├── Settings/
│   │   └── ModernMode/       # optional alt theme
│   ├── Navigation/           # TabBar, page-flip controller
│   ├── Resources/
│   │   ├── Fonts/            # Caveat, Architects Daughter, Kalam, Indie Flower
│   │   ├── Localizable.xcstrings
│   │   └── Assets.xcassets
│   └── Supporting/           # Info.plist, entitlements, PrivacyInfo.xcprivacy
├── WeeklyPlannerTests/       # XCTest unit
├── WeeklyPlannerUITests/     # XCUITest
└── docs/
    ├── mock/                 # HTML reference (do not edit)
    └── phases/               # ← you are here
```

## Glossary

- **Paper mode** — primary theme: leather book + cream pages + ink + sticky notes.
- **Modern mode** — fallback: stock iOS look with SF Pro and system colors. Toggleable.
- **PAPER** — the runtime theme object (Swift `PaperTheme` struct), injected via `@Environment`.
- **Ink color** — the per-category handwritten-pen color used for event titles.
- **Page-flip** — 3D `rotation3DEffect` transition with shading, used between days.
- **Hobonichi** — Japanese planner format with 7 day-rows on one page; our Week page.
- **Foundation Models** — Apple's on-device LLM framework (iOS 26+).

## Retrospectives

### Phase 13-a — Foundation Models Integration (Core Layer)

Shipped the `WeeklyPlanner/Intelligence/` module: `IntelligenceService` protocol, `PlannerLanguageModel` bridge (iOS 26+ Foundation Models, gated `#if canImport(FoundationModels)` + `@available(iOS 26.0, *)`), `StubIntelligenceService` (reused as the test double *and* the runtime fallback), five tools (FindEvents / FindFreeSlots / ScanInbox / SummarizeWeek / LastInteraction) wired to existing store protocols, `SystemPrompt`, `SafetyGuard`, and `Availability` probe. Added `events(matching: EventQuery)` to `EventStoring` with conformance on all four implementations (SwiftData, EventKit mirror, environment stub, preview-seeded stub).

`AISearchViewModel` now talks to `IntelligenceService` instead of the canned table directly. When the model is unavailable — older device, Apple Intelligence off in Settings, or the planner's own AI toggle off — the overlay still shows the same canned answers via the stub, plus a `unavailableReason.fallbackMessage` the view can render in the footer. `PaperLanguageModel` is constructed inline at AI-overlay open time inside `RootView.makeIntelligenceService()`; no global singleton.

**Deferred to Phase 13-b**: `StickyInsightGenerator`, `WeekSummaryGenerator`, `EventSuggestionGenerator`, and token-level streaming. WeekSummary blocks on Phase 14 (Review page). Sticky and EventSuggestion generators want a background-task scheduler that fits more naturally with Phase 19. Streaming wants on-device validation before we ship the typewriter UX.

**Tests added**: 11 XCTest classes / 31 new test methods under `WeeklyPlannerTests/Intelligence/` and one new fallback-path test in `AISearchViewModelTests`. Full suite: 167 unit tests + SmokeUITests, all green.

**Files**: `WeeklyPlanner/Intelligence/{Availability,IntelligenceService,PlannerContext,PlannerLanguageModel,SafetyGuard,StubIntelligenceService,SystemPrompt}.swift`, `WeeklyPlanner/Intelligence/Tools/{EventQuery,FindEventsTool,FindFreeSlotsTool,LastInteractionTool,ScanInboxTool,SummarizeWeekTool,ToolEventResult,ToolRegistry}.swift`; modified `WeeklyPlanner/Features/AISearch/{AISearchViewModel,PaperAISearchView}.swift`, `WeeklyPlanner/App/RootView.swift`, `WeeklyPlanner/Stores/{Environment+Stores,EventStore,EventStore+EventKit}.swift`, `WeeklyPlanner/Features/EventDetail/PaperEventSheet.swift`.

### Phase 14 — Paper Review Page

Shipped the end-of-week reflection surface: `PaperReviewView` composes `ReviewHeader` (rotated -3° completion %), `ReviewSummaryBlock` (AI SUMMARY eyebrow + blue-ink paragraph), `TimeSpentBarChart` with `CategoryTimeRow`s (dotted baseline + proportional fills), `AINotesList` with colored ★ bullets, and `StreaksBlock` with a 7-day pill row. `ReviewViewModel` aggregates per-week hours by category, tasks done/total, and `completionPercent` from the existing stores.

Closed the Phase 13-b WeekSummary deferral: `WeekSummary` value type + `WeekSummaryGenerator` (with the canned `fallback(weekOffset:tasksDone:tasksTotal:)` factory) now power the AI SUMMARY block. The Review page falls back gracefully when Apple Intelligence is off.

Navigation entry is a temporary three-segment Day/Week/Review extension to `DayWeekToggle`. Phase 15 will replace it with a proper tab bar.

Streak data is hardcoded to a single "Morning run" row per spec v1.0. A real `StreakStore` arrives with user-defined habits in a later phase.

**Tests added**: 3 classes / 8 new test methods. Full suite: 188 unit tests + UI tests, all green.

**Files**: `WeeklyPlanner/Intelligence/WeekSummary.swift`, `WeeklyPlanner/Intelligence/Tasks/WeekSummaryGenerator.swift`, `WeeklyPlanner/Features/Review/{PaperReviewView,ReviewHeader,ReviewSummaryBlock,CategoryTimeRow,TimeSpentBarChart,AINotesList,StreaksBlock,ReviewViewModel}.swift`; modified `WeeklyPlanner/Models/AppStyle.swift`, `WeeklyPlanner/Features/DayPage/DayWeekToggle.swift`, `WeeklyPlanner/App/RootView.swift`.

### Phase 15 — Paper Tab Bar & Navigation Wiring

Shipped the leather-bound bottom tab bar: `PaperTabBar` hosts three `PaperTab` cells (Calendar / Review / Settings) with the cream "index-tab" bookmark popping up behind the active tab, the dashed stitched-seam line near the top edge, and the leather `theme.bookCover` background. `AppShell` is the new root composition — it owns the persistent `BookCover` at z=0 so tab switches cross-fade the inside-the-book content (0.18s) without remounting the cover. Tab selection is held by `TabSelection` (`@Observable`) and persists across launches via the new `UserSettings.lastTabRaw` field, wired through `SettingsStoring`.

The temporary three-segment Day/Week/Review toggle from Phase 14 is gone: `PaperView` reverts to two cases (`.day`, `.week`), `DayWeekToggle` is back to two segments, and the Review screen is reachable only through the tab bar. The Calendar tab's `BookContainer` now gets `includesCover: false` so the shell-owned cover shows through.

`PaperSettingsView` ships as a centered placeholder ("Theme, font, and connections arrive in Phase 16.") — Phase 16 builds the real settings page. Modal overlays (`WeekPickerSheet`, `PaperAISearchView`) migrated from `RootView` into `AppShell` so they continue to layer above both the active tab and the new bar. A `StubSettingsStore` joined the existing store stubs in `Environment+Stores.swift` so previews/tests that read `\.settingsStore` never crash.

**Tests added**: 2 classes / 6 new test methods (`UserSettingsLastTabTests`, `TabSelectionTests`). Full suite: 194 unit tests + UI tests, all green.

**Files**: `WeeklyPlanner/Navigation/{TabSelection,PaperTab,PaperTabBar,AppShell}.swift`, `WeeklyPlanner/Features/Settings/PaperSettingsView.swift`; modified `WeeklyPlanner/Models/{AppStyle,UserSettings}.swift`, `WeeklyPlanner/Features/DayPage/{BookContainer,DayWeekToggle}.swift`, `WeeklyPlanner/App/RootView.swift`, `WeeklyPlanner/Stores/Environment+Stores.swift`.

### Phase 16 — Settings (Theme, Handwriting, Size, Preferences)

Shipped the embedded Settings page: a `BookPage` + `PaperSurface` paper page on top of the persistent leather cover, hosting a `SettingsHeader` ("Make it yours" + Cochin italic sub-line + gradient rule), then five sections — `ThemeCardsGrid` (cream / kraft / midnight), `FontCardsGrid` (caveat / architects / kalam / indie), `SizeSegmented` (S / M / L with live handwriting preview), `ConnectionsPlaceholder` (Phase 17 fills it), and `PreferencesGroup` (Week-starts-on / Default-reminder / Apple Intelligence) — closing with the centered italic `AboutFooter`. `SettingsViewModel` reads on init from `SettingsStoring.current()` and writes through `SettingsStoring.update`, so every selection persists.

Closed two Phase 15 gaps along the way: `WeeklyPlannerApp` now injects a production `SwiftDataSettingsStore` (it was falling through to `StubSettingsStore`, so tab selection wasn't actually surviving relaunches), and `AppShell` now reads the persisted row via `@Query` and re-injects `\.paperTheme` / `\.paperFont` / `\.paperSize` at the top of `body`. The whole app re-renders on every settings write — book cover, page chrome, ink, and handwriting all flip live. Verified end-to-end in the simulator: flipping `themeKey`/`fontKey`/`sizeKey` in the SwiftData store immediately changed every paper view on next launch (screenshot at `docs/phases/phase-16-settings.png`).

Snapshot tests are deferred to Phase 21 (we have no `swift-snapshot-testing` dep). `PaperSettingsViewTests` instead asserts structural invariants — 3 themes / 4 fonts / 3 sizes / 5 reminder options / 2 week-start choices — and the visual diff is performed manually against `docs/mock/paper-settings.jsx`.

**Tests added**: 2 classes / 13 new test methods (`SettingsViewModelTests` × 7, `PaperSettingsViewTests` × 6). Full suite: 211 unit tests + UI tests, all green.

**Files**: `WeeklyPlanner/Features/Settings/{SettingsViewModel,SettingsHeader,SectionTitle,ThemeCardsGrid,ThemeCard,FontCardsGrid,FontCard,SizeSegmented,ConnectionsPlaceholder,PreferencesGroup,PrefRow,ToggleRow,AboutFooter}.swift`; modified `WeeklyPlanner/Features/Settings/PaperSettingsView.swift`, `WeeklyPlanner/App/WeeklyPlannerApp.swift`, `WeeklyPlanner/Navigation/AppShell.swift`.

### Phase 17 — Settings (Connections)

Shipped the real Connections card: `ConnectionsSection` replaces the
Phase 16 placeholder via a one-line `ConnectionsPlaceholder` shim, so
`PaperSettingsView` doesn't churn. Three rows — Gmail (interactive),
Apple Mail (read-only, mirrors `MFMailComposeViewController.canSendMail()`),
Google Calendar ("Coming soon", disabled) — inside the cream card with
0.5pt dividers. Each row hosts its own brand mark: hand-rolled SwiftUI
Canvas for the Gmail "M", `Image(systemName: "apple.logo")` for Apple,
and a stylized "31" tile for Google Calendar.

The auth foundation is the bigger piece: `GoogleAuthService` protocol +
`LiveGoogleAuthService` composes `GoogleAuthConfig` (reads
`GoogleClientID` from Info.plist), a thin `GIDSigningClient` SDK seam
(`RealGIDSigningClient` in production, `FakeGIDSigningClient` for the
seven-test `GoogleAuthServiceTests` suite), and a generic
`TokenKeychainStore<GoogleAccountInfo>` wrapping `KeychainAccess`. The
SDK seam returns our own `GoogleAccountInfo` rather than `GIDGoogleUser`,
keeping Google SDK types out of every test boundary.

`RealGIDSigningClient` bridges GoogleSignIn-iOS 7.1.0's callback-based
APIs to Swift `async/await` via `withCheckedThrowingContinuation` (the
SDK at that version doesn't expose async overloads), extracting all
`Sendable` token fields inside the callback so the non-`Sendable`
`GIDGoogleUser` never crosses an isolation boundary. Cancel detection
uses the documented `kGIDSignInErrorDomain` + `-5` (kGIDSignInErrorCodeCanceled);
nil `expirationDate` falls back to `.distantPast` so a missing-expiry
SDK response forces a proactive refresh rather than trusting a fabricated
future timestamp.

Tokens auto-refresh when `<5min` remain via the cached refresh token.

Secret plumbing lives in a gitignored `Secrets.xcconfig` whose
`GOOGLE_CLIENT_ID` and `REVERSED_GOOGLE_CLIENT_ID` flow through XcodeGen
`configFiles` and `INFOPLIST_KEY_GoogleClientID` into the bundled
Info.plist (replacing the Phase 01 `PLACEHOLDER` URL scheme). A
committed `Secrets.example.xcconfig` documents the contract; missing
secrets surface as `GoogleAuthError.notConfigured` → in-app "Gmail
isn't configured…" alert rather than a crash. The Info.plist source
file also declares `<key>GoogleClientID</key><string>$(GOOGLE_CLIENT_ID)</string>`
explicitly — Xcode's `INFOPLIST_KEY_` build setting fills in an existing
key but does not add a missing one.

`ConnectionsViewModel` (`@Observable`) owns the connect/disconnect
choreography: optimistic toggle → `auth.signIn` → persist + broadcast
`Notification.Name.gmailDidConnect` (Phase 18 will listen). On cancel:
silent revert. On network/notConfigured: revert + alert. On disconnect:
confirmation dialog → `signOut` + Keychain clear + `inboxStore.clearPending()`
so re-connect doesn't resurrect stale `InboxSuggestion` rows. Six
view-model tests cover the four connect paths and two disconnect paths.

The `.onOpenURL` handler in `WeeklyPlannerApp` hands incoming OAuth
callback URLs to `GIDSignIn.sharedInstance.handle(_:)`.

Verified end-to-end on simulator with a real Google account
(`nsnguyen19@gmail.com`): tap toggle → ASWebAuthenticationSession sheet
appears → "Google hasn't verified this app" interstitial (expected for
Testing-mode OAuth projects) → consent screen lists `gmail.readonly`
and `userinfo.email` → return to app → row updates to
"nsnguyen19@gmail.com · syncing events". Token persisted in Keychain;
Phase 18 will consume it for the actual inbox fetch.

**Plan deviations encountered**: (1) iOS Simulator Keychain requires
entitlements, so the test target gained
`WeeklyPlannerTests/WeeklyPlannerTests.entitlements` (keychain-access-groups
via ad-hoc signing) and the project-wide build commands switched from
`CODE_SIGNING_ALLOWED=NO` to `CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO`.
(2) GoogleSignIn-iOS 7.1.0 is callback-only (no async/await surface);
`RealGIDSigningClient` bridges via continuations. (3) `Info.plist`
needed an explicit `GoogleClientID` key declaration for `INFOPLIST_KEY_`
substitution to work.

**Tests added**: 4 classes / 23 new test methods
(`TokenKeychainStoreTests` × 4, `GoogleAuthServiceTests` × 7,
`ConnectionsViewModelTests` × 6, `ConnectionsSectionTests` × 6). Full
suite: 234 tests, all green. Snapshot tests deferred to Phase 21.

**Files**: `WeeklyPlanner/Auth/GoogleAuth/{GoogleAccountInfo,GoogleAuthConfig,GoogleAuthError,GoogleAuthService,GIDSigningClient,LiveGoogleAuthService,TokenKeychainStore}.swift`, `WeeklyPlanner/Features/Settings/{ConnectionsSection,ConnectionRow,ConnectionsViewModel}.swift`, `WeeklyPlanner/Features/Settings/Logos/{GmailBrandLogo,AppleBrandLogo,GoogleCalLogo}.swift`, `WeeklyPlannerTests/WeeklyPlannerTests.entitlements`; modified `WeeklyPlanner/Stores/{Environment+Stores,InboxStore}.swift`, `WeeklyPlanner/App/WeeklyPlannerApp.swift`, `WeeklyPlanner/Features/Settings/ConnectionsPlaceholder.swift`, `project.yml`, `WeeklyPlanner/Supporting/Info.plist`, `.gitignore`, `README.md`.

