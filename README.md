# Weekly Planner

A weekly planner iOS app with a paper-planner aesthetic — leather book cover,
cream pages, handwritten ink, AI sticky notes, page-flip animations — layered
on top of EventKit, Apple Intelligence (Foundation Models), Gmail, and
UserNotifications.

## Status

**Milestones A–I complete** — Phases 01–19 + 21 shipped. Phase 20 (Modern
Mode) was implemented end-to-end then archived (preserved at git tag
`phase-20-archive`); v1.0 ships Paper only. The app builds and runs
end-to-end: leather book chrome, Day / Week pages with hobonichi layout,
page-flip animations, week picker, event detail + AI search sheets,
real on-device Foundation Models integration, Review page with AI
summary, paper-bottom tab bar, live-switching Settings (3 themes × 4
handwriting fonts × 3 text sizes), Gmail OAuth + inbox pipeline
producing real iOS Calendar events, local notifications (time +
arrival-based), and end-to-end accessibility (VoiceOver labels, custom
rotors, Dynamic Type with handwriting clamp, Reduce Motion alternatives,
WCAG AA contrast, Bold Text font weight swap, RTL gesture/rotation
fixes, Localizable.xcstrings scaffolding). 302 unit tests + 9 UI tests,
all green.

| Milestone | Phases | Status |
|-----------|--------|--------|
| A — Foundation         | 01–04 | ✅ done |
| B — Day Page           | 05–08 | ✅ done |
| C — Week Nav           | 09–10 | ✅ done |
| D — Sheets & AI        | 11–12 | ✅ done |
| E — Intelligence       | 13    | ✅ done |
| F — Other Screens      | 14–15 | ✅ done |
| G — Settings           | 16–17 | ✅ done |
| H — Integrations       | 18–19 | ✅ done |
| I — Polish             | 21    | ✅ done (Phase 20 archived) |
| J — Completeness       | 22–24 | ⏳ in progress (Phases 22 + 23 ✅ shipped on `main`; 24 pending) |
| K — Ship               | 25–26 | ⏳ pending (Polish/Icon/Privacy, App Store Submission) |

See `docs/phases/README.md` for the full 26-phase plan and per-phase
retrospectives.

## Action items before App Store submission

One functional gap still ships before App Store review:

- ✅ **Phase 22 — Manual Event CRUD.** *(shipped on `main` in
  [#5](https://github.com/nsnguyen/ios-weekly-planner/pull/5))* Tap
  "+ add another" or "+ add your first event" to open an editable
  `PaperEventSheet` with title / time / category / location / notes.
  Long-press an event row for Edit / Delete. Tap "Edit" in the
  view-mode header to promote the sheet to edit mode in place.
- ✅ **Phase 23 — Manual Task CRUD.** *(shipped on `main` in
  [#5](https://github.com/nsnguyen/ios-weekly-planner/pull/5))* The
  always-visible dashed yellow to-do patch carries an inline
  "+ add a to-do" composer with a dashed-circle commit checkbox.
  Long-press a to-do for the mini popover (priority / due / delete).
  Swipe-left to delete. Auto-refresh on `.taskStoreDidChange`.
- **Phase 24 — AI Sticky v2 (Live & Actionable).** The current sticky
  generates one encouraging line per day and never refreshes. v2 runs
  four signal sources (travel-time ETA via MapKit, weather via
  WeatherKit, calendar-keyword detection via Foundation Models, and
  inbox-flagged items) and cascades up to 3 actionable stickies that
  refresh on day-page open + pull-to-refresh.

Then **Phase 25** (Final Polish, App Icon, Launch Screen, Privacy
Manifest) and **Phase 26** (App Store Submission & TestFlight) close
out the ship milestone. Plus these manual checks should happen in
TestFlight before public release:

- [ ] **VoiceOver sweep** across Day → Week → Review → Settings → AI search
      overlay → Event sheet on a real device. Automated
      `XCUIAccessibilityAudit` already catches structural issues; this
      catches pronunciation, composite-row grouping edge cases, and
      anything that reads awkwardly out loud.
- [ ] **AX5 Dynamic Type** render check on Day page across all 4 handwriting
      fonts (Caveat, Architects Daughter, Kalam, Indie Flower). Watch
      for event-title clipping; the layout adapter widens time gutter +
      side tabs at AX2+, but real text at AX5 is the proof.
- [ ] **RTL** via Settings → General → Language → Arabic. Confirm side tabs
      anchor to the right edge, page-flip drag direction inverts
      (right-drag = previous day), and DayPageHeader date number leans
      the opposite way (+3° instead of -3°).
- [ ] **Bold Text** via Accessibility → Display & Text Size → Bold Text.
      Confirm Caveat renders as SemiBold and Kalam renders as Bold
      (heavier stroke).
- [ ] **Apple Intelligence on-device** — the Foundation Models layer is
      wired but worth one end-to-end pass on a device with Apple
      Intelligence enabled (verify the AI sticky note, AI Search overlay
      answers, and Review page AI summary all produce real model output,
      not the fallback canned strings).
- [ ] **Gmail pipeline on a real Gmail account** — verified during Phase
      18 but re-confirm post-merge that pull-to-refresh + the 1-hour
      `BGAppRefreshTask` still produce InboxSuggestion rows.
- [ ] **Notifications on a physical device** — Phase 19 was verified on
      simulator; re-confirm time-based and location-based reminders fire
      on a real device, including `time-sensitive` interruption level
      during Focus modes.

These are not gates for the existing Milestone I merge to `main`;
they're gates for hitting "Submit to App Store Review" in App Store
Connect.

## Requirements

| Tool             | Version   | Why                                |
|------------------|-----------|------------------------------------|
| macOS            | 15+       | Required for Xcode 26              |
| Xcode            | 26.0+     | iOS 26 SDK, Swift 6                |
| iOS Simulator    | 26.0+     | `xcodebuild -downloadPlatform iOS` |
| Homebrew         | latest    | Install build tools                |
| XcodeGen         | 2.45+     | Generates `.xcodeproj` from YAML   |
| SwiftLint        | 0.63+     | Static analysis                    |
| SwiftFormat      | 0.61+     | Auto-format                        |

Install build tools:

```bash
brew install xcodegen swiftlint swiftformat
```

## Setup

```bash
# 1. Clone and enter
git clone <repo-url> ios-weekly-planner
cd ios-weekly-planner

# 2. Generate the Xcode project (project.yml is the source of truth)
xcodegen generate

# 3. Open in Xcode
open WeeklyPlanner.xcodeproj
```

The generated `WeeklyPlanner.xcodeproj` is git-ignored — regenerate it any time
project structure changes by editing `project.yml` and re-running
`xcodegen generate`.

## Build & test from the command line

```bash
# Build
xcodebuild build \
  -project WeeklyPlanner.xcodeproj \
  -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO

# Test
xcodebuild test \
  -project WeeklyPlanner.xcodeproj \
  -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO

# Lint
swiftlint --strict
swiftformat --lint .
```

## Project layout

```
ios-weekly-planner/
├── project.yml                       # XcodeGen spec (source of truth)
├── WeeklyPlanner/
│   ├── App/                          # @main + RootView
│   ├── Resources/
│   │   ├── Assets.xcassets/          # AppIcon, AccentColor, LaunchBackground
│   │   ├── Fonts/                    # Caveat, Architects Daughter, Kalam, Indie Flower
│   │   │   └── LICENSES/             # SIL Open Font License files
│   │   └── PrivacyInfo.xcprivacy
│   └── Supporting/
│       ├── Info.plist
│       └── WeeklyPlanner.entitlements
├── WeeklyPlannerTests/               # XCTest unit tests
├── WeeklyPlannerUITests/             # XCUITest UI tests
├── .github/workflows/ci.yml
└── docs/
    ├── mock/                         # HTML reference (do not edit)
    └── phases/                       # Per-phase specs (this drives implementation)
```

## Fonts

The four handwriting font families ship as nine static TTF files in
`WeeklyPlanner/Resources/Fonts/`:

| File                            | PostScript name             | License |
|---------------------------------|-----------------------------|---------|
| Caveat-Regular.ttf              | `Caveat-Regular`            | OFL 1.1 |
| Caveat-Medium.ttf               | `Caveat-Medium`             | OFL 1.1 |
| Caveat-SemiBold.ttf             | `Caveat-SemiBold`           | OFL 1.1 |
| Caveat-Bold.ttf                 | `Caveat-Bold`               | OFL 1.1 |
| ArchitectsDaughter-Regular.ttf  | `ArchitectsDaughter-Regular`| OFL 1.1 |
| Kalam-Light.ttf                 | `Kalam-Light`               | OFL 1.1 |
| Kalam-Regular.ttf               | `Kalam-Regular`             | OFL 1.1 |
| Kalam-Bold.ttf                  | `Kalam-Bold`                | OFL 1.1 |
| IndieFlower-Regular.ttf         | `IndieFlower-Regular`       | OFL 1.1 |

The Caveat weights are sliced from the upstream variable font (`Caveat[wght].ttf`)
using `fonttools varLib.mutator`, with PostScript / family / subfamily / weight
metadata rewritten to match the static-instance convention.

## Bundle identifier

`com.weeklyplanner.WeeklyPlanner` is a placeholder. Replace with the production
ID in `project.yml`, `WeeklyPlanner.entitlements`, and the Google OAuth URL
type in `Info.plist` before Phase 23.

## Google OAuth setup (Phase 17+)

The app's Gmail integration uses Google's iOS OAuth client. The client ID
is **not** committed — every developer drops their own (or the team's) into
a gitignored `Secrets.xcconfig` at the repo root.

### One-time setup

1. Go to https://console.cloud.google.com/apis/credentials
2. **Create credentials → OAuth client ID**, Application type **iOS**,
   Bundle ID **`com.weeklyplanner.WeeklyPlanner`**.
3. Copy the two values Google shows you (Client ID and the iOS URL scheme —
   they're the same string, inverted).
4. Copy `Secrets.example.xcconfig` to `Secrets.xcconfig` and paste both
   values:

   ```
   GOOGLE_CLIENT_ID = 1234-abcd.apps.googleusercontent.com
   REVERSED_GOOGLE_CLIENT_ID = com.googleusercontent.apps.1234-abcd
   ```

5. `xcodegen generate` (XcodeGen picks up `Secrets.xcconfig` via
   `configFiles`).
6. Build and run. The Gmail toggle in Settings should now open the real
   OAuth sheet.

### Scopes + test users

While the OAuth project is in "Testing" mode, only the Google accounts
listed under **OAuth consent screen → Audience → Test users** can sign in.
Add your own Gmail address there. App Store submission requires moving to
Production, which triggers Google's brand verification + CASA security
assessment (4–6 weeks) — plan for it in Phase 23.

### If `Secrets.xcconfig` is missing

The app still builds and runs; tapping the Gmail toggle surfaces an
in-app alert ("Gmail isn't configured…") instead of crashing. Every other
feature continues to work.

## License

TBD — see `docs/phases/phase-23-app-store-submission.md`. Third-party fonts
are distributed under the SIL Open Font License 1.1; see
`WeeklyPlanner/Resources/Fonts/LICENSES/`.
