-- Sprint 3 foundation: announcements, notifications, events schemas

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  audience text not null default 'all'
    check (audience in ('all', 'district', 'club', 'role')),
  audience_ref text,
  published_at timestamptz,
  expires_at timestamptz,
  created_by uuid references auth.users (id) on delete set null,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists announcements_published_idx
  on public.announcements (is_published, published_at desc);

drop trigger if exists announcements_set_updated_at on public.announcements;
create trigger announcements_set_updated_at
before update on public.announcements
for each row execute function public.set_updated_at();

create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  token text not null,
  platform text not null check (platform in ('android', 'ios', 'web')),
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (user_id, token)
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  body text not null,
  type text not null default 'general',
  data jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_idx
  on public.notifications (user_id, created_at desc);

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  starts_at timestamptz not null,
  ends_at timestamptz,
  location_text text,
  district_id integer references public.districts (id),
  youth_club_id uuid references public.youth_clubs (id),
  capacity int,
  is_published boolean not null default false,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists events_starts_idx on public.events (is_published, starts_at);

drop trigger if exists events_set_updated_at on public.events;
create trigger events_set_updated_at
before update on public.events
for each row execute function public.set_updated_at();

create table if not exists public.event_rsvps (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'going'
    check (status in ('going', 'maybe', 'declined')),
  created_at timestamptz not null default now(),
  unique (event_id, profile_id)
);

-- RLS
alter table public.announcements enable row level security;
alter table public.device_tokens enable row level security;
alter table public.notifications enable row level security;
alter table public.events enable row level security;
alter table public.event_rsvps enable row level security;

drop policy if exists "announcements_read_published" on public.announcements;
drop policy if exists "device_tokens_own" on public.device_tokens;
drop policy if exists "notifications_own" on public.notifications;
drop policy if exists "notifications_own_update" on public.notifications;
drop policy if exists "events_read_published" on public.events;
drop policy if exists "event_rsvps_own" on public.event_rsvps;

create policy "announcements_read_published" on public.announcements
  for select to authenticated
  using (
    is_published = true
    and (published_at is null or published_at <= now())
    and (expires_at is null or expires_at > now())
  );

create policy "device_tokens_own" on public.device_tokens
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "notifications_own" on public.notifications
  for select to authenticated using (user_id = auth.uid());

create policy "notifications_own_update" on public.notifications
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "events_read_published" on public.events
  for select to authenticated using (is_published = true);

create policy "event_rsvps_own" on public.event_rsvps
  for all to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

-- Demo announcement for feed smoke-test
insert into public.announcements (title, body, audience, is_published, published_at)
select
  'Welcome to SYU Sri Lanka',
  'Complete your registration to unlock club messaging, events, and regional updates.',
  'all',
  true,
  now()
where not exists (
  select 1 from public.announcements where title = 'Welcome to SYU Sri Lanka'
);
