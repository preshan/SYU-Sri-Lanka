# SYU Sri Lanka

Flutter (Android-first) membership app for SYU Sri Lanka.

## Stack

- Flutter 3.44+
- Supabase (Auth + Postgres + Storage + Realtime)
- Firebase Cloud Messaging (later)
- Flutter Web admin (later)

## Android targets

- `minSdk`: 26 (Android 8+)
- `targetSdk`: 35 (Android 15 runtime behavior)
- `compileSdk`: 36 (current AndroidX requirement)

## Setup

1. Copy env file:

```bash
cp .env.example .env
```

2. Fill `SUPABASE_URL` and `SUPABASE_ANON_KEY` (anon key only — never put service role in the app).

3. Install & run:

```bash
flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
flutter run
```

## Brand

Logo assets live in `assets/brand/` (`syu_logo.png`, launcher icon variants).
Primary brand: crimson `#E10600` on near-black `#0A0A0A`.

## Database

SQL migrations are in `supabase/migrations/`.
Apply with Supabase CLI or Management API against your project.

## GitHub

Project board: https://github.com/users/preshan/projects/2
