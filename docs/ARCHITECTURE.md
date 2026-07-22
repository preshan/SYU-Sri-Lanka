# Architecture — SYU Sri Lanka

Flutter + Supabase membership platform for State Youth Union Sri Lanka.

## System context

```mermaid
flowchart LR
  subgraph clients [Clients]
    Android[Android app]
    Web[Flutter Web / GitHub Pages]
  end

  subgraph supabase [Supabase]
    Auth[Auth]
    DB[(Postgres + RLS)]
    Storage[Storage]
    RT[Realtime]
    Edge[Edge Functions]
  end

  Android --> Auth
  Android --> DB
  Android --> Storage
  Android --> RT
  Android --> Edge
  Web --> Auth
  Web --> DB
  Web --> Storage
  Web --> RT
  Web --> Edge
  Edge --> Auth
  Edge --> DB
  Edge -.->|SMTP Gmail| Mail[Gmail SMTP]
```

## Logical layers

```mermaid
flowchart TB
  UI[Presentation — screens / panels]
  Dom[Features — auth, home, admin, messaging…]
  Core[Core — router, theme, supabase bootstrap, config]
  Remote[Supabase client — Auth, PostgREST, Storage, Functions]

  UI --> Dom
  Dom --> Core
  Core --> Remote
```

## Backend decision

See [ADR-001-backend.md](./ADR-001-backend.md):

- Authorization lives in **Postgres RLS** (not a custom API layer)
- Clients use **anon key only**; service role stays in Edge Functions
- Edge Functions: OTP mail, admin provision member/staff, email update, Auth SMTP sync

## Roles & scope

```mermaid
flowchart TB
  SA[super_admin<br/>national]
  DA[district_admin<br/>district scope]
  VA[division_admin<br/>DS division scope]
  M[member<br/>self only]

  SA -->|manages| DA
  SA -->|manages| VA
  DA -->|manages| VA
  SA --> M
  DA --> M
  VA --> M
```

| Role | Scope field | Staff UI (`is_staff_admin`) | Notable powers |
|------|-------------|----------------------------|----------------|
| `member` | — | No | Profile, news, events/RSVP, chat, notifications |
| `division_admin` | `ds_division` | Yes | Members in DS, add member, notes, suspend, DS WhatsApp |
| `district_admin` | `district` | Yes | Members in district, create division admins, organizers |
| `super_admin` | national | Yes | All of above + publish news/events/broadcast, clubs write, open admin chat, create district admins |

Staff detection: `is_staff_admin()` = super ∨ district ∨ division.

## Data domains (high level)

```mermaid
erDiagram
  profiles ||--o{ user_roles : has
  roles ||--o{ user_roles : defines
  profiles ||--o{ member_qualifications : has
  profiles ||--o{ event_rsvps : rsvps
  events ||--o{ event_rsvps : receives
  conversations ||--o{ conversation_participants : has
  conversations ||--o{ messages : contains
  profiles ||--o| member_admin_notes : noted_by_staff
  districts ||--o{ ds_divisions : contains
  ds_divisions ||--o{ gn_divisions : contains
```

Full schema: [DATABASE_SCHEMA.md](./DATABASE_SCHEMA.md).

## Edge Functions

| Function | Who calls | Purpose |
|----------|-----------|---------|
| `send-app-otp` | App (signup / recovery) | Issue OTP + send Gmail (avoids Auth email quota) |
| `admin-create-member` | Staff | Create auth user, finalize profile, email temp password |
| `admin-create-staff` | Super / district | Create district or division admin |
| `admin-update-member-email` | Staff | Change email while force-password pending |
| `sync-auth-smtp` | Ops / admin | Sync mail settings toward Auth SMTP |

## App navigation map

```mermaid
flowchart TD
  Splash[/splash/] --> Login[/login/]
  Splash --> Home[/home/]
  Login --> Home
  Login --> Reg[/register/]
  Login --> Forgot[/forgot-password/]
  Reg --> Confirm[/confirm-email/]
  Confirm --> Home
  Forgot --> Login
  Home --> Force[/force-password/]
  Home --> Wizard[/registration/]
  Home --> Edit[/profile/edit/]
  Home --> Settings[/settings/]
  Home --> Notif[/notifications/]
  Home --> Admin[/admin/]
  Admin --> AddMem[/admin/add-member/]
```

## Related docs

- [USE_CASES.md](./USE_CASES.md) — actors, use cases, sequence flows
- [SCREENSHOT_GUIDE.md](./SCREENSHOT_GUIDE.md) — UI capture checklist for the product doc
- [SECURITY_CHECKLIST.md](./SECURITY_CHECKLIST.md)
- [RELEASE_RUNBOOK.md](./RELEASE_RUNBOOK.md)
