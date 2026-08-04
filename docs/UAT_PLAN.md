# UAT plan — member journeys

| # | Journey | Steps | Pass? |
|---|---------|-------|-------|
| 1 | Sign up | Register → confirm email screen → enter inbox code → home | |
| 2 | Forgot password | Login → Forgot password → receive code → set new password → login | |
| 3 | Registration wizard | Home → Complete registration → Personal → Location → Qualifications → Submit | |
| 4 | Profile | Settings → Edit profile → save → optional photo | |
| 5 | Announcements | News tab shows published items; pull to refresh | |
| 6 | Events | Events tab → RSVP Going | |
| 7 | Messaging | Chat tab lists conversations; open thread; send message | |
| 8 | Admin members | `/admin` as staff → Members → filter / note / suspend as allowed by role | |
| 9 | Admin publish | Admin News/Events → publish → visible in member app | |
| 10 | Sign out | Settings → Sign out → lands on login | |

## Environments

- Supabase project with app email OTP configured (`send-app-otp` + `app_mail_settings`)
- Test accounts: one member, one `super_admin`
- Android device or emulator (API 26+) and optional Chrome for admin
