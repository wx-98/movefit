## Why

MoveFit currently ships only Simplified Chinese UI resources even though an English-first device can request English backend content. Users selecting English or following an English system language still encounter Chinese navigation, forms, errors, accessibility text and bundled content. The full iOS interface needs an English release path that stays consistent with server locale selection.

## What Changes

- Add English as a selectable, persisted app language and make Follow System resolve English when the device prefers it, without breaking existing Chinese preference values.
- Localize every user-facing iOS surface, including navigation, forms, validation, status/error messages, accessibility labels, privacy/help text, bundled offline catalogs and format-sensitive values.
- Correct both Chinese and English privacy/help disclosures against implemented data flows, including conditional remote AI analysis of aggregate health metrics and authenticated account/workout sync; do not simply translate outdated claims.
- Keep backend content requests aligned with the selected content locale; display reviewed English training plans once the linked backend change is deployed.
- Add localization coverage and English/Chinese UI acceptance tests, including language switching and offline states.

## Capabilities

### New Capabilities

- `ios-english-localization`: Complete English and Simplified Chinese UI resources, locale-aware presentation, dynamic text, accessibility, and regression coverage.

### Modified Capabilities

- `app-preferences-support`: English becomes a supported selectable language; Follow System and offline help/privacy content must honor the effective language.

## Impact

- iOS app language model and root locale injection; localized resource membership; all user-facing SwiftUI screens and view-model messages; bundled training, exercise, challenge and help content; localization tests.
- No new third-party dependencies or API shape changes. The linked backend change `publish-english-training-plan-catalog` provides English training content under the existing locale contract.
