# Coding standards & folder structure

## Layout

```
lib/
  app.dart
  main.dart
  core/           # theme, router, errors, config, shared widgets
  features/       # feature modules (auth, registration, home, ...)
supabase/
  migrations/     # SQL migrations (source of truth)
docs/             # ADRs and project workflow docs
```

## Conventions
- Feature-first folders under `lib/features/<name>/{data,presentation}`
- Prefer Riverpod providers for app services
- Never commit `.env`, service-role keys, or keystores
- User-facing errors go through `AppErrorMapper`
- Android: `minSdk 26`, `targetSdk 35`, `compileSdk 36`

## Commands
```bash
flutter pub get
flutter analyze
flutter test
flutter run
```
