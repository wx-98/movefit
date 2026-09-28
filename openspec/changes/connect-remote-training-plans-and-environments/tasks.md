## 1. Contract and catalog

- [x] 1.1 Add failing tests for training-plan URL, locale, cursor pagination, DTO mapping, invalid payload and valid empty response; then implement the remote repository and run focused tests.
- [x] 1.2 Add failing tests for complete-result fallback on network/contract failure and cancellation propagation; then implement the fallback adapter and run focused tests.

## 2. App integration

- [x] 2.1 Add failing AppModel tests for language-aware initial load, language-change refresh, source state, empty remote catalog and retry; then inject the remote-first repository and run focused tests.
- [x] 2.2 Update workout presentation to show remote, local fallback and empty states with a retry action; add UI/state coverage and verify the relevant suite.

## 3. Build environments

- [x] 3.1 Add failing configuration tests for placeholder, loopback, LAN and HTTP Release URLs; implement strict Release validation and run focused tests.
- [x] 3.2 Replace developer-specific Debug and placeholder Release build URLs; document local, staging override and production build commands; verify resolved build settings for both configurations.

## 4. Verification

- [x] 4.1 Run all iOS unit/UI tests and inspect the diff for contract, safety, localization and unrelated changes.
- [ ] 4.2 After backend deployment and reviewed seed data, verify staging training-plan API and physical-device catalog, fallback, retry and language switching; record redacted evidence only.
- [ ] 4.3 When production is reachable, verify a Release build uses production HTTPS endpoints and passes the public catalog smoke test; record redacted evidence only.

Verification note (2026-09-27): iOS unit tests 127/127 and UI tests 16/16 passed; Release
simulator build and production URL inspection passed. Both staging and production public
training-plan list endpoints returned HTTP 404. The backend training-plan code is present
locally but its image has not been released to either environment; live acceptance remains open.
