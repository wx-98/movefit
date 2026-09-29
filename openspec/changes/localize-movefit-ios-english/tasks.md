## 1. Language infrastructure

- [x] 1.1 Add failing tests for English-first Follow System, explicit English/Chinese selection, persistence compatibility and immediate locale switching; implement language resolution and English bundle registration, then run focused tests.
- [x] 1.2 Add failing tests for runtime message, enum label and formatted-value localization; implement an explicit effective-language localization adapter without global mutable state, then run focused tests.

## 2. Full interface resources

- [x] 2.1 Inventory released user-facing literals and add a coverage check for untranslated Chinese presentation strings; create reviewed English resource keys and verify resource packaging.
- [x] 2.2 Localize app shell, home, health metrics, trends, sleep and history screens including accessibility and formatted values; run focused UI/state tests.
- [x] 2.3 Localize workouts, exercise catalog, training plan, active workout and manual entry screens including all empty/fallback/error states; run focused UI/state tests.
- [x] 2.4 Localize challenges, wellness articles and remote-content source/status presentation; run focused UI/state tests.
- [x] 2.5 Audit implemented client/server data flows, correct Chinese and English privacy/help claims about conditional remote AI aggregate values, account/workout sync and provider-dependent sign-in; localize profile, account/registration, appearance/language, help/support, privacy and about screens, alerts and runtime messages; run focused UI/state tests and obtain product/legal copy review before release.

## 3. Offline data and acceptance

- [x] 3.1 Add failing English offline-fallback tests and localize bundled training, exercise, challenge, help and wellness content without changing stable IDs or numeric data; run focused tests.
- [ ] 3.2 Run full iOS unit/UI suites and English/Chinese simulator journeys, review localization coverage, safety/privacy wording, narrow layouts and VoiceOver labels, and fix regressions.
- [x] 3.3 Verify a Release build packages both languages and production HTTPS settings, and smoke-test `locale=en` against the linked backend English catalog when available; record redacted evidence only.

Verification note (2026-09-29, interface completion): tasks 2.1-2.5 and 3.1 are complete. The
strict coverage check reports 0 gaps after localizing 15 additional screens (personal health,
help/support, tickets, privacy, devices, backend status, about, account/registration, workout
session, manual entry, challenges, wellness) and registering English translations for all
bundled training, exercise, challenge and wellness fallback content under stable IDs; both
`.strings` tables now hold 994 parity-checked keys. Two defects were found and fixed during
verification: (1) the batch merge had written named `*.format` keys into `zh-Hans.lproj` as
identity mappings, rendering raw key names in the Chinese UI — 27 keys were corrected to their
Chinese format values; (2) the coverage scanner now normalizes `LocalizedStringKey`
interpolation to SwiftUI's runtime `%@`/`%lld` pattern keys before comparing.

Verification note (2026-09-29, regression and release evidence): unit tests 144/144 and UI
tests 16/16 pass on the iPhone 17 Pro simulator. A second recurrence of the flaky launch
SIGSEGV inside HealthKit's statistics-query predicate formatting (same Apple-framework stack
as recorded on 09-28) was mitigated by serializing the seven concurrent daily-summary queries
in `HealthKitAdapter`; no further recurrence in three full UI runs after the change. For 3.3,
a Release simulator build packages both `en.lproj` and `zh-Hans.lproj` (994 keys each) with
production HTTPS endpoints, and launching it with `-AppleLanguages (en)` rendered the English
Home journey (rings card, degraded health-data copy, English tab bar). Task 3.2 remains open:
English/Chinese simulator journeys beyond the Home smoke, safety/privacy copy review, narrow
layouts and VoiceOver labels still need human review before release.
