# Use cases & flows — SYU Sri Lanka

Actors and primary journeys for the membership app.

## Actors

```mermaid
flowchart LR
  Guest[Guest<br/>not signed in]
  Member[Member]
  DivAdmin[Division admin]
  DistAdmin[District admin]
  Super[Super admin]

  Guest -->|register / login| Member
  Super -.->|provisions| Member
  Super -.->|provisions| DistAdmin
  Super -.->|provisions| DivAdmin
  DistAdmin -.->|provisions| DivAdmin
  DistAdmin -.->|provisions| Member
  DivAdmin -.->|provisions| Member
```

## Use case catalogue

| ID | Use case | Primary actor | Priority |
|----|----------|---------------|----------|
| UC-01 | Sign up with email OTP | Guest | Critical |
| UC-02 | Log in | Guest | Critical |
| UC-03 | Reset password (OTP) | Guest | Critical |
| UC-04 | Complete registration wizard | Member | Critical |
| UC-05 | Edit profile / avatar | Member | High |
| UC-06 | Read news | Member | High |
| UC-07 | Browse events + RSVP | Member | High |
| UC-08 | Message (member inbox) | Member | High |
| UC-09 | View notifications | Member | Medium |
| UC-10 | Open community links | Member / staff | Medium |
| UC-11 | Admin: list / filter members | Staff | Critical |
| UC-12 | Admin: add member | Staff | Critical |
| UC-13 | Admin: suspend / reinstate | Staff | Critical |
| UC-14 | Admin: private member notes | Staff | High |
| UC-15 | Admin: publish news / events | Super admin | High |
| UC-16 | Admin: broadcast message | Super admin | High |
| UC-17 | Admin: direct chat with member | Super admin | High |
| UC-18 | Admin: manage youth clubs | Super admin | Medium |
| UC-19 | Admin: manage staff admins | Super / district | High |
| UC-20 | Admin: divisional organizers | Super / district | Medium |
| UC-21 | Force password change | Provisioned user | Critical |
| UC-22 | Suspended account blocked | Any suspended user | Critical |

## Capability matrix

| Capability | Member | Division admin | District admin | Super admin |
|------------|:------:|:--------------:|:--------------:|:-----------:|
| Self profile / wizard | ✓ | ✓ | ✓ | ✓ |
| News / events / RSVP | ✓ | ✓ | ✓ | ✓ |
| Member chat inbox | ✓ | ✓ | ✓ | ✓ |
| Staff home dashboard | | ✓ | ✓ | ✓ |
| Members in scope | | DS | District | All |
| Add member | | ✓ | ✓ | ✓ |
| Suspend / notes | | ✓ | ✓ | ✓ |
| Create division admin | | | ✓ | ✓ |
| Create district admin | | | | ✓ |
| Organizers CRUD | | | ✓ | ✓ |
| Publish news / events / broadcast | | | | ✓ |
| Admin↔member chat open | | | | ✓ |
| Youth clubs write | | | | ✓ |

## Sequence flows

### UC-01 — Sign up + OTP (Gmail via Edge Function)

```mermaid
sequenceDiagram
  actor U as Guest
  participant App as Flutter app
  participant Auth as Supabase Auth
  participant Fn as send-app-otp
  participant DB as Postgres
  participant Mail as Gmail SMTP

  U->>App: Register email + password
  App->>Auth: signUp
  Auth-->>App: user created (autoconfirm)
  App->>Fn: email, purpose=signup
  Fn->>DB: issue_app_email_otp
  Fn->>DB: get_mail_settings_internal
  Fn->>Mail: send 6-digit code
  U->>App: Enter code on /confirm-email
  App->>DB: verify_app_signup_otp
  DB-->>App: app_email_verified
  App->>App: Navigate /home
```

### UC-03 — Forgot password

```mermaid
sequenceDiagram
  actor U as Guest
  participant App as Flutter app
  participant Fn as send-app-otp
  participant DB as Postgres

  U->>App: /forgot-password
  App->>Fn: purpose=recovery
  Fn-->>U: Email with code
  U->>App: Code + new password
  App->>DB: verify_app_recovery_otp
  App->>App: Return to login
```

### UC-02 / UC-21 / UC-22 — Login gates

```mermaid
flowchart TD
  A[Login success] --> B{Suspended?}
  B -->|yes| X[Sign out + contact admin message]
  B -->|no| C{Email verified?}
  C -->|no| D[/confirm-email/]
  C -->|yes| E{must_change_password?}
  E -->|yes| F[/force-password/]
  E -->|no| G[/home/]
  D --> G
  F --> G
```

### UC-12 — Admin provisions a member

```mermaid
sequenceDiagram
  actor A as Staff admin
  participant App as Flutter /admin/add-member
  participant Fn as admin-create-member
  participant Auth as Auth Admin API
  participant DB as Postgres
  participant Mail as Gmail

  A->>App: Submit name, email, phone, location…
  App->>Fn: JWT + payload
  Fn->>Fn: is_staff_admin + scope check
  Fn->>Auth: createUser temp password
  Fn->>DB: admin_finalize_provisioned_member
  Fn->>Mail: email temp password
  Fn-->>App: success
  Note over Auth,DB: User must change password on first login
```

### UC-19 — Create staff admin

```mermaid
flowchart LR
  Super[super_admin] -->|district_admin or division_admin| Staff[New staff user]
  Dist[district_admin] -->|division_admin only| Staff
  Staff --> Mail[Temp password email]
  Mail --> Force[Force password change]
```

### Member vs staff home

```mermaid
flowchart TB
  Home[/home/]
  Home --> StaffCheck{is_staff_admin?}
  StaffCheck -->|no| MemberUI[Member hub<br/>completeness, community links]
  StaffCheck -->|yes| AdminDash[Admin dashboard tiles]
  Home --> Tabs[Bottom nav: Home News Events Chat Settings]
```

## Related

- [ARCHITECTURE.md](./ARCHITECTURE.md)
- [SCREENSHOT_GUIDE.md](./SCREENSHOT_GUIDE.md) — capture IDs for the product document
- [UAT_PLAN.md](./UAT_PLAN.md)
