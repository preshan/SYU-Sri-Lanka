-- SYU Sri Lanka — Sprint 1 foundation schema
-- Reuses existing integer-keyed location tables (districts, ds_divisions, gn_divisions)

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- Roles
-- ---------------------------------------------------------------------------
create table if not exists public.roles (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  created_at timestamptz not null default now()
);

insert into public.roles (code, name, description) values
  ('member', 'Member', 'Approved SYU member'),
  ('club_admin', 'Club Admin', 'Youth club administrator'),
  ('district_admin', 'District Admin', 'District-level administrator'),
  ('super_admin', 'Super Admin', 'National administrator')
on conflict (code) do nothing;

create table if not exists public.user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  role_id uuid not null references public.roles (id) on delete cascade,
  scope_type text check (scope_type in ('national', 'district', 'club')),
  scope_id text,
  created_at timestamptz not null default now(),
  unique (user_id, role_id, scope_type, scope_id)
);

-- ---------------------------------------------------------------------------
-- Profiles (1:1 with auth.users) — location FKs match existing int IDs
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  full_name text,
  preferred_name text,
  phone text,
  nic text,
  date_of_birth date,
  gender text,
  status text not null default 'pending_registration'
    check (status in (
      'pending_registration',
      'pending_approval',
      'active',
      'suspended'
    )),
  avatar_path text,
  district_id integer references public.districts (id),
  ds_division_id integer references public.ds_divisions (id),
  gn_division_id integer references public.gn_divisions (id),
  youth_club_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists profiles_status_idx on public.profiles (status);
create index if not exists profiles_nic_idx on public.profiles (nic);
create index if not exists profiles_phone_idx on public.profiles (phone);

-- ---------------------------------------------------------------------------
-- Qualifications & youth clubs
-- ---------------------------------------------------------------------------
create table if not exists public.qualifications (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name_en text not null,
  level_order int not null default 0,
  is_active boolean not null default true
);

insert into public.qualifications (code, name_en, level_order) values
  ('ol', 'O/L', 10),
  ('al', 'A/L', 20),
  ('diploma', 'Diploma', 30),
  ('bachelor', 'Bachelor Degree', 40),
  ('master', 'Master Degree', 50),
  ('other', 'Other', 99)
on conflict (code) do nothing;

create table if not exists public.member_qualifications (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  qualification_id uuid not null references public.qualifications (id) on delete restrict,
  institution text,
  year_completed int,
  created_at timestamptz not null default now()
);

create table if not exists public.youth_clubs (
  id uuid primary key default gen_random_uuid(),
  code text unique,
  name text not null,
  district_id integer references public.districts (id),
  ds_division_id integer references public.ds_divisions (id),
  gn_division_id integer references public.gn_divisions (id),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'profiles_youth_club_id_fkey'
  ) then
    alter table public.profiles
      add constraint profiles_youth_club_id_fkey
      foreign key (youth_club_id) references public.youth_clubs (id);
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Social links & activity logs
-- ---------------------------------------------------------------------------
create table if not exists public.social_links (
  id uuid primary key default gen_random_uuid(),
  owner_type text not null check (owner_type in ('member', 'club', 'org')),
  owner_id uuid not null,
  platform text not null check (platform in (
    'facebook', 'instagram', 'whatsapp', 'youtube', 'tiktok', 'website', 'other'
  )),
  url text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists social_links_owner_idx on public.social_links (owner_type, owner_id);

create table if not exists public.activity_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users (id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists activity_logs_entity_idx on public.activity_logs (entity_type, entity_id);
create index if not exists activity_logs_actor_idx on public.activity_logs (actor_id);

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, status)
  values (new.id, new.email, 'pending_registration')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.roles enable row level security;
alter table public.user_roles enable row level security;
alter table public.profiles enable row level security;
alter table public.districts enable row level security;
alter table public.ds_divisions enable row level security;
alter table public.gn_divisions enable row level security;
alter table public.qualifications enable row level security;
alter table public.member_qualifications enable row level security;
alter table public.youth_clubs enable row level security;
alter table public.social_links enable row level security;
alter table public.activity_logs enable row level security;

drop policy if exists "roles_read_all" on public.roles;
drop policy if exists "districts_read_all" on public.districts;
drop policy if exists "ds_read_all" on public.ds_divisions;
drop policy if exists "gn_read_all" on public.gn_divisions;
drop policy if exists "qualifications_read_all" on public.qualifications;
drop policy if exists "youth_clubs_read_active" on public.youth_clubs;
drop policy if exists "profiles_select_own" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;
drop policy if exists "member_qualifications_own" on public.member_qualifications;
drop policy if exists "social_links_member_own" on public.social_links;
drop policy if exists "activity_logs_select_own" on public.activity_logs;

create policy "roles_read_all" on public.roles for select to authenticated using (true);
create policy "districts_read_all" on public.districts for select to authenticated using (true);
create policy "ds_read_all" on public.ds_divisions for select to authenticated using (true);
create policy "gn_read_all" on public.gn_divisions for select to authenticated using (true);
create policy "qualifications_read_all" on public.qualifications for select to authenticated using (true);
create policy "youth_clubs_read_active" on public.youth_clubs for select to authenticated using (is_active = true);

create policy "profiles_select_own" on public.profiles
  for select to authenticated using (auth.uid() = id);
create policy "profiles_update_own" on public.profiles
  for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);
create policy "profiles_insert_own" on public.profiles
  for insert to authenticated with check (auth.uid() = id);

create policy "member_qualifications_own" on public.member_qualifications
  for all to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

create policy "social_links_member_own" on public.social_links
  for all to authenticated
  using (owner_type = 'member' and owner_id = auth.uid())
  with check (owner_type = 'member' and owner_id = auth.uid());

create policy "activity_logs_select_own" on public.activity_logs
  for select to authenticated using (actor_id = auth.uid());
