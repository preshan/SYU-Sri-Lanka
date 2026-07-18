# UAT plan — critical member journeys

| # | Journey | Steps | Pass? |
|---|---------|-------|-------|
| 1 | Sign up | Register → confirm email screen → confirm in inbox → login | |
| 2 | Forgot password | Login → Forgot password → receive email | |
| 3 | Registration wizard | Home → Complete registration → Personal → Location → Qualifications → Submit → pending status | |
| 4 | Profile | Profile tab status → Edit profile → save → upload photo | |
| 5 | Announcements | News tab shows published items; pull to refresh | |
| 6 | Events | Events tab → RSVP Going | |
| 7 | Messaging | Chat tab lists conversations; open thread; send message | |
| 8 | Admin approval | `/admin` as super_admin → Approvals → Approve member | |
| 9 | Admin publish | Admin News/Events → publish → visible in member app | |
| 10 | Sign out | Profile → Sign out → lands on login | |

## Environments

- Supabase project with email confirmation enabled
- Test accounts: one member, one `super_admin`
- Android device or emulator (API 26+) and optional Chrome for admin
