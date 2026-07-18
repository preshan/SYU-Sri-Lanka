# Localization scaffold

Flutter gen-l10n is prepared under `lib/l10n/`.

## Languages

| Code | Language |
|------|----------|
| `en` | English (template) |
| `si` | Sinhala |
| `ta` | Tamil |

## Usage

1. Add keys to `app_en.arb`, then translate in `app_si.arb` / `app_ta.arb`.
2. Run `flutter gen-l10n` (or build) to regenerate.
3. Wire `AppLocalizations` into `MaterialApp.router` when ready to localize UI strings.

Until strings are migrated, the app remains English-first.
