# Database schema (Sprint 1–2)

## Location hierarchy (existing)

| Table | PK | Notes |
|-------|----|--------|
| `districts` | `integer` | Province optional |
| `ds_divisions` | `integer` | FK → districts |
| `gn_divisions` | `integer` | FK → ds_divisions |

Registration and profiles reuse these integer IDs (no UUID remapping).

## Identity & access

| Table | Purpose |
|-------|---------|
| `roles` | `member`, `club_admin`, `district_admin`, `super_admin` |
| `user_roles` | Assignments with optional `scope_type` / `scope_id` |
| `profiles` | 1:1 with `auth.users`; membership fields + status |

### Profile status

- `pending_registration` — account created, wizard not submitted
- `pending_approval` — registration submitted
- `active` — approved member
- `suspended` — blocked

## Registration masters

| Table | Purpose |
|-------|---------|
| `qualifications` | Education catalog |
| `member_qualifications` | Join profile ↔ qualification |
| `youth_clubs` | Clubs linked to district/DS/GN |

## Member app content (Sprint 3+)

| Table | Purpose |
|-------|---------|
| `announcements` | Published org/club updates with audience targeting |
| `notifications` | In-app notification inbox per user |
| `device_tokens` | FCM/APNs device registration |
| `events` | Published events |
| `event_rsvps` | Member RSVP (`going` / `maybe` / `declined`) |

## Safe writes

`submit_member_registration(...)` — security definer RPC used by the Flutter wizard. Validates NIC format, age 15–35, district, then updates profile + qualifications atomically and writes an activity log.

## RLS baseline

Deny-by-default. Authenticated users can read location/qualification/club catalogs; members can select/update only their own profile and related rows.
