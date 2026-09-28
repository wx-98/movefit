## ADDED Requirements

### Requirement: Published training catalog
The iOS app MUST request the core backend's public training-plan catalog using the selected supported locale, follow opaque `next_cursor` pages, and map complete published plans into domain models without exposing transport DTOs to Views.

#### Scenario: Multiple published pages
- **WHEN** the backend returns a valid page with `has_more` and `next_cursor`
- **THEN** the app requests subsequent pages and presents every unique published plan with the server's title, steps, safety notes and stable ID

#### Scenario: Valid empty publication
- **WHEN** the backend returns a valid empty page with no next cursor
- **THEN** the app shows a remote empty state and does not substitute bundled plans

### Requirement: Safe contract mapping
The iOS app MUST explicitly map supported workout types and difficulty codes and reject invalid identifiers, inconsistent page cursors or malformed plan content without partially presenting an untrusted remote page.

#### Scenario: Unknown server enum
- **WHEN** a plan contains an unsupported workout type or difficulty
- **THEN** the remote catalog fails with a distinguishable contract error and does not silently drop that plan

### Requirement: Explicit offline fallback
The iOS app MUST use bundled training plans only when the remote request fails, label them as local fallback and offer retry. Cancellation MUST NOT trigger fallback.

#### Scenario: Catalog endpoint unavailable
- **WHEN** the training endpoint is unreachable or returns an incompatible response
- **THEN** bundled plans remain browsable with an explicit local-content status and retry action

#### Scenario: Request cancelled
- **WHEN** a newer request replaces an in-flight catalog request
- **THEN** the cancelled request does not overwrite the newer catalog or display fallback

### Requirement: Language-aware catalog refresh
The iOS app MUST load the catalog after restoring language preference and refresh it when the user changes language.

#### Scenario: Language changed
- **WHEN** the user changes the app language from Simplified Chinese to Follow System on an English-language device
- **THEN** the next training request uses `locale=en` and replaces the old-language catalog only after that request completes
