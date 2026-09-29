## 1. Contract and catalog

- [x] 1.1 Add failing tests for training-plan URL, locale, cursor pagination, DTO mapping, invalid payload and valid empty response; then implement the remote repository and run focused tests.
- [x] 1.2 Add failing tests for complete-result fallback on network/contract failure and cancellation propagation; then implement the fallback adapter and run focused tests.

## 2. App integration

- [x] 2.1 Add failing AppModel tests for language-aware initial load, language-change refresh, source state, empty remote catalog and retry; then inject the remote-first repository and run focused tests.
- [x] 2.2 Update workout presentation to show remote, local fallback and empty states with a retry action; add UI/state coverage and verify the relevant suite.
- [x] 2.3 Add a failing regression test for an English-first device whose app UI locale resolves to Chinese; source Follow System content locale from the device's preferred language, then run focused and full iOS tests.

## 3. Build environments

- [x] 3.1 Add failing configuration tests for placeholder, loopback, LAN and HTTP Release URLs; implement strict Release validation and run focused tests.
- [x] 3.2 Replace developer-specific Debug and placeholder Release build URLs; document local, staging override and production build commands; verify resolved build settings for both configurations.

## 4. Verification

- [x] 4.1 Run all iOS unit/UI tests and inspect the diff for contract, safety, localization and unrelated changes.
- [x] 4.2 After backend deployment and reviewed seed data, verify staging training-plan API and physical-device catalog, fallback, retry and language switching; record redacted evidence only.
- [x] 4.3 When production is reachable, verify a Release build uses production HTTPS endpoints and passes the public catalog smoke test; record redacted evidence only.

Verification note (2026-09-27): iOS unit tests 127/127 and UI tests 16/16 passed; Release
simulator build and production URL inspection passed. Both staging and production public
training-plan list endpoints returned HTTP 404. The backend training-plan code is present
locally but its image has not been released to either environment; live acceptance remains open.

Verification note (2026-09-28): staging core-api and challenge-worker now run the same immutable
`movefit-backed` digest `sha256:31136aef0609f87d1d11dc161ef801f09126045e553948b85cda25eb704e7e6f`
and are healthy. Staging MySQL advanced from `0009_google_authorization` to
`0010_training_plan_catalog` after a verified root-only pre-migration backup. The reviewed
`zh-Hans` seed published eight plans; the public list and a plan detail returned HTTP 200.
The existing staging public smoke passed 9/9 checks. Production still runs its prior digest.
Physical-device acceptance remains open: the selected iPhone 17 Pro is connected, but its
Debug build cannot be provisioned because the current Apple Personal Team does not support
the project's Sign in with Apple entitlement. Do not mark 4.2 or 4.3 complete from backend
HTTP checks alone.

Verification note (2026-09-28, physical-device follow-up): with user approval, a temporary
Debug QA build omitted only the Sign in with Apple entitlement at build time, retained HealthKit,
and resolved all three service URLs to staging HTTPS. It installed and launched on the selected
iPhone 17 Pro. The Workout screen visibly labeled the catalog as server-published, showed eight
plans across categories, and displayed the published Five Kilometre Easy Run title, 38-minute
duration and three ordered steps. The staging Chinese catalog returned HTTP 200; its English
catalog returned a valid empty page. A separate offline QA build was briefly installed for
fallback/retry checks, but iOS denied launch while the device was
locked, so the verified staging QA build was immediately reinstalled. Language switching and
physical offline/retry checks were pending at that point.
On a second attempt, the offline QA build installed and launched while the phone was unlocked,
but iPhone Mirroring could not connect while the phone was in use and timed out before its
Workout screen could be observed. The staging QA build was reinstalled and relaunched again.
The production health endpoint returned HTTP 200 but its training-plan list returned HTTP 404,
so production acceptance remains open. No Apple login acceptance is claimed from the QA build.

Verification note (2026-09-28, offline follow-up): after the phone was locked, iPhone Mirroring
connected to the selected iPhone 17 Pro. The temporary Debug build with an unreachable core
address opened the Workout screen, which visibly labeled its catalog "本地离线方案", retained
browsable bundled categories and offered "重试训练目录". Tapping retry left the source correctly
marked as local when the endpoint still failed. The staging HTTPS build was then reinstalled.
The live staging list still returned HTTP 200 and production still returned HTTP 404. Physical
language switching remains unverified; no screenshots or health metrics were committed.

Verification note (2026-09-28, language follow-up): on the same physical device, the App
preference visibly changed from Follow System to Simplified Chinese and back to Follow System;
the remote Chinese catalog remained available. This phone's system locale is Chinese, so that
toggle did not establish an English `locale=en` request. Launching only this process with
temporary `-AppleLanguages`/`-AppleLocale` arguments did not change the observed catalog.
The English-locale physical-device scenario remains unverified; no device-wide language
preference was changed. The staging QA build remains installed.
It was relaunched without temporary locale arguments and again displayed the server-published
Chinese catalog before ending the mirror session.

Verification note (2026-09-28, production and language check): public production frontend,
core, work and AI endpoints returned HTTP 200, and their application containers were healthy.
The production training-plan list still returned HTTP 404; therefore the Release public-catalog
smoke check remains open. The selected iPhone 17 Pro had Simplified Chinese first and English
second in its system language preferences. iPhone Mirroring could not reorder those languages;
temporary app-only English process environment variables also left the observed remote catalog
in Chinese. The device language order was not changed, and the staging QA app was relaunched
normally. Physical English-locale acceptance remains open; no screenshots or personal data were
committed.

Verification note (2026-09-28, English device): the selected iPhone 17 Pro now uses English
as its primary system language, while the App preference remains Follow System. After a full
app-process restart, the Workout screen still showed the eight published Chinese plans.
The staging public catalog returned a valid empty English page and eight Chinese plans,
so the physical result does not satisfy the expected `locale=en` behavior. The implementation
currently derives content locale from `Locale.current`, which Apple documents as constrained
by the app's available localizations; this build only includes Simplified Chinese.
Task 4.2 remains open pending a reviewed locale-source correction and repeat acceptance.

Verification note (2026-09-28, locale-source fix): the Follow System content locale now derives
from `Locale.preferredLanguages.first` instead of `Locale.current`, so an English-primary device
with a zh-Hans-only app bundle requests `locale=en`. A regression test asserts the remote empty
catalog is requested with `["en"]`. Focused tests 10/10, unit tests 128/128 and UI tests 16/16
passed on the iPhone 17 Pro simulator; one UI run aborted when HealthKit crashed internally
while formatting a statistics-query predicate date (SIGSEGV inside Foundation `_NSPredicateUtilities`),
which did not reproduce on rerun or in any prior full suite. The physical English-device
re-acceptance required by task 4.2 is still pending.

Verification note (2026-09-28, physical-device locale acceptance): on the selected English-primary
iPhone 17 Pro with the App preference at Follow System, a Debug QA build (Sign in with Apple
entitlement omitted for personal-team provisioning, HealthKit retained) routed the main backend
through a local logging reverse proxy in front of staging and reached the exercises and AI
staging hosts directly. The device sent `GET /api/v1/training-plans?locale=en` (HTTP 200, the
valid empty English page) and requested challenges, articles and help articles with `locale=en`;
the eight published Chinese plans were not requested. After the on-device App language preference
was switched to Simplified Chinese and the app relaunched, the same build sent `locale=zh-Hans`
for all public content; restoring Follow System resumed `locale=en`. Evidence is request-line
logs only; no tokens, request/response bodies or screenshots were recorded. Incidental finding:
staging `GET /api/v1/client-config?platform=ios&app_version=1.0` returned HTTP 422 (the app
degrades without blocking); the backend should confirm the expected parameter set. Combined with
the earlier catalog, fallback, retry and visual language-toggle evidence above, task 4.2 is
complete; task 4.3 remains open pending the production release of the training-plan image.

Verification note (2026-09-28, production recheck): the public frontend and core, work and AI
readiness endpoints returned HTTP 200, while `GET /api/v1/training-plans?locale=zh-Hans`
returned HTTP 404. Production core-api remained healthy on its earlier `e309b4d919d5` image,
and `movefit_core.alembic_version` remained `0009_google_authorization`; the training-plan
schema and image are not yet deployed there. Task 4.3 cannot pass until a separately authorized
production migration and rollout is complete. No production state was changed.

Verification note (2026-09-28, QA reinstallation follow-up): after the successful English-
locale acceptance recorded above, a newly rebuilt staging QA app was installed on the same
device. iOS denied its launch with a development-profile trust/signature message. The renewed
profile is unexpired, includes the selected device, has the expected app identifier and matches
the available Apple Development signing identity. Device-side trust has not yet been confirmed;
the installed QA app may need its developer profile trusted again before it can launch. This
later signing issue does not change the earlier request-line acceptance evidence, but should be
resolved before further on-device testing. No app data was intentionally removed.

Verification note (2026-09-29, production read-only recheck): the core, work and AI public
`/health/ready` endpoints returned HTTP 200. Both `zh-Hans` and `en` production training-plan
list requests returned HTTP 404. The production core-api and challenge-worker containers were
healthy but still used the previous `e309b4d919d5` image. No production state was changed, and
task 4.3 remains open until the separately authorized backend rollout makes the public catalog
available and a Release build can be smoke-tested against it.

Verification note (2026-09-29, production rollout and Release acceptance): after explicit user
approval, a fresh off-host MySQL backup completed and its streamed checksum matched. Production
advanced to migration `0010_training_plan_catalog`, then loaded the reviewed eight-plan
`zh-Hans` seed. Core API and challenge worker now run the same staging-verified immutable
`movefit-backed` digest `sha256:31136aef0609f87d1d11dc161ef801f09126045e553948b85cda25eb704e7e6f`
and both report healthy. The Release simulator build succeeded; its resolved Info.plist uses
`https://api.movefitgo.com`, `https://exercises.movefitgo.com`, and
`https://ai.movefitgo.com`. Production public smoke passed 9/9 checks. The training-plan
catalog returned eight distinct Chinese plans across cursor pages, a selected detail returned
HTTP 200, and the valid empty English catalog returned HTTP 200. No credentials, personal data,
response bodies, device screenshots, or health metrics were recorded in this evidence.
