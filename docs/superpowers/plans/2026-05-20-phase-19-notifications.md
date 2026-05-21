# Phase 19 — Notifications (Time + Location Reminders) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the `Reminder.timeBefore(minutes:)` / `Reminder.onArrive(...)` values already stored on `Event`, and the `TaskItem.reminderTime` / `TaskItem.locationReminder` fields already stored on `TaskItem`, into real iOS local notifications via `UNUserNotificationCenter` and `CLCircularRegion`. Apply the user's default reminder preference (already done by Phase 18's `DefaultReminderPolicy`); handle permission grant/deny, denied-banner display in Settings → Connections, snooze/action handling, and deep-link routing on notification tap.

**Architecture:**
- **SDK seams:** `NotificationCentering` protocol over `UNUserNotificationCenter` and `LocationManaging` protocol over `CLLocationManager`. Live impls thinly wrap the real frameworks; fake impls drive unit tests. No tests touch the system services.
- **Schedulers:** Two flavors, parallel shapes. `EventNotificationScheduler.schedule(event:)` reads `event.reminders` and emits stable-identifier `UNNotificationRequest`s — calendar triggers for `.timeBefore`, location triggers for `.onArrive`. `TaskNotificationScheduler.schedule(task:)` mirrors the shape for `TaskItem.reminderTime` (calendar) + `TaskItem.locationReminder` (location). Both clear existing requests for the same id before scheduling.
- **LocationReminderManager:** Owns a `LocationManaging` instance and the 20-region active set (iOS hard cap). Re-evaluates the priority queue (today's events first, then next 24h, then next 7d) on every `register(...)` call and on day rollover. `requestWhenInUseAuthorization` on the first onArrive toggle; escalates to `requestAlwaysAuthorization` only when the user enables onArrive on an event >24h out. Region entry → builds a `UNNotificationRequest` and hands it to `NotificationCentering.add(_:)`.
- **Authorization:** `NotificationAuthorization` exposes `request()` + `status()`. The first time the engine notices `defaultReminderMinutes != nil` AND status is `.notDetermined`, it triggers the system prompt (after the first event with a reminder is saved). Denied status surfaces a banner in `ConnectionsSection`.
- **Deep linking:** `DeepLinkRouter` (`@Observable`) holds an optional `.event(UUID)` / `.task(UUID)` pending request. `AppDelegate+Notifications` parses `userInfo` on cold-launch and on tap, writes into the router, then `AppShell` observes the router, switches tabs to `.calendar`, and propagates the open request to `DayPageView` (which already owns `openEventID`).
- **Re-schedule triggers:** A single `NotificationReschedulingObserver` listens to `.eventStoreDidChange` + `.taskStoreDidChange` (already posted today by the stores), re-fetches the affected entity, and calls the matching scheduler. After a permission grant, `rescheduleAll(in: now…now+30d)` runs once.
- **Logging:** `os.Logger(subsystem: "com.weeklyplanner.WeeklyPlanner", category: "Notifications")` for every schedule / cancel / region-event call. Honors the Phase 18 deviation memo (`--info` flag required to see).

**Tech Stack:** Swift 6, SwiftUI, UserNotifications, CoreLocation, SwiftData (read-only — no migration), `UIApplicationDelegateAdaptor`. No new SPM dep. New target entitlement: `com.apple.developer.usernotifications.time-sensitive`.

---

## File Structure

### Created

```
WeeklyPlanner/Notifications/NotificationCentering.swift                     # protocol seam + LiveNotificationCenter + FakeNotificationCenter
WeeklyPlanner/Notifications/NotificationAuthorization.swift                 # async request() + status() + .timeSensitive opt-in
WeeklyPlanner/Notifications/NotificationCategoryIDs.swift                   # eventCategory + taskCategory + action IDs + registration helper
WeeklyPlanner/Notifications/NotificationContentBuilder.swift                # title/subtitle/body for time + location flavors
WeeklyPlanner/Notifications/EventNotificationScheduler.swift                # schedule(event:) / cancel(eventID:) / rescheduleAll(in:)
WeeklyPlanner/Notifications/TaskNotificationScheduler.swift                 # schedule(task:) / cancel(taskID:) / rescheduleAll(in:)
WeeklyPlanner/Notifications/LocationManaging.swift                          # protocol seam + LiveLocationManager + FakeLocationManager
WeeklyPlanner/Notifications/LocationReminderManager.swift                   # 20-region priority queue + delegate routing
WeeklyPlanner/Notifications/NotificationReschedulingObserver.swift          # listens to eventStoreDidChange / taskStoreDidChange
WeeklyPlanner/Notifications/DeepLinkRouter.swift                            # @Observable pending event/task tap state
WeeklyPlanner/Notifications/AppDelegate+Notifications.swift                 # UIApplicationDelegate + UNUserNotificationCenterDelegate
WeeklyPlannerTests/Notifications/NotificationContentBuilderTests.swift      # 3 tests
WeeklyPlannerTests/Notifications/EventNotificationSchedulerTests.swift      # 5 tests
WeeklyPlannerTests/Notifications/TaskNotificationSchedulerTests.swift       # 4 tests
WeeklyPlannerTests/Notifications/LocationReminderManagerTests.swift         # 4 tests
WeeklyPlannerTests/Notifications/DeepLinkRouterTests.swift                  # 2 tests
WeeklyPlannerTests/Notifications/Support/FakeNotificationCenter.swift       # shared fake
WeeklyPlannerTests/Notifications/Support/FakeLocationManager.swift          # shared fake
```

### Modified

```
WeeklyPlanner/Supporting/WeeklyPlanner.entitlements                         # add com.apple.developer.usernotifications.time-sensitive
WeeklyPlanner/App/WeeklyPlannerApp.swift                                    # @UIApplicationDelegateAdaptor + env wiring for new keys
WeeklyPlanner/Navigation/AppShell.swift                                     # observe DeepLinkRouter; propagate event-open into Calendar tab
WeeklyPlanner/Features/DayPage/DayPageView.swift                            # observe DeepLinkRouter.pendingEventID → openEventID
WeeklyPlanner/Features/Settings/ConnectionsSection.swift                    # denied-notifications banner above the card
WeeklyPlanner/Stores/Environment+Stores.swift                               # \.notificationCenter, \.eventScheduler, \.taskScheduler, \.locationReminderManager, \.deepLinkRouter env keys + stubs
```

Note: `WeeklyPlanner/Notifications/DefaultReminderPolicy.swift` already exists from Phase 18. Phase 19 does **not** modify it.

---

## Sequencing Notes

Strict ordering within each task is TDD: write the failing test → run it red → minimal implementation → run it green → commit. Schedulers come first because the location/delegate/routing pieces all depend on them. The `AppDelegate` + AppShell glue lands last so we can integration-verify end-to-end on simulator.

Commit prefix convention: `feat(phase-19): …` / `test(phase-19): …` / `fix(phase-19): …` / `docs(phase-19): …` — matching Phase 17/18.

Honor Phase 18 deviations memo (`milestone-h-state` + `phase-18-deviations`):
- `os.Logger` subsystem `com.weeklyplanner.WeeklyPlanner`, category `Notifications`. Use `--info` to see at runtime.
- Test target keeps existing `WeeklyPlannerTests.entitlements`; `xcodebuild test` flags stay `CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO`.
- `Event` is `@Model final class`, mutate via class ref.
- Per-iteration try/catch in any loop that fans out across multiple events.

Build/test command (used for every "run tests" step below):
```bash
xcodebuild test \
  -project WeeklyPlanner.xcodeproj \
  -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.0' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO \
  -only-testing:WeeklyPlannerTests
```

When the steps below say `Run: <test command>` use the form above with the appropriate `-only-testing:` filter.

---

### Task 1: Add the `.timeSensitive` entitlement

**Files:**
- Modify: `WeeklyPlanner/Supporting/WeeklyPlanner.entitlements`

- [ ] **Step 1: Add the `time-sensitive` key**

Edit `WeeklyPlanner/Supporting/WeeklyPlanner.entitlements`. New full contents:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)com.weeklyplanner.WeeklyPlanner</string>
    </array>
    <key>com.apple.developer.usernotifications.time-sensitive</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 2: Regenerate the Xcode project**

Run: `xcodegen generate`
Expected: `Created project at WeeklyPlanner.xcodeproj`

- [ ] **Step 3: Confirm the entitlement is wired**

Run: `plutil -p WeeklyPlanner/Supporting/WeeklyPlanner.entitlements`
Expected: output contains `"com.apple.developer.usernotifications.time-sensitive" => 1`

- [ ] **Step 4: Smoke build**

Run:
```bash
xcodebuild build \
  -project WeeklyPlanner.xcodeproj \
  -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.0' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Supporting/WeeklyPlanner.entitlements WeeklyPlanner.xcodeproj
git commit -m "$(cat <<'EOF'
feat(phase-19): add time-sensitive notification entitlement

Required for interruptionLevel=.timeSensitive on event/task reminders so
they deliver even during Focus modes (App Store reviewer expectation).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: `NotificationCentering` protocol + `Live` + `Fake`

**Files:**
- Create: `WeeklyPlanner/Notifications/NotificationCentering.swift`
- Create: `WeeklyPlannerTests/Notifications/Support/FakeNotificationCenter.swift`

- [ ] **Step 1: Write the protocol seam + Live impl**

Create `WeeklyPlanner/Notifications/NotificationCentering.swift`:

```swift
import Foundation
import UserNotifications

/// Thin protocol seam over `UNUserNotificationCenter` so the schedulers can
/// be unit-tested without touching the system service.
@MainActor
protocol NotificationCentering: AnyObject {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>)
    func add(_ request: UNNotificationRequest) async throws
    func pendingRequests() async -> [UNNotificationRequest]
    func removePending(withIdentifiers: [String])
    func removeAllPending()
}

/// Production wrapper around `UNUserNotificationCenter.current()`. No logic;
/// every method delegates straight through. The whole point of this type is
/// that it can be swapped for `FakeNotificationCenter` in tests.
@MainActor
final class LiveNotificationCenter: NotificationCentering {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        center.setNotificationCategories(categories)
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func pendingRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }

    func removePending(withIdentifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeAllPending() {
        center.removeAllPendingNotificationRequests()
    }
}
```

Wait — fix the parameter name in `removePending`:

```swift
    func removePending(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
```

And update the protocol declaration to match: `func removePending(withIdentifiers identifiers: [String])`.

- [ ] **Step 2: Write the test fake**

Create `WeeklyPlannerTests/Notifications/Support/FakeNotificationCenter.swift`:

```swift
import Foundation
import UserNotifications
@testable import WeeklyPlanner

/// Records every call. Schedulers/managers under test inspect these arrays
/// for assertions. All methods complete synchronously — async signatures are
/// kept only to satisfy the protocol.
@MainActor
final class FakeNotificationCenter: NotificationCentering {
    var stubAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    var stubAuthorizationGranted: Bool = true
    var stubAuthorizationError: Error?

    private(set) var requestedAuthorizationOptions: UNAuthorizationOptions?
    private(set) var registeredCategories: Set<UNNotificationCategory> = []
    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var removedIdentifiers: [String] = []
    private(set) var removeAllCount: Int = 0

    func authorizationStatus() async -> UNAuthorizationStatus { stubAuthorizationStatus }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestedAuthorizationOptions = options
        if let error = stubAuthorizationError { throw error }
        return stubAuthorizationGranted
    }

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        registeredCategories = categories
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }

    func pendingRequests() async -> [UNNotificationRequest] { addedRequests }

    func removePending(withIdentifiers identifiers: [String]) {
        addedRequests.removeAll { identifiers.contains($0.identifier) }
        removedIdentifiers.append(contentsOf: identifiers)
    }

    func removeAllPending() {
        addedRequests.removeAll()
        removeAllCount += 1
    }
}
```

- [ ] **Step 3: Smoke-build to confirm the protocol compiles**

Run:
```bash
xcodebuild build \
  -project WeeklyPlanner.xcodeproj \
  -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.0' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add WeeklyPlanner/Notifications/NotificationCentering.swift \
        WeeklyPlannerTests/Notifications/Support/FakeNotificationCenter.swift
git commit -m "$(cat <<'EOF'
feat(phase-19): NotificationCentering protocol seam + test fake

Live impl wraps UNUserNotificationCenter.current(); FakeNotificationCenter
records every call so schedulers can be tested without touching the system
service. Mirrors the Phase 18 URLSessionProtocol pattern.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: `NotificationCategoryIDs`

**Files:**
- Create: `WeeklyPlanner/Notifications/NotificationCategoryIDs.swift`

- [ ] **Step 1: Implement the constants + builder**

Create `WeeklyPlanner/Notifications/NotificationCategoryIDs.swift`:

```swift
import UserNotifications

/// Identifiers for the actionable categories registered once at app launch.
///
/// Two category ids — one for events, one for tasks — so the action set
/// shown on long-press / swipe differs per content type. Action ids land in
/// `response.actionIdentifier` inside the `UNUserNotificationCenterDelegate`
/// callback.
enum NotificationCategoryIDs {
    static let event = "com.weeklyplanner.notification.event"
    static let task  = "com.weeklyplanner.notification.task"

    enum Action {
        static let viewEvent  = "com.weeklyplanner.action.viewEvent"
        static let snooze10   = "com.weeklyplanner.action.snooze10"
        static let viewTask   = "com.weeklyplanner.action.viewTask"
        static let markDone   = "com.weeklyplanner.action.markDone"
    }

    /// The full category set to register via `NotificationCentering.setNotificationCategories(_:)`
    /// during app launch. Phase 21 will localize the user-visible action titles.
    static func all() -> Set<UNNotificationCategory> {
        let view = UNNotificationAction(
            identifier: Action.viewEvent,
            title: String(localized: "View"),
            options: [.foreground]
        )
        let snooze = UNNotificationAction(
            identifier: Action.snooze10,
            title: String(localized: "Snooze 10 min"),
            options: []
        )
        let eventCategory = UNNotificationCategory(
            identifier: event,
            actions: [view, snooze],
            intentIdentifiers: [],
            options: []
        )

        let viewTask = UNNotificationAction(
            identifier: Action.viewTask,
            title: String(localized: "View"),
            options: [.foreground]
        )
        let markDone = UNNotificationAction(
            identifier: Action.markDone,
            title: String(localized: "Mark Done"),
            options: [.destructive]
        )
        let taskCategory = UNNotificationCategory(
            identifier: task,
            actions: [viewTask, markDone],
            intentIdentifiers: [],
            options: []
        )

        return [eventCategory, taskCategory]
    }
}
```

- [ ] **Step 2: Smoke-build**

Run:
```bash
xcodebuild build \
  -project WeeklyPlanner.xcodeproj \
  -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.0' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Notifications/NotificationCategoryIDs.swift
git commit -m "$(cat <<'EOF'
feat(phase-19): notification category + action identifiers

Two categories (event, task) with the spec's action sets. Register once at
launch via NotificationCentering.setNotificationCategories(_:).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: `NotificationAuthorization`

**Files:**
- Create: `WeeklyPlanner/Notifications/NotificationAuthorization.swift`

- [ ] **Step 1: Implement**

Create `WeeklyPlanner/Notifications/NotificationAuthorization.swift`:

```swift
import Foundation
import UserNotifications
import os

/// Wraps the alert+sound+badge+timeSensitive opt-in flow. Callers either
/// observe the current `status()` to gate UI affordances, or fire `request()`
/// on first need.
@MainActor
final class NotificationAuthorization {
    static let log = Logger(subsystem: "com.weeklyplanner.WeeklyPlanner", category: "Notifications")

    private let center: any NotificationCentering

    init(center: any NotificationCentering) {
        self.center = center
    }

    /// Returns the current OS-reported status. Cheap; safe to call every render.
    func status() async -> UNAuthorizationStatus {
        await center.authorizationStatus()
    }

    /// Requests `[.alert, .sound, .badge, .timeSensitive]`. Returns the user's
    /// answer translated to a `UNAuthorizationStatus`. Logs the outcome via
    /// `os.Logger` (use `log show --info`).
    func request() async -> UNAuthorizationStatus {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge, .timeSensitive])
            Self.log.info("Notification auth request granted=\(granted, privacy: .public)")
        } catch {
            Self.log.error("Notification auth request failed: \(String(describing: error), privacy: .public)")
        }
        return await center.authorizationStatus()
    }
}
```

- [ ] **Step 2: Smoke-build**

Run the build command from Task 3 Step 2.
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Notifications/NotificationAuthorization.swift
git commit -m "$(cat <<'EOF'
feat(phase-19): NotificationAuthorization request + status wrapper

Asks for [.alert, .sound, .badge, .timeSensitive] and logs the outcome under
the Notifications os.Logger category for on-device debugging.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: `NotificationContentBuilder` + tests

**Files:**
- Create: `WeeklyPlanner/Notifications/NotificationContentBuilder.swift`
- Create: `WeeklyPlannerTests/Notifications/NotificationContentBuilderTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `WeeklyPlannerTests/Notifications/NotificationContentBuilderTests.swift`:

```swift
import XCTest
@testable import WeeklyPlanner

@MainActor
final class NotificationContentBuilderTests: XCTestCase {

    func testTitleTruncatedAt64Chars() {
        let long = String(repeating: "x", count: 70)
        let content = NotificationContentBuilder.timeBased(
            title: long,
            startsAt: Date(timeIntervalSinceReferenceDate: 800_000_000),
            location: nil,
            minutesBefore: 15
        )
        XCTAssertEqual(content.title.count, 64)
        XCTAssertTrue(content.title.hasSuffix("…"))
    }

    func testTimeBasedBodyContainsMinutes() {
        let content = NotificationContentBuilder.timeBased(
            title: "Lunch",
            startsAt: Date(timeIntervalSinceReferenceDate: 800_000_000),
            location: "Café Bleu",
            minutesBefore: 15
        )
        XCTAssertTrue(content.body.contains("15"))
        XCTAssertTrue(content.subtitle.contains("Café Bleu"))
    }

    func testLocationBasedBodyMentionsArrival() {
        let content = NotificationContentBuilder.locationBased(
            title: "Lunch",
            locationName: "Marina"
        )
        XCTAssertTrue(content.body.contains("Marina"))
    }
}
```

- [ ] **Step 2: Run the failing test**

Run:
```bash
xcodebuild test \
  -project WeeklyPlanner.xcodeproj \
  -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.0' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO \
  -only-testing:WeeklyPlannerTests/NotificationContentBuilderTests
```
Expected: build failure with "cannot find 'NotificationContentBuilder' in scope".

- [ ] **Step 3: Implement**

Create `WeeklyPlanner/Notifications/NotificationContentBuilder.swift`:

```swift
import Foundation
import UserNotifications

/// Builds `UNNotificationContent` for time-based and location-based alerts.
///
/// All user-facing strings go through `String(localized:)` so Phase 21 can
/// translate them by simply filling the catalog. Titles longer than 64 chars
/// are truncated with an ellipsis (`"…"`) — keeps Lock Screen previews tidy.
enum NotificationContentBuilder {
    static let maxTitleLength = 64

    static func timeBased(title: String,
                          startsAt: Date,
                          location: String?,
                          minutesBefore: Int) -> UNMutableNotificationContent
    {
        let content = baseContent()
        content.title = truncate(title)
        content.subtitle = makeSubtitle(startsAt: startsAt, location: location)
        let formatString = String(localized: "In \(minutesBefore) minutes.",
                                  comment: "Time-based reminder body. Argument is minutes-before-start.")
        content.body = formatString
        content.categoryIdentifier = NotificationCategoryIDs.event
        return content
    }

    static func locationBased(title: String, locationName: String) -> UNMutableNotificationContent {
        let content = baseContent()
        content.title = truncate(title)
        let formatString = String(localized: "You've arrived at \(locationName).",
                                  comment: "Location-based reminder body. Argument is the place name.")
        content.body = formatString
        content.subtitle = locationName
        content.categoryIdentifier = NotificationCategoryIDs.event
        return content
    }

    /// Mirror of `timeBased`/`locationBased` for tasks. Uses the task category
    /// so the action set includes "Mark Done".
    static func taskTimeBased(title: String, dueAt: Date) -> UNMutableNotificationContent {
        let content = baseContent()
        content.title = truncate(title)
        content.subtitle = makeSubtitle(startsAt: dueAt, location: nil)
        content.body = String(localized: "Task reminder.", comment: "Task time-based body.")
        content.categoryIdentifier = NotificationCategoryIDs.task
        return content
    }

    static func taskLocationBased(title: String, locationName: String) -> UNMutableNotificationContent {
        let content = baseContent()
        content.title = truncate(title)
        content.subtitle = locationName
        content.body = String(localized: "You've arrived at \(locationName).",
                              comment: "Task location-based body.")
        content.categoryIdentifier = NotificationCategoryIDs.task
        return content
    }

    private static func baseContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        return content
    }

    private static func truncate(_ title: String) -> String {
        guard title.count > maxTitleLength else { return title }
        let prefix = title.prefix(maxTitleLength - 1)
        return "\(prefix)…"
    }

    private static func makeSubtitle(startsAt: Date, location: String?) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let time = formatter.string(from: startsAt)
        if let location, !location.isEmpty {
            return "\(time) · \(location)"
        }
        return time
    }
}
```

- [ ] **Step 4: Run tests**

Run the test command from Step 2.
Expected: `Test Suite 'NotificationContentBuilderTests' passed`, 3 tests succeeded.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Notifications/NotificationContentBuilder.swift \
        WeeklyPlannerTests/Notifications/NotificationContentBuilderTests.swift
git commit -m "$(cat <<'EOF'
feat(phase-19): NotificationContentBuilder for time + location alerts

Title truncated at 64 chars with ellipsis. All user-facing strings via
String(localized:) so Phase 21 can fill the catalog. .timeSensitive
interruption level on every content (entitlement landed in Task 1).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: `EventNotificationScheduler` + tests

**Files:**
- Create: `WeeklyPlanner/Notifications/EventNotificationScheduler.swift`
- Create: `WeeklyPlannerTests/Notifications/EventNotificationSchedulerTests.swift`

This task uses `LocationReminderManager` for the location-trigger path. We **inject** the location manager as a dependency (so we can also fake it in this test). The real `LocationReminderManager` lands in Task 8.

For Task 6's tests we only need the protocol surface — define it now in this same task and stub the impl with a fake. The real impl ships in Task 8.

- [ ] **Step 1: Add the `LocationRegistering` protocol**

Create `WeeklyPlanner/Notifications/LocationRegistering.swift`:

```swift
import Foundation

/// Subset of `LocationReminderManager` that the schedulers depend on. Pulled
/// out as a protocol so `EventNotificationSchedulerTests` can fake region
/// registration without instantiating the real manager.
@MainActor
protocol LocationRegistering: AnyObject {
    /// Registers a region for entry monitoring. Returns the request identifier
    /// that the location manager will use when it fires the eventual
    /// `UNNotificationRequest`, or `nil` if the region was rejected (e.g. the
    /// 20-region cap is full and this region's priority is lower than all
    /// active ones).
    @discardableResult
    func register(eventID: UUID,
                  reminder: LocationReminder,
                  content: @escaping () -> UNMutableNotificationContent,
                  proximityInDays: Int) -> String?

    func unregister(eventID: UUID)
}
```

(`UNMutableNotificationContent` needs the import.) Update the file to:

```swift
import Foundation
import UserNotifications

@MainActor
protocol LocationRegistering: AnyObject {
    @discardableResult
    func register(eventID: UUID,
                  reminder: LocationReminder,
                  content: @escaping () -> UNMutableNotificationContent,
                  proximityInDays: Int) -> String?

    func unregister(eventID: UUID)
}
```

- [ ] **Step 2: Write the failing scheduler tests**

Create `WeeklyPlannerTests/Notifications/EventNotificationSchedulerTests.swift`:

```swift
import XCTest
import UserNotifications
@testable import WeeklyPlanner

@MainActor
final class EventNotificationSchedulerTests: XCTestCase {

    private var center: FakeNotificationCenter!
    private var locations: FakeLocationRegistrar!
    private var scheduler: EventNotificationScheduler!

    override func setUp() async throws {
        center = FakeNotificationCenter()
        locations = FakeLocationRegistrar()
        scheduler = EventNotificationScheduler(center: center, locationRegistrar: locations)
    }

    func testScheduleTimeReminderProducesCalendarRequest() async throws {
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let event = Event(
            title: "Lunch with Sara",
            start: start,
            end: start.addingTimeInterval(3600),
            location: "Café Bleu",
            category: .personal,
            reminders: [.timeBefore(minutes: 15)]
        )

        try await scheduler.schedule(event: event)

        XCTAssertEqual(center.addedRequests.count, 1)
        let req = try XCTUnwrap(center.addedRequests.first)
        XCTAssertEqual(req.identifier, "event-\(event.id.uuidString)-time-15")
        XCTAssertNotNil(req.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(req.content.title, "Lunch with Sara")
    }

    func testScheduleArrivalRegistersRegion() async throws {
        let start = Date().addingTimeInterval(60 * 60 * 24 * 2)
        let event = Event(
            title: "Sara's Birthday",
            start: start,
            end: start.addingTimeInterval(3600),
            location: "Trick Dog",
            category: .personal,
            reminders: [.onArrive(LocationReminder(name: "Trick Dog",
                                                  latitude: 37.759,
                                                  longitude: -122.412,
                                                  radiusMeters: 150))]
        )

        try await scheduler.schedule(event: event)

        XCTAssertEqual(locations.registered.count, 1)
        let registered = try XCTUnwrap(locations.registered.first)
        XCTAssertEqual(registered.eventID, event.id)
        XCTAssertEqual(registered.reminder.name, "Trick Dog")
    }

    func testRescheduleClearsOldRequestsByPrefix() async throws {
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let event = Event(
            title: "Lunch",
            start: start,
            end: start.addingTimeInterval(3600),
            category: .personal,
            reminders: [.timeBefore(minutes: 15)]
        )

        try await scheduler.schedule(event: event)
        XCTAssertEqual(center.addedRequests.count, 1)
        // Change reminders, schedule again.
        event.reminders = [.timeBefore(minutes: 30)]
        try await scheduler.schedule(event: event)

        XCTAssertEqual(center.addedRequests.count, 1, "Old request should have been cleared before adding the new one")
        XCTAssertEqual(center.addedRequests.first?.identifier, "event-\(event.id.uuidString)-time-30")
        XCTAssertTrue(center.removedIdentifiers.contains("event-\(event.id.uuidString)-time-15"))
    }

    func testCancelByEventIDRemovesAllRequests() async throws {
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let event = Event(
            title: "Lunch",
            start: start,
            end: start.addingTimeInterval(3600),
            category: .personal,
            reminders: [.timeBefore(minutes: 15), .timeBefore(minutes: 60)]
        )
        try await scheduler.schedule(event: event)
        XCTAssertEqual(center.addedRequests.count, 2)

        await scheduler.cancel(eventID: event.id)

        XCTAssertTrue(center.addedRequests.isEmpty)
        XCTAssertEqual(locations.unregistered.last, event.id)
    }

    func testPastTimeReminderIsSkipped() async throws {
        // Reminder time would land in the past — scheduler should not add it.
        let start = Date().addingTimeInterval(60)            // 1 min from now
        let event = Event(
            title: "Imminent",
            start: start,
            end: start.addingTimeInterval(3600),
            category: .personal,
            reminders: [.timeBefore(minutes: 15)]            // -14 min from now
        )
        try await scheduler.schedule(event: event)
        XCTAssertTrue(center.addedRequests.isEmpty)
    }
}

/// In-test fake for `LocationRegistering`. Just records inputs.
@MainActor
final class FakeLocationRegistrar: LocationRegistering {
    struct Registration {
        let eventID: UUID
        let reminder: LocationReminder
        let proximityInDays: Int
    }

    private(set) var registered: [Registration] = []
    private(set) var unregistered: [UUID] = []
    var stubAcceptsAll: Bool = true

    func register(eventID: UUID,
                  reminder: LocationReminder,
                  content: @escaping () -> UNMutableNotificationContent,
                  proximityInDays: Int) -> String?
    {
        registered.append(.init(eventID: eventID, reminder: reminder, proximityInDays: proximityInDays))
        return stubAcceptsAll ? "event-\(eventID.uuidString)-arrive" : nil
    }

    func unregister(eventID: UUID) {
        unregistered.append(eventID)
    }
}
```

- [ ] **Step 3: Run the failing tests**

Run:
```bash
xcodebuild test \
  -project WeeklyPlanner.xcodeproj \
  -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.0' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO \
  -only-testing:WeeklyPlannerTests/EventNotificationSchedulerTests
```
Expected: build failure — `EventNotificationScheduler` not in scope.

- [ ] **Step 4: Implement the scheduler**

Create `WeeklyPlanner/Notifications/EventNotificationScheduler.swift`:

```swift
import Foundation
import UserNotifications
import os

/// Reads `event.reminders` and emits stable-identifier `UNNotificationRequest`s.
///
/// Identifier shape — predictable on purpose so the rescheduling observer can
/// clear them with `removePending(withIdentifiers:)` without keeping any side
/// state:
///   - `event-{uuid}-time-{minutes}` — `UNCalendarNotificationTrigger`
///   - `event-{uuid}-arrive`         — `UNLocationNotificationTrigger`
///                                     (registered by `LocationRegistering`)
@MainActor
final class EventNotificationScheduler {
    private static let log = Logger(subsystem: "com.weeklyplanner.WeeklyPlanner", category: "Notifications")

    private let center: any NotificationCentering
    private let locationRegistrar: any LocationRegistering
    private let eventStore: (any EventStoring)?

    init(center: any NotificationCentering,
         locationRegistrar: any LocationRegistering,
         eventStore: (any EventStoring)? = nil)
    {
        self.center = center
        self.locationRegistrar = locationRegistrar
        self.eventStore = eventStore
    }

    /// Clears any existing notifications for this event and re-schedules from
    /// its current `reminders`. Idempotent.
    func schedule(event: Event) async throws {
        let prefix = "event-\(event.id.uuidString)-"
        let pending = await center.pendingRequests()
        let toRemove = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        if !toRemove.isEmpty {
            center.removePending(withIdentifiers: toRemove)
            Self.log.info("Cleared \(toRemove.count) pending requests for event \(event.id, privacy: .public)")
        }
        locationRegistrar.unregister(eventID: event.id)

        for reminder in event.reminders {
            do {
                switch reminder {
                case let .timeBefore(minutes):
                    try await scheduleTime(event: event, minutesBefore: minutes)
                case let .onArrive(location):
                    scheduleArrival(event: event, reminder: location)
                }
            } catch {
                Self.log.error("Schedule failed for event \(event.id, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
    }

    /// Removes every notification request for this event id and any registered
    /// region.
    func cancel(eventID: UUID) async {
        let prefix = "event-\(eventID.uuidString)-"
        let pending = await center.pendingRequests()
        let toRemove = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        if !toRemove.isEmpty {
            center.removePending(withIdentifiers: toRemove)
        }
        locationRegistrar.unregister(eventID: eventID)
    }

    /// Re-schedules every event whose start is inside `window`. Called after a
    /// notification-authorization grant and on the future manual-add flow.
    func rescheduleAll(in window: ClosedRange<Date>) async {
        guard let store = eventStore else {
            Self.log.error("rescheduleAll called without an EventStoring — no-op")
            return
        }
        // Compute a coarse week range bracketing the window.
        let startOffset = Self.weekOffset(from: window.lowerBound, today: Date())
        let endOffset = Self.weekOffset(from: window.upperBound, today: Date())
        var events: [Event] = []
        for offset in startOffset...endOffset {
            do {
                let weekEvents = try await store.events(forWeekOffset: offset, today: Date())
                events.append(contentsOf: weekEvents)
            } catch {
                Self.log.error("rescheduleAll fetch failed for offset \(offset, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
        for event in events where window.contains(event.start) {
            do { try await schedule(event: event) }
            catch { Self.log.error("rescheduleAll schedule failed: \(String(describing: error), privacy: .public)") }
        }
    }

    // MARK: - Private

    private func scheduleTime(event: Event, minutesBefore: Int) async throws {
        let fireDate = event.start.addingTimeInterval(TimeInterval(-minutesBefore * 60))
        guard fireDate > Date() else { return }   // Past — silently skip.

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute],
                                                         from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let content = NotificationContentBuilder.timeBased(
            title: event.title,
            startsAt: event.start,
            location: event.location,
            minutesBefore: minutesBefore
        )
        content.userInfo = ["event.id": event.id.uuidString]

        let id = "event-\(event.id.uuidString)-time-\(minutesBefore)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try await center.add(request)
        Self.log.info("Scheduled event-time \(id, privacy: .public) for \(fireDate, privacy: .public)")
    }

    private func scheduleArrival(event: Event, reminder: LocationReminder) {
        let proximity = max(0, Calendar.current.dateComponents([.day], from: Date(), to: event.start).day ?? 0)
        let identifier = "event-\(event.id.uuidString)-arrive"
        let title = event.title
        let location = event.location
        let _ = locationRegistrar.register(
            eventID: event.id,
            reminder: reminder,
            content: {
                let content = NotificationContentBuilder.locationBased(title: title, locationName: reminder.name)
                if let location { content.subtitle = location }
                content.userInfo = ["event.id": event.id.uuidString]
                return content
            },
            proximityInDays: proximity
        )
        Self.log.info("Registered arrival region \(identifier, privacy: .public) proximityDays=\(proximity, privacy: .public)")
    }

    /// Crude Monday-based week offset from `today` to `date`. Mirrors
    /// `SwiftDataEventStore.weekBounds` semantics; suitable for selecting the
    /// fetch window.
    private static func weekOffset(from date: Date, today: Date) -> Int {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.weekOfYear], from: today, to: date)
        return comps.weekOfYear ?? 0
    }
}
```

- [ ] **Step 5: Run tests, fix until green**

Run the test command from Step 3.
Expected: `Test Suite 'EventNotificationSchedulerTests' passed`, 5 tests succeeded.

- [ ] **Step 6: Commit**

```bash
git add WeeklyPlanner/Notifications/LocationRegistering.swift \
        WeeklyPlanner/Notifications/EventNotificationScheduler.swift \
        WeeklyPlannerTests/Notifications/EventNotificationSchedulerTests.swift
git commit -m "$(cat <<'EOF'
feat(phase-19): EventNotificationScheduler with calendar + location triggers

schedule() clears old requests by id prefix, then re-emits from event.reminders.
LocationRegistering protocol pulled out so the real LocationReminderManager
can land in Task 8 without forking the API.

5 unit tests cover the happy path, region registration, re-schedule, cancel,
and past-time skip.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: `TaskNotificationScheduler` + tests

**Files:**
- Create: `WeeklyPlanner/Notifications/TaskNotificationScheduler.swift`
- Create: `WeeklyPlannerTests/Notifications/TaskNotificationSchedulerTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `WeeklyPlannerTests/Notifications/TaskNotificationSchedulerTests.swift`:

```swift
import XCTest
import UserNotifications
@testable import WeeklyPlanner

@MainActor
final class TaskNotificationSchedulerTests: XCTestCase {

    private var center: FakeNotificationCenter!
    private var locations: FakeLocationRegistrar!
    private var scheduler: TaskNotificationScheduler!

    override func setUp() async throws {
        center = FakeNotificationCenter()
        locations = FakeLocationRegistrar()
        scheduler = TaskNotificationScheduler(center: center, locationRegistrar: locations)
    }

    func testScheduleReminderTimeProducesCalendarRequest() async throws {
        let due = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let task = TaskItem(title: "Pay rent", due: due, category: .personal, reminderTime: due)

        try await scheduler.schedule(task: task)

        XCTAssertEqual(center.addedRequests.count, 1)
        let req = try XCTUnwrap(center.addedRequests.first)
        XCTAssertEqual(req.identifier, "task-\(task.id.uuidString)-time")
        XCTAssertNotNil(req.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(req.content.categoryIdentifier, NotificationCategoryIDs.task)
    }

    func testScheduleLocationReminderRegistersRegion() async throws {
        let due = Date().addingTimeInterval(60 * 60 * 24 * 2)
        let task = TaskItem(
            title: "Pick up keys",
            due: due,
            category: .personal,
            locationReminder: LocationReminder(name: "Marina",
                                               latitude: 37.806,
                                               longitude: -122.432,
                                               radiusMeters: 150)
        )
        try await scheduler.schedule(task: task)

        XCTAssertTrue(center.addedRequests.isEmpty)
        XCTAssertEqual(locations.registered.count, 1)
        XCTAssertEqual(locations.registered.first?.eventID, task.id)
    }

    func testCancelByTaskIDClearsRequestsAndRegions() async throws {
        let due = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let task = TaskItem(title: "Pay rent", due: due, category: .personal, reminderTime: due)
        try await scheduler.schedule(task: task)
        XCTAssertEqual(center.addedRequests.count, 1)

        await scheduler.cancel(taskID: task.id)

        XCTAssertTrue(center.addedRequests.isEmpty)
        XCTAssertEqual(locations.unregistered.last, task.id)
    }

    func testNoReminderFieldsSchedulesNothing() async throws {
        let due = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let task = TaskItem(title: "Read book", due: due, category: .personal)   // No reminders at all.

        try await scheduler.schedule(task: task)

        XCTAssertTrue(center.addedRequests.isEmpty)
        XCTAssertTrue(locations.registered.isEmpty)
    }
}
```

- [ ] **Step 2: Run the failing tests**

Run:
```bash
xcodebuild test \
  -project WeeklyPlanner.xcodeproj \
  -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.0' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO \
  -only-testing:WeeklyPlannerTests/TaskNotificationSchedulerTests
```
Expected: build failure — `TaskNotificationScheduler` not in scope.

- [ ] **Step 3: Implement the scheduler**

Create `WeeklyPlanner/Notifications/TaskNotificationScheduler.swift`:

```swift
import Foundation
import UserNotifications
import os

/// Mirrors `EventNotificationScheduler` for `TaskItem` — `reminderTime`
/// becomes a `UNCalendarNotificationTrigger`, `locationReminder` becomes a
/// region monitored by `LocationRegistering`.
///
/// Identifier shapes:
///   - `task-{uuid}-time`   — calendar trigger
///   - `task-{uuid}-arrive` — location trigger (registered through registrar)
@MainActor
final class TaskNotificationScheduler {
    private static let log = Logger(subsystem: "com.weeklyplanner.WeeklyPlanner", category: "Notifications")

    private let center: any NotificationCentering
    private let locationRegistrar: any LocationRegistering
    private let taskStore: (any TaskStoring)?

    init(center: any NotificationCentering,
         locationRegistrar: any LocationRegistering,
         taskStore: (any TaskStoring)? = nil)
    {
        self.center = center
        self.locationRegistrar = locationRegistrar
        self.taskStore = taskStore
    }

    func schedule(task: TaskItem) async throws {
        let prefix = "task-\(task.id.uuidString)-"
        let pending = await center.pendingRequests()
        let toRemove = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        if !toRemove.isEmpty {
            center.removePending(withIdentifiers: toRemove)
        }
        locationRegistrar.unregister(eventID: task.id)

        if let when = task.reminderTime, when > Date() {
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: when)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let content = NotificationContentBuilder.taskTimeBased(title: task.title, dueAt: when)
            content.userInfo = ["task.id": task.id.uuidString]
            let id = "task-\(task.id.uuidString)-time"
            try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            Self.log.info("Scheduled task-time \(id, privacy: .public)")
        }

        if let region = task.locationReminder {
            let title = task.title
            let _ = locationRegistrar.register(
                eventID: task.id,
                reminder: region,
                content: {
                    let content = NotificationContentBuilder.taskLocationBased(title: title, locationName: region.name)
                    content.userInfo = ["task.id": task.id.uuidString]
                    return content
                },
                proximityInDays: max(0, Calendar.current.dateComponents([.day], from: Date(), to: task.due).day ?? 0)
            )
            Self.log.info("Registered task arrival region \(task.id, privacy: .public)")
        }
    }

    func cancel(taskID: UUID) async {
        let prefix = "task-\(taskID.uuidString)-"
        let pending = await center.pendingRequests()
        let toRemove = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        if !toRemove.isEmpty {
            center.removePending(withIdentifiers: toRemove)
        }
        locationRegistrar.unregister(eventID: taskID)
    }

    func rescheduleAll(in window: ClosedRange<Date>) async {
        guard let store = taskStore else {
            Self.log.error("rescheduleAll called without TaskStoring")
            return
        }
        // Tasks are weekly-bucketed; iterate the same week offsets as events.
        let cal = Calendar(identifier: .gregorian)
        let startOffset = cal.dateComponents([.weekOfYear], from: Date(), to: window.lowerBound).weekOfYear ?? 0
        let endOffset = cal.dateComponents([.weekOfYear], from: Date(), to: window.upperBound).weekOfYear ?? 0
        var tasks: [TaskItem] = []
        for offset in startOffset...endOffset {
            do { tasks.append(contentsOf: try await store.tasks(forWeekOffset: offset, today: Date())) }
            catch { Self.log.error("rescheduleAll task fetch failed: \(String(describing: error), privacy: .public)") }
        }
        for task in tasks where task.done == false {
            do { try await schedule(task: task) }
            catch { Self.log.error("rescheduleAll task schedule failed: \(String(describing: error), privacy: .public)") }
        }
    }
}
```

- [ ] **Step 4: Run tests**

Run the test command from Step 2.
Expected: `Test Suite 'TaskNotificationSchedulerTests' passed`, 4 tests succeeded.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Notifications/TaskNotificationScheduler.swift \
        WeeklyPlannerTests/Notifications/TaskNotificationSchedulerTests.swift
git commit -m "$(cat <<'EOF'
feat(phase-19): TaskNotificationScheduler with calendar + location triggers

Mirrors EventNotificationScheduler shape for TaskItem.reminderTime and
TaskItem.locationReminder. 4 unit tests cover the matrix
(time-only / location-only / cancel / no-reminders).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: `LocationManaging` seam + `LocationReminderManager` + tests

**Files:**
- Create: `WeeklyPlanner/Notifications/LocationManaging.swift`
- Create: `WeeklyPlannerTests/Notifications/Support/FakeLocationManager.swift`
- Create: `WeeklyPlanner/Notifications/LocationReminderManager.swift`
- Create: `WeeklyPlannerTests/Notifications/LocationReminderManagerTests.swift`

- [ ] **Step 1: Add the location seam + Live + Fake**

Create `WeeklyPlanner/Notifications/LocationManaging.swift`:

```swift
import CoreLocation
import Foundation

/// Subset of `CLLocationManager` that `LocationReminderManager` calls into.
/// Pulled into a protocol so tests can drive region entry without monitoring
/// a real device.
@MainActor
protocol LocationManaging: AnyObject {
    var locationDelegate: CLLocationManagerDelegate? { get set }
    var authorizationStatus: CLAuthorizationStatus { get }
    var monitoredRegions: Set<CLRegion> { get }

    func requestWhenInUseAuthorization()
    func requestAlwaysAuthorization()
    func startMonitoring(for region: CLRegion)
    func stopMonitoring(for region: CLRegion)
}

@MainActor
final class LiveLocationManager: NSObject, LocationManaging {
    private let manager: CLLocationManager

    var locationDelegate: CLLocationManagerDelegate? {
        get { manager.delegate }
        set { manager.delegate = newValue }
    }

    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }
    var monitoredRegions: Set<CLRegion> { manager.monitoredRegions }

    override init() {
        self.manager = CLLocationManager()
        super.init()
    }

    func requestWhenInUseAuthorization() { manager.requestWhenInUseAuthorization() }
    func requestAlwaysAuthorization() { manager.requestAlwaysAuthorization() }
    func startMonitoring(for region: CLRegion) { manager.startMonitoring(for: region) }
    func stopMonitoring(for region: CLRegion) { manager.stopMonitoring(for: region) }
}
```

Create `WeeklyPlannerTests/Notifications/Support/FakeLocationManager.swift`:

```swift
import CoreLocation
import Foundation
@testable import WeeklyPlanner

@MainActor
final class FakeLocationManager: LocationManaging {
    var locationDelegate: CLLocationManagerDelegate?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var monitoredRegions: Set<CLRegion> = []

    private(set) var whenInUseRequestCount = 0
    private(set) var alwaysRequestCount = 0

    func requestWhenInUseAuthorization() { whenInUseRequestCount += 1 }
    func requestAlwaysAuthorization()    { alwaysRequestCount += 1 }

    func startMonitoring(for region: CLRegion) {
        monitoredRegions.insert(region)
    }

    func stopMonitoring(for region: CLRegion) {
        monitoredRegions.remove(region)
    }

    /// Simulates region entry by invoking the delegate.
    func simulateEntry(_ region: CLRegion) {
        guard let manager = locationDelegate else { return }
        let fakeCL = CLLocationManager()
        manager.locationManager?(fakeCL, didEnterRegion: region)
    }
}
```

- [ ] **Step 2: Write the failing manager tests**

Create `WeeklyPlannerTests/Notifications/LocationReminderManagerTests.swift`:

```swift
import CoreLocation
import UserNotifications
import XCTest
@testable import WeeklyPlanner

@MainActor
final class LocationReminderManagerTests: XCTestCase {

    private var location: FakeLocationManager!
    private var center: FakeNotificationCenter!
    private var manager: LocationReminderManager!

    override func setUp() async throws {
        location = FakeLocationManager()
        center = FakeNotificationCenter()
        manager = LocationReminderManager(location: location, center: center)
    }

    func testRegisterUpTo20Regions() {
        for i in 0..<25 {
            let id = UUID()
            _ = manager.register(
                eventID: id,
                reminder: LocationReminder(name: "P\(i)", latitude: 0, longitude: 0, radiusMeters: 150),
                content: { UNMutableNotificationContent() },
                proximityInDays: 5    // All same priority — keep insertion order.
            )
        }
        XCTAssertLessThanOrEqual(location.monitoredRegions.count, 20)
    }

    func testPriorityKeepsTodayEventsActive() {
        // Fill with far-future events first.
        var farIDs: [UUID] = []
        for i in 0..<20 {
            let id = UUID()
            farIDs.append(id)
            _ = manager.register(
                eventID: id,
                reminder: LocationReminder(name: "Far\(i)", latitude: 0, longitude: 0, radiusMeters: 150),
                content: { UNMutableNotificationContent() },
                proximityInDays: 7
            )
        }
        XCTAssertEqual(location.monitoredRegions.count, 20)

        // Now register a today event. It should evict the lowest-priority far-future one.
        let todayID = UUID()
        _ = manager.register(
            eventID: todayID,
            reminder: LocationReminder(name: "Today", latitude: 0, longitude: 0, radiusMeters: 150),
            content: { UNMutableNotificationContent() },
            proximityInDays: 0
        )

        XCTAssertEqual(location.monitoredRegions.count, 20)
        XCTAssertTrue(location.monitoredRegions.contains { $0.identifier.contains(todayID.uuidString) })
    }

    func testRegionEntryFiresNotification() async {
        let id = UUID()
        _ = manager.register(
            eventID: id,
            reminder: LocationReminder(name: "Marina", latitude: 37.8, longitude: -122.4, radiusMeters: 150),
            content: {
                let c = UNMutableNotificationContent()
                c.title = "Arrived"
                return c
            },
            proximityInDays: 0
        )
        let region = try! XCTUnwrap(location.monitoredRegions.first { $0.identifier.contains(id.uuidString) })

        location.simulateEntry(region)

        // Allow the async add to flush.
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(center.addedRequests.count, 1)
        XCTAssertEqual(center.addedRequests.first?.content.title, "Arrived")
    }

    func testEscalateToAlwaysAuthOnFarFutureEvent() {
        location.authorizationStatus = .authorizedWhenInUse
        _ = manager.register(
            eventID: UUID(),
            reminder: LocationReminder(name: "Beach", latitude: 0, longitude: 0, radiusMeters: 150),
            content: { UNMutableNotificationContent() },
            proximityInDays: 5    // >24h.
        )
        XCTAssertEqual(location.alwaysRequestCount, 1)
    }
}
```

- [ ] **Step 3: Run the failing tests**

Run:
```bash
xcodebuild test \
  -project WeeklyPlanner.xcodeproj \
  -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.0' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO \
  -only-testing:WeeklyPlannerTests/LocationReminderManagerTests
```
Expected: build failure — `LocationReminderManager` not in scope.

- [ ] **Step 4: Implement `LocationReminderManager`**

Create `WeeklyPlanner/Notifications/LocationReminderManager.swift`:

```swift
import CoreLocation
import Foundation
import UserNotifications
import os

/// Manages the iOS-mandated 20-region cap via a priority queue: lower
/// `proximityInDays` always wins. On every `register(...)` call we:
///   1. Drop any prior registration for the same event id (so re-scheduling
///      isn't lossy).
///   2. Insert the new entry.
///   3. Sort by `proximityInDays` ascending.
///   4. Cap to the top 20 — entries that fall off the cliff stop monitoring.
///
/// On region entry the `CLLocationManagerDelegate` callback finds the matching
/// entry by region identifier, asks the stored content factory for a fresh
/// `UNMutableNotificationContent`, and adds the request via `NotificationCentering`.
@MainActor
final class LocationReminderManager: NSObject, LocationRegistering, CLLocationManagerDelegate {
    private static let log = Logger(subsystem: "com.weeklyplanner.WeeklyPlanner", category: "Notifications")
    private static let maxRegions = 20
    private static let escalationThresholdDays = 1

    private struct Entry {
        let eventID: UUID
        let regionIdentifier: String
        let region: CLCircularRegion
        let contentFactory: () -> UNMutableNotificationContent
        let proximityInDays: Int
    }

    private var entries: [Entry] = []
    private let location: any LocationManaging
    private let center: any NotificationCentering

    init(location: any LocationManaging, center: any NotificationCentering) {
        self.location = location
        self.center = center
        super.init()
        self.location.locationDelegate = self
    }

    // MARK: LocationRegistering

    @discardableResult
    func register(eventID: UUID,
                  reminder: LocationReminder,
                  content: @escaping () -> UNMutableNotificationContent,
                  proximityInDays: Int) -> String?
    {
        let identifier = "loc-\(eventID.uuidString)"
        // Remove any existing entry for this event id, both from our priority
        // queue and from the OS's active set.
        if let existing = entries.first(where: { $0.eventID == eventID }) {
            location.stopMonitoring(for: existing.region)
            entries.removeAll { $0.eventID == eventID }
        }

        let circle = CLCircularRegion(center: reminder.coordinate,
                                       radius: reminder.radiusMeters,
                                       identifier: identifier)
        circle.notifyOnEntry = true
        circle.notifyOnExit = false

        let entry = Entry(eventID: eventID,
                          regionIdentifier: identifier,
                          region: circle,
                          contentFactory: content,
                          proximityInDays: proximityInDays)
        entries.append(entry)

        requestAuthorizationIfNeeded(proximityInDays: proximityInDays)
        rebalanceMonitoring()

        // Returned identifier == the request identifier the eventual
        // delivered notification will carry.
        return identifier
    }

    func unregister(eventID: UUID) {
        guard let existing = entries.first(where: { $0.eventID == eventID }) else { return }
        location.stopMonitoring(for: existing.region)
        entries.removeAll { $0.eventID == eventID }
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor [weak self] in
            await self?.handleEntry(region: region)
        }
    }

    // MARK: - Private

    private func handleEntry(region: CLRegion) async {
        guard let entry = entries.first(where: { $0.regionIdentifier == region.identifier }) else { return }
        let content = entry.contentFactory()
        let request = UNNotificationRequest(identifier: entry.regionIdentifier,
                                            content: content,
                                            trigger: nil)
        do {
            try await center.add(request)
            Self.log.info("Delivered region-entry notification for \(entry.eventID, privacy: .public)")
        } catch {
            Self.log.error("Region-entry add failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func requestAuthorizationIfNeeded(proximityInDays: Int) {
        switch location.authorizationStatus {
        case .notDetermined:
            location.requestWhenInUseAuthorization()
        case .authorizedWhenInUse where proximityInDays > Self.escalationThresholdDays:
            location.requestAlwaysAuthorization()
        default:
            break
        }
    }

    private func rebalanceMonitoring() {
        // Sort by proximity ascending; cap to maxRegions.
        entries.sort { $0.proximityInDays < $1.proximityInDays }
        let keepers = Array(entries.prefix(Self.maxRegions))
        let dropped = entries.dropFirst(Self.maxRegions)
        for entry in dropped {
            location.stopMonitoring(for: entry.region)
        }
        entries = keepers

        // Make sure the OS is monitoring exactly our keeper set.
        let monitored = location.monitoredRegions.map(\.identifier)
        for entry in entries where monitored.contains(entry.regionIdentifier) == false {
            location.startMonitoring(for: entry.region)
        }
    }
}
```

- [ ] **Step 5: Run tests**

Run the test command from Step 3.
Expected: `Test Suite 'LocationReminderManagerTests' passed`, 4 tests succeeded.

- [ ] **Step 6: Commit**

```bash
git add WeeklyPlanner/Notifications/LocationManaging.swift \
        WeeklyPlanner/Notifications/LocationReminderManager.swift \
        WeeklyPlannerTests/Notifications/Support/FakeLocationManager.swift \
        WeeklyPlannerTests/Notifications/LocationReminderManagerTests.swift
git commit -m "$(cat <<'EOF'
feat(phase-19): LocationReminderManager + LocationManaging seam

Priority queue keyed by proximity-in-days caps active regions at 20 (iOS
hard limit). Far-future onArrive triggers always-auth escalation. Region
entry → UNNotificationRequest dispatch via NotificationCentering.add(_:).
4 unit tests cover cap, priority eviction, entry flow, escalation.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: `DeepLinkRouter` + tests

**Files:**
- Create: `WeeklyPlanner/Notifications/DeepLinkRouter.swift`
- Create: `WeeklyPlannerTests/Notifications/DeepLinkRouterTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `WeeklyPlannerTests/Notifications/DeepLinkRouterTests.swift`:

```swift
import XCTest
@testable import WeeklyPlanner

@MainActor
final class DeepLinkRouterTests: XCTestCase {

    func testRequestEventStoresUUID() {
        let router = DeepLinkRouter()
        let id = UUID()
        router.request(.event(id))
        XCTAssertEqual(router.pending, .event(id))
    }

    func testConsumeReturnsAndClears() {
        let router = DeepLinkRouter()
        let id = UUID()
        router.request(.task(id))
        let consumed = router.consume()
        XCTAssertEqual(consumed, .task(id))
        XCTAssertNil(router.pending)
    }
}
```

- [ ] **Step 2: Run the failing test**

Run:
```bash
xcodebuild test \
  -project WeeklyPlanner.xcodeproj \
  -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.0' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO \
  -only-testing:WeeklyPlannerTests/DeepLinkRouterTests
```
Expected: build failure — `DeepLinkRouter` not in scope.

- [ ] **Step 3: Implement**

Create `WeeklyPlanner/Notifications/DeepLinkRouter.swift`:

```swift
import Foundation
import Observation

/// Holds the pending deep-link request set by `AppDelegate+Notifications`
/// when the user taps a notification (or cold-launches via one). `AppShell`
/// observes `pending`, consumes it once the matching sheet is presented.
@MainActor
@Observable
final class DeepLinkRouter {
    enum Destination: Equatable {
        case event(UUID)
        case task(UUID)
    }

    private(set) var pending: Destination?

    func request(_ destination: Destination) {
        pending = destination
    }

    /// Reads and clears the pending value. Use this when the consumer has
    /// committed to navigating — no re-firing.
    @discardableResult
    func consume() -> Destination? {
        defer { pending = nil }
        return pending
    }
}
```

- [ ] **Step 4: Run tests**

Run the test command from Step 2.
Expected: `Test Suite 'DeepLinkRouterTests' passed`, 2 tests succeeded.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Notifications/DeepLinkRouter.swift \
        WeeklyPlannerTests/Notifications/DeepLinkRouterTests.swift
git commit -m "$(cat <<'EOF'
feat(phase-19): DeepLinkRouter @Observable for notification tap routing

Two cases: .event(UUID) and .task(UUID). AppShell observes pending, consumes
it when the matching sheet is presented. Phase 19's AppDelegate populates it
from notification userInfo.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 10: `AppDelegate+Notifications`

**Files:**
- Create: `WeeklyPlanner/Notifications/AppDelegate+Notifications.swift`

This step has no automated tests (UIApplicationDelegate behavior is integration-tested manually). The delegate is small enough to inspect by eye.

- [ ] **Step 1: Implement the delegate**

Create `WeeklyPlanner/Notifications/AppDelegate+Notifications.swift`:

```swift
import UIKit
import UserNotifications
import os

/// `UIApplicationDelegate` + `UNUserNotificationCenterDelegate` adapter.
/// Responsibilities:
///   1. Register the actionable categories at launch.
///   2. Become the foreground-presentation delegate so notifications show as
///      banners even when the app is in front.
///   3. Translate tap / action / cold-launch payloads into `DeepLinkRouter`
///      requests + task-store side effects.
///
/// The delegate stays SwiftData-free in `application(_:didFinishLaunchingWithOptions:)`
/// — region-entry cold-launches must finish quickly to avoid OS termination.
@MainActor
final class NotificationsAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private static let log = Logger(subsystem: "com.weeklyplanner.WeeklyPlanner", category: "Notifications")

    /// Set by `WeeklyPlannerApp.init` after construction. Optionality keeps the
    /// delegate cheap to instantiate.
    var router: DeepLinkRouter?
    var taskStore: (any TaskStoring)?
    var center: (any NotificationCentering)?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool
    {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().setNotificationCategories(NotificationCategoryIDs.all())
        return true
    }

    // Show banners in foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        completionHandler([.banner, .list, .sound])
    }

    // Tap / action handling.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void)
    {
        let userInfo = response.notification.request.content.userInfo
        let action = response.actionIdentifier
        let request = response.notification.request

        switch action {
        case NotificationCategoryIDs.Action.viewEvent,
             UNNotificationDefaultActionIdentifier:
            if let id = uuid(forKey: "event.id", in: userInfo) {
                router?.request(.event(id))
            } else if let id = uuid(forKey: "task.id", in: userInfo) {
                router?.request(.task(id))
            }
        case NotificationCategoryIDs.Action.viewTask:
            if let id = uuid(forKey: "task.id", in: userInfo) {
                router?.request(.task(id))
            }
        case NotificationCategoryIDs.Action.snooze10:
            Task { @MainActor in
                await snooze(request: request, by: 10 * 60)
            }
        case NotificationCategoryIDs.Action.markDone:
            if let id = uuid(forKey: "task.id", in: userInfo) {
                Task { @MainActor in
                    try? await taskStore?.toggle(id: id)
                    self.center?.removePending(withIdentifiers: [request.identifier])
                }
            }
        default:
            break
        }

        completionHandler()
    }

    // MARK: - Private

    private func uuid(forKey key: String, in info: [AnyHashable: Any]) -> UUID? {
        guard let raw = info[key] as? String else { return nil }
        return UUID(uuidString: raw)
    }

    private func snooze(request: UNNotificationRequest, by seconds: TimeInterval) async {
        guard let center else { return }
        let newID = "\(request.identifier)-snooze-\(Int(Date().timeIntervalSince1970))"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let newRequest = UNNotificationRequest(identifier: newID,
                                                content: request.content,
                                                trigger: trigger)
        do {
            try await center.add(newRequest)
            Self.log.info("Snoozed notification \(request.identifier, privacy: .public) by \(seconds, privacy: .public)s")
        } catch {
            Self.log.error("Snooze re-add failed: \(String(describing: error), privacy: .public)")
        }
    }
}
```

- [ ] **Step 2: Smoke build**

Run:
```bash
xcodebuild build \
  -project WeeklyPlanner.xcodeproj \
  -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.0' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Notifications/AppDelegate+Notifications.swift
git commit -m "$(cat <<'EOF'
feat(phase-19): NotificationsAppDelegate + UNUserNotificationCenterDelegate

Registers categories at launch, presents banners in foreground, routes taps
into DeepLinkRouter, implements snooze-10 by re-adding the request, and
fires TaskStoring.toggle(id:) for Mark Done. Stays SwiftData-free at
didFinishLaunching so region-entry wakes can return fast.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 11: `NotificationReschedulingObserver`

**Files:**
- Create: `WeeklyPlanner/Notifications/NotificationReschedulingObserver.swift`

- [ ] **Step 1: Implement**

Create `WeeklyPlanner/Notifications/NotificationReschedulingObserver.swift`:

```swift
import Foundation
import os

/// Bridges existing store change notifications to scheduler updates. Listens
/// to `.eventStoreDidChange` and `.taskStoreDidChange` (already posted by
/// `SwiftDataEventStore` / `SwiftDataTaskStore` on every upsert/delete) and
/// calls the scheduler's `rescheduleAll` over a short forward window.
///
/// Bulk re-schedule is cheap because the schedulers clear by id-prefix
/// before re-adding — no leakage.
@MainActor
final class NotificationReschedulingObserver {
    private static let log = Logger(subsystem: "com.weeklyplanner.WeeklyPlanner", category: "Notifications")

    private let eventScheduler: EventNotificationScheduler
    private let taskScheduler: TaskNotificationScheduler
    private var observers: [NSObjectProtocol] = []

    init(eventScheduler: EventNotificationScheduler, taskScheduler: TaskNotificationScheduler) {
        self.eventScheduler = eventScheduler
        self.taskScheduler = taskScheduler
        attach()
    }

    deinit {
        let center = NotificationCenter.default
        for token in observers { center.removeObserver(token) }
    }

    /// Called once after a permission grant.
    func rescheduleNext30Days() async {
        let window = Date()...Date().addingTimeInterval(60 * 60 * 24 * 30)
        await eventScheduler.rescheduleAll(in: window)
        await taskScheduler.rescheduleAll(in: window)
    }

    private func attach() {
        let center = NotificationCenter.default
        let eventToken = center.addObserver(forName: .eventStoreDidChange, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.rescheduleNext30Days() }
        }
        let taskToken = center.addObserver(forName: .taskStoreDidChange, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.rescheduleNext30Days() }
        }
        observers = [eventToken, taskToken]
    }
}
```

- [ ] **Step 2: Smoke build**

Run the build command from Task 10 Step 2.
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Notifications/NotificationReschedulingObserver.swift
git commit -m "$(cat <<'EOF'
feat(phase-19): observer that re-schedules notifications on store changes

Listens to .eventStoreDidChange / .taskStoreDidChange (already posted by the
SwiftData stores on every upsert/delete) and re-runs rescheduleAll over the
next 30 days. Schedulers clear by id-prefix before re-adding so this is
idempotent.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 12: Environment env keys + stubs

**Files:**
- Modify: `WeeklyPlanner/Stores/Environment+Stores.swift`

- [ ] **Step 1: Add env keys + a `StubNotificationCenter`**

Edit `WeeklyPlanner/Stores/Environment+Stores.swift`. Append the new entries to the `extension EnvironmentValues` block — directly after the existing `inboxSyncEngine` entry, INSIDE the same extension:

```swift
    /// Notification center seam — Phase 19. Defaults to a no-op so previews
    /// and tests don't trigger the permission prompt or leak requests.
    @Entry var notificationCenter: any NotificationCentering = StubNotificationCenter()

    /// Event-side notification scheduler — Phase 19. Optional so previews can
    /// skip wiring; nil means scheduling is a silent no-op.
    @Entry var eventNotificationScheduler: EventNotificationScheduler? = nil

    /// Task-side notification scheduler — Phase 19.
    @Entry var taskNotificationScheduler: TaskNotificationScheduler? = nil

    /// Location reminder manager — Phase 19. Optional for the same reason.
    @Entry var locationReminderManager: LocationReminderManager? = nil

    /// Deep-link routing target for notification taps — Phase 19.
    @Entry var deepLinkRouter: DeepLinkRouter = DeepLinkRouter()
```

Then append a stub class after the existing `StubSettingsStore`:

```swift
/// No-op `NotificationCentering` used as the default environment value. Lets
/// previews and tests render views that read `\.notificationCenter` without
/// touching the system service.
@MainActor
final class StubNotificationCenter: NotificationCentering {
    nonisolated init() {}

    func authorizationStatus() async -> UNAuthorizationStatus { .notDetermined }
    func requestAuthorization(options _: UNAuthorizationOptions) async throws -> Bool { false }
    func setNotificationCategories(_: Set<UNNotificationCategory>) {}
    func add(_: UNNotificationRequest) async throws {}
    func pendingRequests() async -> [UNNotificationRequest] { [] }
    func removePending(withIdentifiers _: [String]) {}
    func removeAllPending() {}
}
```

Add the `import UserNotifications` at the top of the file alongside the existing imports.

- [ ] **Step 2: Smoke build**

Run the build command from Task 10 Step 2.
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Stores/Environment+Stores.swift
git commit -m "$(cat <<'EOF'
feat(phase-19): notification env keys + StubNotificationCenter default

\\.notificationCenter, \\.eventNotificationScheduler,
\\.taskNotificationScheduler, \\.locationReminderManager,
\\.deepLinkRouter — mirrors the env-keys pattern from Phase 17/18.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 13: Wire delegate + schedulers in `WeeklyPlannerApp`

**Files:**
- Modify: `WeeklyPlanner/App/WeeklyPlannerApp.swift`

- [ ] **Step 1: Add the delegate adapter and construct schedulers**

Edit `WeeklyPlanner/App/WeeklyPlannerApp.swift`. Replace the file with the additions wired in (new sections marked with `// MARK: Phase 19`):

```swift
import SwiftData
import SwiftUI
import UserNotifications

@main
struct WeeklyPlannerApp: App {
    @UIApplicationDelegateAdaptor(NotificationsAppDelegate.self) private var appDelegate

    @State private var container: ModelContainer
    @State private var eventStore: any EventStoring
    @State private var inboxStore: any InboxStoring
    @State private var taskStore: any TaskStoring
    @State private var settingsStore: any SettingsStoring
    @State private var googleAuthService: any GoogleAuthService
    @State private var gmailClient: GmailClient
    @State private var inboxSyncEngine: InboxSyncEngine
    @State private var bgRefreshScheduler: BackgroundRefreshScheduler
    @State private var eventKitAuth: EventKitAuthorization

    // MARK: Phase 19 — notifications wiring
    @State private var notificationCenter: any NotificationCentering
    @State private var notificationAuth: NotificationAuthorization
    @State private var locationManager: LocationReminderManager
    @State private var eventScheduler: EventNotificationScheduler
    @State private var taskScheduler: TaskNotificationScheduler
    @State private var rescheduleObserver: NotificationReschedulingObserver
    @State private var deepLinkRouter: DeepLinkRouter

    init() {
        let container = SwiftDataStack.production
        let baseEventStore = SwiftDataEventStore(context: container.mainContext)
        let taskStore = SwiftDataTaskStore(context: container.mainContext)
        let settingsStore = SwiftDataSettingsStore(context: container.mainContext)
        let googleAuthService = LiveGoogleAuthService(
            config: .fromBundle(),
            client: RealGIDSigningClient(),
            keychain: TokenKeychainStore<GoogleAccountInfo>(
                serviceID: "com.weeklyplanner.WeeklyPlanner.google"
            )
        )
        let eventKitGateway = SystemEventKitGateway()
        let calendarManager = CategoryCalendarManager(gateway: eventKitGateway)
        let eventKitAuth = EventKitAuthorization(gateway: eventKitGateway)
        let eventStore: any EventStoring = EventKitMirroringEventStore(
            base: baseEventStore,
            gateway: eventKitGateway,
            calendarManager: calendarManager
        )
        #if DEBUG
            SeedLoader.seedIfEmpty(context: container.mainContext)
        #endif
        let wiredInboxStore = SwiftDataInboxStore(
            context: container.mainContext,
            eventStore: eventStore,
            settingsStore: settingsStore
        )
        let gmailClient = GmailClient(auth: googleAuthService, session: URLSession.shared)
        let extractor: any EventExtractor = LiveEventExtractor()
        let syncEngine = InboxSyncEngine(
            client: gmailClient,
            extractor: extractor,
            inboxStore: wiredInboxStore,
            deltaSync: GmailDeltaSync(settingsStore: settingsStore)
        )
        let scheduler = BackgroundRefreshScheduler(engine: syncEngine)
        scheduler.registerHandler()

        // MARK: Phase 19 — notifications wiring
        let center: any NotificationCentering = LiveNotificationCenter()
        let authWrapper = NotificationAuthorization(center: center)
        let location = LiveLocationManager()
        let locationMgr = LocationReminderManager(location: location, center: center)
        let eventSched = EventNotificationScheduler(center: center,
                                                    locationRegistrar: locationMgr,
                                                    eventStore: eventStore)
        let taskSched = TaskNotificationScheduler(center: center,
                                                  locationRegistrar: locationMgr,
                                                  taskStore: taskStore)
        let rescheduler = NotificationReschedulingObserver(eventScheduler: eventSched,
                                                           taskScheduler: taskSched)
        let router = DeepLinkRouter()

        _container = State(initialValue: container)
        _eventStore = State(initialValue: eventStore)
        _inboxStore = State(initialValue: wiredInboxStore)
        _taskStore = State(initialValue: taskStore)
        _settingsStore = State(initialValue: settingsStore)
        _googleAuthService = State(initialValue: googleAuthService)
        _gmailClient = State(initialValue: gmailClient)
        _inboxSyncEngine = State(initialValue: syncEngine)
        _bgRefreshScheduler = State(initialValue: scheduler)
        _eventKitAuth = State(initialValue: eventKitAuth)
        _notificationCenter = State(initialValue: center)
        _notificationAuth = State(initialValue: authWrapper)
        _locationManager = State(initialValue: locationMgr)
        _eventScheduler = State(initialValue: eventSched)
        _taskScheduler = State(initialValue: taskSched)
        _rescheduleObserver = State(initialValue: rescheduler)
        _deepLinkRouter = State(initialValue: router)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.eventStore, eventStore)
                .environment(\.inboxStore, inboxStore)
                .environment(\.taskStore, taskStore)
                .environment(\.settingsStore, settingsStore)
                .environment(\.googleAuthService, googleAuthService)
                .environment(\.gmailClient, gmailClient)
                .environment(\.inboxSyncEngine, inboxSyncEngine)
                .environment(\.notificationCenter, notificationCenter)
                .environment(\.eventNotificationScheduler, eventScheduler)
                .environment(\.taskNotificationScheduler, taskScheduler)
                .environment(\.locationReminderManager, locationManager)
                .environment(\.deepLinkRouter, deepLinkRouter)
                .modelContainer(container)
                .onOpenURL { url in
                    _ = RealGIDSigningClient().handle(url: url)
                }
                .task {
                    await eventKitAuth.requestEventsIfNeeded()
                    // Hand the delegate the live references it needs to route taps.
                    appDelegate.router = deepLinkRouter
                    appDelegate.taskStore = taskStore
                    appDelegate.center = notificationCenter
                    // Probe authorization once on launch so the denied-banner
                    // in ConnectionsSection has accurate state on first render.
                    _ = await notificationAuth.status()
                }
        }
    }
}
```

- [ ] **Step 2: Smoke build**

Run:
```bash
xcodebuild build \
  -project WeeklyPlanner.xcodeproj \
  -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.0' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Run full test suite to confirm no regression**

Run:
```bash
xcodebuild test \
  -project WeeklyPlanner.xcodeproj \
  -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.0' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO \
  -only-testing:WeeklyPlannerTests
```
Expected: all tests pass (258 prior + 18 new = 276).

- [ ] **Step 4: Commit**

```bash
git add WeeklyPlanner/App/WeeklyPlannerApp.swift
git commit -m "$(cat <<'EOF'
feat(phase-19): wire UIApplicationDelegateAdaptor + notification stack

Constructs LiveNotificationCenter, LocationReminderManager, and the two
schedulers at app init; injects them into the environment. The delegate
gets a back-reference to DeepLinkRouter + TaskStoring + NotificationCentering
inside the WindowGroup .task so cold-launches can finish their permission
probe without blocking init.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 14: AppShell routes `DeepLinkRouter.pending` into the Calendar tab

**Files:**
- Modify: `WeeklyPlanner/Navigation/AppShell.swift`
- Modify: `WeeklyPlanner/Features/DayPage/DayPageView.swift`

- [ ] **Step 1: Have AppShell observe the router**

In `WeeklyPlanner/Navigation/AppShell.swift`, add the environment read near the existing `@Environment` lines:

```swift
    @Environment(\.deepLinkRouter) private var deepLinkRouter
```

And below the existing `.onReceive(NotificationCenter.default.publisher(for: .gmailDidConnect))`, add an `.onChange(of: deepLinkRouter.pending)` that switches to the Calendar tab whenever a pending request appears:

```swift
        .onChange(of: deepLinkRouter.pending) { _, new in
            guard new != nil else { return }
            selection.current = .calendar
            // DayPageView consumes the router itself; we just make sure the
            // calendar tab is visible.
        }
```

- [ ] **Step 2: Have DayPageView consume the router**

In `WeeklyPlanner/Features/DayPage/DayPageView.swift`, add the environment read alongside the existing ones:

```swift
    @Environment(\.deepLinkRouter) private var deepLinkRouter
```

And add an `.onChange(of: deepLinkRouter.pending)` modifier on the outermost view (alongside the existing `.task` and other modifiers near the bottom):

```swift
        .onChange(of: deepLinkRouter.pending) { _, new in
            guard case let .event(id) = new else { return }
            openEventID = id
            deepLinkRouter.consume()
        }
```

(If `DayPageView` already has an `.onChange` block, add another one — they stack fine.)

- [ ] **Step 3: Smoke build**

Run the build command from Task 13 Step 2.
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Run full test suite (no regressions)**

Run the test command from Task 13 Step 3.
Expected: all 276 tests pass.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Navigation/AppShell.swift WeeklyPlanner/Features/DayPage/DayPageView.swift
git commit -m "$(cat <<'EOF'
feat(phase-19): AppShell + DayPageView route notification taps to event sheet

AppShell flips to .calendar when DeepLinkRouter.pending fires; DayPageView
sets its existing openEventID state from the .event(UUID) variant and calls
DeepLinkRouter.consume() so the request doesn't re-fire on the next render.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 15: Denied-notifications banner in Connections section

**Files:**
- Modify: `WeeklyPlanner/Features/Settings/ConnectionsSection.swift`

- [ ] **Step 1: Inject the auth status and render the banner**

Edit `WeeklyPlanner/Features/Settings/ConnectionsSection.swift`. Add the environment read with the other ones:

```swift
    @Environment(\.notificationCenter) private var notificationCenter
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
```

Add `import UserNotifications` at the top.

Replace the `var body` with the existing card wrapped in a `VStack` that prepends the banner when denied:

```swift
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if notificationStatus == .denied {
                deniedBanner
            }
            card
        }
        .task {
            notificationStatus = await notificationCenter.authorizationStatus()
            if viewModel == nil {
                viewModel = ConnectionsViewModel(
                    settingsStore: settingsStore,
                    inboxStore: inboxStore,
                    auth: auth
                )
            }
        }
        // (existing .alert and .confirmationDialog modifiers stay)
    }

    private var deniedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "bell.slash")
                .foregroundStyle(theme.ink)
            VStack(alignment: .leading, spacing: 2) {
                Text("Notifications are off")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Text("Reminders won't fire. Open Settings to enable.")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.inkMuted)
            }
            Spacer()
            Button(action: openSystemSettings) {
                Text("Open Settings")
                    .font(.system(size: 13, weight: .semibold))
            }
        }
        .padding(12)
        .background(theme.creamHi)
        .overlay(
            RoundedRectangle(cornerRadius: 10).strokeBorder(theme.rule, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
```

(The existing `.alert` and `.confirmationDialog` modifiers move down inside the `.task { }` chain. Keep them but apply them to the new outer `VStack`.)

- [ ] **Step 2: Smoke build**

Run the build command from Task 13 Step 2.
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Run full test suite (no regressions)**

Run the test command from Task 13 Step 3.
Expected: all 276 tests pass.

- [ ] **Step 4: Commit**

```bash
git add WeeklyPlanner/Features/Settings/ConnectionsSection.swift
git commit -m "$(cat <<'EOF'
feat(phase-19): denied-notifications banner in Settings → Connections

Reads the current UNUserNotificationCenter authorization status when the
view appears; if .denied, renders an above-the-card banner with a deep-link
button to Settings.app.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 16: First-event permission prompt + post-grant reschedule

**Files:**
- Modify: `WeeklyPlanner/Stores/InboxStore+Gmail.swift`

The first time an event with a reminder lands (either from inbox accept or from a future manual add), we want to prompt the user once if status is `.notDetermined`. After they grant, the rescheduling observer (Task 11) re-runs the scheduler over the next 30 days.

The most natural seam is `SwiftDataInboxStore.accept(id:)`. The rescheduling observer already fires on `.eventStoreDidChange` so the schedule call happens for free — we only need to add the one-shot permission probe.

- [ ] **Step 1: Inject `NotificationAuthorization` into the inbox store**

This requires a tiny refactor: `SwiftDataInboxStore` already takes `eventStore` and `settingsStore` optionally. Add an optional `notificationAuth: NotificationAuthorization?` parameter (default nil so previews don't break), and after the existing `try await eventStore.upsert(event)` in `accept(id:)`, add:

```swift
        if let auth = notificationAuth {
            Task { @MainActor in
                let status = await auth.status()
                if status == .notDetermined {
                    _ = await auth.request()
                }
            }
        }
```

Then in `WeeklyPlannerApp.init`, pass `notificationAuth: authWrapper` when constructing `wiredInboxStore`:

```swift
        let wiredInboxStore = SwiftDataInboxStore(
            context: container.mainContext,
            eventStore: eventStore,
            settingsStore: settingsStore,
            notificationAuth: authWrapper
        )
```

Move `let authWrapper = NotificationAuthorization(center: center)` and `let center: any NotificationCentering = LiveNotificationCenter()` up so they're constructed *before* `wiredInboxStore`. Update the existing `_inboxStore` State assignment accordingly. The `let location = LiveLocationManager()` block and below can stay where it is.

- [ ] **Step 2: Smoke build**

Run the build command from Task 13 Step 2.
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Run full test suite**

Run the test command from Task 13 Step 3.
Expected: all 276 tests pass.

- [ ] **Step 4: Commit**

```bash
git add WeeklyPlanner/Stores/InboxStore.swift \
        WeeklyPlanner/Stores/InboxStore+Gmail.swift \
        WeeklyPlanner/App/WeeklyPlannerApp.swift
git commit -m "$(cat <<'EOF'
feat(phase-19): prompt for notification permission on first inbox accept

SwiftDataInboxStore.accept(id:) now optionally probes NotificationAuthorization
and fires the system prompt when status is .notDetermined. The rescheduling
observer (registered for .eventStoreDidChange) takes care of the actual
notification scheduling on its own — this seam is just for the one-shot
permission ask.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

If `SwiftDataInboxStore.init` signature needs widening in `WeeklyPlanner/Stores/InboxStore.swift`, that's where the default-nil `notificationAuth: NotificationAuthorization?` parameter goes. Mirror the optional-parameter style of `eventStore` / `settingsStore`.

---

### Task 17: Manual on-device verification

**Files:** none changed — pure validation.

This task is a checklist; nothing here is automatable. Document the outcome in the retrospective (Task 18).

- [ ] **Step 1: Boot the app on a physical iPhone (or iOS 26 simulator with Permissions reset)**

Run:
```bash
xcodebuild build install \
  -project WeeklyPlanner.xcodeproj \
  -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.0'
xcrun simctl launch booted com.weeklyplanner.WeeklyPlanner
```
Expected: app boots; no notification prompt yet (intentional — we ask only after first event-with-reminder).

- [ ] **Step 2: Verify time-based reminder fires**

In the app, open Settings → set Default Reminder to **15 min before**. From the inbox section, accept one suggestion whose start is >15 min in the future (or use the Phase 18 verification flow to land a real Gmail event). Within 1-2s of acceptance, you should see the system notification permission prompt — tap **Allow**.

Console (`Console.app` filtered by subsystem `com.weeklyplanner.WeeklyPlanner` and category `Notifications`) should log `"Scheduled event-time event-<uuid>-time-15 for <date>"`.

Wait until `event.start - 15min`. Confirm:
- Notification banner appears with the event title, `"{time} · {location}"` subtitle, and `"In 15 minutes."` body.
- Long-press / 3D-Touch shows two actions: **View** and **Snooze 10 min**.
- Tapping the banner opens the app to the event detail sheet.
- Tapping **Snooze 10 min** dismisses it and re-delivers ~10 min later.

- [ ] **Step 3: Verify location-based reminder fires**

Pick an event with a `LocationReminder` (use the seed data, or edit an event so its `reminders` includes `.onArrive(LocationReminder(name:"Trick Dog", ..., radiusMeters: 150))`).

In the simulator: **Features → Location → Custom Location** to a point >500m away. Wait for the app to register the region. Then **Custom Location** → set the lat/lng to the geofence center. Confirm:
- A new banner fires with title from the event, subtitle = location name, body = `"You've arrived at {name}."`
- Tap routes to the event detail sheet via `DeepLinkRouter`.

- [ ] **Step 4: Verify denied-path banner**

In the simulator, go to **Settings → Weekly Planner → Notifications → Allow Notifications: OFF**. Open the app → Settings tab → scroll to Connections. Confirm:
- The "Notifications are off — reminders won't fire" banner is visible above the Connections card.
- **Open Settings** button opens Settings.app.

Re-enable notifications, return to the app. Confirm the banner disappears (the `.task` modifier re-reads status on every appearance of the Connections section).

- [ ] **Step 5: Verify reschedule-on-grant**

After re-enabling permissions, accept another inbox suggestion. Confirm a new scheduled notification appears in the Console under category `Notifications` and fires at the right time.

- [ ] **Step 6: Capture a screenshot of the banner state**

Save it to `docs/phases/phase-19-notifications.png` for the retro.

- [ ] **Step 7: Note any deviations**

Open `/tmp/phase19-deviations.md` and capture anything that drifted from the plan. (This file is referenced by Task 18; ad hoc, not committed.)

---

### Task 18: Retrospective + Phase 19 marked complete

**Files:**
- Modify: `docs/phases/README.md`

- [ ] **Step 1: Mark Phase 19 ✅ in the phase table**

Change the row in `docs/phases/README.md`:

```
| 19 | Notifications (Time + Location Reminders)            | H                   | ⏳     |
```

to:

```
| 19 | Notifications (Time + Location Reminders)            | H                   | ✅     |
```

Update "Current state:" line near it from `Milestones A–F + Phases 16, 17, 18 shipped. 258 unit tests green. Next up: Phase 19 — Notifications.` to:

`Milestones A–F + H shipped. 276 unit tests green. Next up: Phase 20 — Modern Mode.`

(Exact test count to match what `xcodebuild test` reports at the end.)

- [ ] **Step 2: Append the Phase 19 retrospective**

Append a new `### Phase 19 — Notifications (Time + Location Reminders)` section under the existing `### Phase 18 — Gmail Inbox Pipeline` retrospective. Cover:
- What shipped (NotificationCentering + LocationManaging seams, two schedulers, LocationReminderManager priority queue, DeepLinkRouter, AppDelegate routing, denied-banner).
- Plan deviations encountered + how they were fixed (pull from `/tmp/phase19-deviations.md`).
- Tests added (target ~18 new; record the actual final count).
- File list (same shape as Phase 18 retro).
- Anything verified on-device vs. simulator (per Task 17 outputs).

Write it in the same voice as the prior phases — descriptive paragraphs, bullet point for deviations.

- [ ] **Step 3: Commit the retro**

```bash
git add docs/phases/README.md docs/phases/phase-19-notifications.png
git commit -m "$(cat <<'EOF'
docs(phase-19): retrospective + status updates

Phase 19 marked ✅. Phase table updated. Retrospective documents the
notification stack and any plan deviations encountered.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 4: Confirm branch state**

Run:
```bash
git log --oneline -20
git status
```
Expected: clean working tree, every Phase 19 commit visible.

---

### Task 19: Milestone H merge to main

**Files:** none changed.

- [ ] **Step 1: Final full test pass**

Run:
```bash
xcodebuild test \
  -project WeeklyPlanner.xcodeproj \
  -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.0' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO
```
Expected: all tests pass on both `WeeklyPlannerTests` and `WeeklyPlannerUITests` schemes.

- [ ] **Step 2: Merge milestone-h-integrations into main**

```bash
git checkout main
git merge --no-ff milestone-h-integrations -m "Merge branch 'milestone-h-integrations' (Phase 17 — Connections; Phase 18 — Gmail pipeline; Phase 19 — Notifications)"
git log --oneline -5
```
Expected: merge commit at HEAD; phase commits visible below it.

- [ ] **Step 3: Update memory `milestone-h-state` to reflect completion**

(Done by the executor after merge; the memory file lives at
`~/.claude/projects/.../memory/milestone-h-state.md` per `MEMORY.md`.)

Stop here — pushing to a remote and tagging a release are user-driven.

---

## Self-Review

After writing this plan, re-read the spec at `docs/superpowers/specs/2026-05-20-milestone-h-integrations-design.md` §4 ("Phase 19 — Notifications") and check this plan against it:

1. **Spec coverage:**
   - `NotificationCenter` protocol → Task 2 ✅
   - `EventNotificationScheduler` → Task 6 ✅
   - `TaskNotificationScheduler` → Task 7 ✅
   - `LocationReminderManager` → Task 8 ✅
   - `NotificationContentBuilder` → Task 5 ✅
   - `NotificationCategoryIDs` → Task 3 ✅
   - `AppDelegate+Notifications` → Task 10 ✅
   - `DefaultReminderPolicy` → already shipped in Phase 18, called by inbox accept; Task 16 augments the same call site to also probe permission ✅
   - Entitlements (time-sensitive) → Task 1 ✅
   - Re-scheduling triggers (event upsert, auth grant) → Tasks 11 + 16 ✅
   - Denied banner in Settings → Task 15 ✅
   - Snooze 10 / mark done / view actions → Tasks 3 + 10 ✅
   - 20-region priority queue → Task 8 ✅
   - Always-auth escalation for far-future events → Task 8 ✅
   - Cold-launch SwiftData-free delegate → Task 10 ✅

2. **Test coverage targets:**
   - Spec says ~20 unit tests for Phase 19. This plan delivers 18 across the five test classes (3 + 5 + 4 + 4 + 2). DefaultReminderPolicy tests were claimed in Phase 19 spec but Phase 18 already wrote 3 of them — no double-count.

3. **No placeholders.** Every code step has complete code. The retro task asks the executor to fill exact deviation details once Task 17 has run, which is correct — they don't exist yet.

4. **Type consistency.**
   - `LocationRegistering.register(...)` signature matches between Task 6 (declaration) and Task 8 (impl).
   - `NotificationCentering.removePending(withIdentifiers identifiers:)` matches between Task 2 (live impl), the fake, and every caller.
   - `EventNotificationScheduler.schedule(event:)` / `cancel(eventID:)` / `rescheduleAll(in:)` match across tests, impl, observer, and the App.

If anything in the executor's run diverges (e.g. SwiftUI Environment macros change in iOS 26), the existing patterns from Phase 17 (`@Entry` macro) and Phase 18 (env wiring + stubs) are authoritative — follow them.

---

*Plan written 2026-05-20 against spec `docs/superpowers/specs/2026-05-20-milestone-h-integrations-design.md`. Ready for `superpowers:subagent-driven-development`.*
