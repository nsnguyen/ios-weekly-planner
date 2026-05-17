# Phase 22 — Final Polish, App Icon, Launch Screen, Privacy Manifest

## Goal
Finalize the visual identity (app icon set, launch screen, marketing artwork), complete the privacy manifest, optimize performance, fix all warnings, prepare release notes, and harden the app for App Store review.

## Why this is needed
Cosmetic and metadata work that has to be right for a credible v1.0 launch. App Store reviewers will reject misformatted icons, missing privacy declarations, or first-launch crashes.

## Prerequisites
- All feature phases (01–21).

## Files Created / Modified

```
WeeklyPlanner/Resources/Assets.xcassets/AppIcon.appiconset/*.png    # NEW — all sizes (1024, 180, 167, 152, 120, 87, etc.)
WeeklyPlanner/Resources/Assets.xcassets/AppIcon.alternate-cream/    # NEW — alt icon (cream variant)
WeeklyPlanner/Resources/Assets.xcassets/AppIcon.alternate-midnight/ # NEW — alt icon (dark variant)
WeeklyPlanner/Resources/LaunchScreen.swift                          # MODIFY — final art
WeeklyPlanner/Supporting/PrivacyInfo.xcprivacy                      # MODIFY — final declarations
WeeklyPlanner/Marketing/ScreenshotsHarness.swift                    # NEW — UI test that captures App Store screenshots
WeeklyPlanner/Marketing/AppPreviewScript.md                         # NEW — script for App Preview video
WeeklyPlanner/Resources/Localizable.xcstrings                       # MODIFY — final marketing strings (eyebrow, etc.)
docs/release/v1.0.0/CHANGELOG.md                                    # NEW
docs/release/v1.0.0/REVIEWER_NOTES.md                               # NEW
docs/release/v1.0.0/PRIVACY_POLICY.md                               # NEW
docs/release/v1.0.0/TERMS_OF_SERVICE.md                             # NEW
README.md                                                            # MODIFY — public-facing
WeeklyPlannerTests/PerformanceTests.swift                            # NEW — measure metrics
```

## Visual & Interaction Checklist

### App Icon (primary)
- [ ] 1024×1024 master rendered from a Sketch/Figma source.
- [ ] Concept: closed leather-bound planner viewed at slight 3/4 angle, hint of cream pages peeking out, embossed handwriting "P". Cream + dark-brown palette.
- [ ] All required sizes generated: 180, 167, 152, 120, 87, 80, 76, 60, 58, 40, 29, 20 (plus 1024).
- [ ] Light + Dark + Tinted variants (iOS 18+ feature) — supply all three.
- [ ] No transparency (App Store requires opaque icons).
- [ ] Corner radius applied by iOS — do not pre-round.

### Alternate icons (in-app picker — defer to v1.1 UI; ship asset catalog now)
- [ ] `AppIcon.alternate-cream` — full cream paper page front.
- [ ] `AppIcon.alternate-midnight` — Midnight-theme dark variant.

### Launch screen
- [ ] Solid `#1A1410` background (Cream-theme book cover end color).
- [ ] No logos, no text — minimal, instant.
- [ ] Implemented as SwiftUI `LaunchScreenView` referenced in Info.plist.

### Marketing screenshots (6.7" and 6.1" iPhone sizes)
- [ ] Captured via `ScreenshotsHarness` UI test that:
  1. Seeds the in-memory store with a curated week.
  2. Navigates to Day page (Saturday), Week page, Review, AI overlay (answered state), Event sheet (Sara's birthday), Settings (Theme grid).
  3. Captures `XCUIScreen.main.screenshot()` into the test bundle's artifacts.
- [ ] Captions added in Fastlane / App Store Connect (not code).

### App Preview video (30s)
- [ ] Storyboard in `AppPreviewScript.md`:
  - 0–4s: leather cover opens → cream page; voice-over `"Plan your week the way you used to."`
  - 4–10s: scroll through events on Day page; tap one.
  - 10–17s: open AI overlay; ask `"Free time Sunday morning?"`; show answer.
  - 17–24s: flip to Week page; swipe.
  - 24–30s: theme switch from Cream → Midnight; closing logo.
- [ ] Captured manually with Xcode Capture or QuickTime device recording.

## Logic & Data Checklist

### Privacy Manifest finalization
- [ ] Declare data types collected:
  - **Calendars** — purpose: App Functionality. Linked to identity? No. Tracking? No.
  - **Email Address** — purpose: App Functionality (Gmail account email for display). Linked to identity? Yes. Tracking? No.
  - **Email Messages** — purpose: App Functionality (event extraction). Stored on-device only.
  - **Location** — purpose: App Functionality (geo-fenced reminders). Linked to identity? No. Tracking? No.
- [ ] Required Reason API: `UserDefaults` `CA92.1`, `FileTimestamp` if used (`C617.1`), etc.
- [ ] No tracking domains. No third-party SDKs that track. Google Sign-In is for authentication only (declared).

### App Store Connect metadata (drafted in `REVIEWER_NOTES.md`)
- [ ] App name: `"The Planner — Weekly Journal"`.
- [ ] Subtitle: `"Paper planner with AI memory"`.
- [ ] Keywords: `paper, planner, calendar, journal, AI, intelligence, weekly, hobonichi, productivity, organizer`.
- [ ] Description (~3000 chars) — draft included.
- [ ] What's New (release notes) — draft.
- [ ] Support URL, Marketing URL, Privacy Policy URL.
- [ ] Category: Productivity (primary), Lifestyle (secondary).
- [ ] Age rating: 4+.

### Privacy policy + ToS
- [ ] Linked from Settings → About → Privacy/Terms (add small links — defer UI to v1.1 if tight; ensure URLs are valid for v1.0).
- [ ] Privacy policy explains:
  - All AI processing on-device.
  - Gmail data fetched only with explicit user OAuth; stored locally; never transmitted to our servers.
  - EventKit data lives in iOS Calendar/Reminders.
  - We do not run analytics or crash reporters in v1.0 (or, if added, declare them).

### Reviewer notes
- [ ] Include test Gmail credentials (or instructions to use the reviewer's own).
- [ ] Explain Apple Intelligence requirement (iPhone 15 Pro/16+, iOS 26).
- [ ] Note geofence testing via Simulator Location.
- [ ] Provide a path through Day → Event → AI → Settings → Connections.

### CHANGELOG
- [ ] `v1.0.0 (TBD)`:
  - Paper-aesthetic Day, Week, Review, AI Search, Event Detail, Week Picker, Settings.
  - EventKit two-way sync.
  - Apple Intelligence (Foundation Models) on-device search and sticky-note insights.
  - Gmail inbox-to-calendar suggestions.
  - Time + location reminders.
  - Three themes × four handwriting fonts × three text sizes.
  - Modern (stock iOS) mode opt-in.

### Performance budget
- [ ] App cold-start to interactive (Day page on Saturday May 16) ≤ **2.0s** on iPhone 15 Pro.
- [ ] First-screen render frame count: at 60Hz target ≤ **6 dropped frames** across 5s of swiping.
- [ ] Page flip animation: 60fps sustained (no dropped frames on iPhone 15 Pro).
- [ ] Memory: foreground RSS ≤ **150 MB** with full week loaded.
- [ ] AI overlay average response (test query "When's my next dentist appointment?") ≤ **2.0s** on-device.

### Crash + warning hygiene
- [ ] Zero Xcode build warnings (Swift, SwiftLint, SwiftFormat).
- [ ] Zero strict-concurrency `Sendable` warnings.
- [ ] No `print(...)` outside DEBUG.
- [ ] `os_log`/`Logger` configured per subsystem; privacy specifiers set.

### Optional analytics (decision)
- [ ] **No analytics in v1.0.** If we want crash reporting, use Apple's built-in MetricKit reports (no third-party SDK). Document in privacy.

## Tests (TDD)

`PerformanceTests`
- [ ] `testDayPageInitialRenderUnder2Seconds()` using `XCTMetric.applicationLaunch`.
- [ ] `testPageFlipFrameRate()` using `XCTOSSignpostMetric`.
- [ ] `testAIQueryLatencyDentistUnder2Seconds()` — mocked model returns immediately to verify only UI overhead.

`ScreenshotsHarness` (UI test)
- [ ] Iterates the 6 marketing screens, captures attachments.
- [ ] Verifies each screen passes accessibility audit (re-uses Phase 21).

## Acceptance Criteria
- Submitting to TestFlight builds and passes Apple's automated validation.
- Privacy nutrition labels match the manifest.
- App icon renders correctly across home screen, Spotlight, Settings, Notifications.
- Launch screen visible for ≤ 0.5s.
- Performance budgets met on iPhone 15 Pro.
- Marketing screenshots match brand standards.

## Out of Scope
- In-app icon picker UI (defer v1.1).
- Localized App Store metadata (English only for v1.0).
- App Clips, Widgets, Watch app (out for v1.0).
- Crash reporting service.

## Risks & Notes
- **Foundation Models device matrix** — explain clearly in App Store description that AI features require iPhone 15 Pro or newer; otherwise the app works minus AI suggestions.
- **Privacy manifest format** changes occasionally; verify against Apple's current schema at submission time.
- **Tinted app icon** is required for iOS 18+ home-screen customization; provide a monochrome variant.
- **No HTTPS analytics endpoints** to declare (clean privacy story is a feature).
