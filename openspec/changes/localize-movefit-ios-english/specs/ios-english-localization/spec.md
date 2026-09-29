## ADDED Requirements

### Requirement: Complete bilingual interface
The iOS app MUST provide Simplified Chinese and English resources for every released user-facing screen, navigation title, form label, validation and error message, loading and empty state, action, accessibility label, privacy/help notice and bundled offline explanation. English must not expose unexplained Chinese UI literals, and Chinese behavior MUST remain available.

#### Scenario: English-first device
- **WHEN** the device's first preferred language is English and the app preference is Follow System
- **THEN** all released navigation and feature screens, alerts and accessibility labels use English while remote content requests use `locale=en`

#### Scenario: Explicit Chinese preference
- **WHEN** an English-first device selects Simplified Chinese in the app
- **THEN** the same screens and runtime messages switch to Chinese and remote content requests use `locale=zh-Hans` without changing stored user records

#### Scenario: Privacy disclosure reflects implemented flows
- **WHEN** a user reads the offline privacy notice in either supported language
- **THEN** it distinguishes on-device HealthKit raw samples from conditional remote AI requests containing aggregate metric values, and describes authenticated sync and provider-dependent sign-in consistently across both languages

### Requirement: Locale-aware dynamic presentation
The app MUST localize runtime-generated status, enum display names, date/time/number/unit phrases and formatted messages using the effective app language. It MUST preserve stable persisted identifiers and API enum wire values.

#### Scenario: Language changes while app is open
- **WHEN** the user changes the app language after a status or error has been shown
- **THEN** the visible presentation updates in the selected language without requiring a process restart or changing the underlying state code

#### Scenario: Formatted training duration
- **WHEN** a training plan with a duration is displayed in English
- **THEN** the duration and accessibility value use an English, locale-aware unit phrase while the numeric duration and plan identity remain unchanged

### Requirement: Honest localized offline content
The app MUST provide reviewed English and Chinese bundled training, exercise, challenge, help and wellness content where those features use offline fallback. Remote content MUST remain in the requested locale; an empty English response MUST remain an explicitly empty remote state rather than silently showing Chinese or mislabeled bundled content.

#### Scenario: English offline fallback
- **WHEN** an English-selected device cannot reach the training catalog
- **THEN** its bundled plans, steps, safety notes, source label and retry action display in English under stable local IDs

#### Scenario: Valid empty English catalog
- **WHEN** the English backend returns a valid empty catalog
- **THEN** the app shows a localized remote empty state and does not present Chinese fallback as English content
