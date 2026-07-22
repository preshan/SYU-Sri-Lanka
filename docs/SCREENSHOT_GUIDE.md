# Screenshot guide — product documentation

Capture **15** UIs for the product / features doc.  
Save as `{ID}-{slug}.png` (example: `SS-01-splash.png`).

**Devices:** Android for member flows; Chrome optional for admin.  
**Web:** https://preshan.github.io/SYU-Sri-Lanka/  
**APK:** latest GitHub Release.

Explain in text only (no screenshot): confirm-email OTP, forgot-password, edit-profile, chat thread detail.

## Accounts (`Login as`)

Use a **role name**, never “Logged out”:

| Login as | Who |
|----------|-----|
| **Guest** | Not signed in (splash / login / register only) |
| **Member** | Any active member |
| **Division admin** | DS / division admin (`division_admin`) |
| **District admin** | District admin (`district_admin`) |
| **Super admin** | `admin@syu.lk` |

Create district / division admins via **Staff Admins** if you don’t have them yet.

---

## The 15 shots

| ID | Filename | Screen | How to open | Login as |
|----|----------|--------|-------------|----------|
| SS-01 | `splash` | Splash / brand | Cold start | Guest |
| SS-02 | `login` | Login | `/login` | Guest |
| SS-03 | `register` | Register | Login → Register | Guest |
| SS-04 | `member-home` | Member dashboard / home hub | `/home` | Member |
| SS-05 | `registration-wizard` | Member registration question form | Home → Complete registration (incomplete profile) | Member |
| SS-06 | `news-feed` | News (member) | Home → News | Member |
| SS-07 | `events-list` | Events (member) | Home → Events | Member |
| SS-08 | `admin-home-super` | Admin dashboard (full tiles) | `/home` | Super admin |
| SS-09 | `admin-home-district` | Admin dashboard (district) | `/home` | District admin |
| SS-10 | `admin-members` | Member list | Admin → Members | Super admin *(or District admin)* |
| SS-11 | `admin-add-member` | Add member form | `/admin/add-member` | Super admin *(or District / Division admin)* |
| SS-12 | `admin-news` | Admin news (create / publish) | Admin → News | Super admin |
| SS-13 | `admin-events` | Admin events (create / publish) | Admin → Events | Super admin |
| SS-14 | `whatsapp-link` | Set / view DS WhatsApp group | Admin home → WhatsApp / community tile | Division admin |
| SS-15 | `organizers` | Divisional organizers (list + add) | Admin home → Organizers | District admin *(or Super admin)* |

---

## Why these 15

| Group | IDs | Covers |
|-------|-----|--------|
| Guest entry | SS-01–03 | Brand, login, register |
| Member app | SS-04–07 | Dashboard, registration form, news, events |
| Staff dashboards | SS-08–09 | Super vs district admin home |
| Ops | SS-10–15 | Member list, add member, publish news/events, WhatsApp, organizers |

## Capture order

1. **Guest** → SS-01 … SS-03  
2. **Member** → SS-04 … SS-07  
3. **Super admin** → SS-08, SS-10 … SS-13  
4. **District admin** → SS-09, SS-15  
5. **Division admin** → SS-14  

## Use-case mapping

| Shots | Use cases |
|-------|-----------|
| SS-01–03 | UC-01, UC-02 |
| SS-04–07 | UC-04, UC-06, UC-07 |
| SS-08–15 | UC-10–UC-12, UC-15, UC-19, UC-20 |
