# Phase 01 — Project Bootstrap & Tooling

## Goal
Create a buildable, testable, signable SwiftUI iOS 26 Xcode project with all third-party dependencies, fonts, capabilities, entitlements, and CI scaffolding in place — but no app features yet.

## Why this is needed
Every later phase ships changes into a real project that builds and tests on simulator and device. Get this wrong and every subsequent phase fights tooling.

## Prerequisites
None.

## Files Created / Modified

```
WeeklyPlanner.xcodeproj/                                  # NEW (generated)
WeeklyPlanner/App/WeeklyPlannerApp.swift                  # NEW — @main App entry
WeeklyPlanner/App/RootView.swift                          # NEW — placeholder root view
WeeklyPlanner/Supporting/Info.plist                       # NEW
WeeklyPlanner/Supporting/WeeklyPlanner.entitlements       # NEW
WeeklyPlanner/Supporting/PrivacyInfo.xcprivacy            # NEW (privacy manifest)
WeeklyPlanner/Resources/Assets.xcassets/                  # NEW
WeeklyPlanner/Resources/Fonts/Caveat-{400,500,600,700}.ttf            # NEW
WeeklyPlanner/Resources/Fonts/ArchitectsDaughter-Regular.ttf          # NEW
WeeklyPlanner/Resources/Fonts/Kalam-{Light,Regular,Bold}.ttf          # NEW
WeeklyPlanner/Resources/Fonts/IndieFlower-Regular.ttf                 # NEW
WeeklyPlannerTests/SmokeTests.swift                       # NEW — verifies app launches
WeeklyPlannerUITests/SmokeUITests.swift                   # NEW — launches simulator app
Package.swift                                              # NEW — SPM manifest if used
.swift-version                                             # NEW — pin to 6.0
.swiftformat                                               # NEW — style config
.swiftlint.yml                                             # NEW — lint config
.github/workflows/ci.yml                                   # NEW — build + test on PR
README.md                                                  # MODIFY — replace stub
.gitignore                                                 # NEW — Swift/Xcode/macOS
```

## Visual & Interaction Checklist

There is no UI in this phase. The app launches to a blank screen with the text `"Weekly Planner — bootstrap"` centered in SF Pro, on a `#F2F2F7` background, just to prove the build works.

## Logic & Data Checklist

### Xcode project setup
- [ ] Project name: `WeeklyPlanner`. Bundle ID: `com.<org>.WeeklyPlanner` (placeholder — finalize before Phase 23).
- [ ] Deployment target: iOS **26.0**. iPhone only. Portrait only.
- [ ] Swift language version: **6.0**, strict concurrency: **complete**.
- [ ] App lifecycle: **SwiftUI**.
- [ ] Devices: iPhone (universal off). Orientation: portrait only.
- [ ] Encryption export compliance: declare `ITSAppUsesNonExemptEncryption = NO` for now.
- [ ] Categories: Productivity.

### Info.plist keys
- [ ] `NSCalendarsFullAccessUsageDescription` — "Weekly Planner reads and writes your iOS Calendar so events stay in sync with the system Calendar app."
- [ ] `NSRemindersFullAccessUsageDescription` — "Weekly Planner stores your tasks as iOS Reminders so they sync with Reminders.app."
- [ ] `NSContactsUsageDescription` — "Weekly Planner uses Contacts to show invitee names on events." (only if invitees are wired; deferred to Phase 11.)
- [ ] `NSLocationWhenInUseUsageDescription` — "Weekly Planner uses your location to deliver 'when I arrive' reminders for events with a place." (Phase 19.)
- [ ] `NSUserNotificationsUsageDescription` — implicit, but include for clarity.
- [ ] `NSAppleEventsUsageDescription` — not needed.
- [ ] `UIBackgroundModes` — `["fetch"]` for Gmail background sync (Phase 18).
- [ ] `UIRequiresFullScreen` — `YES`.
- [ ] `UISupportedInterfaceOrientations` — `[UIInterfaceOrientationPortrait]` only.
- [ ] `UIAppFonts` — list **all 9** font files (Caveat 4 weights, Architects Daughter, Kalam 3 weights, Indie Flower).
- [ ] `LSApplicationCategoryType` — `public.app-category.productivity`.
- [ ] `CFBundleURLTypes` — Google OAuth redirect URI placeholder (Phase 17).

### Entitlements
- [ ] `com.apple.developer.usernotifications.communication` — for time-sensitive notifications.
- [ ] `com.apple.developer.kernel.increased-memory-limit` — only if needed (defer until profiled).
- [ ] Keychain access groups: `$(AppIdentifierPrefix)com.<org>.WeeklyPlanner` for OAuth tokens.
- [ ] Sign in with Apple: NOT required.
- [ ] iCloud / CloudKit: deferred (decide in Phase 23 whether to add cross-device sync).

### SPM dependencies (pinned)
- [ ] `swift-collections` — for `OrderedDictionary` if needed.
- [ ] `GoogleSignIn-iOS` (≥ 8.0) — Gmail OAuth (Phase 17/18).
- [ ] `GoogleAPIClientForREST` — Gmail messages API (Phase 18).
- [ ] `KeychainAccess` (or roll our own thin wrapper) — token storage.
- [ ] `Pow` (optional) — for delightful micro-animations. **Defer** unless we hit a wall in Phase 08.
- [ ] **No** RxSwift, Combine wrappers, or third-party UI frameworks. SwiftUI only.

### Fonts
- [ ] Download official font files from Google Fonts:
  - Caveat (Regular 400, Medium 500, SemiBold 600, Bold 700)
  - Architects Daughter (Regular)
  - Kalam (Light 300, Regular 400, Bold 700)
  - Indie Flower (Regular)
- [ ] Verify each font's PostScript name matches what `UIFont(name:)` will look up; document the exact PS name in code comments.
- [ ] Add all files to `Copy Bundle Resources` build phase.
- [ ] Add license files for each font to `Resources/Fonts/LICENSES/`.

### Privacy Manifest (`PrivacyInfo.xcprivacy`)
- [ ] Declare data types accessed: Calendar (other purposes), Email (app functionality — Phase 18), Location (other purposes — Phase 19).
- [ ] Required Reason API list:
  - `NSPrivacyAccessedAPICategoryUserDefaults` reason `CA92.1` (app functionality).
  - `NSPrivacyAccessedAPICategoryFileTimestamp` reason `C617.1` if used.
  - `NSPrivacyAccessedAPICategoryDiskSpace` reason `E174.1` if used.
- [ ] No tracking domains.

### Lint/format
- [ ] `swiftformat` config: 4-space indent, max line 120, trailing commas, sorted imports.
- [ ] `swiftlint` config: ban force-unwraps, force-cast, enforce `final` on classes, ban `print` outside `#if DEBUG`.

### Continuous Integration (`.github/workflows/ci.yml`)
- [ ] Trigger on `pull_request` and `push` to `main`.
- [ ] Runner: `macos-15` with Xcode 17 selected via `xcode-select`.
- [ ] Steps: cache SPM → build for iPhone 15 Pro simulator → run unit tests → run UI tests → upload xcresult bundle.
- [ ] Fail PR on lint errors or test failures.

### App icon stub
- [ ] Placeholder 1024×1024 PNG in `Assets.xcassets/AppIcon.appiconset/` (single image, all sizes regenerated). Final icon comes in Phase 22.

### Launch screen
- [ ] Storyboard-less SwiftUI launch screen showing `#1A1410` solid color with no text. Final treatment in Phase 22.

## Tests (TDD)

`WeeklyPlannerTests/SmokeTests.swift`
- [ ] `testFontsRegistered()` — for every PostScript name we use, `UIFont(name:, size: 12)` returns non-nil. Iterates the list of 9 fonts.
- [ ] `testBundleIdentifier()` — sanity check the bundle ID matches the expected value.
- [ ] `testDeploymentTarget()` — read minimum iOS version from `Bundle.main`, assert `>= 26.0`.

`WeeklyPlannerUITests/SmokeUITests.swift`
- [ ] `testAppLaunches()` — launches the app, asserts the placeholder text "Weekly Planner — bootstrap" is visible within 5 seconds.

## Acceptance Criteria

- `xcodebuild build` succeeds for the `iPhone 15 Pro` simulator (iOS 26) target.
- All smoke tests pass locally and in CI.
- All 9 fonts load successfully at runtime (verified by SmokeTests).
- Launching the app on simulator shows only the placeholder. No crashes, no warnings.
- SwiftLint and SwiftFormat run clean.

## Out of Scope

- App icon final art (Phase 22).
- Launch screen final art (Phase 22).
- Any actual features.
- CloudKit / iCloud sync (potential later).
- Localization (Phase 21).

## Risks & Notes

- **Foundation Models requires iOS 26 and Apple Silicon devices.** Older test devices won't exercise AI; plan for an iPhone 15 Pro (or A17+) test device early.
- **Google Sign-In SDK** historically pulls in `GTMSessionFetcher` and `AppAuth` as transitive deps. Lock major versions.
- **Font names vs file names differ.** Always test by PostScript name, not file name. Capture in code comment when added.
- **Strict concurrency (Swift 6)** will surface warnings in 3rd-party libs. We'll need `@preconcurrency import` shims where unavoidable; document each one.
