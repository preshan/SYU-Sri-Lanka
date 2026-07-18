# Architecture Decision Record — Backend approach

## Status
Accepted (Sprint 1)

## Context
SYU Sri Lanka needs auth, member data, realtime messaging, storage, and push notifications.
The product owner requires Flutter + Supabase/Postgres/FCM and **no Laravel** unless unavoidable.

## Decision
Use **Supabase** as the backend platform:

- Auth: Supabase Auth
- Data: PostgreSQL + Row Level Security
- Files: Supabase Storage
- Realtime: Supabase Realtime on chat tables
- Push: Firebase Cloud Messaging, with a **Supabase Edge Function** only for privileged FCM send

## Consequences
- Mobile/admin clients talk to Supabase directly with the anon/publishable key
- Authorization is enforced in Postgres RLS (not a custom API layer)
- Edge Functions are an exception for server secrets (FCM), not a general backend rewrite

## Rejected alternatives
- Laravel / custom Node API for every CRUD endpoint
- Shipping the service-role key inside the Flutter app
