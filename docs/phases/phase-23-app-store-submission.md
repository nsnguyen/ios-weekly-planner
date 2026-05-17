# Phase 23 — App Store Submission & TestFlight

## Goal
Ship v1.0 to TestFlight, run a one-week beta, address feedback, and submit to the App Store for review. Includes signing, App Store Connect setup, distribution profile, build automation, and release management.

## Why this is needed
The product is only real once it's on devices in users' hands.

## Prerequisites
- Phases 01–22 complete. All tests green. No outstanding warnings.

## Files Created / Modified

```
fastlane/Fastfile                                           # NEW — beta + release lanes
fastlane/Appfile                                            # NEW — team + bundle ID
fastlane/Matchfile                                          # NEW — code signing
.github/workflows/release.yml                               # NEW — tag-triggered release pipeline
.github/workflows/testflight.yml                            # NEW — nightly testflight builds
docs/release/v1.0.0/PUBLIC_BETA_README.md                   # NEW — testers' guide
docs/release/v1.0.0/RELEASE_CHECKLIST.md                    # NEW — pre-submission gate
docs/release/v1.0.0/SUPPORT_FAQ.md                          # NEW — common questions
README.md                                                    # MODIFY — install + contribute
```

## Visual & Interaction Checklist

This phase has no in-app UI. Deliverables are process + artifacts.

## Logic & Data Checklist

### App Store Connect setup
- [ ] Create app record. Bundle ID: finalized (e.g., `com.<org>.WeeklyPlanner`).
- [ ] SKU: `WEEKLY-PLANNER-2026`.
- [ ] Primary language: English (U.S.).
- [ ] Pricing & Availability: Free (in 175 countries) — confirm tax forms signed.
- [ ] App Privacy: complete based on the privacy manifest from Phase 22.
- [ ] App Information: subtitle, primary category Productivity, secondary Lifestyle.
- [ ] User Access: assign QA testers as Internal users in TestFlight.

### Code signing (Fastlane Match)
- [ ] Generate App Store distribution certificate.
- [ ] Generate provisioning profile `WeeklyPlanner App Store`.
- [ ] Store in private Git via `match` (encrypted).
- [ ] Configure GitHub Actions secrets: `MATCH_PASSWORD`, `FASTLANE_USER`, `FASTLANE_PASSWORD` (with app-specific password), `ASC_API_KEY_ID/ISSUER/KEY_CONTENT`.

### Build automation
- [ ] `fastlane beta` lane:
  - `match appstore`.
  - `increment_build_number` (timestamp-based).
  - `build_app(scheme: "WeeklyPlanner", export_method: "app-store")`.
  - `upload_to_testflight(skip_submission: false, distribute_external: false)`.
  - Adds the build to internal testers automatically.
- [ ] `fastlane release` lane:
  - Same as beta, then `upload_to_app_store(submit_for_review: true, automatic_release: false)`.
  - `slack` (or email) notification on completion.

### CI
- [ ] `.github/workflows/testflight.yml`: triggers on push to `main` (or nightly cron). Runs full test suite, then `fastlane beta` on success.
- [ ] `.github/workflows/release.yml`: triggers on git tag `v*.*.*`. Runs tests, then `fastlane release`.

### Pre-submission checklist (encoded in `RELEASE_CHECKLIST.md`)
- [ ] All unit + UI tests pass.
- [ ] Snapshot tests committed and stable.
- [ ] App icon present in all sizes.
- [ ] Launch screen renders correctly.
- [ ] Privacy manifest committed.
- [ ] Privacy policy URL live.
- [ ] Support URL live.
- [ ] Marketing URL (optional) live.
- [ ] App Store screenshots uploaded (6.7" and 6.1").
- [ ] App Preview video uploaded (optional but recommended).
- [ ] Keywords filled.
- [ ] Categories selected.
- [ ] Age rating completed.
- [ ] Export compliance declared (`ITSAppUsesNonExemptEncryption = NO`).
- [ ] Reviewer notes attached (Phase 22 `REVIEWER_NOTES.md`).
- [ ] Test account credentials provided (a Gmail test account with sample event emails).
- [ ] In-app purchase: none.
- [ ] Sign in with Apple: not used; not required.
- [ ] Permissions usage strings audited.
- [ ] Crash logs from internal testing: zero unresolved.

### TestFlight beta plan
- [ ] Internal testers: dev team + ~5 close friends. Recruit during Phase 22.
- [ ] External testers (TestFlight public): 100 users via invitation link, sourced via Twitter/X + Anthropic community.
- [ ] Beta window: 7 days.
- [ ] Feedback channel: TestFlight built-in screenshot+note feature.
- [ ] Triage process: each report categorized as `blocker | bug | polish | wish`. Blockers fix-and-rebuild; bugs fold into v1.0.1.

### Submission strategy
- [ ] Submit after beta week if no blockers.
- [ ] Phased release ON (1% → 10% → 100% over 7 days) to catch crashes.
- [ ] Monitor App Store Connect Metrics dashboard daily for first 2 weeks.

### Post-launch ops
- [ ] Triage support email within 48h.
- [ ] Hotfix protocol: any sev-1 crash → expedited review request.
- [ ] Roadmap to v1.1:
  - Recurring events.
  - Google Calendar two-way sync.
  - In-app icon picker.
  - User-defined habit streaks.
  - Voice input via Speech framework.
  - Localized App Store metadata (top 5 languages).

## Tests (TDD)

No new unit tests. Verification via:
- [ ] TestFlight build succeeds.
- [ ] Apple's automated validation passes.
- [ ] Internal testers complete the Phase 22 acceptance flow end-to-end.

## Acceptance Criteria
- A signed `.ipa` builds and uploads to TestFlight without manual Xcode intervention.
- App passes App Store automated validation.
- App Store metadata complete and accurate.
- Public beta runs 7 days with at least 50 active testers.
- App submitted to App Store review and **approved**.
- v1.0.0 released to App Store (phased rollout).

## Out of Scope
- Web landing page (defer; have a single Notion-style page for Privacy/Support).
- Press kit.
- Hunt rituals (Product Hunt, etc.) — coordinate separately.
- v1.1 features.

## Risks & Notes
- **App Store review for AI apps** can ask for explanations of what the model does. Have a short response prepared referencing privacy policy.
- **Apple may flag `EKEvent.notes` use** for storing `--planner-meta--` blobs. If rejected, switch to a side-table mapping eventID → metadata.
- **Foundation Models entitlement** — confirm whether iOS 26 requires anything special; as of writing, framework usage is implicit.
- **Code signing** is the #1 source of last-minute delays. Run Fastlane Match locally **and** in CI ≥ 1 week before submission.
- **Phased rollout** can be paused if crash rate spikes; configure Sentry/MetricKit thresholds (or hand-monitor in v1.0).
