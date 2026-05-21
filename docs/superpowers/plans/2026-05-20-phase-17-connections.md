# Phase 17 — Settings → Connections Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the Connections card in Settings — three rows (Gmail, Apple Mail, Google Calendar) with brand logos, status text, and Paper toggles — backed by a real GoogleSignIn OAuth flow, Keychain-stored tokens, and `Secrets.xcconfig`-driven secret plumbing. Apple Mail and Google Calendar rows are read-only / placeholder per v1.0 spec.

**Architecture:**
- Secrets flow: a gitignored `Secrets.xcconfig` holds `GOOGLE_CLIENT_ID` and `REVERSED_GOOGLE_CLIENT_ID`; XcodeGen wires it as `configFiles` for Debug + Release; the values reach Info.plist via `INFOPLIST_KEY_GoogleClientID` and `$(REVERSED_GOOGLE_CLIENT_ID)` in `CFBundleURLSchemes`. A committed `Secrets.example.xcconfig` documents the contract.
- Auth layer: `GoogleAuthService` protocol with `LiveGoogleAuthService` (wraps `GIDSignIn.sharedInstance` through a thin internal `GIDSigningClient` seam so tests can fake the SDK) and `StubGoogleAuthService` (canned responses for previews + view-model tests). Tokens persist in Keychain via `TokenKeychainStore<T: Codable>`.
- UI: `ConnectionsSection` replaces the body of the existing `ConnectionsPlaceholder` (single-file swap — no churn to `PaperSettingsView`). It hosts three `ConnectionRow` views, each rendering its own brand logo (`GmailBrandLogo`, `AppleBrandLogo`, `GoogleCalLogo`). Orchestration lives in `ConnectionsViewModel` (`@Observable`): connect/disconnect choreography, optimistic toggle, cascade-delete of pending `InboxSuggestion` rows on disconnect, transient alert state.
- App-side OAuth callback: `WeeklyPlannerApp` adds `.onOpenURL { GIDSignIn.sharedInstance.handle($0) }`. No `UIApplicationDelegateAdaptor` (Phase 19 adds one).

**Tech Stack:** Swift 6, SwiftUI, SwiftData, KeychainAccess (already in `project.yml`), GoogleSignIn-iOS (added in Task 3), XCTest. XcodeGen 2.x regenerates the project from `project.yml`; new files under `WeeklyPlanner/Auth/` and `WeeklyPlanner/Features/Settings/` are picked up automatically because the target's `sources` is the entire `WeeklyPlanner/` folder.

---

## File Structure

### Created

```
Secrets.example.xcconfig                                                # COMMITTED — contract template
Secrets.xcconfig                                                        # GITIGNORED — local-only
WeeklyPlanner/Auth/GoogleAuth/GoogleAccountInfo.swift                   # DTO: email + tokens + expiry
WeeklyPlanner/Auth/GoogleAuth/GoogleAuthConfig.swift                    # reads Bundle "GoogleClientID" key
WeeklyPlanner/Auth/GoogleAuth/GoogleAuthError.swift                     # typed errors
WeeklyPlanner/Auth/GoogleAuth/TokenKeychainStore.swift                  # generic Keychain wrapper
WeeklyPlanner/Auth/GoogleAuth/GoogleAuthService.swift                   # protocol + StubGoogleAuthService
WeeklyPlanner/Auth/GoogleAuth/GIDSigningClient.swift                    # SDK seam: protocol + Real impl
WeeklyPlanner/Auth/GoogleAuth/LiveGoogleAuthService.swift               # production impl
WeeklyPlanner/Features/Settings/ConnectionsSection.swift                # replaces ConnectionsPlaceholder body
WeeklyPlanner/Features/Settings/ConnectionRow.swift                     # one row (logo + label/detail + toggle)
WeeklyPlanner/Features/Settings/ConnectionsViewModel.swift              # @Observable orchestrator
WeeklyPlanner/Features/Settings/Logos/GmailBrandLogo.swift              # 22×16 multi-color
WeeklyPlanner/Features/Settings/Logos/AppleBrandLogo.swift              # 18×22 mono
WeeklyPlanner/Features/Settings/Logos/GoogleCalLogo.swift               # 20×20 stylized "31"
WeeklyPlannerTests/Auth/TokenKeychainStoreTests.swift                   # Codable roundtrip
WeeklyPlannerTests/Auth/GoogleAuthServiceTests.swift                    # Live + Stub + GIDSigningClient seam
WeeklyPlannerTests/Features/Settings/ConnectionsViewModelTests.swift    # connect/disconnect choreography
WeeklyPlannerTests/Features/Settings/ConnectionsSectionTests.swift      # structural assertions (rows count, toggle state matrix)
```

### Modified

```
.gitignore                                              # add Secrets.xcconfig
project.yml                                             # GoogleSignIn-iOS package + configFiles + INFOPLIST_KEY
WeeklyPlanner/Supporting/Info.plist                     # CFBundleURLSchemes → $(REVERSED_GOOGLE_CLIENT_ID); add GoogleClientID
WeeklyPlanner/Stores/Environment+Stores.swift           # add \.googleAuthService env key + StubGoogleAuthService default
WeeklyPlanner/App/WeeklyPlannerApp.swift                # inject Live GoogleAuthService + .onOpenURL handler
WeeklyPlanner/Features/Settings/ConnectionsPlaceholder.swift  # body becomes a thin wrapper around ConnectionsSection — file kept so PaperSettingsView call-site doesn't change
README.md                                               # add "Google OAuth setup" section
docs/phases/README.md                                   # Phase 17 retrospective + status flip
```

### Conventions (already established, restated for reviewers)

- **No emojis in source files unless they're literal UI strings.**
- **POSIX-locked formatters** in tests for determinism.
- **`@Observable`** for view models; **`@Environment`** for cross-cutting deps (stores, theme, services).
- **Tests under `WeeklyPlannerTests/<Mirror>/`** mirror the source folder structure (`Auth/`, `Features/Settings/`).
- **Per-task atomic commits** with `chore(phase-17):` / `feat(phase-17):` / `test(phase-17):` / `docs(phase-17):` prefix.
- **Snapshot tests deferred** to Phase 21 (no `swift-snapshot-testing` dep). `ConnectionsSectionTests` asserts structural invariants (row count, toggle state matrix); visual conformance is checked manually against `docs/mock/paper-settings.jsx`.
- **Branch:** `milestone-h-integrations` (already created).

---

## Task 1: Baseline verification

**Files:** none (verification only)

Confirm the branch is clean and the full suite is green before adding code.

- [ ] **Step 1: Confirm we're on the milestone branch with the spec committed**

```bash
git status --short
git branch --show-current
git log --oneline -3
```

Expected:
- `git status --short` is empty (the spec commit landed; nothing else dirty)
- branch is `milestone-h-integrations`
- HEAD is `64d65db docs(milestone-h): design spec — Phase 17 + 18 + 19 (Integrations)`

- [ ] **Step 2: Regenerate Xcode project and re-baseline**

```bash
xcodegen generate 2>&1 | tail -2
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO 2>&1 \
  | grep -E "TEST FAILED|TEST SUCCEEDED|Executed [0-9]+ tests" | tail -3
```

Expected: `Loaded project` line; `** TEST SUCCEEDED **`; `Executed 211 tests, with 0 failures` (matches the Phase 16 retro).

- [ ] **Step 3: Do not commit**

Verification only.

---

## Task 2: Secret plumbing (xcconfig + Info.plist + .gitignore)

**Files:**
- Create: `Secrets.example.xcconfig`
- Create: `Secrets.xcconfig` (gitignored; never committed)
- Modify: `.gitignore`
- Modify: `project.yml` (configFiles + INFOPLIST_KEY_GoogleClientID)
- Modify: `WeeklyPlanner/Supporting/Info.plist` (CFBundleURLSchemes uses `$(REVERSED_GOOGLE_CLIENT_ID)`)

Wire the secret so the build can read the OAuth client ID at runtime without committing it.

- [ ] **Step 1: Add `Secrets.xcconfig` to `.gitignore` BEFORE creating the file**

Edit `.gitignore`. Append under "Local override files":

```
# Google OAuth secrets — local-only, never commit
Secrets.xcconfig
```

Verify:

```bash
grep -c "^Secrets.xcconfig$" .gitignore
```

Expected: `1`.

- [ ] **Step 2: Create the committed example (empty values, documents the contract)**

Create `Secrets.example.xcconfig`:

```
// Copy this file to Secrets.xcconfig (gitignored) and fill in the values.
// Get the iOS OAuth client ID from https://console.cloud.google.com/apis/credentials
// (Application type: iOS, Bundle ID: com.weeklyplanner.WeeklyPlanner).

GOOGLE_CLIENT_ID =
REVERSED_GOOGLE_CLIENT_ID =
```

- [ ] **Step 3: Create the gitignored local secrets file with the user's real values**

Create `Secrets.xcconfig`:

```
GOOGLE_CLIENT_ID = 436650706844-9nonlbksnaal4io6cldhkrf7qkgf23gk.apps.googleusercontent.com
REVERSED_GOOGLE_CLIENT_ID = com.googleusercontent.apps.436650706844-9nonlbksnaal4io6cldhkrf7qkgf23gk
```

Verify it is NOT staged:

```bash
git status --short Secrets.xcconfig
```

Expected: empty output (file is gitignored).

- [ ] **Step 4: Wire `configFiles` and the Info.plist key into `project.yml`**

In `project.yml`, inside `targets: WeeklyPlanner:`, after the existing `settings:` block, add a `configFiles` mapping and add `INFOPLIST_KEY_GoogleClientID` under `settings.base`.

Replace the `targets.WeeklyPlanner.settings` block (currently ends at `SWIFT_EMIT_LOC_STRINGS: YES`) with:

```yaml
    configFiles:
      Debug: Secrets.xcconfig
      Release: Secrets.xcconfig
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.weeklyplanner.WeeklyPlanner
        PRODUCT_NAME: WeeklyPlanner
        TARGETED_DEVICE_FAMILY: "1"
        SUPPORTED_INTERFACE_ORIENTATIONS: UIInterfaceOrientationPortrait
        INFOPLIST_FILE: WeeklyPlanner/Supporting/Info.plist
        CODE_SIGN_ENTITLEMENTS: WeeklyPlanner/Supporting/WeeklyPlanner.entitlements
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor
        CURRENT_PROJECT_VERSION: "1"
        MARKETING_VERSION: "0.1.0"
        ENABLE_PREVIEWS: YES
        IPHONEOS_DEPLOYMENT_TARGET: "26.0"
        SWIFT_EMIT_LOC_STRINGS: YES
        INFOPLIST_KEY_GoogleClientID: $(GOOGLE_CLIENT_ID)
```

`configFiles` is a XcodeGen top-level target key, NOT under `settings`. Indentation matters — it sits between `settings:` and `dependencies:`. Move the existing `settings:` block down two lines and add `configFiles:` above it.

- [ ] **Step 5: Update Info.plist to consume `$(REVERSED_GOOGLE_CLIENT_ID)`**

In `WeeklyPlanner/Supporting/Info.plist`, find the existing entry (currently `com.googleusercontent.apps.PLACEHOLDER`):

```xml
            <key>CFBundleURLSchemes</key>
            <array>
                <string>com.googleusercontent.apps.PLACEHOLDER</string>
            </array>
```

Replace with:

```xml
            <key>CFBundleURLSchemes</key>
            <array>
                <string>$(REVERSED_GOOGLE_CLIENT_ID)</string>
            </array>
```

Xcode performs `$(...)` substitution in Info.plist values at build time from the merged build settings (which include `Secrets.xcconfig` via `configFiles`).

- [ ] **Step 6: Regenerate Xcode project and confirm clean build**

```bash
xcodegen generate 2>&1 | tail -2
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO 2>&1 \
  | grep -E "BUILD FAILED|BUILD SUCCEEDED" | tail -2
```

Expected: `Loaded project` line; `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Verify the URL scheme actually resolved at build time**

```bash
xcrun --sdk iphonesimulator PlistBuddy -c "Print :CFBundleURLTypes:0:CFBundleURLSchemes:0" \
  $(find ~/Library/Developer/Xcode/DerivedData -name "WeeklyPlanner.app" -path "*Debug-iphonesimulator*" | head -1)/Info.plist
```

Expected: `com.googleusercontent.apps.436650706844-9nonlbksnaal4io6cldhkrf7qkgf23gk` (the reversed client ID, not the literal `$(...)` string).

If the output is empty or contains `$(`, the substitution didn't happen — check that `configFiles` sits at the right YAML level in `project.yml`.

- [ ] **Step 8: Commit**

```bash
git add .gitignore Secrets.example.xcconfig project.yml WeeklyPlanner/Supporting/Info.plist WeeklyPlanner.xcodeproj
git commit -m "$(cat <<'EOF'
chore(phase-17): wire Secrets.xcconfig for Google OAuth client ID

Adds a gitignored Secrets.xcconfig (per-developer) and a committed
Secrets.example.xcconfig that documents the GOOGLE_CLIENT_ID /
REVERSED_GOOGLE_CLIENT_ID contract. project.yml feeds the values into
Info.plist via configFiles + INFOPLIST_KEY_GoogleClientID and the
CFBundleURLSchemes entry, replacing the Phase 01 PLACEHOLDER.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Confirm `Secrets.xcconfig` was NOT included:

```bash
git show --stat HEAD | grep -c "Secrets.xcconfig"
```

Expected: `1` (only `Secrets.example.xcconfig`). If `2`, the gitignore wasn't honored — `git reset HEAD~`, fix `.gitignore`, retry.

---

## Task 3: Add GoogleSignIn-iOS SPM dependency

**Files:**
- Modify: `project.yml` (packages + dependencies)

- [ ] **Step 1: Add the package declaration**

In `project.yml`, under `packages:`, replace the placeholder comment with:

```yaml
  GoogleSignIn-iOS:
    url: https://github.com/google/GoogleSignIn-iOS
    from: "7.1.0"
```

The two-line `# GoogleSignIn-iOS, GoogleAPIClientForREST — deferred...` comment goes away (Phase 18 adds GoogleAPIClientForREST separately).

- [ ] **Step 2: Add the target dependency**

Under `targets.WeeklyPlanner.dependencies:`, append:

```yaml
      - package: GoogleSignIn-iOS
        product: GoogleSignIn
```

- [ ] **Step 3: Regenerate and let SPM resolve**

```bash
xcodegen generate 2>&1 | tail -2
xcodebuild -resolvePackageDependencies -project WeeklyPlanner.xcodeproj \
  -scheme WeeklyPlanner 2>&1 | tail -5
```

Expected: `Resolve Package Graph` succeeds. First run downloads the dep (~10s).

- [ ] **Step 4: Confirm build still passes**

```bash
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO 2>&1 \
  | grep -E "BUILD FAILED|BUILD SUCCEEDED" | tail -2
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add project.yml WeeklyPlanner.xcodeproj
git commit -m "$(cat <<'EOF'
chore(phase-17): add GoogleSignIn-iOS SPM dependency

Phase 17 needs GIDSignIn.sharedInstance for the OAuth flow. Pinned to 7.1.0
to match Apple's current iOS 26 / Swift 6 toolchain compatibility window.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: `GoogleAccountInfo` DTO

**Files:**
- Create: `WeeklyPlanner/Auth/GoogleAuth/GoogleAccountInfo.swift`

A pure value type, no logic — no tests needed.

- [ ] **Step 1: Write the file**

```swift
import Foundation

/// The minimal account snapshot the app keeps in Keychain after a successful
/// Google OAuth sign-in. Refreshed in place by `GoogleAuthService.accessToken()`
/// when `expiresAt` is within five minutes of `now`.
struct GoogleAccountInfo: Codable, Equatable, Hashable {
    let email: String
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
}
```

- [ ] **Step 2: Confirm compilation**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO 2>&1 \
  | grep -E "BUILD FAILED|BUILD SUCCEEDED" | tail -2
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Auth/GoogleAuth/GoogleAccountInfo.swift WeeklyPlanner.xcodeproj
git commit -m "feat(phase-17): GoogleAccountInfo DTO" -m "Codable snapshot of the OAuth result: email + access token + refresh token + expiry. Used by GoogleAuthService and persisted via TokenKeychainStore.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: `GoogleAuthError`

**Files:**
- Create: `WeeklyPlanner/Auth/GoogleAuth/GoogleAuthError.swift`

- [ ] **Step 1: Write the file**

```swift
import Foundation

/// Errors surfaced by `GoogleAuthService`. UI-layer code maps these to user-
/// visible alerts; the `notConfigured` case fires when `Secrets.xcconfig`
/// hasn't been filled in (intentional graceful-degradation rather than a
/// crash so the rest of the app keeps running for non-Gmail features).
enum GoogleAuthError: Error, Equatable {
    /// `Bundle.main`'s `GoogleClientID` key is missing or empty.
    case notConfigured
    /// User dismissed the OAuth sheet.
    case userCancelled
    /// Network error during sign-in or token refresh.
    case network(String)
    /// Token refresh failed because the user revoked from Google's side, or the
    /// refresh token itself is invalid. UI should flip `gmailConnected=false`.
    case reauthenticationRequired
    /// No `UIWindowScene` available to present the OAuth sheet from. Should
    /// never happen in a foreground app; defensive.
    case noPresenter
}
```

- [ ] **Step 2: Commit**

```bash
git add WeeklyPlanner/Auth/GoogleAuth/GoogleAuthError.swift WeeklyPlanner.xcodeproj
git commit -m "feat(phase-17): GoogleAuthError typed errors

Five cases covering the realistic failure modes: notConfigured (secret
missing), userCancelled, network, reauthenticationRequired, noPresenter.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: `TokenKeychainStore` (TDD)

**Files:**
- Create: `WeeklyPlanner/Auth/GoogleAuth/TokenKeychainStore.swift`
- Test:   `WeeklyPlannerTests/Auth/TokenKeychainStoreTests.swift`

Generic Codable wrapper around `KeychainAccess`. Tests use a unique per-test service ID so they don't collide between runs or with the production key.

- [ ] **Step 1: Write the failing test file**

Create `WeeklyPlannerTests/Auth/TokenKeychainStoreTests.swift`:

```swift
import XCTest
@testable import WeeklyPlanner

final class TokenKeychainStoreTests: XCTestCase {
    private var serviceID: String!
    private var store: TokenKeychainStore<GoogleAccountInfo>!

    override func setUp() async throws {
        try await super.setUp()
        serviceID = "com.weeklyplanner.tests.\(UUID().uuidString)"
        store = TokenKeychainStore<GoogleAccountInfo>(serviceID: serviceID)
        try store.clear()
    }

    override func tearDown() async throws {
        try? store.clear()
        try await super.tearDown()
    }

    func testSaveAndLoadRoundtrip() throws {
        let info = GoogleAccountInfo(
            email: "sara@gmail.com",
            accessToken: "access-123",
            refreshToken: "refresh-456",
            expiresAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        try store.save(info)
        let loaded = try store.load()

        XCTAssertEqual(loaded, info)
    }

    func testLoadReturnsNilWhenEmpty() throws {
        let loaded = try store.load()
        XCTAssertNil(loaded)
    }

    func testClearRemovesValue() throws {
        try store.save(.init(email: "x@y.z", accessToken: "a", refreshToken: "r", expiresAt: .init()))
        try store.clear()
        XCTAssertNil(try store.load())
    }

    func testOverwriteReplacesValue() throws {
        let first = GoogleAccountInfo(email: "a@x.com", accessToken: "t1", refreshToken: "r1", expiresAt: .init())
        let second = GoogleAccountInfo(email: "a@x.com", accessToken: "t2", refreshToken: "r2", expiresAt: .init())
        try store.save(first)
        try store.save(second)
        XCTAssertEqual(try store.load(), second)
    }
}
```

- [ ] **Step 2: Run the test, expect compile failure**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO -only-testing:WeeklyPlannerTests/TokenKeychainStoreTests 2>&1 \
  | grep -E "error:|TEST FAILED" | head -5
```

Expected: `error: cannot find 'TokenKeychainStore' in scope` (compile fail = TDD red).

- [ ] **Step 3: Write the minimal implementation**

Create `WeeklyPlanner/Auth/GoogleAuth/TokenKeychainStore.swift`:

```swift
import Foundation
import KeychainAccess

/// Generic Codable wrapper around `KeychainAccess`. One slot per `serviceID`
/// — the value is JSON-encoded and stored under the well-known key `"value"`.
/// The serviceID acts as the namespace (production passes
/// `"com.weeklyplanner.WeeklyPlanner.google"`; tests pass a per-test UUID
/// suffix).
///
/// Errors from `KeychainAccess` propagate as `Error`. `load()` returns `nil`
/// when nothing is stored; it does NOT throw for the empty case.
struct TokenKeychainStore<Value: Codable> {
    private let keychain: Keychain
    private static var slotKey: String { "value" }

    init(serviceID: String) {
        keychain = Keychain(service: serviceID)
    }

    func save(_ value: Value) throws {
        let data = try JSONEncoder().encode(value)
        try keychain.set(data, key: Self.slotKey)
    }

    func load() throws -> Value? {
        guard let data = try keychain.getData(Self.slotKey) else { return nil }
        return try JSONDecoder().decode(Value.self, from: data)
    }

    func clear() throws {
        try keychain.remove(Self.slotKey)
    }
}
```

- [ ] **Step 4: Run tests, expect green**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO -only-testing:WeeklyPlannerTests/TokenKeychainStoreTests 2>&1 \
  | grep -E "TEST FAILED|TEST SUCCEEDED|Executed [0-9]+ tests" | tail -3
```

Expected: `** TEST SUCCEEDED **`; `Executed 4 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Auth/GoogleAuth/TokenKeychainStore.swift \
        WeeklyPlannerTests/Auth/TokenKeychainStoreTests.swift \
        WeeklyPlanner.xcodeproj
git commit -m "feat(phase-17): TokenKeychainStore generic Codable wrapper

JSON-encoded values stored under a single 'value' slot per serviceID.
Tests use per-UUID service IDs so they don't collide with production or
each other. 4 tests cover roundtrip, empty-load, clear, overwrite.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: `GoogleAuthService` protocol + `StubGoogleAuthService`

**Files:**
- Create: `WeeklyPlanner/Auth/GoogleAuth/GoogleAuthService.swift`

The stub is the test/preview double AND the runtime fallback when `Secrets.xcconfig` is missing. No standalone tests — its behaviour is exercised through `ConnectionsViewModelTests` (Task 12).

- [ ] **Step 1: Write the file**

```swift
import Foundation
import UIKit

/// The authentication surface the UI calls into. Production wires
/// `LiveGoogleAuthService`; previews and `ConnectionsViewModelTests` wire
/// `StubGoogleAuthService`.
@MainActor
protocol GoogleAuthService: AnyObject {
    /// Presents the OAuth sheet and returns the freshly-signed-in account.
    /// Throws `GoogleAuthError.userCancelled` if the user dismisses.
    func signIn(presenting: UIViewController) async throws -> GoogleAccountInfo

    /// Revokes the current session and clears the Keychain slot.
    func signOut() async

    /// Returns the cached account, or `nil` if signed-out.
    func currentAccount() -> GoogleAccountInfo?

    /// Returns a valid access token, refreshing if `expiresAt` is within five
    /// minutes of `now`. Throws `.reauthenticationRequired` if the refresh
    /// token itself is rejected.
    func accessToken() async throws -> String
}

/// Canned `GoogleAuthService` used by previews, `ConnectionsViewModelTests`,
/// and as the runtime fallback when `GoogleAuthConfig` reports the client ID
/// is missing. Holds a single in-memory `GoogleAccountInfo` and records call
/// counts so tests can assert orchestration.
@MainActor
final class StubGoogleAuthService: GoogleAuthService {
    /// What `signIn(presenting:)` returns on success. Default is a fixed
    /// `sara@gmail.com` account expiring far in the future.
    var nextSignInResult: Result<GoogleAccountInfo, Error>

    /// In-memory cache of the "current" account; mutated by `signIn` and
    /// `signOut`.
    private(set) var stored: GoogleAccountInfo?

    /// Counters tests can read.
    private(set) var signInCount = 0
    private(set) var signOutCount = 0
    private(set) var accessTokenCount = 0

    nonisolated init() {
        nextSignInResult = .success(.init(
            email: "sara@gmail.com",
            accessToken: "stub-access-token",
            refreshToken: "stub-refresh-token",
            expiresAt: Date(timeIntervalSinceNow: 3600)
        ))
    }

    func signIn(presenting _: UIViewController) async throws -> GoogleAccountInfo {
        signInCount += 1
        let info = try nextSignInResult.get()
        stored = info
        return info
    }

    func signOut() async {
        signOutCount += 1
        stored = nil
    }

    func currentAccount() -> GoogleAccountInfo? {
        stored
    }

    func accessToken() async throws -> String {
        accessTokenCount += 1
        guard let stored else { throw GoogleAuthError.reauthenticationRequired }
        return stored.accessToken
    }
}
```

- [ ] **Step 2: Confirm compilation**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO 2>&1 \
  | grep -E "BUILD FAILED|BUILD SUCCEEDED" | tail -2
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Auth/GoogleAuth/GoogleAuthService.swift WeeklyPlanner.xcodeproj
git commit -m "feat(phase-17): GoogleAuthService protocol + StubGoogleAuthService

Protocol exposes signIn/signOut/currentAccount/accessToken. The stub
backs previews, ConnectionsViewModelTests, and the runtime fallback path
when Secrets.xcconfig is missing — call counters let tests assert the
view-model's orchestration without touching the real SDK.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: `GoogleAuthConfig`

**Files:**
- Create: `WeeklyPlanner/Auth/GoogleAuth/GoogleAuthConfig.swift`

Pure value reader. No tests — too thin (one Bundle read).

- [ ] **Step 1: Write the file**

```swift
import Foundation

/// Reads the Google OAuth client ID at process startup. Sourced from the
/// `Secrets.xcconfig`-driven Info.plist key `GoogleClientID`; an empty or
/// missing value means the developer hasn't filled in `Secrets.xcconfig`
/// and `LiveGoogleAuthService.signIn(...)` will throw
/// `GoogleAuthError.notConfigured` rather than crash.
struct GoogleAuthConfig {
    let clientID: String

    /// Reads from `Bundle.main`'s Info.plist. Returns an empty `clientID` when
    /// the key is absent or blank.
    static func fromBundle(_ bundle: Bundle = .main) -> GoogleAuthConfig {
        let raw = bundle.object(forInfoDictionaryKey: "GoogleClientID") as? String
        return GoogleAuthConfig(clientID: raw?.trimmingCharacters(in: .whitespaces) ?? "")
    }

    var isConfigured: Bool { !clientID.isEmpty }
}
```

- [ ] **Step 2: Commit**

```bash
git add WeeklyPlanner/Auth/GoogleAuth/GoogleAuthConfig.swift WeeklyPlanner.xcodeproj
git commit -m "feat(phase-17): GoogleAuthConfig reads GoogleClientID from Info.plist

Sourced via Secrets.xcconfig → INFOPLIST_KEY_GoogleClientID. An empty
value means Secrets.xcconfig wasn't filled in; LiveGoogleAuthService
throws .notConfigured rather than crashing.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: `GIDSigningClient` protocol seam + Real impl

**Files:**
- Create: `WeeklyPlanner/Auth/GoogleAuth/GIDSigningClient.swift`

The seam isolates the GoogleSignIn SDK so `LiveGoogleAuthService` is testable. The protocol returns our own `GoogleAccountInfo` (NOT `GIDGoogleUser`), keeping SDK types out of the test surface.

- [ ] **Step 1: Write the file**

```swift
import Foundation
import GoogleSignIn
import UIKit

/// Thin adapter over `GIDSignIn.sharedInstance`. The protocol returns our own
/// `GoogleAccountInfo` (NOT `GIDGoogleUser`) so the test fake doesn't need to
/// construct SDK types. The real impl is the only place where SDK types are
/// touched in the auth layer.
@MainActor
protocol GIDSigningClient {
    /// Configures the SDK with the given client ID. Called once at app
    /// start-up; idempotent.
    func configure(clientID: String)

    /// Presents the OAuth sheet and returns the resulting account snapshot.
    func signIn(presenting: UIViewController, scopes: [String]) async throws -> GoogleAccountInfo

    /// Refreshes the access token using the cached refresh token.
    func refresh() async throws -> GoogleAccountInfo

    /// Hands a URL to the SDK (called from `WeeklyPlannerApp.onOpenURL`).
    func handle(url: URL) -> Bool

    /// Revokes server-side and clears the SDK's local cache.
    func signOut()

    /// Returns the SDK's currently-signed-in user as a snapshot, or `nil`.
    func currentSnapshot() -> GoogleAccountInfo?
}

@MainActor
final class RealGIDSigningClient: GIDSigningClient {
    func configure(clientID: String) {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
    }

    func signIn(presenting: UIViewController, scopes: [String]) async throws -> GoogleAccountInfo {
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: presenting,
                hint: nil,
                additionalScopes: scopes
            )
            return try snapshot(from: result.user)
        } catch let error as NSError where error.code == GIDSignInError.canceled.rawValue {
            throw GoogleAuthError.userCancelled
        } catch {
            throw GoogleAuthError.network(error.localizedDescription)
        }
    }

    func refresh() async throws -> GoogleAccountInfo {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw GoogleAuthError.reauthenticationRequired
        }
        do {
            try await user.refreshTokensIfNeeded()
            return try snapshot(from: user)
        } catch {
            throw GoogleAuthError.reauthenticationRequired
        }
    }

    func handle(url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }

    func currentSnapshot() -> GoogleAccountInfo? {
        guard let user = GIDSignIn.sharedInstance.currentUser else { return nil }
        return try? snapshot(from: user)
    }

    private func snapshot(from user: GIDGoogleUser) throws -> GoogleAccountInfo {
        guard let email = user.profile?.email else {
            throw GoogleAuthError.network("Missing email on Google profile")
        }
        return GoogleAccountInfo(
            email: email,
            accessToken: user.accessToken.tokenString,
            refreshToken: user.refreshToken.tokenString,
            expiresAt: user.accessToken.expirationDate ?? Date(timeIntervalSinceNow: 3000)
        )
    }
}
```

- [ ] **Step 2: Confirm compilation**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO 2>&1 \
  | grep -E "BUILD FAILED|BUILD SUCCEEDED" | tail -2
```

Expected: `** BUILD SUCCEEDED **`. If the build complains about `GIDSignInError.canceled` not existing, the SDK API changed — check the [GoogleSignIn-iOS migration notes](https://github.com/google/GoogleSignIn-iOS) for the current cancellation sentinel.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Auth/GoogleAuth/GIDSigningClient.swift WeeklyPlanner.xcodeproj
git commit -m "feat(phase-17): GIDSigningClient protocol seam + Real adapter

Wraps GIDSignIn.sharedInstance so LiveGoogleAuthService is testable.
Protocol returns our own GoogleAccountInfo (not GIDGoogleUser) — fakes
don't have to construct SDK types.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: `LiveGoogleAuthService` (TDD against the seam)

**Files:**
- Create: `WeeklyPlanner/Auth/GoogleAuth/LiveGoogleAuthService.swift`
- Test:   `WeeklyPlannerTests/Auth/GoogleAuthServiceTests.swift`

- [ ] **Step 1: Write the failing test file**

Create `WeeklyPlannerTests/Auth/GoogleAuthServiceTests.swift`:

```swift
import XCTest
import UIKit
@testable import WeeklyPlanner

@MainActor
final class GoogleAuthServiceTests: XCTestCase {
    private var serviceID: String!
    private var keychain: TokenKeychainStore<GoogleAccountInfo>!
    private var fakeClient: FakeGIDSigningClient!
    private var sut: LiveGoogleAuthService!

    override func setUp() async throws {
        try await super.setUp()
        serviceID = "com.weeklyplanner.tests.\(UUID().uuidString)"
        keychain = TokenKeychainStore<GoogleAccountInfo>(serviceID: serviceID)
        try keychain.clear()
        fakeClient = FakeGIDSigningClient()
        sut = LiveGoogleAuthService(
            config: GoogleAuthConfig(clientID: "test-client-id"),
            client: fakeClient,
            keychain: keychain
        )
    }

    override func tearDown() async throws {
        try? keychain.clear()
        try await super.tearDown()
    }

    func testSignInPersistsTokensInKeychain() async throws {
        let presenter = UIViewController()
        let result = try await sut.signIn(presenting: presenter)

        XCTAssertEqual(result.email, "sara@gmail.com")
        let stored = try keychain.load()
        XCTAssertEqual(stored, result)
        XCTAssertEqual(fakeClient.signInCount, 1)
    }

    func testSignInFailurePropagatesAndDoesNotStore() async throws {
        fakeClient.signInResult = .failure(GoogleAuthError.userCancelled)
        let presenter = UIViewController()

        do {
            _ = try await sut.signIn(presenting: presenter)
            XCTFail("Expected throw")
        } catch GoogleAuthError.userCancelled {
            // expected
        }

        XCTAssertNil(try keychain.load())
    }

    func testSignOutClearsKeychainAndSDK() async throws {
        _ = try await sut.signIn(presenting: UIViewController())
        XCTAssertNotNil(try keychain.load())

        await sut.signOut()

        XCTAssertNil(try keychain.load())
        XCTAssertEqual(fakeClient.signOutCount, 1)
    }

    func testAccessTokenReturnsCachedWhenFresh() async throws {
        _ = try await sut.signIn(presenting: UIViewController())
        let token = try await sut.accessToken()
        XCTAssertEqual(token, "stub-access-token")
        XCTAssertEqual(fakeClient.refreshCount, 0)
    }

    func testAccessTokenRefreshesWhenExpiringSoon() async throws {
        fakeClient.signInResult = .success(.init(
            email: "sara@gmail.com",
            accessToken: "old-token",
            refreshToken: "r",
            expiresAt: Date(timeIntervalSinceNow: 60) // 1 min from now → triggers refresh
        ))
        fakeClient.refreshResult = .success(.init(
            email: "sara@gmail.com",
            accessToken: "new-token",
            refreshToken: "r",
            expiresAt: Date(timeIntervalSinceNow: 3600)
        ))
        _ = try await sut.signIn(presenting: UIViewController())

        let token = try await sut.accessToken()

        XCTAssertEqual(token, "new-token")
        XCTAssertEqual(fakeClient.refreshCount, 1)
        XCTAssertEqual(try keychain.load()?.accessToken, "new-token")
    }

    func testNotConfiguredThrowsWhenClientIDEmpty() async throws {
        sut = LiveGoogleAuthService(
            config: GoogleAuthConfig(clientID: ""),
            client: fakeClient,
            keychain: keychain
        )

        do {
            _ = try await sut.signIn(presenting: UIViewController())
            XCTFail("Expected throw")
        } catch GoogleAuthError.notConfigured {
            // expected
        }

        XCTAssertEqual(fakeClient.signInCount, 0) // SDK never touched
    }

    func testCurrentAccountReadsFromKeychain() async throws {
        _ = try await sut.signIn(presenting: UIViewController())
        let account = sut.currentAccount()
        XCTAssertEqual(account?.email, "sara@gmail.com")
    }
}

// MARK: - Test double

@MainActor
final class FakeGIDSigningClient: GIDSigningClient {
    var signInResult: Result<GoogleAccountInfo, Error> = .success(.init(
        email: "sara@gmail.com",
        accessToken: "stub-access-token",
        refreshToken: "stub-refresh-token",
        expiresAt: Date(timeIntervalSinceNow: 3600)
    ))
    var refreshResult: Result<GoogleAccountInfo, Error> = .failure(GoogleAuthError.reauthenticationRequired)

    private(set) var configureCount = 0
    private(set) var signInCount = 0
    private(set) var refreshCount = 0
    private(set) var signOutCount = 0
    private(set) var handleCount = 0
    private(set) var currentSnapshotCount = 0

    func configure(clientID _: String) { configureCount += 1 }

    func signIn(presenting _: UIViewController, scopes _: [String]) async throws -> GoogleAccountInfo {
        signInCount += 1
        return try signInResult.get()
    }

    func refresh() async throws -> GoogleAccountInfo {
        refreshCount += 1
        return try refreshResult.get()
    }

    func handle(url _: URL) -> Bool { handleCount += 1; return true }
    func signOut() { signOutCount += 1 }
    func currentSnapshot() -> GoogleAccountInfo? { currentSnapshotCount += 1; return nil }
}
```

- [ ] **Step 2: Run the test, expect compile fail**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO -only-testing:WeeklyPlannerTests/GoogleAuthServiceTests 2>&1 \
  | grep -E "error:" | head -5
```

Expected: `error: cannot find 'LiveGoogleAuthService' in scope`.

- [ ] **Step 3: Write the implementation**

Create `WeeklyPlanner/Auth/GoogleAuth/LiveGoogleAuthService.swift`:

```swift
import Foundation
import UIKit

/// Production `GoogleAuthService`. Composes:
/// - `GoogleAuthConfig` (the client ID from Info.plist),
/// - `GIDSigningClient` (the SDK seam — `RealGIDSigningClient` in production,
///   `FakeGIDSigningClient` in tests),
/// - `TokenKeychainStore<GoogleAccountInfo>` (encrypted local cache).
///
/// On init, calls `client.configure(clientID:)` once so `GIDSignIn` knows
/// which app it's signing in for. Subsequent `signIn` calls use that config.
@MainActor
final class LiveGoogleAuthService: GoogleAuthService {
    private let config: GoogleAuthConfig
    private let client: GIDSigningClient
    private let keychain: TokenKeychainStore<GoogleAccountInfo>
    private let scopes = [
        "https://www.googleapis.com/auth/gmail.readonly",
        "https://www.googleapis.com/auth/userinfo.email",
    ]
    private static let refreshLeeway: TimeInterval = 5 * 60 // refresh when <5 min remain

    init(
        config: GoogleAuthConfig,
        client: GIDSigningClient,
        keychain: TokenKeychainStore<GoogleAccountInfo>
    ) {
        self.config = config
        self.client = client
        self.keychain = keychain
        if config.isConfigured {
            client.configure(clientID: config.clientID)
        }
    }

    func signIn(presenting: UIViewController) async throws -> GoogleAccountInfo {
        guard config.isConfigured else { throw GoogleAuthError.notConfigured }
        let info = try await client.signIn(presenting: presenting, scopes: scopes)
        try keychain.save(info)
        return info
    }

    func signOut() async {
        client.signOut()
        try? keychain.clear()
    }

    func currentAccount() -> GoogleAccountInfo? {
        (try? keychain.load()) ?? client.currentSnapshot()
    }

    func accessToken() async throws -> String {
        guard let cached = try keychain.load() else {
            throw GoogleAuthError.reauthenticationRequired
        }
        if cached.expiresAt.timeIntervalSinceNow > Self.refreshLeeway {
            return cached.accessToken
        }
        let refreshed = try await client.refresh()
        try keychain.save(refreshed)
        return refreshed.accessToken
    }
}
```

- [ ] **Step 4: Run tests, expect green**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO -only-testing:WeeklyPlannerTests/GoogleAuthServiceTests 2>&1 \
  | grep -E "TEST FAILED|TEST SUCCEEDED|Executed [0-9]+ tests" | tail -3
```

Expected: `** TEST SUCCEEDED **`; `Executed 7 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Auth/GoogleAuth/LiveGoogleAuthService.swift \
        WeeklyPlannerTests/Auth/GoogleAuthServiceTests.swift \
        WeeklyPlanner.xcodeproj
git commit -m "feat(phase-17): LiveGoogleAuthService composes config + SDK seam + Keychain

Production GoogleAuthService. Refreshes tokens via the SDK when <5min
remain; throws .notConfigured when Secrets.xcconfig is empty; persists
every successful sign-in to Keychain via TokenKeychainStore. 7 tests
cover sign-in persistence, cancel propagation, sign-out cascade, fresh
vs expiring access tokens, .notConfigured short-circuit, currentAccount
fallback.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 11: Environment wiring (`\.googleAuthService`)

**Files:**
- Modify: `WeeklyPlanner/Stores/Environment+Stores.swift`
- Modify: `WeeklyPlanner/App/WeeklyPlannerApp.swift`

- [ ] **Step 1: Add the env key to `Environment+Stores.swift`**

Append to the `EnvironmentValues` extension (after `intelligenceService`):

```swift
    /// The active `GoogleAuthService`. Defaults to `StubGoogleAuthService`
    /// so previews never crash. Production wires `LiveGoogleAuthService`
    /// in `WeeklyPlannerApp`.
    @Entry var googleAuthService: any GoogleAuthService = StubGoogleAuthService()
```

- [ ] **Step 2: Inject the production service in `WeeklyPlannerApp`**

Edit `WeeklyPlanner/App/WeeklyPlannerApp.swift`. Add a new `@State` property after `settingsStore`:

```swift
    @State private var googleAuthService: any GoogleAuthService
```

Inside `init()`, after `settingsStore` is built and before `_container = State(...)`, construct it:

```swift
        let googleAuthService = LiveGoogleAuthService(
            config: .fromBundle(),
            client: RealGIDSigningClient(),
            keychain: TokenKeychainStore<GoogleAccountInfo>(
                serviceID: "com.weeklyplanner.WeeklyPlanner.google"
            )
        )
```

Then store it on `_googleAuthService` alongside the others:

```swift
        _googleAuthService = State(initialValue: googleAuthService)
```

In `body`, inject it via `.environment` alongside the existing stores:

```swift
                .environment(\.googleAuthService, googleAuthService)
```

- [ ] **Step 3: Add the `.onOpenURL` handler for OAuth callback**

Still in `body`, on the same chain after `.modelContainer(container)`:

```swift
                .onOpenURL { url in
                    _ = RealGIDSigningClient().handle(url: url)
                }
```

Note: `RealGIDSigningClient` is cheap to construct — it's a stateless wrapper. The SDK singleton (`GIDSignIn.sharedInstance`) holds the actual state.

- [ ] **Step 4: Confirm build + existing tests still green**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO 2>&1 \
  | grep -E "TEST FAILED|TEST SUCCEEDED|Executed [0-9]+ tests" | tail -3
```

Expected: `** TEST SUCCEEDED **`; `Executed 222 tests, with 0 failures` (211 baseline + 4 keychain + 7 auth-service).

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Stores/Environment+Stores.swift \
        WeeklyPlanner/App/WeeklyPlannerApp.swift \
        WeeklyPlanner.xcodeproj
git commit -m "feat(phase-17): wire LiveGoogleAuthService at the app entry

Adds \\.googleAuthService env key (StubGoogleAuthService default for
previews/tests). WeeklyPlannerApp builds the live service with
GoogleAuthConfig.fromBundle + RealGIDSigningClient + a Keychain store
namespaced at com.weeklyplanner.WeeklyPlanner.google. Also adds
.onOpenURL { GIDSignIn.handle(\$0) } so the OAuth callback URL is
delivered to the SDK on app re-entry.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 12: `ConnectionsViewModel` (TDD)

**Files:**
- Create: `WeeklyPlanner/Features/Settings/ConnectionsViewModel.swift`
- Test:   `WeeklyPlannerTests/Features/Settings/ConnectionsViewModelTests.swift`

Owns the connect/disconnect choreography. UI binds to `@Observable` properties; tests assert orchestration against `StubGoogleAuthService` + in-memory SwiftData stack.

- [ ] **Step 1: Write the failing test file**

Create `WeeklyPlannerTests/Features/Settings/ConnectionsViewModelTests.swift`:

```swift
import XCTest
import SwiftData
@testable import WeeklyPlanner

@MainActor
final class ConnectionsViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var settingsStore: SwiftDataSettingsStore!
    private var inboxStore: SwiftDataInboxStore!
    private var auth: StubGoogleAuthService!
    private var sut: ConnectionsViewModel!

    override func setUp() async throws {
        try await super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: UserSettings.self, InboxSuggestion.self, Event.self, TaskItem.self,
            configurations: config
        )
        settingsStore = SwiftDataSettingsStore(context: container.mainContext)
        inboxStore = SwiftDataInboxStore(context: container.mainContext)
        auth = StubGoogleAuthService()
        sut = ConnectionsViewModel(
            settingsStore: settingsStore,
            inboxStore: inboxStore,
            auth: auth
        )
    }

    // MARK: - Connect

    func testConnectHappyPathSetsConnectedFlagAndEmail() async throws {
        let presenter = await MainActor.run { UIViewController() }

        await sut.connectGmail(presenter: presenter)

        let settings = try settingsStore.current()
        XCTAssertTrue(settings.gmailConnected)
        XCTAssertEqual(settings.gmailAccountEmail, "sara@gmail.com")
        XCTAssertTrue(sut.isGmailConnected)
        XCTAssertNil(sut.alert)
    }

    func testConnectCancelRevertsOptimisticFlag() async throws {
        auth.nextSignInResult = .failure(GoogleAuthError.userCancelled)
        let presenter = await MainActor.run { UIViewController() }

        await sut.connectGmail(presenter: presenter)

        let settings = try settingsStore.current()
        XCTAssertFalse(settings.gmailConnected)
        XCTAssertNil(settings.gmailAccountEmail)
        XCTAssertFalse(sut.isGmailConnected)
        // cancel is silent — no alert
        XCTAssertNil(sut.alert)
    }

    func testConnectNetworkFailureShowsAlert() async throws {
        auth.nextSignInResult = .failure(GoogleAuthError.network("timeout"))
        let presenter = await MainActor.run { UIViewController() }

        await sut.connectGmail(presenter: presenter)

        XCTAssertFalse(sut.isGmailConnected)
        XCTAssertNotNil(sut.alert)
        XCTAssertEqual(sut.alert?.title, "Couldn't connect Gmail")
    }

    func testConnectNotConfiguredShowsHelpfulAlert() async throws {
        auth.nextSignInResult = .failure(GoogleAuthError.notConfigured)
        let presenter = await MainActor.run { UIViewController() }

        await sut.connectGmail(presenter: presenter)

        XCTAssertFalse(sut.isGmailConnected)
        XCTAssertEqual(sut.alert?.title, "Gmail isn't configured")
    }

    // MARK: - Disconnect

    func testDisconnectClearsConnectedFlag() async throws {
        // Pre-state: connected.
        await sut.connectGmail(presenter: UIViewController())
        XCTAssertTrue(try settingsStore.current().gmailConnected)

        await sut.disconnectGmail()

        let settings = try settingsStore.current()
        XCTAssertFalse(settings.gmailConnected)
        XCTAssertNil(settings.gmailAccountEmail)
        XCTAssertEqual(auth.signOutCount, 1)
    }

    func testDisconnectCascadeDeletesPendingSuggestions() async throws {
        await sut.connectGmail(presenter: UIViewController())
        try await inboxStore.upsert(makeSuggestion(id: "msg-1"))
        try await inboxStore.upsert(makeSuggestion(id: "msg-2"))

        await sut.disconnectGmail()

        let remaining = try await inboxStore.pending(
            forWeekOffset: 0,
            today: Date(timeIntervalSince1970: 1_700_000_000)
        )
        XCTAssertTrue(remaining.isEmpty)
    }

    // MARK: - Helpers

    private func makeSuggestion(id: String) -> InboxSuggestion {
        InboxSuggestion(
            gmailMessageID: id,
            proposedStart: Date(timeIntervalSince1970: 1_700_050_000), // mid-week of the "today" used above
            title: "Lunch with Sara",
            fromName: "Resy",
            fromEmail: "reservations@resy.com",
            subject: "Confirmed: 1pm at Café Bleu",
            bodySnippet: nil
        )
    }
}
```

- [ ] **Step 2: Run tests, expect compile fail**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO -only-testing:WeeklyPlannerTests/ConnectionsViewModelTests 2>&1 \
  | grep -E "error:" | head -5
```

Expected: `error: cannot find 'ConnectionsViewModel' in scope`.

- [ ] **Step 3: Add a helper on `SwiftDataInboxStore` for cascade-delete**

The cascade-delete on disconnect needs to clear pending suggestions. Add a single method to `WeeklyPlanner/Stores/InboxStore.swift`. First, extend the protocol (right after `func dismiss(id: UUID) async throws`):

```swift
    /// Deletes every `InboxSuggestion` row whose status is `.pending`. Called
    /// from `ConnectionsViewModel.disconnectGmail` so a re-connect doesn't
    /// resurrect stale rows from a previous account.
    func clearPending() async throws
```

Implement it on `SwiftDataInboxStore` (right after `dismiss`):

```swift
    func clearPending() async throws {
        let pendingRaw = InboxStatus.pending.rawValue
        let descriptor = FetchDescriptor<InboxSuggestion>(
            predicate: #Predicate<InboxSuggestion> { $0.statusRaw == pendingRaw }
        )
        for row in try context.fetch(descriptor) {
            context.delete(row)
        }
        try context.save()
    }
```

Add a no-op to `StubInboxStore` in `Environment+Stores.swift`:

```swift
    func clearPending() async throws {}
```

- [ ] **Step 4: Write the implementation**

Create `WeeklyPlanner/Features/Settings/ConnectionsViewModel.swift`:

```swift
import Foundation
import Observation
import UIKit

/// Orchestrates the Gmail row's connect / disconnect side effects so the
/// SwiftUI `ConnectionsSection` stays declarative.
///
/// Flow on connect: optimistic flag flip → `auth.signIn(...)` → on success
/// persist `gmailConnected=true` + `gmailAccountEmail` and broadcast
/// `Notification.Name.gmailDidConnect` (Phase 18 listens to kick a one-shot
/// sync). On cancel: silently revert. On network/notConfigured: revert AND
/// surface a `ConnectionsAlert` the view binds to.
///
/// Flow on disconnect: `auth.signOut()` + clear Keychain + flip
/// `gmailConnected=false` + cascade-delete pending `InboxSuggestion` rows so
/// a re-connect doesn't resurrect stale suggestions from the prior account.
@MainActor
@Observable
final class ConnectionsViewModel {
    /// Mirror of `UserSettings.gmailConnected` for the toggle binding.
    private(set) var isGmailConnected: Bool = false
    /// Account email for the row's detail line; nil when disconnected.
    private(set) var gmailAccountEmail: String?
    /// Transient alert state; the view binds and clears via `dismissAlert()`.
    var alert: ConnectionsAlert?

    private let settingsStore: any SettingsStoring
    private let inboxStore: any InboxStoring
    private let auth: any GoogleAuthService

    init(
        settingsStore: any SettingsStoring,
        inboxStore: any InboxStoring,
        auth: any GoogleAuthService
    ) {
        self.settingsStore = settingsStore
        self.inboxStore = inboxStore
        self.auth = auth
        refreshFromSettings()
    }

    /// Re-reads `gmailConnected` / `gmailAccountEmail` from the store. Called
    /// at init and after every successful connect/disconnect.
    func refreshFromSettings() {
        guard let settings = try? settingsStore.current() else { return }
        isGmailConnected = settings.gmailConnected
        gmailAccountEmail = settings.gmailAccountEmail
    }

    func connectGmail(presenter: UIViewController) async {
        do {
            let account = try await auth.signIn(presenting: presenter)
            try settingsStore.update { s in
                s.gmailConnected = true
                s.gmailAccountEmail = account.email
            }
            refreshFromSettings()
            NotificationCenter.default.post(name: .gmailDidConnect, object: account.email)
        } catch GoogleAuthError.userCancelled {
            refreshFromSettings()
        } catch GoogleAuthError.notConfigured {
            refreshFromSettings()
            alert = .notConfigured
        } catch {
            refreshFromSettings()
            alert = .connectFailed
        }
    }

    func disconnectGmail() async {
        await auth.signOut()
        try? await inboxStore.clearPending()
        try? settingsStore.update { s in
            s.gmailConnected = false
            s.gmailAccountEmail = nil
        }
        refreshFromSettings()
    }

    func dismissAlert() { alert = nil }
}

/// Transient alert state surfaced from `ConnectionsViewModel`. Two cases for
/// v1.0; more get added as Phase 18 reauthentication-required surfaces here.
struct ConnectionsAlert: Equatable {
    let title: String
    let message: String

    static let connectFailed = ConnectionsAlert(
        title: "Couldn't connect Gmail",
        message: "Check your network and try again."
    )

    static let notConfigured = ConnectionsAlert(
        title: "Gmail isn't configured",
        message: "Add your Google OAuth client ID to Secrets.xcconfig and rebuild. See README."
    )
}

extension Notification.Name {
    /// Posted by `ConnectionsViewModel.connectGmail` on success. Phase 18's
    /// `InboxSyncEngine` listens and kicks a one-shot sync so the user sees
    /// suggestions appear within ~10s of toggling the row on.
    static let gmailDidConnect = Notification.Name("WeeklyPlanner.gmailDidConnect")
}
```

- [ ] **Step 5: Run tests, expect green**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO -only-testing:WeeklyPlannerTests/ConnectionsViewModelTests 2>&1 \
  | grep -E "TEST FAILED|TEST SUCCEEDED|Executed [0-9]+ tests" | tail -3
```

Expected: `** TEST SUCCEEDED **`; `Executed 6 tests, with 0 failures`.

- [ ] **Step 6: Commit**

```bash
git add WeeklyPlanner/Features/Settings/ConnectionsViewModel.swift \
        WeeklyPlanner/Stores/InboxStore.swift \
        WeeklyPlanner/Stores/Environment+Stores.swift \
        WeeklyPlannerTests/Features/Settings/ConnectionsViewModelTests.swift \
        WeeklyPlanner.xcodeproj
git commit -m "feat(phase-17): ConnectionsViewModel orchestrates connect/disconnect

@Observable view-model that owns the Gmail toggle's side effects:
optimistic flag → auth.signIn → persist gmailConnected/email + broadcast
.gmailDidConnect; cancel is silent; network/notConfigured set an alert;
disconnect cascades a clearPending() on InboxStore so stale suggestions
don't survive an account swap. 6 tests cover the four connect paths and
two disconnect paths.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 13: Brand logos (three small SwiftUI files)

**Files:**
- Create: `WeeklyPlanner/Features/Settings/Logos/GmailBrandLogo.swift`
- Create: `WeeklyPlanner/Features/Settings/Logos/AppleBrandLogo.swift`
- Create: `WeeklyPlanner/Features/Settings/Logos/GoogleCalLogo.swift`

Pure SwiftUI shapes (no SF Symbols — brand assets shouldn't ship via SF Symbols per Apple HIG, and SF Symbols' Gmail glyph is licensed for marketing-only use). Match the mock at `docs/mock/paper-settings.jsx` (search for "GmailLogo", "AppleLogo", "GoogleCalLogo").

- [ ] **Step 1: GmailBrandLogo (22×16 multi-color "M")**

Create `WeeklyPlanner/Features/Settings/Logos/GmailBrandLogo.swift`:

```swift
import SwiftUI

/// Gmail "M" envelope logo, ~22×16. Five fills approximating the official
/// Gmail mark — used inside the Connections row's 28pt logo slot. NOT an SF
/// Symbol (Gmail SF glyph is marketing-only per Apple HIG).
struct GmailBrandLogo: View {
    var size: CGSize = CGSize(width: 22, height: 16)

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height

            // Left red panel
            let leftPanel = Path { p in
                p.move(to: CGPoint(x: 0, y: h * 0.25))
                p.addLine(to: CGPoint(x: 0, y: h))
                p.addLine(to: CGPoint(x: w * 0.18, y: h))
                p.addLine(to: CGPoint(x: w * 0.18, y: h * 0.45))
                p.closeSubpath()
            }
            context.fill(leftPanel, with: .color(Color(red: 0.91, green: 0.26, blue: 0.21)))

            // Right red panel
            let rightPanel = Path { p in
                p.move(to: CGPoint(x: w, y: h * 0.25))
                p.addLine(to: CGPoint(x: w, y: h))
                p.addLine(to: CGPoint(x: w * 0.82, y: h))
                p.addLine(to: CGPoint(x: w * 0.82, y: h * 0.45))
                p.closeSubpath()
            }
            context.fill(rightPanel, with: .color(Color(red: 0.91, green: 0.26, blue: 0.21)))

            // Inner red triangles (the "M" interior)
            let innerLeft = Path { p in
                p.move(to: CGPoint(x: w * 0.18, y: h * 0.45))
                p.addLine(to: CGPoint(x: w * 0.18, y: h))
                p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.7))
                p.closeSubpath()
            }
            context.fill(innerLeft, with: .color(Color(red: 0.83, green: 0.18, blue: 0.18)))

            let innerRight = Path { p in
                p.move(to: CGPoint(x: w * 0.82, y: h * 0.45))
                p.addLine(to: CGPoint(x: w * 0.82, y: h))
                p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.7))
                p.closeSubpath()
            }
            context.fill(innerRight, with: .color(Color(red: 0.83, green: 0.18, blue: 0.18)))

            // Top envelope flap (white over the panels)
            let flap = Path { p in
                p.move(to: CGPoint(x: 0, y: h * 0.25))
                p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.7))
                p.addLine(to: CGPoint(x: w, y: h * 0.25))
                p.addLine(to: CGPoint(x: w, y: h * 0.1))
                p.addLine(to: CGPoint(x: 0, y: h * 0.1))
                p.closeSubpath()
            }
            context.fill(flap, with: .color(.white))
        }
        .frame(width: size.width, height: size.height)
        .accessibilityLabel("Gmail logo")
    }
}

#Preview("GmailBrandLogo") {
    GmailBrandLogo().padding().background(.white)
}
```

- [ ] **Step 2: AppleBrandLogo (18×22 mono)**

Create `WeeklyPlanner/Features/Settings/Logos/AppleBrandLogo.swift`:

```swift
import SwiftUI

/// Apple logo silhouette, ~18×22. Renders via `Image(systemName: "apple.logo")`
/// at the theme's ink color. The SF Symbol is permitted for first-party Apple
/// product references (Apple HIG section "Apple logo").
struct AppleBrandLogo: View {
    var size: CGSize = CGSize(width: 18, height: 22)

    @Environment(\.paperTheme) private var theme

    var body: some View {
        Image(systemName: "apple.logo")
            .resizable()
            .scaledToFit()
            .frame(width: size.width, height: size.height)
            .foregroundStyle(theme.ink)
            .accessibilityLabel("Apple logo")
    }
}

#Preview("AppleBrandLogo") {
    AppleBrandLogo().padding().background(PaperTheme.cream.cream).paperTheme(.cream)
}
```

- [ ] **Step 3: GoogleCalLogo (20×20 stylized "31")**

Create `WeeklyPlanner/Features/Settings/Logos/GoogleCalLogo.swift`:

```swift
import SwiftUI

/// Stylized Google Calendar "31" tile, ~20×20. Hand-rolled SwiftUI rather
/// than the official brand asset — Phase 17 ships this row as "Coming soon",
/// so a recognizable but generic calendar tile is sufficient.
struct GoogleCalLogo: View {
    var size: CGSize = CGSize(width: 20, height: 20)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size.width * 0.18)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: size.width * 0.18)
                        .strokeBorder(Color(red: 0.85, green: 0.85, blue: 0.85), lineWidth: 0.5)
                )

            Text("31")
                .font(.system(size: size.width * 0.55, weight: .semibold))
                .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96)) // Google blue
        }
        .frame(width: size.width, height: size.height)
        .accessibilityLabel("Google Calendar logo")
    }
}

#Preview("GoogleCalLogo") {
    GoogleCalLogo().padding().background(.white)
}
```

- [ ] **Step 4: Build, no tests for visual primitives**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO 2>&1 \
  | grep -E "BUILD FAILED|BUILD SUCCEEDED" | tail -2
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Features/Settings/Logos/ WeeklyPlanner.xcodeproj
git commit -m "feat(phase-17): brand logos for ConnectionRow (Gmail / Apple / GoogleCal)

Three small SwiftUI primitives that render inside the 28pt logo slot of
each ConnectionRow. Gmail is hand-rolled Canvas paths (SF Symbol is
marketing-only); Apple is the SF Symbol 'apple.logo' (HIG-permitted);
Google Calendar is a stylized '31' tile (row is 'Coming soon' in v1.0).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 14: `ConnectionRow` (single-row primitive)

**Files:**
- Create: `WeeklyPlanner/Features/Settings/ConnectionRow.swift`

Pure presentation. Composition tests live in `ConnectionsSectionTests` (Task 16).

- [ ] **Step 1: Write the file**

```swift
import SwiftUI

/// One row of the Connections card: 28pt logo · label + detail (flex) ·
/// 44×26 PaperToggle. The label is system 14pt 600 ink; the detail is system
/// 11pt ink2. The toggle's `isOn` binding is supplied by the parent; the
/// `isEnabled` flag dims and disables the toggle (used by the Apple Mail and
/// Google Calendar rows).
struct ConnectionRow<Logo: View>: View {
    let logo: Logo
    let label: String
    let detail: String
    @Binding var isOn: Bool
    var isEnabled: Bool = true
    var onTap: (() -> Void)? = nil

    @Environment(\.paperTheme) private var theme

    init(
        @ViewBuilder logo: () -> Logo,
        label: String,
        detail: String,
        isOn: Binding<Bool>,
        isEnabled: Bool = true,
        onTap: (() -> Void)? = nil
    ) {
        self.logo = logo()
        self.label = label
        self.detail = detail
        _isOn = isOn
        self.isEnabled = isEnabled
        self.onTap = onTap
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack { logo }
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.ink2)
                    .lineSpacing(1.3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            PaperToggle(isOn: $isOn, style: .regular)
                .opacity(isEnabled ? 1 : 0.4)
                .allowsHitTesting(isEnabled)
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }
}

#Preview("ConnectionRow — Gmail off") {
    StatefulPreview(initial: false) { binding in
        ConnectionRow(
            logo: { GmailBrandLogo() },
            label: "Gmail",
            detail: "Tap to connect — pulls events & reminders from your inbox",
            isOn: binding
        )
        .padding()
        .background(PaperTheme.cream.creamHi)
        .paperTheme(.cream)
    }
}

/// Local preview helper — gives the binding a backing store so #Preview can
/// render without an enclosing view-model.
private struct StatefulPreview<Content: View>: View {
    @State private var value: Bool
    let content: (Binding<Bool>) -> Content

    init(initial: Bool, @ViewBuilder content: @escaping (Binding<Bool>) -> Content) {
        _value = State(initialValue: initial)
        self.content = content
    }

    var body: some View { content($value) }
}
```

- [ ] **Step 2: Build**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO 2>&1 \
  | grep -E "BUILD FAILED|BUILD SUCCEEDED" | tail -2
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Features/Settings/ConnectionRow.swift WeeklyPlanner.xcodeproj
git commit -m "feat(phase-17): ConnectionRow presentation primitive

28pt logo · label/detail (flex) · 44×26 PaperToggle. Generic over the
logo type so each row supplies its own brand mark. isEnabled dims the
toggle for the Apple Mail and Google Calendar rows.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 15: `ConnectionsSection` (composes the three rows)

**Files:**
- Create: `WeeklyPlanner/Features/Settings/ConnectionsSection.swift`

- [ ] **Step 1: Write the file**

```swift
import MessageUI
import SwiftUI

/// The real Connections card — replaces Phase 16's `ConnectionsPlaceholder`
/// body. Three rows separated by 0.5pt rules: Gmail (interactive — drives
/// `ConnectionsViewModel`), Apple Mail (read-only status based on
/// `MFMailComposeViewController.canSendMail()`), Google Calendar ("Coming
/// soon", disabled).
struct ConnectionsSection: View {
    @Environment(\.paperTheme) private var theme
    @Environment(\.googleAuthService) private var auth
    @Environment(\.settingsStore) private var settingsStore
    @Environment(\.inboxStore) private var inboxStore

    @State private var viewModel: ConnectionsViewModel?
    @State private var showDisconnectConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(eyebrow: "SOURCES", title: "Connections")

            card
        }
        .task {
            if viewModel == nil {
                viewModel = ConnectionsViewModel(
                    settingsStore: settingsStore,
                    inboxStore: inboxStore,
                    auth: auth
                )
            }
        }
        .alert(item: alertBinding) { a in
            Alert(title: Text(a.title), message: Text(a.message), dismissButton: .default(Text("OK")))
        }
        .confirmationDialog(
            "Disconnect Gmail?",
            isPresented: $showDisconnectConfirm,
            titleVisibility: .visible
        ) {
            Button("Disconnect", role: .destructive) { Task { await viewModel?.disconnectGmail() } }
            Button("Cancel", role: .cancel) { viewModel?.refreshFromSettings() }
        } message: {
            Text("Pending inbox suggestions for this account will be removed.")
        }
    }

    // MARK: - Card body

    private var card: some View {
        VStack(spacing: 0) {
            gmailRow
            Divider().background(theme.rule).frame(height: 0.5)
            appleMailRow
            Divider().background(theme.rule).frame(height: 0.5)
            googleCalRow
        }
        .background(theme.creamHi)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14).strokeBorder(theme.rule, lineWidth: 0.5)
        )
        .padding(.bottom, 14)
    }

    // MARK: - Rows

    private var gmailRow: some View {
        ConnectionRow(
            logo: { GmailBrandLogo() },
            label: "Gmail",
            detail: gmailDetail,
            isOn: gmailToggleBinding
        )
    }

    private var appleMailRow: some View {
        let connected = MFMailComposeViewController.canSendMail()
        return ConnectionRow(
            logo: { AppleBrandLogo() },
            label: "Apple Mail",
            detail: connected ? "Connected · iCloud" : "Sign in to Mail in iOS Settings",
            isOn: .constant(connected),
            isEnabled: false,
            onTap: { viewModel?.alert = .appleMailManagedByiOS }
        )
    }

    private var googleCalRow: some View {
        ConnectionRow(
            logo: { GoogleCalLogo() },
            label: "Google Calendar",
            detail: "Coming soon",
            isOn: .constant(false),
            isEnabled: false
        )
    }

    // MARK: - Bindings

    private var gmailDetail: String {
        if let vm = viewModel, vm.isGmailConnected, let email = vm.gmailAccountEmail {
            return "\(email) · syncing events"
        }
        return "Tap to connect — pulls events & reminders from your inbox"
    }

    private var gmailToggleBinding: Binding<Bool> {
        Binding(
            get: { viewModel?.isGmailConnected ?? false },
            set: { newValue in
                guard let vm = viewModel else { return }
                if newValue, vm.isGmailConnected == false {
                    Task { await vm.connectGmail(presenter: topPresenter()) }
                } else if newValue == false, vm.isGmailConnected {
                    showDisconnectConfirm = true
                }
            }
        )
    }

    private var alertBinding: Binding<ConnectionsAlert?> {
        Binding(get: { viewModel?.alert }, set: { viewModel?.alert = $0 })
    }

    /// Resolves the active key window's root view controller for the SDK to
    /// present the OAuth sheet from. Avoids Scene Delegate footguns by walking
    /// `UIApplication.shared.connectedScenes`.
    @MainActor
    private func topPresenter() -> UIViewController {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let keyWindow = scenes.flatMap { $0.windows }.first(where: { $0.isKeyWindow })
        return keyWindow?.rootViewController ?? UIViewController()
    }
}

extension ConnectionsAlert: Identifiable {
    var id: String { title + message }

    static let appleMailManagedByiOS = ConnectionsAlert(
        title: "Apple Mail",
        message: "Apple Mail is managed by iOS Settings."
    )
}
```

- [ ] **Step 2: Replace the body of `ConnectionsPlaceholder` so the call-site in `PaperSettingsView` keeps working**

Edit `WeeklyPlanner/Features/Settings/ConnectionsPlaceholder.swift`. Replace the file contents with:

```swift
import SwiftUI

/// Phase 16 left this file as a placeholder. Phase 17 keeps the type so
/// `PaperSettingsView`'s call-site (`ConnectionsPlaceholder()`) doesn't churn
/// — the body now simply forwards to the real `ConnectionsSection`. A future
/// refactor (Phase 22 polish) can rename the call-site and delete this
/// shim.
struct ConnectionsPlaceholder: View {
    var body: some View {
        ConnectionsSection()
    }
}

#Preview("ConnectionsPlaceholder") {
    ConnectionsPlaceholder()
        .padding()
        .background(PaperTheme.cream.cream)
        .paperTheme(.cream)
}
```

- [ ] **Step 3: Build + full test suite**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO 2>&1 \
  | grep -E "TEST FAILED|TEST SUCCEEDED|Executed [0-9]+ tests" | tail -3
```

Expected: `** TEST SUCCEEDED **`; existing test count holds (no regressions); previews still render.

- [ ] **Step 4: Commit**

```bash
git add WeeklyPlanner/Features/Settings/ConnectionsSection.swift \
        WeeklyPlanner/Features/Settings/ConnectionsPlaceholder.swift \
        WeeklyPlanner.xcodeproj
git commit -m "feat(phase-17): ConnectionsSection replaces Phase 16 placeholder

Three rows (Gmail interactive, Apple Mail read-only, Google Calendar
disabled) inside the cream card. Gmail toggle drives ConnectionsViewModel
via a Binding that intercepts off→on (sign-in) and on→off (destructive
confirmation dialog). ConnectionsPlaceholder becomes a one-line shim so
PaperSettingsView's call-site doesn't churn.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 16: `ConnectionsSectionTests` (structural assertions)

**Files:**
- Test: `WeeklyPlannerTests/Features/Settings/ConnectionsSectionTests.swift`

`ViewInspector` is not a dep (Phase 16 deferred snapshot tests for the same reason). Assert what we can without instantiating the view: the alert factory matrix and the `gmailDetail` logic via the view-model.

- [ ] **Step 1: Write the test file**

Create `WeeklyPlannerTests/Features/Settings/ConnectionsSectionTests.swift`:

```swift
import XCTest
import SwiftData
@testable import WeeklyPlanner

@MainActor
final class ConnectionsSectionTests: XCTestCase {

    // MARK: - ConnectionsAlert factory

    func testAlertConnectFailedShape() {
        let a = ConnectionsAlert.connectFailed
        XCTAssertEqual(a.title, "Couldn't connect Gmail")
        XCTAssertFalse(a.message.isEmpty)
    }

    func testAlertNotConfiguredMentionsSecretsFile() {
        let a = ConnectionsAlert.notConfigured
        XCTAssertEqual(a.title, "Gmail isn't configured")
        XCTAssertTrue(a.message.contains("Secrets.xcconfig"))
    }

    func testAlertAppleMailMentionsiOSSettings() {
        let a = ConnectionsAlert.appleMailManagedByiOS
        XCTAssertEqual(a.title, "Apple Mail")
        XCTAssertTrue(a.message.contains("iOS Settings"))
    }

    // MARK: - gmailDidConnect notification

    func testGmailDidConnectNotificationName() {
        XCTAssertEqual(
            Notification.Name.gmailDidConnect.rawValue,
            "WeeklyPlanner.gmailDidConnect"
        )
    }

    // MARK: - View-model detail line via container

    func testGmailDetailTextWhenDisconnected() async throws {
        let vm = makeViewModel(connected: false, email: nil)
        XCTAssertFalse(vm.isGmailConnected)
        XCTAssertNil(vm.gmailAccountEmail)
    }

    func testGmailDetailTextWhenConnected() async throws {
        let vm = makeViewModel(connected: true, email: "sara@gmail.com")
        XCTAssertTrue(vm.isGmailConnected)
        XCTAssertEqual(vm.gmailAccountEmail, "sara@gmail.com")
    }

    // MARK: - Helpers

    private func makeViewModel(connected: Bool, email: String?) -> ConnectionsViewModel {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: UserSettings.self, InboxSuggestion.self, Event.self, TaskItem.self,
            configurations: config
        )
        let settingsStore = SwiftDataSettingsStore(context: container.mainContext)
        try! settingsStore.update { s in
            s.gmailConnected = connected
            s.gmailAccountEmail = email
        }
        return ConnectionsViewModel(
            settingsStore: settingsStore,
            inboxStore: SwiftDataInboxStore(context: container.mainContext),
            auth: StubGoogleAuthService()
        )
    }
}
```

- [ ] **Step 2: Run tests, expect green (no new types needed — everything's been built)**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO -only-testing:WeeklyPlannerTests/ConnectionsSectionTests 2>&1 \
  | grep -E "TEST FAILED|TEST SUCCEEDED|Executed [0-9]+ tests" | tail -3
```

Expected: `** TEST SUCCEEDED **`; `Executed 6 tests, with 0 failures`.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlannerTests/Features/Settings/ConnectionsSectionTests.swift WeeklyPlanner.xcodeproj
git commit -m "test(phase-17): ConnectionsSectionTests structural assertions

ViewInspector isn't a dep (Phase 16 deferred snapshot tests for the same
reason). 6 tests cover the alert factory matrix, the gmailDidConnect
notification name, and the view-model detail-line state matrix.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 17: README "Google OAuth setup" section

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Locate the README's current bottom**

```bash
grep -n "^## " README.md | tail -5
```

The new section goes BEFORE the "License" section if one exists, otherwise at the bottom.

- [ ] **Step 2: Append the section**

Append the following to `README.md` (or insert above an existing License section):

```markdown
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
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs(phase-17): Google OAuth setup section in README

Per-developer Secrets.xcconfig contract, scope and test-user requirements,
graceful-degradation behavior when the file is missing. Points at the
Google Cloud Console URL and the bundle ID reviewers will need.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 18: Full test suite + manual on-device verification

**Files:** none (verification only)

- [ ] **Step 1: Full suite green**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO 2>&1 \
  | grep -E "TEST FAILED|TEST SUCCEEDED|Executed [0-9]+ tests" | tail -3
```

Expected: `** TEST SUCCEEDED **`; `Executed 228 tests, with 0 failures` (211 baseline + 4 keychain + 7 auth-service + 6 view-model + 6 section-tests = 234… ±3 if any test was renamed; the exact number isn't load-bearing, the green is).

- [ ] **Step 2: Launch in the simulator and visually confirm the row**

```bash
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
xcrun simctl install booted $(find ~/Library/Developer/Xcode/DerivedData -name "WeeklyPlanner.app" -path "*Debug-iphonesimulator*" | head -1)
xcrun simctl launch booted com.weeklyplanner.WeeklyPlanner
open -a Simulator
```

Then in the simulator:
- Tap the Settings tab (right-most paper-tab-bar item).
- Scroll to the **Connections** section. Three rows visible:
  - **Gmail** with the red-and-white "M" logo, label, "Tap to connect…" detail, toggle off.
  - **Apple Mail** with the Apple silhouette, "Connected · iCloud" (simulator returns true from `canSendMail`).
  - **Google Calendar** with the "31" tile, "Coming soon", toggle off and dimmed.
- Tap the Gmail toggle → Safari/ASWebAuthenticationSession sheet appears showing Google's account picker. Cancel → toggle returns to off, no alert.
- Tap the Gmail toggle again → sign in with the test-user Gmail account you added in Step 3 of the README setup → consent screen → on success the row's detail updates to `"{your-email} · syncing events"` and the toggle stays on.
- Tap the Gmail toggle off → "Disconnect Gmail?" confirmation dialog → tap **Disconnect** → detail returns to "Tap to connect…", toggle off.
- Force-quit and relaunch → previous connected state is restored from Keychain (the simulator preserves Keychain across launches by default).

If anything misbehaves at this step, stop and debug before continuing — Phase 18 builds on these guarantees.

- [ ] **Step 3: Do not commit**

Verification only.

---

## Task 19: Phase 17 retrospective + docs update

**Files:**
- Modify: `docs/phases/README.md` (append retro + flip status)

- [ ] **Step 1: Append the retrospective**

After the Phase 16 retrospective in `docs/phases/README.md`, append:

```markdown
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
keeping Google SDK types out of every test boundary. Tokens auto-refresh
when `<5min` remain via the cached refresh token.

Secret plumbing lives in a gitignored `Secrets.xcconfig` whose
`GOOGLE_CLIENT_ID` and `REVERSED_GOOGLE_CLIENT_ID` flow through XcodeGen
`configFiles` and `INFOPLIST_KEY_GoogleClientID` into the bundled
Info.plist (replacing the Phase 01 `PLACEHOLDER` URL scheme). A
committed `Secrets.example.xcconfig` documents the contract; missing
secrets surface as `GoogleAuthError.notConfigured` → in-app "Gmail
isn't configured…" alert rather than a crash.

`ConnectionsViewModel` (`@Observable`) owns the connect/disconnect
choreography: optimistic toggle → `auth.signIn` → persist + broadcast
`Notification.Name.gmailDidConnect` (Phase 18 will listen). On cancel:
silent revert. On network/notConfigured: revert + alert. On disconnect:
confirmation dialog → `signOut` + Keychain clear + `inboxStore.clearPending()`
so re-connect doesn't resurrect stale `InboxSuggestion` rows. Six
view-model tests cover the four connect paths and two disconnect paths.

The `.onOpenURL` handler in `WeeklyPlannerApp` hands incoming OAuth
callback URLs to `GIDSignIn.sharedInstance.handle(_:)`.

**Tests added**: 4 classes / 23 new test methods
(`TokenKeychainStoreTests` × 4, `GoogleAuthServiceTests` × 7,
`ConnectionsViewModelTests` × 6, `ConnectionsSectionTests` × 6). Full
suite stays green. Snapshot tests deferred to Phase 21.

**Files**: `WeeklyPlanner/Auth/GoogleAuth/{GoogleAccountInfo,GoogleAuthConfig,GoogleAuthError,GoogleAuthService,GIDSigningClient,LiveGoogleAuthService,TokenKeychainStore}.swift`, `WeeklyPlanner/Features/Settings/{ConnectionsSection,ConnectionRow,ConnectionsViewModel}.swift`, `WeeklyPlanner/Features/Settings/Logos/{GmailBrandLogo,AppleBrandLogo,GoogleCalLogo}.swift`; modified `WeeklyPlanner/Stores/{Environment+Stores,InboxStore}.swift`, `WeeklyPlanner/App/WeeklyPlannerApp.swift`, `WeeklyPlanner/Features/Settings/ConnectionsPlaceholder.swift`, `project.yml`, `WeeklyPlanner/Supporting/Info.plist`, `.gitignore`, `README.md`.
```

- [ ] **Step 2: Flip the status table**

In the same file, change the Phase 17 row of the Phase Map table from:

```
| 17 | Settings — Connections (Gmail OAuth, Google, Apple)  | G                   | ⏳     |
```

to:

```
| 17 | Settings — Connections (Gmail OAuth, Google, Apple)  | G                   | ✅     |
```

Update the "Current state" line below the table to mention Phase 17 shipped:

```
**Current state:** Milestones A–F + Phases 16, 17 shipped. 234 unit tests
green. Next up: Phase 18 — Gmail Inbox Pipeline.
```

(Adjust the test count to whatever Step 1 of Task 18 reported.)

- [ ] **Step 3: Commit**

```bash
git add docs/phases/README.md
git commit -m "docs(phase-17): retrospective + status updates

Phase 17 marked complete in the Phase Map; current-state line updated to
point at Phase 18. Retrospective covers the auth foundation, secret
plumbing, view-model orchestration, and the brand-logo decisions.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 20: Hand-off

**Files:** none

- [ ] **Step 1: Confirm the branch is clean and the suite is green**

```bash
git status --short
git log --oneline -25 | grep "phase-17"
```

Expected: empty status; ~18 `phase-17` commits.

- [ ] **Step 2: Do NOT merge to main yet**

Phase 18 and 19 land on the same `milestone-h-integrations` branch. The final merge to `main` happens after all three phases are green.

- [ ] **Step 3: Hand off to Phase 18 plan-writing**

Notify the user that Phase 17 is complete on the branch. The next step is to write the Phase 18 plan via `superpowers:writing-plans` against the same Milestone H spec, informed by anything we learned from real on-device OAuth behaviour during Task 18 verification (token refresh timing, cold-launch Keychain restore, presenter-resolution edge cases).

---

## Self-review

Spec coverage:
- ✅ Phase 17 phase-doc files — every one in the spec's file list maps to a task here.
- ✅ Secret plumbing (Task 2).
- ✅ GoogleSignIn SPM dep (Task 3).
- ✅ Auth layer files (Tasks 4–10).
- ✅ Env wiring (Task 11).
- ✅ View-model + tests (Task 12).
- ✅ Brand logos (Task 13).
- ✅ ConnectionRow (Task 14).
- ✅ ConnectionsSection (Task 15) + the placeholder-shim approach to avoid PaperSettingsView churn.
- ✅ Structural tests (Task 16).
- ✅ README (Task 17).
- ✅ Manual on-device verification (Task 18).
- ✅ Retrospective (Task 19).

Placeholder scan: no "TBD" / "implement later" / vague "appropriate handling" strings. Every test method is named and bodied. Every commit message is concrete.

Type consistency: `GoogleAccountInfo`, `GoogleAuthService`, `GIDSigningClient`, `LiveGoogleAuthService`, `StubGoogleAuthService`, `TokenKeychainStore<Value>`, `ConnectionsViewModel`, `ConnectionsSection`, `ConnectionRow`, `ConnectionsAlert`, `Notification.Name.gmailDidConnect` — all referenced names match the file where they're defined.

Out-of-scope deferred (Phase 18 / 19 handle):
- Reauthentication-required surfacing in the row's detail line (Phase 18 surfaces "Reconnect Gmail" inline when the GmailClient hits a 401 on refresh).
- Denied-notifications banner in the Connections card (Phase 19 adds it).
- Triggering an actual Gmail sync on `gmailDidConnect` (Phase 18's `InboxSyncEngine` listens).
