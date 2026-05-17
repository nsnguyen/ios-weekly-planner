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

| #  | Phase                                                | Milestone           |
|----|------------------------------------------------------|---------------------|
| 01 | Project Bootstrap & Tooling                          | A — Foundation      |
| 02 | Design System (Theme, Fonts, Tokens)                 | A                   |
| 03 | Data Models & SwiftData Persistence                  | A                   |
| 04 | EventKit & Calendar Integration                      | A                   |
| 05 | Paper Primitives & Book Chrome                       | B — Day Page        |
| 06 | Paper Day Page (Static Layout + Events + Inbox)      | B                   |
| 07 | Day Page To-Do Block & AI Sticky Note                | B                   |
| 08 | Side Tabs & Page-Flip System                         | B                   |
| 09 | Top Bar & Week Picker                                | C — Week Nav        |
| 10 | Paper Week Page                                      | C                   |
| 11 | Paper Event Detail Sheet                             | D — Sheets          |
| 12 | Paper AI Search Overlay (UI)                         | D                   |
| 13 | Foundation Models (Apple Intelligence) Integration   | E — Intelligence    |
| 14 | Paper Review Page                                    | F — Other Screens   |
| 15 | Paper Tab Bar & Navigation Wiring                    | F                   |
| 16 | Settings — Theme, Handwriting, Size, Preferences     | G — Settings        |
| 17 | Settings — Connections (Gmail OAuth, Google, Apple)  | G                   |
| 18 | Gmail Inbox Pipeline & Event Suggestions             | H — Integrations    |
| 19 | Notifications (Time + Location Reminders)            | H                   |
| 20 | Modern Mode (Alternative Stock-iOS Theme)            | I — Polish          |
| 21 | Accessibility, Dynamic Type, Localization, RTL       | I                   |
| 22 | Final Polish, App Icon, Launch Screen, Privacy       | J — Ship            |
| 23 | App Store Submission & TestFlight                    | J                   |

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
