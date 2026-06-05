# Phase 36a — Personalization Additive (Fonts · Templates · Footer) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Four more handwriting fonts (suggestion 42), quick-template chips in the create-event sheet + an opaque sheet card (41), and a finished Settings footer with the real app version (47).

**Architecture:** Fonts are purely additive — bundle 4 OFL `.ttf`s, register in `Info.plist` `UIAppFonts`, extend the `PaperFont` enum (the Settings `FontCardsGrid` iterates `allCases`, so the grid grows automatically). "Templates" did not exist in the codebase — per user decision (2026-06-04) we build the minimal real thing: a curated `EventTemplate` value set rendered as horizontal chips in the **create** event sheet that pre-fill the composer, plus the sheet-card transparency fix the tester actually described ("line doesn't show"). Footer reads the marketing version from the bundle via a testable `AppVersion` helper.

**Tech Stack:** SwiftUI, XcodeGen (`project.yml` auto-scans `Resources/`; fonts register via `Supporting/Info.plist`), XCTest.

**Split note:** Week-start expansion (45) is deliberately NOT here — it is its own plan (`2026-06-04-phase-36b-week-start.md`), per user decision.

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `WeeklyPlanner/Resources/Fonts/PatrickHand-Regular.ttf` (+3 more) | NEW | bundled font binaries (OFL) |
| `docs/licenses/fonts/*-OFL.txt` | NEW | license texts (redistribution requirement) |
| `WeeklyPlanner/Supporting/Info.plist` | MODIFY | `UIAppFonts` + 4 entries |
| `WeeklyPlanner/DesignSystem/PaperFont.swift` | MODIFY | 4 new cases + mappings |
| `WeeklyPlannerTests/DesignSystem/PaperFontRegistrationTests.swift` | NEW | every PostScript name actually loads |
| `WeeklyPlannerTests/.../PaperSettingsViewTests.swift` | MODIFY | font-count invariant 4 → 8 |
| `WeeklyPlanner/DesignSystem/AppVersion.swift` | NEW | bundle version → display string |
| `WeeklyPlanner/Features/Settings/AboutFooter.swift` | MODIFY | finished footer w/ real version |
| `WeeklyPlannerTests/DesignSystem/AppVersionTests.swift` | NEW | format + fallbacks |
| `WeeklyPlanner/Models/EventTemplate.swift` | NEW | curated template set + composer apply |
| `WeeklyPlanner/Features/EventDetail/EditableFields/TemplateChipsRow.swift` | NEW | horizontal chips (create mode only) |
| `WeeklyPlanner/Features/EventDetail/PaperEventSheet+Edit.swift` | MODIFY | host chips; opaque card investigation in `PaperEventSheet.swift` |
| `WeeklyPlannerTests/EventDetail/EventTemplateTests.swift` | NEW | apply semantics + set invariants |
| `WeeklyPlannerUITests/QuickTemplateUITests.swift` | NEW | chip → prefilled → saved |
| `WeeklyPlannerUITests/FontPickUITests.swift` | NEW | pick a new font, persists |

**Canonical test command** ("the test command"; device from `xcrun simctl list devices available`):

```bash
xcodegen generate
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=<available iPhone, iOS 26.5>' \
  -only-testing:<filter> \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO
```

---

### Task 1: Bundle the four fonts (files + plist + licenses)

The four families (all SIL OFL, single-weight, handwriting — license-clear for bundling):

| Family | File | Expected PostScript name |
|---|---|---|
| Patrick Hand | `PatrickHand-Regular.ttf` | `PatrickHand-Regular` |
| Shadows Into Light | `ShadowsIntoLight.ttf` | `ShadowsIntoLight` |
| Gochi Hand | `GochiHand-Regular.ttf` | `GochiHand-Regular` |
| Nanum Pen Script | `NanumPenScript-Regular.ttf` | `NanumPenScript-Regular` |

- [ ] **Step 1: Download fonts + licenses**

```bash
cd /Users/nguyen-mini/Documents/dev/ios-weekly-planner/WeeklyPlanner/Resources/Fonts
curl -fLO https://raw.githubusercontent.com/google/fonts/main/ofl/patrickhand/PatrickHand-Regular.ttf
curl -fLO https://raw.githubusercontent.com/google/fonts/main/ofl/shadowsintolight/ShadowsIntoLight.ttf
curl -fLO https://raw.githubusercontent.com/google/fonts/main/ofl/gochihand/GochiHand-Regular.ttf
curl -fLO https://raw.githubusercontent.com/google/fonts/main/ofl/nanumpenscript/NanumPenScript-Regular.ttf

mkdir -p /Users/nguyen-mini/Documents/dev/ios-weekly-planner/docs/licenses/fonts
cd /Users/nguyen-mini/Documents/dev/ios-weekly-planner/docs/licenses/fonts
curl -fL https://raw.githubusercontent.com/google/fonts/main/ofl/patrickhand/OFL.txt -o PatrickHand-OFL.txt
curl -fL https://raw.githubusercontent.com/google/fonts/main/ofl/shadowsintolight/OFL.txt -o ShadowsIntoLight-OFL.txt
curl -fL https://raw.githubusercontent.com/google/fonts/main/ofl/gochihand/OFL.txt -o GochiHand-OFL.txt
curl -fL https://raw.githubusercontent.com/google/fonts/main/ofl/nanumpenscript/OFL.txt -o NanumPenScript-OFL.txt
```

Verify: `ls WeeklyPlanner/Resources/Fonts/` shows 13 `.ttf` files (9 existing + 4 new); each download is >10KB (`du -h` — a tiny file means a 404 page, re-check the URL against `https://github.com/google/fonts/tree/main/ofl/<family>`).

- [ ] **Step 2: Register in `WeeklyPlanner/Supporting/Info.plist`** — extend the `UIAppFonts` array (bare filenames, matching the existing entries):

```xml
    <string>PatrickHand-Regular.ttf</string>
    <string>ShadowsIntoLight.ttf</string>
    <string>GochiHand-Regular.ttf</string>
    <string>NanumPenScript-Regular.ttf</string>
```

- [ ] **Step 3: Regenerate + build check**

```bash
xcodegen generate
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=<available iPhone, iOS 26.5>' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add WeeklyPlanner/Resources/Fonts/ WeeklyPlanner/Supporting/Info.plist docs/licenses/fonts/
git commit -m "feat(fonts): bundle Patrick Hand, Shadows Into Light, Gochi Hand, Nanum Pen (OFL) (Phase 36a #42)"
```

---

### Task 2: Extend `PaperFont` (TDD via registration test)

**Files:**
- Modify: `WeeklyPlanner/DesignSystem/PaperFont.swift`
- Create: `WeeklyPlannerTests/DesignSystem/PaperFontRegistrationTests.swift`
- Modify: the count invariant in `PaperSettingsViewTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import UIKit
import XCTest
@testable import WeeklyPlanner

final class PaperFontRegistrationTests: XCTestCase {
    private var allRegisteredNames: [String] {
        UIFont.familyNames.flatMap { UIFont.fontNames(forFamilyName: $0) }.sorted()
    }

    func testAllCasesIncludeTheFourNewFamilies() {
        XCTAssertEqual(PaperFont.allCases.count, 8)
        XCTAssertTrue(PaperFont.allCases.contains(.patrick))
        XCTAssertTrue(PaperFont.allCases.contains(.shadows))
        XCTAssertTrue(PaperFont.allCases.contains(.gochi))
        XCTAssertTrue(PaperFont.allCases.contains(.nanum))
    }

    func testEveryFamilyResolvesItsRegularFace() {
        for family in PaperFont.allCases {
            let name = family.postScriptName(for: .regular)
            XCTAssertNotNil(UIFont(name: name, size: 12),
                            "'\(name)' did not load — wrong PostScript name or missing UIAppFonts entry. Registered: \(allRegisteredNames)")
        }
    }

    func testEveryFamilyResolvesItsBoldMapping() {
        // Single-weight families map bold → their regular face; it must
        // still be a loadable name.
        for family in PaperFont.allCases {
            let name = family.postScriptName(for: .bold)
            XCTAssertNotNil(UIFont(name: name, size: 12),
                            "'\(name)' (bold mapping for \(family)) did not load. Registered: \(allRegisteredNames)")
        }
    }

    func testNewFamiliesKeepRegularLegibilityWeight() {
        for family in [PaperFont.patrick, .shadows, .gochi, .nanum] {
            XCTAssertEqual(family.weightFor(legibility: .bold), .regular,
                           "Single-weight family must not pretend to have a bolder face")
        }
    }
}
```

And in `PaperSettingsViewTests.swift`, replace the count test:

```swift
    func testPaperFontCountIsEightSoFontCardsGridIsFourFullRows() {
        // FontCardsGrid is a 2-col grid; 8 fonts == 4 full rows.
        XCTAssertEqual(PaperFont.allCases.count, 8)
    }
```

(Delete `testPaperFontCountIsFourSoFontCardsGridIsTwoFullRows`.)

- [ ] **Step 2: Run to verify failure** — `-only-testing:WeeklyPlannerTests/PaperFontRegistrationTests`. Expected: compile failure (`.patrick` etc.).

- [ ] **Step 3: Implement in `PaperFont.swift`** — extend each switch:

```swift
enum PaperFont: String, CaseIterable, Hashable, Codable {
    case caveat
    case architects
    case kalam
    case indie
    case patrick
    case shadows
    case gochi
    case nanum
```

```swift
    var displayName: String {
        switch self {
        case .caveat: "Caveat"
        case .architects: "Architects"
        case .kalam: "Kalam"
        case .indie: "Indie"
        case .patrick: "Patrick Hand"
        case .shadows: "Shadows"
        case .gochi: "Gochi Hand"
        case .nanum: "Nanum Pen"
        }
    }
```

```swift
    var fallbackPostScriptName: String {
        switch self {
        case .caveat: "Cochin"
        case .architects, .kalam, .indie,
             .patrick, .shadows, .gochi, .nanum: "Caveat-Regular"
        }
    }
```

```swift
    func postScriptName(for weight: Font.Weight) -> String {
        switch self {
        case .caveat: caveatName(for: weight)
        case .architects: "ArchitectsDaughter-Regular"
        case .kalam: kalamName(for: weight)
        case .indie: "IndieFlower-Regular"
        case .patrick: "PatrickHand-Regular"
        case .shadows: "ShadowsIntoLight"
        case .gochi: "GochiHand-Regular"
        case .nanum: "NanumPenScript-Regular"
        }
    }
```

```swift
    func weightFor(legibility: LegibilityWeight) -> Font.Weight {
        guard legibility == .bold else { return .regular }
        switch self {
        case .caveat:     return .semibold
        case .kalam:      return .bold
        case .architects, .indie,
             .patrick, .shadows, .gochi, .nanum:
            return .regular
        }
    }
```

- [ ] **Step 4: Run to verify pass**

Run: `-only-testing:WeeklyPlannerTests/PaperFontRegistrationTests -only-testing:WeeklyPlannerTests/PaperSettingsViewTests -only-testing:WeeklyPlannerTests/SettingsViewModelTests`
Expected: PASS. **If a registration test fails on a PostScript name**, the failure message prints every registered name — take the actual one from that list, fix the enum, re-run. The test defines the contract; do NOT skip it.

- [ ] **Step 5: Visual check** — `FontCardsGrid` needs no change (iterates `allCases`); open the Settings preview or simulator and confirm 8 cards render with live previews.

- [ ] **Step 6: Commit**

```bash
git add WeeklyPlanner/DesignSystem/PaperFont.swift WeeklyPlannerTests/
git commit -m "feat(fonts): PaperFont gains patrick/shadows/gochi/nanum with verified PostScript names (Phase 36a #42)"
```

---

### Task 3: `AppVersion` + finished `AboutFooter`

**Files:**
- Create: `WeeklyPlanner/DesignSystem/AppVersion.swift`
- Modify: `WeeklyPlanner/Features/Settings/AboutFooter.swift`
- Test: `WeeklyPlannerTests/DesignSystem/AppVersionTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import WeeklyPlanner

final class AppVersionTests: XCTestCase {
    func testFormatsMarketingAndBuild() {
        XCTAssertEqual(AppVersion.display(marketing: "1.1.0", build: "12"), "v1.1.0 (12)")
    }

    func testFallsBackWhenMissing() {
        XCTAssertEqual(AppVersion.display(marketing: nil, build: nil), "v1.0 (1)")
    }

    func testCurrentReadsTheRealBundle() {
        // The test bundle host app carries the real Info.plist values.
        XCTAssertTrue(AppVersion.current().hasPrefix("v"))
        XCTAssertTrue(AppVersion.current().contains("("))
    }
}
```

- [ ] **Step 2: Run to verify failure** — `-only-testing:WeeklyPlannerTests/AppVersionTests`. Expected: compile failure.

- [ ] **Step 3: Implement** `AppVersion.swift`:

```swift
import Foundation

/// Marketing + build version for user-facing display ("v1.0.0 (1)").
enum AppVersion {
    static func display(marketing: String?, build: String?) -> String {
        "v\(marketing ?? "1.0") (\(build ?? "1"))"
    }

    static func current(bundle: Bundle = .main) -> String {
        display(marketing: bundle.infoDictionary?["CFBundleShortVersionString"] as? String,
                build: bundle.infoDictionary?["CFBundleVersion"] as? String)
    }
}
```

Rework `AboutFooter.swift` (replaces the hardcoded `"The Planner · v1.0 · made with care"`):

```swift
import SwiftUI

/// Finished settings trailer (Phase 36a #47): centered two-line sign-off
/// with the real bundle version. Privacy/Terms links land with Phase 40
/// once those documents exist.
struct AboutFooter: View {
    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    var body: some View {
        VStack(spacing: 3) {
            LinearGradient(stops: [
                .init(color: .clear, location: 0.0),
                .init(color: theme.ink, location: 0.5),
                .init(color: .clear, location: 1.0),
            ], startPoint: .leading, endPoint: .trailing)
                .opacity(0.25)
                .frame(width: 120, height: 1)
                .padding(.bottom, 7)

            Text("The Planner · \(AppVersion.current())")
                .font(font.font(at: 16 * size.scale, weight: .regular))
                .italic()
                .foregroundStyle(theme.ink3)

            Text("made with care")
                .font(font.font(at: 13 * size.scale, weight: .regular))
                .italic()
                .foregroundStyle(theme.inkDecorative)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("The Planner, version \(AppVersion.current())")
    }
}

#Preview("AboutFooter · cream") {
    AboutFooter()
        .padding()
        .background(PaperTheme.cream.cream)
        .paperTheme(.cream)
}
```

- [ ] **Step 4: Run to verify pass** — `-only-testing:WeeklyPlannerTests/AppVersionTests`. Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/DesignSystem/AppVersion.swift WeeklyPlanner/Features/Settings/AboutFooter.swift WeeklyPlannerTests/DesignSystem/AppVersionTests.swift
git commit -m "feat(settings): finished AboutFooter with real bundle version (Phase 36a #47)"
```

---

### Task 4: `EventTemplate` model + composer apply

**Files:**
- Create: `WeeklyPlanner/Models/EventTemplate.swift`
- Test: `WeeklyPlannerTests/EventDetail/EventTemplateTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import WeeklyPlanner

@MainActor
final class EventTemplateTests: XCTestCase {
    func testCuratedSetHasAtLeastSixUniqueTemplates() {
        XCTAssertGreaterThanOrEqual(EventTemplate.curated.count, 6)
        XCTAssertEqual(Set(EventTemplate.curated.map(\.id)).count, EventTemplate.curated.count)
    }

    func testApplyPrefillsComposerKeepingStartAnchor() {
        let anchor = Date(timeIntervalSince1970: 1_780_000_000)
        let state = EventComposerState.empty(at: anchor, calendar: WeekMath.mondayCalendar())
        let originalStart = state.start

        let gym = EventTemplate.curated.first { $0.id == "gym" }!
        state.apply(gym)

        XCTAssertEqual(state.title, "Gym")
        XCTAssertEqual(state.category, .health)
        XCTAssertEqual(state.start, originalStart, "Template must not move the chosen start")
        XCTAssertEqual(state.end, originalStart.addingTimeInterval(60 * 60))
        XCTAssertTrue(state.alertOn)
        XCTAssertEqual(state.alertMinutes, 15)
    }

    func testApplyWithoutAlertTurnsAlertOff() {
        let state = EventComposerState.empty(at: Date(timeIntervalSince1970: 1_780_000_000),
                                             calendar: WeekMath.mondayCalendar())
        let lunch = EventTemplate.curated.first { $0.id == "lunch" }!
        state.apply(lunch)

        XCTAssertEqual(state.title, "Lunch")
        XCTAssertFalse(state.alertOn)
    }

    func testApplyKeepsComposerSavable() {
        let state = EventComposerState.empty(at: Date(timeIntervalSince1970: 1_780_000_000),
                                             calendar: WeekMath.mondayCalendar())
        state.apply(EventTemplate.curated[0])
        XCTAssertTrue(state.canSave)
    }
}
```

- [ ] **Step 2: Run to verify failure** — `-only-testing:WeeklyPlannerTests/EventTemplateTests`. Expected: compile failure.

- [ ] **Step 3: Implement** `EventTemplate.swift`:

```swift
import Foundation

/// A curated quick-fill preset for the create-event sheet (Phase 36a #41
/// "more template"). Value-type set — user-defined templates are a later
/// phase if requested.
struct EventTemplate: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let category: Category
    let durationMinutes: Int
    /// `nil` = no alert preset.
    let alertMinutes: Int?
}

extension EventTemplate {
    static let curated: [EventTemplate] = [
        EventTemplate(id: "gym", title: "Gym", category: .health, durationMinutes: 60, alertMinutes: 15),
        EventTemplate(id: "standup", title: "Standup", category: .work, durationMinutes: 15, alertMinutes: 5),
        EventTemplate(id: "lunch", title: "Lunch", category: .personal, durationMinutes: 60, alertMinutes: nil),
        EventTemplate(id: "call", title: "Call", category: .family, durationMinutes: 30, alertMinutes: 5),
        EventTemplate(id: "errands", title: "Errands", category: .personal, durationMinutes: 45, alertMinutes: nil),
        EventTemplate(id: "datenight", title: "Date night", category: .family, durationMinutes: 120, alertMinutes: 60),
    ]
}

extension EventComposerState {
    /// Pre-fill from a template. Keeps the user's chosen start anchor;
    /// sets title/category/duration/alert.
    func apply(_ template: EventTemplate) {
        title = template.title
        category = template.category
        end = start.addingTimeInterval(TimeInterval(template.durationMinutes * 60))
        if let minutes = template.alertMinutes {
            alertOn = true
            alertMinutes = minutes
        } else {
            alertOn = false
        }
    }
}
```

- [ ] **Step 4: Run to verify pass** — same filter. Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Models/EventTemplate.swift WeeklyPlannerTests/EventDetail/EventTemplateTests.swift
git commit -m "feat(templates): curated EventTemplate set + composer apply (Phase 36a #41)"
```

---

### Task 5: `TemplateChipsRow` + hosting (create mode only)

**Files:**
- Create: `WeeklyPlanner/Features/EventDetail/EditableFields/TemplateChipsRow.swift`
- Modify: `WeeklyPlanner/Features/EventDetail/PaperEventSheet+Edit.swift`
- Modify: `WeeklyPlanner/Accessibility/AccessibilityIDs.swift`

- [ ] **Step 1: Accessibility ID** (in `AccessibilityIDs.swift`):

```swift
    // MARK: Quick templates (Phase 36a)
    static func eventTemplateChip(_ id: String) -> String { "paperEventSheet.template.\(id)" }
```

- [ ] **Step 2: `TemplateChipsRow.swift`:**

```swift
import SwiftUI

/// Horizontal quick-template chips shown at the top of the CREATE event
/// sheet. Tapping one pre-fills the composer (it stays fully editable).
struct TemplateChipsRow: View {
    let onPick: (EventTemplate) -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(EventTemplate.curated) { template in
                    Button {
                        onPick(template)
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(CategoryPalette.inkColor(template.category, in: theme))
                                .frame(width: 7, height: 7)
                            Text(template.title)
                                .font(font.font(at: 14 * size.scale, weight: .regular))
                                .foregroundStyle(theme.ink)
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(theme.creamHi))
                        .overlay(Capsule().strokeBorder(theme.rule, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(template.title) template")
                    .accessibilityHint("Double tap to pre-fill the event.")
                    .accessibilityIdentifier(AccessibilityIDs.eventTemplateChip(template.id))
                }
            }
            .padding(.vertical, 2)
        }
        .padding(.bottom, 10)
    }
}

#Preview("TemplateChipsRow · cream") {
    TemplateChipsRow { _ in }
        .padding()
        .background(PaperTheme.cream.cream)
        .paperTheme(.cream)
}
```

⚠️ If `CategoryPalette.inkColor(_:in:)`'s actual signature differs (it's the one used by `InkColorModifier`), match it.

- [ ] **Step 3: Host it.** In `PaperEventSheet+Edit.swift` (`EditableEventContent.body`), ABOVE the title field, gated to create mode (the view already receives `isCreate`):

```swift
            if isCreate {
                TemplateChipsRow { template in
                    composer.apply(template)
                }
            }
```

- [ ] **Step 4: Compile check** — run `-only-testing:WeeklyPlannerTests/EventTemplateTests`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Features/EventDetail/ WeeklyPlanner/Accessibility/AccessibilityIDs.swift
git commit -m "feat(templates): quick-template chips in the create-event sheet (Phase 36a #41)"
```

---

### Task 6: Opaque sheet card ("less transparent so line doesn't show")

**Files:**
- Modify: `WeeklyPlanner/Features/EventDetail/PaperEventSheet.swift` (investigate first)

- [ ] **Step 1: Find the translucency.** The tester sees the day page's ruled lines through the sheet card. Locate the card's backing:

```bash
grep -n "opacity\|Material\|ultraThin\|creamHi\|cream" WeeklyPlanner/Features/EventDetail/PaperEventSheet.swift
```

- [ ] **Step 2: Make the CARD fill fully opaque** — wherever the card rectangle is filled with a translucent color/material (e.g. `theme.cream.opacity(0.9x)` or a `.thinMaterial`), replace with the solid theme color, keeping any dimmed BACKDROP behind the card as-is (the scrim is supposed to show the page; the card is not):

```swift
            // Card backing: solid paper — ruled lines must not bleed through
            // (suggestion 41).
            .fill(theme.cream)
```

If the fill is already solid, the bleed is the card's own `RuledLines()`-style underlay or a low-opacity shadow overlap — fix whichever it is; the acceptance check is Step 3's screenshot.

- [ ] **Step 3: Visual verification.** Build & run; open an event sheet over a day page; screenshot. No ruled line may be visible through the card area. Run `-only-testing:WeeklyPlannerUITests/EventCreateFlowUITests` to confirm no flow regression.

- [ ] **Step 4: Commit**

```bash
git add WeeklyPlanner/Features/EventDetail/PaperEventSheet.swift
git commit -m "fix(event-sheet): opaque card backing — ruled lines no longer bleed through (Phase 36a #41)"
```

---

### Task 7: UI tests — template chip flow + font pick persistence

**Files:**
- Create: `WeeklyPlannerUITests/QuickTemplateUITests.swift`
- Create: `WeeklyPlannerUITests/FontPickUITests.swift`

- [ ] **Step 1: `QuickTemplateUITests.swift`:**

```swift
import XCTest

final class QuickTemplateUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testGymChipPrefillsAndSaves() {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestSeedEmptyStore"]
        app.launch()

        let calendarTab = app.buttons["tabbar.tab.calendar"]
        if calendarTab.waitForExistence(timeout: 3) { calendarTab.tap() }

        let addLink = app.buttons["daypage.events.addRow"]
        XCTAssertTrue(addLink.waitForExistence(timeout: 5))
        addLink.tap()

        let gymChip = app.buttons["paperEventSheet.template.gym"]
        XCTAssertTrue(gymChip.waitForExistence(timeout: 3), "Template chips missing from create sheet")
        gymChip.tap()

        // Title got pre-filled.
        let titleField = app.textFields.firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 2))
        XCTAssertEqual(titleField.value as? String, "Gym")

        let save = app.buttons["paperEventSheet.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 2))
        save.tap()
        _ = save.waitForNonExistence(timeout: 5)

        let predicate = NSPredicate(format: "label CONTAINS %@", "Gym")
        XCTAssertTrue(app.descendants(matching: .any).matching(predicate).firstMatch
            .waitForExistence(timeout: 5), "Templated event not visible after save")
    }
}
```

- [ ] **Step 2: `FontPickUITests.swift`** (font cards — find the card's identifier by grepping `FontCard` for `accessibilityIdentifier`; if cards carry none, match by label `"Patrick Hand"`):

```swift
import XCTest

final class FontPickUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testPickingANewFontPersistsAcrossRelaunch() {
        let app = XCUIApplication()
        app.launch()

        let settingsTab = app.buttons["tabbar.tab.settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        let patrick = app.staticTexts["Patrick Hand"].firstMatch
        XCTAssertTrue(patrick.waitForExistence(timeout: 5), "New font card not rendered")
        patrick.tap()

        app.terminate()
        app.launch()
        let settingsAgain = app.buttons["tabbar.tab.settings"]
        if settingsAgain.waitForExistence(timeout: 5) { settingsAgain.tap() }

        // The card should still exist and be selected; selection markers are
        // visual, so assert the card exists and tap-state persisted via the
        // selected trait if exposed.
        let patrickAgain = app.staticTexts["Patrick Hand"].firstMatch
        XCTAssertTrue(patrickAgain.waitForExistence(timeout: 5), "Font choice did not survive relaunch")
    }
}
```

⚠️ Strengthen the relaunch assertion if `FontCard` exposes `isSelected` (grep its accessibility traits); the unit-level persistence is already covered by `SettingsViewModelTests.testSelectingFontPersists`.

- [ ] **Step 3: Run** — `-only-testing:WeeklyPlannerUITests/QuickTemplateUITests -only-testing:WeeklyPlannerUITests/FontPickUITests`. Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add WeeklyPlannerUITests/
git commit -m "test(personalization): template-chip flow + font pick persistence UI tests (Phase 36a)"
```

---

### Task 8: Full-suite verification (superpowers:verification-before-completion)

- [ ] **Step 1: FULL unit suite**

```bash
xcodegen generate
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=<available iPhone, iOS 26.5>' \
  -only-testing:WeeklyPlannerTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO
```

Expected: `** TEST SUCCEEDED **`, 0 failures (Phase 21 size/weight legibility audits must stay green with the new fonts).

- [ ] **Step 2: UI suites** — the two new ones + `EventCreateFlowUITests` + `SmokeUITests`. Expected: PASS.

- [ ] **Step 3: Spec checklist sweep** — `docs/phases/phase-36-personalization-expansion.md` items 41/42/47 only (45 lives in plan 36b). Confirm: 8 fonts preview live + apply app-wide, chips apply-as-before, footer reads finished w/ real version, licenses bundled in `docs/licenses/fonts/`.

- [ ] **Step 4: Screenshots** — Settings fonts grid (8 cards), create sheet with chips, sheet-over-page opacity, footer.

- [ ] **Step 5: Report** — branch, files, test counts, the templates-interpretation note (no prior template system existed; built chips per user decision).

---

## Self-review notes

- **Spec coverage:** 42 fonts (T1–2 + Phase 21 weight mapping via `weightFor`), 41 templates (T4–5 chips per user decision) + the transparency half of 41 (T6), 47 footer (T3). 45 (week-start) intentionally in plan 36b. SettingsViewModel count invariants updated (T2).
- **Type consistency:** `EventTemplate(id:title:category:durationMinutes:alertMinutes:)` + `EventComposerState.apply(_:)` identical in tests (T4) and chips (T5). `AppVersion.display/current` consistent T3.
- **Known adaptation points:** `CategoryPalette.inkColor` signature (T5), FontCard identifier for the UI test (T7), the exact translucent fill in T6 (investigation step built in).
- **License diligence:** all four families are SIL OFL; OFL texts committed under `docs/licenses/fonts/` (T1).
