# Screenshot guide — product documentation

Capture these UIs **before** writing the full product / features document.  
Save files as `{ID}-{slug}.png` (example: `SS-01-splash.png`) so they match the table.

**Devices:** Android phone (preferred for member) + Chrome desktop (admin is fine on either).  
**Web:** https://preshan.github.io/SYU-Sri-Lanka/ or local `flutter run -d chrome --web-port=5280`  
**APK:** latest GitHub Release.

## Accounts to use

| Login as | Account | Notes |
|----------|---------|--------|
| **Logged out** | — | Splash, login, register, forgot password |
| **Super admin** | `admin@syu.lk` | Full admin tiles + publish/chat/clubs/staff |
| **Member** | Any **active** member (not suspended) | Use a real member you already created, or add one via Admin → Add member |
| **Division admin** | A `division_admin` user | Create via Staff Admins (as district or super) if you don’t have one |
| **District admin** | A `district_admin` user | Create via Staff Admins (as super) if you don’t have one |

If you only capture with **super admin + one member + logged out**, you still cover ~80% of the doc. Role-difference shots (SS-28–SS-30) need the other staff accounts.

---

## Capture list

### A. Public / auth (logged out)

| ID | Filename slug | Screen / UI | Route / how to open | Login as |
|----|---------------|-------------|---------------------|----------|
| SS-01 | `splash` | Splash / brand intro | Cold start → `/splash` | Logged out |
| SS-02 | `login` | Login | `/login` | Logged out |
| SS-03 | `register` | Register | Login → Register | Logged out |
| SS-04 | `confirm-email` | Confirm email (OTP) | After register, or `/confirm-email` | Logged out or pending user |
| SS-05 | `forgot-password` | Forgot password | Login → Forgot password | Logged out |
| SS-06 | `force-password` | Force password change | Log in as **admin-provisioned** user before first password change | Provisioned member/staff |

### B. Member app (login as **Member**)

| ID | Filename slug | Screen / UI | Route / how to open | Login as |
|----|---------------|-------------|---------------------|----------|
| SS-07 | `member-home` | Member home hub | `/home` Home tab | Member |
| SS-08 | `registration-wizard` | Registration wizard (any step) | Incomplete banner → Complete registration | Member (incomplete profile) |
| SS-09 | `news-feed` | News tab | Home → News | Member |
| SS-10 | `events-list` | Events tab | Home → Events | Member |
| SS-11 | `event-rsvp` | Event detail / RSVP Going | Events → open item → Going | Member |
| SS-12 | `chat-list` | Chat conversations list | Home → Chat | Member |
| SS-13 | `chat-thread` | Open conversation thread | Chat → open thread | Member |
| SS-14 | `settings` | Settings | Home → Settings | Member |
| SS-15 | `edit-profile` | Edit profile | Settings or profile entry → Edit | Member |
| SS-16 | `notifications` | Notification center | Bell / `/notifications` | Member |
| SS-17 | `community-links` | WhatsApp / Facebook tiles (if configured) | Member home | Member |

### C. Staff dashboard (login as **Super admin** unless noted)

| ID | Filename slug | Screen / UI | Route / how to open | Login as |
|----|---------------|-------------|---------------------|----------|
| SS-18 | `admin-home` | Staff admin home dashboard (tiles) | `/home` as staff | Super admin |
| SS-19 | `admin-shell-members` | Admin → Members list | `/admin?tab=members` or tile | Super admin |
| SS-20 | `admin-member-detail` | Member row actions (notes / suspend / saved) | Members → open actions on one member | Super admin |
| SS-21 | `admin-add-member` | Add member form | `/admin/add-member` or tile | Super admin |
| SS-22 | `admin-news` | Admin News / announcements | `/admin?tab=news` | Super admin |
| SS-23 | `admin-events` | Admin Events | `/admin?tab=events` | Super admin |
| SS-24 | `admin-broadcast` | Broadcast | `/admin?tab=broadcast` | Super admin |
| SS-25 | `admin-chat` | Admin chat list | `/admin?tab=chat` | Super admin |
| SS-26 | `admin-clubs` | Youth clubs | `/admin?tab=clubs` | Super admin |
| SS-27 | `admin-audit` | Audit / activity | `/admin?tab=audit` | Super admin |
| SS-28 | `staff-admins` | Staff Admins panel | Admin home → Staff Admins | Super admin *(also useful as District admin)* |
| SS-29 | `organizers` | Divisional Organizers | Admin home → Organizers | Super or District admin |
| SS-30 | `division-home` | Division admin home (fewer tiles) | `/home` | Division admin |

### D. Optional / edge states

| ID | Filename slug | Screen / UI | How | Login as |
|----|---------------|-------------|-----|----------|
| SS-31 | `suspended-login` | Suspended message on login | Suspend a test member, then try login | Suspended member |
| SS-32 | `admin-reports` | Reports placeholder / summary | `/admin?tab=reports` | Super admin |
| SS-33 | `admin-approvals` | Approvals tab (auto-approved note) | `/admin?tab=approvals` | Super admin |
| SS-34 | `web-admin` | Same admin UI on web desktop width | Chrome + `/admin` | Super admin |

---

## Suggested capture order

1. Logged out: **SS-01 → SS-05**  
2. Member: **SS-07 → SS-17**  
3. Super admin: **SS-18 → SS-29**, plus **SS-32–SS-34**  
4. Extra roles / states: **SS-06, SS-30, SS-31**

## Tips

- Hide personal NIC / phone of real people if screenshots leave the org.
- Prefer English UI for the first doc pass (`Settings` → language).
- Crop to the app frame; one primary screen per file.
- After you attach images, the next doc pass will reference them as `![SS-07](…/SS-07-member-home.png)` etc.

## Mapping to use cases

| Screenshots | Use cases |
|-------------|-----------|
| SS-01–SS-06 | UC-01, UC-02, UC-03, UC-21 |
| SS-07–SS-17 | UC-04–UC-10 |
| SS-18–SS-29 | UC-11–UC-20 |
| SS-30–SS-31 | Role variance, UC-22 |
