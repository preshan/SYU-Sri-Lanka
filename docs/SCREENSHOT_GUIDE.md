# Screenshot guide — product documentation

Capture **15** UIs for the product / features doc.  
Save as `{ID}-{slug}.png` (example: `SS-01-splash.png`).

**Devices:** Android for member flows; Chrome optional for admin (`/admin`).  
**Web:** https://preshan.github.io/SYU-Sri-Lanka/  
**APK:** latest GitHub Release.

## Accounts

| Login as | Account |
|----------|---------|
| Logged out | — |
| **Member** | Any active member |
| **Super admin** | `admin@syu.lk` |

---

## The 15 shots

| ID | Filename | Screen | How to open | Login as |
|----|----------|--------|-------------|----------|
| SS-01 | `splash` | Splash / brand | Cold start | Logged out |
| SS-02 | `login` | Login | `/login` | Logged out |
| SS-03 | `register` | Register | Login → Register | Logged out |
| SS-04 | `confirm-email` | Email OTP | After register | Pending user |
| SS-05 | `forgot-password` | Forgot password | Login → Forgot password | Logged out |
| SS-06 | `member-home` | Member home | `/home` | Member |
| SS-07 | `news-feed` | News | Home → News | Member |
| SS-08 | `events-list` | Events (+ RSVP if visible) | Home → Events | Member |
| SS-09 | `chat-list` | Chat inbox | Home → Chat | Member |
| SS-10 | `edit-profile` | Edit profile | Settings → Edit profile | Member |
| SS-11 | `admin-home` | Staff dashboard tiles | `/home` as staff | Super admin |
| SS-12 | `admin-members` | Members list | Admin → Members | Super admin |
| SS-13 | `admin-add-member` | Add member form | `/admin/add-member` | Super admin |
| SS-14 | `admin-news` | Publish news | Admin → News | Super admin |
| SS-15 | `staff-admins` | Staff Admins | Admin home → Staff Admins | Super admin |

---

## Why these 15

| Group | IDs | Covers |
|-------|-----|--------|
| Auth | SS-01–05 | Brand, login, signup OTP, recovery |
| Member | SS-06–10 | Home, news, events, chat, profile |
| Admin | SS-11–15 | Dashboard, members, provision, publish, staff roles |

Skipped (mention in prose only): force-password, suspend banner, organizers, clubs, broadcast, audit, notifications, community links, division-only home, web chrome.

## Capture order

1. Logged out → **SS-01 … SS-05**  
2. Member → **SS-06 … SS-10**  
3. `admin@syu.lk` → **SS-11 … SS-15**

## Use-case mapping

| Shots | Use cases |
|-------|-----------|
| SS-01–05 | UC-01, UC-02, UC-03 |
| SS-06–10 | UC-04–UC-08 |
| SS-11–15 | UC-11, UC-12, UC-15, UC-19 |
