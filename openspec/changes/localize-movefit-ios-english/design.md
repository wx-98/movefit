## Context

The app has a `zh-Hans.lproj/Localizable.strings` file and applies `AppLanguage.locale` to the root SwiftUI environment, but the bundle declares only Chinese. `AppLanguage` offers only Follow System and Simplified Chinese, and many user-visible values are constructed as runtime `String`s or bundled Chinese content rather than SwiftUI localization keys. An English-first device already sends `locale=en` for remote content, but the interface and offline fallback remain Chinese.

## Goals / Non-Goals

**Goals:**
- Deliver a complete English UI across all released tabs, navigation destinations, forms, alerts, empty/error states, accessibility text, privacy/help content and bundled offline content.
- Keep Simplified Chinese behavior and persisted preferences compatible.
- Make explicit app-language choice affect both SwiftUI literals and runtime-generated presentation strings without global mutable locale state.
- Verify English-first Follow System, explicit English and explicit Chinese in simulator, plus a physical-device sanity check when signing permits.

**Non-Goals:**
- Translate server-owned article, challenge or exercise content that the backend does not publish in English; those surfaces must show truthful empty/fallback/source states.
- Change API wire enum values, identifiers, stored workout records or HealthKit data.
- Add a translation SDK or runtime network translation.

## Decisions

1. **Register English resources and keep persisted preference IDs stable.** Add `en` to the Xcode project and a complete English `Localizable.strings`. Add an English `AppLanguage` case while retaining existing raw values for Follow System and Simplified Chinese, so old saved preferences decode unchanged. Follow System resolves the device's first preferred supported language; an explicit choice overrides it. The root `.environment(\.locale, ...)` keeps SwiftUI literal keys reactive.
2. **Use explicit language at non-SwiftUI boundaries.** A small immutable localization adapter resolves strings from the selected `.lproj` bundle using a passed locale/language. View models, domain presentation labels and bundled repositories receive or derive the effective language via constructor or method arguments. Avoid `NSLocalizedString` or global `Bundle.main` for user-visible runtime messages that must follow the in-app picker. This is preferable to global locale swizzling, which would be unsafe and untestable.
3. **Separate codes from display text.** Keep persisted enum raw values and server wire values stable; expose localized presentation names instead of changing storage identifiers. Server-owned English content is displayed verbatim only when `locale=en`; a valid empty response remains a remote empty state, not a fake translation.
4. **Localize bundled/offline data at construction.** The fallback training, exercise, challenge, help and wellness content selects reviewed English or Chinese strings by the effective content locale while keeping stable local IDs and numeric values. Privacy and safety notices are translated without weakening their meaning.
5. **Audit by screen and by string flow.** Build a catalog of user-visible literals and dynamic messages, translate each with context, add a static coverage check for uncovered Chinese UI strings, and test all major navigation paths in both languages. Localized format strings use locale-aware number/date/unit formatting and safe placeholders; accessibility labels are included.
6. **Reconcile privacy statements with actual behavior before translation.** The existing Chinese policy says all profile data stays on-device, Apple/WeChat sign-in is disabled, and HealthKit-derived data never reaches MoveFit servers. Audit the current client calls and backend contracts first: authenticated profile/workout sync is supported; Apple/WeChat availability depends on provider setup; opening a metric detail can send current/average aggregate values to remote AI when access is `remote_available`. Keep raw HealthKit samples, ECG waveforms, precise route data, and user-controlled uploads distinct from those conditional aggregate requests. Update Chinese and English disclosures together, and require product/legal review before release. Do not claim a provider is active solely because adapter code exists.

## Risks / Trade-offs

- [Runtime `String` bypasses SwiftUI localization] → Require explicit localization at presentation boundaries and test language switching without app restart.
- [Persisted raw values change] → Preserve existing preference raw values and only add the English case; migration tests cover old values.
- [Partial backend English content] → Keep each remote feature's source and empty/fallback semantics truthful; do not substitute Chinese as English.
- [Fitness or privacy wording changes meaning] → Review English safety, health disclaimer, permissions and privacy text against Chinese source before release.
- [Existing Chinese privacy claims are stale] → Verify implementation and server contracts, revise both language versions together, and test the same offline disclosure and safety-critical distinctions in each language.
- [Large UI surface leaves untranslated text] → Automate a literal inventory and perform screen-by-screen English simulator QA, including VoiceOver labels and narrow-width layouts.

## Migration Plan

1. Add English resources and language selection while retaining Chinese defaults and existing saved choices.
2. Convert dynamic user-facing strings and bundled content in small feature batches with focused tests.
3. Run full unit/UI suites and both-language simulator acceptance; verify a Release build packages both `.lproj` resources and production HTTPS URLs.
4. Distribute the new iOS build after the linked backend English catalog is staged and reviewed. A previous app build remains the client rollback path; no stored user data migration is needed.

## Open Questions

- Device-side developer-profile trust may limit physical-device QA with the current Personal Team; simulator coverage and a signed distribution build are required regardless.
