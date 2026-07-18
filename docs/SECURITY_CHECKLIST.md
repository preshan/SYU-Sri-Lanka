# Production security checklist

## Auth

- [x] Email confirmation required before login
- [x] Password reset flow documented (`docs/AUTH_RECOVERY.md`)
- [x] Anon key only in mobile/web client; service role never shipped in APK
- [ ] Rotate any management token ever pasted into chat/logs
- [x] Configure Auth redirect URLs for mobile deep link (`syu://auth/callback`) — see `docs/AUTH_RECOVERY.md`

## Database / RLS

- [x] RLS enabled on member-facing tables
- [x] Owner policies for profiles / qualifications / RSVPs / messages
- [x] Admin writes gated by `is_super_admin()`
- [ ] Periodic review of policies after each schema change
- [ ] Confirm no table is exposed without RLS in Supabase dashboard

## Storage

- [x] `avatars` public-read, owner-write under `{uid}/`
- [x] `message-attachments` participant-scoped
- [ ] Validate mime/size limits in production

## Secrets & repo hygiene

- [x] `.env`, management token, admin credentials gitignored
- [x] `.env.example` has placeholders only
- [ ] GitHub secret scanning alerts monitored
- [ ] No service_role in CI logs

## Release

- [ ] Play signing keystore stored outside repo
- [ ] ProGuard/R8 rules reviewed for release builds
- [ ] Privacy policy URL ready for store listing
