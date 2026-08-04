# Localization

Flutter gen-l10n under `lib/l10n/`. UI strings use `AppLocalizations` with a language picker (EN / SI / TA).

## Languages

| Code | Language |
|------|----------|
| `en` | English (template) |
| `si` | Sinhala |
| `ta` | Tamil |

## Usage

1. Add keys to `app_en.arb`, then translate in `app_si.arb` / `app_ta.arb`.
2. Run `flutter gen-l10n` (or build) to regenerate.
3. Prefer `AppLocalizations.of(context)` for user-facing copy (avoid hard-coded English in new screens).
