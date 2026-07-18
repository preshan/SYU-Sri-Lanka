# SYU Sri Lanka

Flutter membership app for SYU Sri Lanka (Android-first, Flutter Web admin).

## Stack

- Flutter 3.44+
- Supabase (Auth + Postgres + Storage + Realtime)
- Flutter Web admin at `/admin` (super_admin)
- FCM planned later

## Android targets

- `minSdk`: 26 (Android 8+)
- `targetSdk`: 35 (Android 15)
- `compileSdk`: 36

## Setup

1. Copy env:

```bash
cp .env.example .env
```

2. Fill `SUPABASE_URL` and `SUPABASE_ANON_KEY` only (never service role in the app).

3. Run:

```bash
flutter pub get
flutter run
# Admin on web:
flutter run -d chrome --web-port=5280
# then open /admin while signed in as super_admin
```

## Brand

Assets in `assets/brand/`. Crimson `#E10600` on near-black `#0A0A0A`.

## Database

Migrations: `supabase/migrations/`. Apply via Management API or Supabase CLI.

## Docs

| Doc | Purpose |
|-----|---------|
| `docs/DATABASE_SCHEMA.md` | Schema overview |
| `docs/AUTH_RECOVERY.md` | Password reset / redirects |
| `docs/SECURITY_CHECKLIST.md` | Production security |
| `docs/RELEASE_RUNBOOK.md` | Ship APK / tags |
| `docs/UAT_PLAN.md` | Critical journey tests |
| `docs/LOCALIZATION.md` | EN / SI / TA scaffold |

## GitHub

- Repo: https://github.com/preshan/SYU-Sri-Lanka
- Project: https://github.com/users/preshan/projects/2
- Releases: installable APKs under GitHub Releases
