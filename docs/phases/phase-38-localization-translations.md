# Phase 38 — Localization & Real Translations

> **Milestone N (Future).** **Outline only — unscheduled.** Covers
> `docs/suggestions.md` line 52: *"Consider ability to change language."*
> A full spec gets its own `superpowers:brainstorming` pass before execution.

## Goal
Ship the app in languages beyond English by populating the localization
scaffold Phase 21 already created, and let users pick a language.

## Why this is needed
Requested as a "future" item. Phase 21 deliberately laid the groundwork — both
`Localizable.xcstrings` (empty, translator-ready) and `InfoPlist.xcstrings`
(English usage strings) exist, RTL is handled, and Dynamic Type is two-track.
The remaining work is content (actual translations) and the surrounding
plumbing, not architecture.

## Prerequisites
- Phase 21 (Accessibility, Dynamic Type, Localization scaffold, RTL). *(Shipped.)*

## Rough Scope (to be detailed when scheduled)
- **Seed the catalog:** ensure every user-facing `Text(...)` literal is in
  `Localizable.xcstrings` (Phase 21 noted CLI builds don't auto-populate — a
  GUI build or a scripted extraction pass is needed first).
- **Pick launch languages** with the user (e.g., Spanish, French, German,
  Japanese) and obtain quality translations (professional or reviewed MT — not
  raw machine output).
- **Handwriting-font coverage:** the four handwriting fonts may lack glyphs for
  some scripts (e.g., CJK). Define per-language font fallbacks; this is the
  biggest unknown and may constrain which languages are viable.
- **Plurals & dates:** verify the existing plural/locale handling (Phase 21
  tests) across the new locales; ensure date/number formatting is locale-aware
  (week-start interacts with Phase 36).
- **Language selection:** rely on the system language by default; an in-app
  override (if wanted) is a Settings addition.
- **AI prompts stay English** internally (the `Intelligence/` prompts) — only
  user-facing strings localize. Decide whether AI *answers* should localize.

## Key Questions to Resolve First
- Which languages, and is system-language-following enough or is an in-app
  picker required?
- Translation source/budget and review process.
- Handwriting-font strategy for non-Latin scripts (the gating risk).

## Out of Scope (for the eventual phase, unless decided otherwise)
- Localizing AI-generated content.
- Region-specific feature variation.

## Risks & Notes
- **Font/script coverage is the real blocker**, not strings — resolve it before
  committing to any non-Latin language.
- Keep this as an outline until the language list and translation pipeline are
  decided; then brainstorm → write a full phase doc → `writing-plans`.
