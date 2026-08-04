# Architecture Decision Record — Backend approach

## Status
Accepted

## Context
SYU Sri Lanka needs auth, member data, realtime messaging, storage, and (later) push notifications.
The stack choice is Flutter + Supabase/Postgres, with **no Laravel** unless unavoidable.

## Decision
Use **Supabase** as the backend platform:

- Auth: Supabase Auth
- Data: PostgreSQL + Row Level Security
- Files: Supabase Storage
- Realtime: Supabase Realtime on chat tables
- Push: Firebase Cloud Messaging planned; Edge Function only for privileged FCM send when that lands

## Consequences
- Mobile/admin clients talk to Supabase directly with the anon/publishable key
- Authorization is enforced in Postgres RLS (not a custom API layer)
- Edge Functions are an exception for server secrets (OTP mail, admin provision, future FCM), not a general backend rewrite

See also: [ARCHITECTURE.md](./ARCHITECTURE.md), [USE_CASES.md](./USE_CASES.md).

## Rejected alternatives
- Laravel / custom Node API for every CRUD endpoint
- Shipping the service-role key inside the Flutter app
