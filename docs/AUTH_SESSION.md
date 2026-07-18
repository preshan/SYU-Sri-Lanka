# Auth session lifetime

## Client

- `FlutterAuthClientOptions(autoRefreshToken: true)` refreshes access tokens in the background.
- Session is persisted locally by `supabase_flutter` across app restarts.

## Server (this project)

- `jwt_exp` set to **604800** (7 days) — maximum allowed on the current Supabase plan.
- Absolute **30-day session timebox** requires Supabase **Pro** (`sessions_timebox`).

## Goal: ~1 month without re-login

1. Keep auto-refresh enabled (done).
2. Use the longest allowed JWT (7 days — done).
3. Upgrade to Pro and set `sessions_timebox = 2592000` (30 days) when ready for a hard 1-month cap.
