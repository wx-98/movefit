# English localization inventory

The iOS app has 36 released Feature Swift files with Chinese UI literals. Before this change,
the source search found about 582 distinct Chinese quoted strings in `MoveFit/Features`.
The existing Chinese `Localizable.strings` had 92 entries but there was no English bundle.

Run `python3 scripts/check_english_localization_coverage.py --report` to see the remaining
presentation literals not represented by an English resource key. The strict invocation
without `--report` exits unsuccessfully while gaps remain.

**Current baseline (2026-09-29): the strict check reports 0 gaps.** All released presentation
literals — static labels, runtime messages, formatted values and the bundled training,
exercise, challenge and wellness fallback content — are registered in `en.lproj` (994 keys,
parity-checked against `zh-Hans.lproj`). The scanner normalizes `LocalizedStringKey`
interpolation to SwiftUI's runtime `%@`/`%lld` pattern keys before comparing. Key parity
still does not verify meaning or visual fit: see the release review paragraph below.

The scanner intentionally reports runtime interpolation and bundled content as well as static
SwiftUI labels. Static labels need paired `.strings` entries. Runtime messages and formatted
values need an explicit `AppLocalizer` call or localized formatting at the presentation
boundary. Bundled content needs locale-specific data under stable IDs. Review every reported
case; do not silence categories or treat the raw count as a count of distinct untranslated
screens.

Release review must also check English safety, privacy, permission and account language,
truncation on narrow devices, Dynamic Type and VoiceOver labels. Automated key parity alone
does not verify the meaning or visual fit of a translation.
