# Production security checklist

Execution record for [#119](https://github.com/preshan/SYU-Sri-Lanka/issues/119) — **2026-07-22**.

## Auth

- [x] Email confirmation required before login (app gate: `profiles.app_email_verified` + OTP)
- [x] Password reset flow documented (`docs/AUTH_RECOVERY.md`)
- [x] Anon key only in mobile/web client; service role never shipped in APK
- [ ] Rotate any management token ever pasted into chat/logs *(ops — do in Supabase dashboard)*
- [x] Configure Auth redirect URLs for mobile deep link (`syu://auth/callback`) — see `docs/AUTH_RECOVERY.md`
- [x] Client no longer fetches SMTP App Password (`get_smtp_credentials` dropped 2026-07-22)
- [ ] **Rotate Gmail App Password** after prior client RPC exposure — [#128](https://github.com/preshan/SYU-Sri-Lanka/issues/128)

## Database / RLS

- [x] RLS enabled on **all** `public` tables (live audit 2026-07-22 — 26/26)
- [x] Owner policies for profiles / qualifications / RSVPs / messages
- [x] Admin writes gated by `is_super_admin()` / staff helpers
- [x] Periodic review of policies after each schema change *(this execution)*
- [x] Confirm no table is exposed without RLS in live project
- [ ] Revoke `anon` EXECUTE on staff SECURITY DEFINER RPCs — [#129](https://github.com/preshan/SYU-Sri-Lanka/issues/129)
- [ ] Review SECURITY DEFINER views `admin_membership_summary` / `admin_events_summary` — [#130](https://github.com/preshan/SYU-Sri-Lanka/issues/130)

## Storage

- [x] `avatars` public-read, owner-write under `{uid}/` (5 MB; jpeg/png/webp)
- [x] `message-attachments` private, participant-scoped (10 MB; images + pdf)
- [x] Validate mime/size limits in production *(confirmed on live buckets)*

## Secrets & repo hygiene

- [x] `.env`, management token, admin credentials gitignored
- [x] `.env.example` has placeholders only
- [x] No `SERVICE_ROLE` in client/`lib/` or CI (Pages uses anon only)
- [ ] GitHub secret scanning alerts monitored *(ops)*
- [x] No service_role in CI workflow definitions

## Release

- [ ] Play signing / ProGuard/R8 / privacy policy URL — [#131](https://github.com/preshan/SYU-Sri-Lanka/issues/131)

## Sign-off

| Gate | Status |
|------|--------|
| Service role absent from client | **Pass** |
| RLS on all public tables | **Pass** |
| Storage buckets locked as designed | **Pass** |
| SMTP secret not client-readable | **Pass** (after migration `20260722000100_*`; rotate App Password via #128) |
| Phase 6 production gate | **Conditional pass** — complete #128 before treating mail secrets as fully remediated |
