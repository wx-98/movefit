## 1. Language infrastructure

- [x] 1.1 Add failing tests for English-first Follow System, explicit English/Chinese selection, persistence compatibility and immediate locale switching; implement language resolution and English bundle registration, then run focused tests.
- [x] 1.2 Add failing tests for runtime message, enum label and formatted-value localization; implement an explicit effective-language localization adapter without global mutable state, then run focused tests.

## 2. Full interface resources

- [ ] 2.1 Inventory released user-facing literals and add a coverage check for untranslated Chinese presentation strings; create reviewed English resource keys and verify resource packaging.
- [ ] 2.2 Localize app shell, home, health metrics, trends, sleep and history screens including accessibility and formatted values; run focused UI/state tests.
- [ ] 2.3 Localize workouts, exercise catalog, training plan, active workout and manual entry screens including all empty/fallback/error states; run focused UI/state tests.
- [ ] 2.4 Localize challenges, wellness articles and remote-content source/status presentation; run focused UI/state tests.
- [ ] 2.5 Audit implemented client/server data flows, correct Chinese and English privacy/help claims about conditional remote AI aggregate values, account/workout sync and provider-dependent sign-in; localize profile, account/registration, appearance/language, help/support, privacy and about screens, alerts and runtime messages; run focused UI/state tests and obtain product/legal copy review before release.

## 3. Offline data and acceptance

- [ ] 3.1 Add failing English offline-fallback tests and localize bundled training, exercise, challenge, help and wellness content without changing stable IDs or numeric data; run focused tests.
- [ ] 3.2 Run full iOS unit/UI suites and English/Chinese simulator journeys, review localization coverage, safety/privacy wording, narrow layouts and VoiceOver labels, and fix regressions.
- [ ] 3.3 Verify a Release build packages both languages and production HTTPS settings, and smoke-test `locale=en` against the linked backend English catalog when available; record redacted evidence only.
