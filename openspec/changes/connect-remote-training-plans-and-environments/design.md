## Context

`AppModel` currently injects `BundledTrainingCatalog` and loads it before restoring the saved app language. The core backend contract is a public `GET /api/v1/training-plans?locale=<en|zh-Hans>&limit=&cursor=` page with snake_case fields and a UUID detail route. iOS already has a `MoveFitAPIClient`, remote DTO conventions and an exercise-catalog fallback pattern. The Xcode project has Debug and Release configurations only; Debug URLs are one developer's LAN and Release URLs are invalid placeholders.

## Goals / Non-Goals

**Goals:** Show published remote plans as the primary catalog; preserve a clearly labeled bundled fallback for network/contract failure; respect locale and cursor pages; use deterministic build-time URL configuration; verify contracts and source state with isolated tests.

**Non-Goals:** Publishing or editing plans, migrating server data, changing authentication, deploying backend images, or asserting production readiness while its host is unreachable.

## Decisions

1. Extend `TrainingCatalogProviding` to accept a locale and return a catalog result containing plans plus source (`remote` or `bundledFallback`) and a safe failure category. `AppModel` owns published state; Views only render it. This follows the existing exercise-catalog boundary rather than adding networking to SwiftUI.
2. Implement `RemoteTrainingCatalogRepository` using the existing core API client and separate DTO/domain mapping. Request cursor pages with a fixed bounded `limit`, reject malformed IDs, unsupported enums, invalid step order/durations and cursor loops, and map server `workout_type`/`difficulty` wire codes explicitly. Use UUID string as domain ID and derive a stable tint from workout type. A valid empty remote page remains empty, not a fallback. The repository never logs raw payloads.
3. Wrap remote and bundled repositories in a fallback adapter. Only transport, HTTP or contract failure causes bundled fallback; cancellation propagates. A failed later page discards partial remote results before fallback. No silent per-item dropping.
4. Restore persisted language before loading plans, and refresh plans when language changes. Follow System derives its content locale from the device's first preferred language (`Locale.preferredLanguages`), not `Locale.current`: Foundation may resolve `Locale.current` to Simplified Chinese when this app bundle offers no English UI localization, even on an English-language device. Inject the preferred-language value into `AppModel` for deterministic tests; the existing language choices and Chinese-only UI remain unchanged. Loading plans must not prevent unrelated local data or account initialization. The UI exposes remote, bundled fallback and empty state with retry; it must not hardcode a false `本地训练方案` caption.
5. Keep Debug defaults on localhost for simulator development, set Release to the three production HTTPS domains, and document a reproducible staging build override for physical-device testing. Validate configured URLs so Release cannot quietly use `.invalid`, loopback, a LAN address or insecure HTTP; avoid Swift-level environment constants. Existing configurations remain two unless a separate staging scheme is necessary.

## Risks / Trade-offs

- [The backend training endpoint is not yet present on staging] → Unit/contract tests can pass, but staging acceptance remains an unchecked task until deployment and seed verification.
- [A valid remote empty catalog hides bundled recommendations] → This is intentional truthfulness; show an empty state with retry rather than invented published content.
- [Bundled fallback text is currently Chinese-only] → Keep fallback explicitly local, and avoid claiming it is an English server translation; localization refinement can follow separately.
- [The UI bundle is Chinese-only while English remote content is selected] → Keep UI localization scope unchanged, but source remote content locale from device language preference; a valid empty English catalog must stay remote empty.
- [Production DNS or host may still be unavailable] → Configuration tests prove values and safety, not reachability; do not mark live acceptance complete without a real request.

## Migration Plan

1. Add failing tests for DTO, paging, fallback, state and build URL validation.
2. Implement the repository and UI wiring, then pass focused and full iOS suites.
3. Deploy the existing backend training route and seed reviewed content separately; run staging public API and physical-device checks with build overrides.
4. Only after production connectivity returns, test Release against production domains. Rollback the iOS catalog provider to bundled fallback if contract incompatibility appears; do not remove the bundled catalog.

## Open Questions

- The server-side rollout date and published locale coverage are external prerequisites; this iOS change does not assume either is already live.
