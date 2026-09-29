## Why

The iOS training catalog still comes exclusively from bundled sample content even though the core backend now exposes published training plans. Its Debug build points to one developer's LAN and its Release build points to an invalid placeholder, so a successful local build does not demonstrate a usable staging or production app.

## What Changes

- Load published training plans from the core backend's public, locale-aware, cursor-paginated API and map the response into existing domain models.
- Preserve bundled plans as an explicitly identified offline fallback; malformed or unavailable remote content must not be presented as server-synced.
- Replace developer-specific and placeholder build URLs with deterministic local Debug defaults and production HTTPS Release defaults, while documenting a staging override for real-device acceptance.
- Add contract, fallback, configuration and UI-state tests; record live staging and release checks only when their endpoints are reachable.

## Capabilities

### New Capabilities

- `remote-training-plans`: Remote catalog loading, safe mapping, pagination, source state and offline fallback for iOS.

### Modified Capabilities

- `backend-environment`: Define all three service URLs for local, staging and production builds, and reject placeholder or unsafe Release URLs.
- `workout-management`: Distinguish remote published plans from bundled fallback in the training-plan experience.

## Impact

The change is scoped to the `movefit` iOS repository: App bootstrap, training catalog repository/DTO, domain-facing source state, workout presentation, Xcode build settings, documentation and tests. It consumes existing `GET /api/v1/training-plans` and `GET /api/v1/training-plans/{id}` contracts; deploying the backend endpoint and seeding published content are separate server-side prerequisites. No third-party dependency is added.
