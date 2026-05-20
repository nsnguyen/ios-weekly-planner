# Weekly Planner

A weekly planner iOS app with a paper-planner aesthetic — leather book cover,
cream pages, handwritten ink, AI sticky notes, page-flip animations — layered
on top of EventKit, Apple Intelligence (Foundation Models), Gmail, and
UserNotifications.

## Status

**Milestones A–F + Phase 16 complete** — Phases 01–16 shipped to `main`. The
app builds and runs end-to-end: leather book chrome, Day / Week pages with
hobonichi layout, page-flip animations, week picker, event detail + AI
search sheets, on-device Foundation Models integration, Review page with AI
summary, the paper-bottom tab bar with right-edge binder-style day tabs, and
a live-switching Settings page (3 themes × 4 handwriting fonts × 3 text
sizes). 211 unit tests + UI smoke tests, all green.

| Milestone | Phases | Status |
|-----------|--------|--------|
| A — Foundation         | 01–04 | ✅ done |
| B — Day Page           | 05–08 | ✅ done |
| C — Week Nav           | 09–10 | ✅ done |
| D — Sheets & AI        | 11–12 | ✅ done |
| E — Intelligence       | 13    | ✅ done |
| F — Other Screens      | 14–15 | ✅ done |
| G — Settings           | 16–17 | 🟡 in progress (Phase 16 ✅) |
| H — Integrations       | 18–19 | ⏳ pending |
| I — Polish             | 20–21 | ⏳ pending |
| J — Ship               | 22–23 | ⏳ pending |

See `docs/phases/README.md` for the full 23-phase plan and per-phase
retrospectives.

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

## License

TBD — see `docs/phases/phase-23-app-store-submission.md`. Third-party fonts
are distributed under the SIL Open Font License 1.1; see
`WeeklyPlanner/Resources/Fonts/LICENSES/`.
