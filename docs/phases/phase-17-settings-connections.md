# Phase 17 — Settings — Connections (Gmail OAuth, Google Calendar, Apple Mail)

## Goal
Implement the Connections card in Settings: three rows (Gmail, Apple Mail, Google Calendar) with brand logos, status text, and Paper toggles. Wire Google Sign-In for Gmail (OAuth scope read-only on `gmail.metadata` and `gmail.readonly`). Apple Mail is a read-only status row (always-on if Apple Mail is configured on the device). Google Calendar is a placeholder for v1.1 with a `"Coming soon"` status.

## Why this is needed
The Connections row drives Phase 18's Gmail pipeline. Without it, the inbox suggestions block is empty.

## Prerequisites
- Phases 01 (Google Sign-In SPM dep + URL scheme), 02, 03 (`UserSettings.gmailConnected/...`), 15, 16 (Settings page shell exists).

## Files Created / Modified

```
WeeklyPlanner/Features/Settings/ConnectionsSection.swift           # NEW — replaces placeholder
WeeklyPlanner/Features/Settings/ConnectionRow.swift                # NEW
WeeklyPlanner/Features/Settings/Logos/GmailBrandLogo.swift         # NEW — 22×16 multi-color
WeeklyPlanner/Features/Settings/Logos/AppleBrandLogo.swift         # NEW — 18×22 mono
WeeklyPlanner/Features/Settings/Logos/GoogleCalLogo.swift          # NEW — 20×20 stylized "31"
WeeklyPlanner/Auth/GoogleAuth/GoogleAuthService.swift              # NEW — wraps GoogleSignIn
WeeklyPlanner/Auth/GoogleAuth/GoogleAuthConfig.swift               # NEW — client ID + scopes
WeeklyPlanner/Auth/GoogleAuth/TokenKeychainStore.swift             # NEW — Keychain wrapper
WeeklyPlanner/Auth/GoogleAuth/GoogleAccountInfo.swift              # NEW — DTO for account email
WeeklyPlanner/App/RootView.swift                                   # MODIFY — handle OAuth callback URL
WeeklyPlannerTests/Auth/GoogleAuthServiceTests.swift               # NEW (mocked GIDSignIn)
WeeklyPlannerTests/Features/ConnectionsSectionTests.swift          # NEW
WeeklyPlannerTests/Features/ConnectionsSnapshotTests.swift         # NEW
```

## Visual & Interaction Checklist

### `ConnectionsSection`
- [ ] Replaces Phase 16's placeholder.
- [ ] `SectionTitle` eyebrow `"SOURCES"` + title `"Connections"`.
- [ ] Card container: background `theme.creamHi`, radius 14, overflow hidden, border 0.5pt `theme.rule`, marginBottom 14.
- [ ] Three `ConnectionRow`s separated by 0.5pt `theme.rule` (no divider after the last).

### `ConnectionRow`
- [ ] Flex row align-center gap 12, padding `12 14`.
- [ ] Leading logo (28pt-wide container, centered).
- [ ] Middle (flex 1, minWidth 0):
  - Label (system 14pt 600 color `ink`).
  - Detail (system 11pt color `ink2` marginTop 1 line-height 1.3).
- [ ] Trailing `PaperToggle` (44×26).

### Row content

#### Gmail
- [ ] Logo: full color Gmail "M" (`GmailBrandLogo`).
- [ ] Label: `"Gmail"`.
- [ ] Detail (toggled on): `"{accountEmail} · syncing events"`.
- [ ] Detail (toggled off): `"Tap to connect — pulls events & reminders from your inbox"`.
- [ ] Toggle interaction:
  - **Off → On**: triggers OAuth flow.
  - **On → Off**: confirmation alert `"Disconnect Gmail?"`. Removes token + clears inbox suggestions.

#### Apple Mail
- [ ] Logo: Apple monochrome.
- [ ] Label: `"Apple Mail"`.
- [ ] Detail: `"Connected · iCloud"` if `MFMailComposeViewController.canSendMail()` is true; else `"Sign in to Mail in iOS Settings"`.
- [ ] Toggle: always on, disabled (greyed). Tap shows tooltip alert `"Apple Mail is managed by iOS Settings."`.
- [ ] **Note**: in v1.0, Apple Mail integration is read-only and limited. Actual MailKit hooks require MDM-distributed extension entitlements; we ship a no-op status indicator. Document in CHANGELOG.

#### Google Calendar
- [ ] Logo: stylized 31.
- [ ] Label: `"Google Calendar"`.
- [ ] Detail: `"Coming soon"`.
- [ ] Toggle: off, disabled.

## Logic & Data Checklist

### Google Sign-In setup
- [ ] `GoogleAuthConfig`:
  - `clientID` — from a `Secrets.plist` (gitignored) or environment variable. Document setup in `README.md` (Phase 22).
  - `scopes`: `["https://www.googleapis.com/auth/gmail.readonly", "https://www.googleapis.com/auth/userinfo.email"]`.
  - `serverClientID` — optional, for refresh token exchange.
- [ ] `Info.plist` `CFBundleURLTypes` entry with `com.googleusercontent.apps.<reversedID>` (Phase 01 placeholder updated here).
- [ ] App delegate / `App` `onOpenURL` handler delegated to `GIDSignIn.sharedInstance.handle(url:)`.

### `GoogleAuthService`
- [ ] `signIn(presenting: UIViewController) async throws -> GoogleAccountInfo` — wraps `GIDSignIn.sharedInstance.signIn(withPresenting:)`.
- [ ] Persists `accessToken`, `refreshToken`, `expiresAt`, `email` in Keychain via `TokenKeychainStore`.
- [ ] `signOut() async`.
- [ ] `currentAccount() -> GoogleAccountInfo?`.
- [ ] `accessToken() async throws -> String` — refreshes if expired.

### `TokenKeychainStore`
- [ ] Generic store keyed by service ID (`"com.<org>.WeeklyPlanner.google"`).
- [ ] Stores codable structs.
- [ ] Migrates across reinstalls? **No** — iOS keychain persists across reinstalls by default; user must explicitly disconnect to clear. Acceptable.

### Toggle behavior
- [ ] **Connect Gmail flow**:
  1. Toggle flips visually to "on" (optimistic).
  2. Present OAuth via `ASWebAuthenticationSession` under the hood (handled by GoogleSignIn SDK).
  3. On success, save tokens, set `settings.gmailConnected = true`, store `accountEmail`. Trigger Phase 18 initial sync.
  4. On cancel/failure, revert toggle to off, show a non-blocking toast `"Couldn't connect Gmail."`.
- [ ] **Disconnect Gmail flow**:
  1. Confirmation alert (`Cancel | Disconnect` destructive).
  2. Confirm → revoke tokens, clear Keychain, set `gmailConnected=false`, delete all `InboxSuggestion` rows.

### Privacy hygiene
- [ ] Display the account email exactly as Google returns it (no normalization).
- [ ] Provide a `"Privacy & Permissions"` info link below the card (placeholder, scope expanded in Phase 22).

## Tests (TDD)

`GoogleAuthServiceTests` (mock `GIDSignIn`)
- [ ] `testSignInPersistsTokensInKeychain()`.
- [ ] `testSignInFailureClearsConnectedFlag()`.
- [ ] `testSignOutRevokesAndClears()`.
- [ ] `testAccessTokenRefreshesWhenExpired()`.

`ConnectionsSectionTests`
- [ ] `testToggleOnTriggersSignIn()`.
- [ ] `testToggleOffShowsConfirmation()`.
- [ ] `testAppleMailToggleAlwaysReadOnly()`.

`ConnectionsSnapshotTests`
- [ ] Snapshot of the card with all 3 rows, Gmail disconnected.
- [ ] Snapshot with Gmail connected as `sara@gmail.com`.
- [ ] Snapshot in midnight theme.

## Acceptance Criteria
- Toggling Gmail launches the system OAuth sheet via `ASWebAuthenticationSession`.
- After successful sign-in, the detail line updates with the account email.
- Token is securely stored in Keychain.
- Disconnect flow revokes the token (verified by replaying API call → 401).
- Apple Mail row shows correct status based on `canSendMail()`.
- Google Calendar row is visible but disabled.

## Out of Scope
- Google Calendar two-way sync (defer v1.1).
- Apple Mail message scanning (requires extension entitlements; defer).
- Microsoft 365 / Outlook (defer).

## Risks & Notes
- **Google Sign-In SDK** uses a `UIViewController` presenter — bridge via `UIApplication.shared.connectedScenes` to get the active key window's root controller. Avoid Scene Delegate footguns.
- **Token refresh** for Google can return 401 if user revoked from Google's side. Handle by detecting 401, clearing local state, and surfacing "Reconnect Gmail" in the row.
- **App Store review**: declare Gmail scope reasons clearly in App Privacy + reviewer notes. Be prepared with screenshots showing what we do with the data (read calendar invites only).
- **Privacy manifest** (Phase 22) must declare `NSPrivacyAccessedAPICategory` for `UserDefaults` (settings) and Email type.
