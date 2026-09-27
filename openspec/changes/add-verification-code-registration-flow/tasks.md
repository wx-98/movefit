## 1. Domain and Application Flow

- [x] 1.1 RED: add unit tests for email/E.164 validation, six-digit code validation, registration state transitions, identifier-change invalidation, cancellation and late-response rejection; GREEN: add provider-neutral verification domain values and state reducer; Verify: run the focused domain test target.
- [x] 1.2 RED: add UseCase tests for request challenge, confirm code, immediate same-identifier proof consumption, proof clearing and success-to-login behavior; GREEN: add `RequestRegistrationCodeUseCase` and `CompleteVerifiedRegistrationUseCase` with injected clock/repository/installation ID; Verify: run focused UseCase tests.

## 2. Networking and Secure Installation Identity

- [x] 2.1 RED: add protocol-level URLSession tests for challenge request/response, confirmation, snake_case DTOs, UUID paths, no authorization header, and final registration payload; GREEN: add `RegistrationVerificationProviding` and implement it in `BackendRepository`; Verify: run networking integration tests with `URLProtocolStub`.
- [x] 2.2 RED: add tests for Problem Details codes and valid/missing/invalid `Retry-After`; GREEN: preserve typed verification/rate-limit errors and headers without exposing provider detail or sensitive request values; Verify: run API client and error-mapping tests.
- [x] 2.3 RED: add Keychain adapter tests for generate-once/reuse/corrupt-value recovery using fictional UUIDs; GREEN: implement `InstallationIdentifying` with a random UUID stored in Keychain and no PII derivation; Verify: run focused platform adapter tests.

## 3. Registration Presentation

- [x] 3.1 RED: add `RegistrationViewModel` tests for request, cooldown, confirm/register, resend, background clock recomputation, double-tap suppression, task cancellation and sensitive-state clearing; GREEN: implement the `@MainActor` ViewModel with constructor injection; Verify: run focused ViewModel tests.
- [x] 3.2 RED: add SwiftUI/UI tests for email/phone inputs, E.164 guidance, one-time-code field, accessible cooldown/error states and removal of manual proof entry; GREEN: update `LocalAccountView`, localized copy and dependency composition; Verify: run account UI tests on an iOS 15-compatible simulator.
- [x] 3.3 Add regression tests proving password login/session restore remain available when verification delivery returns 503 and proving logs/persistence contain no code, proof, password, full contact value or Tencent Cloud credential; Verify: run security and account regression tests.

## 4. Documentation and Environment Acceptance

- [x] 4.1 Update README, backend integration documentation and device acceptance checklist with the three-step registration contract, E.164 requirement, staging/production HTTPS URLs and the rule that Tencent Cloud secrets exist only in backend/Coolify.
- [ ] 4.2 After backend change `add-verified-registration-google-telemetry` is deployed, verify staging email and Tencent Cloud SMS challenge/confirm/register flows on a real device, including wrong code, resend cooldown, 429, 503 and identifier-change cases; record only redacted evidence.

## 5. Final Verification and Review

- [x] 5.1 Run the complete unit, networking, UI and architecture suites plus the repository formatting/lint command; conduct a structured review of requirements, cancellation/races, accessibility, localization, PII/secret handling, error boundaries and iOS 15 compatibility, fixing every P0/P1 finding with TDD.
- [x] 5.2 Run `openspec validate add-verification-code-registration-flow --strict` and confirm the iOS change remains provider-neutral and explicitly linked to the backend verification change before marking implementation complete.
