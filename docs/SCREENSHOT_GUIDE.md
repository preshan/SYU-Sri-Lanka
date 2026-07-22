# Screenshot & flow guide — product documentation

Use this for the full product / features doc.

- **📷 Screenshot** — capture and save as `{ID}-{slug}.png` (15 required).
- **📝 Text path** — describe steps in the doc; **no** screenshot.

Never use “Logged out” in **Login as**. Use a role:

| Login as | Who |
|----------|-----|
| **Guest** | Not signed in |
| **Member** | Active member |
| **Division admin** | `division_admin` (DS) |
| **District admin** | `district_admin` |
| **Super admin** | `admin@syu.lk` |
| **Provisioned user** | Admin-created member/staff before first password change |
| **Suspended member** | Member with `status = suspended` |

**Devices:** Android + optional Chrome.  
**Web:** https://preshan.github.io/SYU-Sri-Lanka/  
**APK:** latest GitHub Release.

---

## A. The 15 screenshots (required)

| ID | Filename | Screen | How to open | Login as |
|----|----------|--------|-------------|----------|
| SS-01 | `splash` | Splash / brand | Cold start | Guest |
| SS-02 | `login` | Login | `/login` | Guest |
| SS-03 | `register` | Register | Login → Register | Guest |
| SS-04 | `member-home` | Member dashboard | `/home` | Member |
| SS-05 | `registration-wizard` | Registration question form | Home → Complete registration | Member (incomplete) |
| SS-06 | `news-feed` | News (member) | Home → News | Member |
| SS-07 | `events-list` | Events (member) | Home → Events | Member |
| SS-08 | `admin-home-super` | Admin dashboard (full) | `/home` | Super admin |
| SS-09 | `admin-home-district` | Admin dashboard (district) | `/home` | District admin |
| SS-10 | `admin-members` | Member list | Admin → Members | Super admin |
| SS-11 | `admin-add-member` | Add member form | `/admin/add-member` | Super admin |
| SS-12 | `admin-news` | Admin news publish | Admin → News | Super admin |
| SS-13 | `admin-events` | Admin events publish | Admin → Events | Super admin |
| SS-14 | `staff-admins` | District & DN admins | Admin home → District & DN admins | Super admin |
| SS-15 | `organizers` | Organizers list / add | Admin home → Organizers | District admin |

**Capture order:** Guest SS-01–03 → Member SS-04–07 → Super SS-08, SS-10–13 → District SS-09, SS-15 → Division SS-14.

---

## B. Full flow catalogue (~34) — shot or text path

| Flow # | Name | Type | Path / steps (no shot unless noted) | Login as | Shot |
|--------|------|------|-------------------------------------|----------|------|
| F-01 | Splash | 📷 | Cold start → `/splash` | Guest | SS-01 |
| F-02 | Login | 📷 | `/login` → email + password → Continue | Guest | SS-02 |
| F-03 | Register | 📷 | Login → Register → submit | Guest | SS-03 |
| F-04 | Confirm email OTP | 📝 | After register → `/confirm-email` → enter 6-digit code from email → verified → `/home` | Member (pending verify) | — |
| F-05 | Forgot password | 📝 | Login → Forgot password → `/forgot-password` → request code → enter code + new password → Login | Guest | — |
| F-06 | Force password change | 📝 | Log in as admin-provisioned user → redirect `/force-password` → set new password → `/home` | Provisioned user | — |
| F-07 | Suspended login block | 📝 | Suspend test member (Admin → Members) → log in as that user → see contact-admin message → signed out | Suspended member | — |
| F-08 | Member dashboard | 📷 | `/home` Home tab (completeness / community tiles) | Member | SS-04 |
| F-09 | Registration wizard | 📷 | Incomplete banner → Complete registration → personal → location → qualifications → club → Submit | Member | SS-05 |
| F-10 | News feed | 📷 | Home → News → pull to refresh | Member | SS-06 |
| F-11 | Events + RSVP | 📷 + 📝 | Home → Events (**SS-07**). RSVP: open event → Going (text only) | Member | SS-07 |
| F-12 | Chat inbox | 📝 | Home → Chat → list conversations | Member | — |
| F-13 | Chat thread | 📝 | Chat → open thread → send message | Member | — |
| F-14 | Settings | 📝 | Home → Settings → language / notifications / website | Member | — |
| F-15 | Edit profile | 📝 | Settings (or profile entry) → Edit profile → save → optional avatar | Member | — |
| F-16 | Notifications center | 📝 | Open bell / `/notifications` → list items | Member | — |
| F-17 | Community links (member) | 📝 | Member home → WhatsApp / Facebook tiles when configured | Member | — |
| F-18 | Admin dashboard (super) | 📷 | `/home` as staff → full tile grid | Super admin | SS-08 |
| F-19 | Admin dashboard (district) | 📷 | `/home` → district-scoped tiles (no super-only tools) | District admin | SS-09 |
| F-20 | Admin dashboard (division) | 📝 | `/home` as division admin → fewer tiles; note WhatsApp | Division admin | — |
| F-21 | Member list | 📷 | `/admin?tab=members` or Members tile → filters / Active vs Suspended | Super admin | SS-10 |
| F-22 | Member actions (note / suspend / save) | 📝 | Members → open row actions → note / suspend / saved | Super admin | — |
| F-23 | Add member | 📷 | `/admin/add-member` → fill form → submit → temp password emailed | Super admin | SS-11 |
| F-24 | Change provisioned email | 📝 | Members → member still on force-password → update email action | Super admin | — |
| F-25 | Admin news | 📷 | `/admin?tab=news` → Create → publish | Super admin | SS-12 |
| F-26 | Admin events | 📷 | `/admin?tab=events` → Create → publish | Super admin | SS-13 |
| F-27 | Broadcast | 📝 | `/admin?tab=broadcast` → compose → send to audience | Super admin | — |
| F-28 | Admin chat | 📝 | `/admin?tab=chat` → open / start direct chat with member | Super admin | — |
| F-29 | Youth clubs | 📝 | `/admin?tab=clubs` → Add club | Super admin | — |
| F-30 | Audit log | 📝 | `/admin?tab=audit` → scroll activity | Super admin | — |
| F-31 | Reports / Approvals | 📝 | `/admin?tab=reports` and `/admin?tab=approvals` | Super admin | — |
| F-32 | Staff Admins | 📝 | Admin home → Staff Admins → add district or division admin | Super admin | — |
| F-33 | WhatsApp (DS) | 📷 | Admin home → WhatsApp → set/view group URL | Division admin | SS-14 |
| F-34 | Organizers | 📷 | Admin home → Organizers → list + add | District admin | SS-15 |

---

## C. Quick reference — text-only paths (copy into doc)

**F-04 Confirm email**  
Register → email with 6-digit code → `/confirm-email` → submit code → home.

**F-05 Forgot password**  
Login → Forgot password → enter email → code in inbox → new password → login.

**F-06 Force password**  
Admin-created account → first login → `/force-password` → new password → home.

**F-07 Suspended**  
Staff suspends member → that user logs in → blocked with contact-admin copy.

**F-12–F-13 Chat**  
Home → Chat → open thread → send.

**F-14–F-15 Settings / profile**  
Home → Settings → Edit profile → save.

**F-16 Notifications**  
`/notifications` or header bell.

**F-22 Member actions**  
Admin → Members → overflow on row → note / suspend / save.

**F-27–F-32**  
Admin shell tabs: Broadcast, Chat, Clubs, Audit, Reports, Approvals; plus Staff Admins from home tiles.

**F-20 Division home**  
Same `/home` as staff with division-scoped tiles; WhatsApp covered by SS-14.

---

## D. Use-case mapping

| Flows | Use cases |
|-------|-----------|
| F-01–F-07 | UC-01–UC-03, UC-21, UC-22 |
| F-08–F-17 | UC-04–UC-10 |
| F-18–F-34 | UC-11–UC-20 |

See also: [USE_CASES.md](./USE_CASES.md), [ARCHITECTURE.md](./ARCHITECTURE.md).
