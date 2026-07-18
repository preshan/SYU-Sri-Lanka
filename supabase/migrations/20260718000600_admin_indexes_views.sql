-- Performance indexes + admin reporting views

create index if not exists profiles_district_idx on public.profiles (district_id);
create index if not exists profiles_club_idx on public.profiles (youth_club_id);
create index if not exists profiles_status_created_idx on public.profiles (status, created_at desc);
create index if not exists event_rsvps_profile_idx on public.event_rsvps (profile_id);
create index if not exists conversation_participants_user_idx
  on public.conversation_participants (user_id);

create or replace view public.admin_membership_summary as
select
  status,
  count(*)::bigint as member_count
from public.profiles
group by status;

create or replace view public.admin_events_summary as
select
  e.id as event_id,
  e.title,
  e.starts_at,
  e.is_published,
  count(r.id)::bigint as rsvp_count,
  count(*) filter (where r.status = 'going')::bigint as going_count
from public.events e
left join public.event_rsvps r on r.event_id = e.id
group by e.id, e.title, e.starts_at, e.is_published;

-- Helper: is current user a super_admin
create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_roles ur
    join public.roles r on r.id = ur.role_id
    where ur.user_id = auth.uid()
      and r.code = 'super_admin'
  );
$$;

grant execute on function public.is_super_admin() to authenticated;

-- Admin can list pending profiles
drop policy if exists "profiles_admin_select" on public.profiles;
create policy "profiles_admin_select" on public.profiles
  for select to authenticated
  using (public.is_super_admin() or auth.uid() = id);

drop policy if exists "profiles_admin_update" on public.profiles;
create policy "profiles_admin_update" on public.profiles
  for update to authenticated
  using (public.is_super_admin() or auth.uid() = id)
  with check (public.is_super_admin() or auth.uid() = id);

-- Announcements / events write for super_admin
drop policy if exists "announcements_admin_all" on public.announcements;
create policy "announcements_admin_all" on public.announcements
  for all to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

drop policy if exists "events_admin_all" on public.events;
create policy "events_admin_all" on public.events
  for all to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

grant select on public.admin_membership_summary to authenticated;
grant select on public.admin_events_summary to authenticated;
