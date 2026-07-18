-- Targeted news/events (all | district | ds | gn) + notify matching members

-- Announcements: structured location targeting
alter table public.announcements
  add column if not exists district_id integer references public.districts (id),
  add column if not exists ds_division_id integer references public.ds_divisions (id),
  add column if not exists gn_division_id integer references public.gn_divisions (id);

alter table public.announcements drop constraint if exists announcements_audience_check;
alter table public.announcements
  add constraint announcements_audience_check
  check (audience in ('all', 'district', 'ds', 'gn', 'club', 'role'));

-- Events: audience + DS/GN (district_id already exists)
alter table public.events
  add column if not exists audience text not null default 'all',
  add column if not exists ds_division_id integer references public.ds_divisions (id),
  add column if not exists gn_division_id integer references public.gn_divisions (id);

alter table public.events drop constraint if exists events_audience_check;
alter table public.events
  add constraint events_audience_check
  check (audience in ('all', 'district', 'ds', 'gn'));

create index if not exists announcements_audience_district_idx
  on public.announcements (audience, district_id);
create index if not exists events_audience_district_idx
  on public.events (audience, district_id);

-- Profiles matching an audience scope (active members only)
create or replace function public.matching_member_ids(
  p_audience text,
  p_district_id integer,
  p_ds_division_id integer,
  p_gn_division_id integer
)
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  select p.id
  from public.profiles p
  where p.status = 'active'
    and (
      p_audience = 'all'
      or (p_audience = 'district' and p.district_id = p_district_id)
      or (p_audience = 'ds' and p.ds_division_id = p_ds_division_id)
      or (p_audience = 'gn' and p.gn_division_id = p_gn_division_id)
    );
$$;

-- Visibility helper for the current user
create or replace function public.member_can_see_audience(
  p_audience text,
  p_district_id integer,
  p_ds_division_id integer,
  p_gn_division_id integer
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles me
    where me.id = auth.uid()
      and (
        p_audience = 'all'
        or (p_audience = 'district' and me.district_id = p_district_id)
        or (p_audience = 'ds' and me.ds_division_id = p_ds_division_id)
        or (p_audience = 'gn' and me.gn_division_id = p_gn_division_id)
        or public.is_super_admin()
      )
  );
$$;

-- Replace announcements RLS
drop policy if exists "announcements_read_published" on public.announcements;
create policy "announcements_read_published" on public.announcements
  for select to authenticated
  using (
    is_published = true
    and (published_at is null or published_at <= now())
    and (expires_at is null or expires_at > now())
    and public.member_can_see_audience(
      audience, district_id, ds_division_id, gn_division_id
    )
  );

-- Replace events RLS
drop policy if exists "events_read_published" on public.events;
create policy "events_read_published" on public.events
  for select to authenticated
  using (
    is_published = true
    and public.member_can_see_audience(
      audience, district_id, ds_division_id, gn_division_id
    )
  );

-- Allow admins to insert notifications for members (via RPC primarily)
drop policy if exists "notifications_admin_insert" on public.notifications;
create policy "notifications_admin_insert" on public.notifications
  for insert to authenticated
  with check (public.is_super_admin());

-- Publish announcement + notify matching members
create or replace function public.admin_publish_announcement(
  p_title text,
  p_body text,
  p_audience text,
  p_district_id integer default null,
  p_ds_division_id integer default null,
  p_gn_division_id integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  aid uuid;
  ncount int := 0;
begin
  if not public.is_super_admin() then
    raise exception 'Admin only';
  end if;
  if p_audience not in ('all', 'district', 'ds', 'gn') then
    raise exception 'Invalid audience';
  end if;
  if p_audience = 'district' and p_district_id is null then
    raise exception 'District required';
  end if;
  if p_audience = 'ds' and p_ds_division_id is null then
    raise exception 'DS division required';
  end if;
  if p_audience = 'gn' and p_gn_division_id is null then
    raise exception 'GN division required';
  end if;

  insert into public.announcements (
    title, body, audience, district_id, ds_division_id, gn_division_id,
    is_published, published_at, created_by
  ) values (
    trim(p_title), trim(p_body), p_audience, p_district_id, p_ds_division_id, p_gn_division_id,
    true, now(), auth.uid()
  ) returning id into aid;

  insert into public.notifications (user_id, title, body, type, data)
  select
    m,
    p_title,
    left(p_body, 240),
    'announcement',
    jsonb_build_object('announcement_id', aid, 'audience', p_audience)
  from public.matching_member_ids(
    p_audience, p_district_id, p_ds_division_id, p_gn_division_id
  ) as m;

  get diagnostics ncount = row_count;

  return jsonb_build_object('id', aid, 'notified', ncount);
end;
$$;

-- Publish event + notify
create or replace function public.admin_publish_event(
  p_title text,
  p_description text,
  p_starts_at timestamptz,
  p_location_text text,
  p_audience text,
  p_district_id integer default null,
  p_ds_division_id integer default null,
  p_gn_division_id integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  eid uuid;
  ncount int := 0;
begin
  if not public.is_super_admin() then
    raise exception 'Admin only';
  end if;
  if p_audience not in ('all', 'district', 'ds', 'gn') then
    raise exception 'Invalid audience';
  end if;
  if p_audience = 'district' and p_district_id is null then
    raise exception 'District required';
  end if;
  if p_audience = 'ds' and p_ds_division_id is null then
    raise exception 'DS division required';
  end if;
  if p_audience = 'gn' and p_gn_division_id is null then
    raise exception 'GN division required';
  end if;

  insert into public.events (
    title, description, starts_at, location_text, audience,
    district_id, ds_division_id, gn_division_id,
    is_published, created_by
  ) values (
    trim(p_title), nullif(trim(p_description), ''), p_starts_at,
    nullif(trim(p_location_text), ''), p_audience,
    p_district_id, p_ds_division_id, p_gn_division_id,
    true, auth.uid()
  ) returning id into eid;

  insert into public.notifications (user_id, title, body, type, data)
  select
    m,
    'Event: ' || p_title,
    coalesce(nullif(trim(p_description), ''), 'New event — open Events to RSVP'),
    'event',
    jsonb_build_object('event_id', eid, 'audience', p_audience)
  from public.matching_member_ids(
    p_audience, p_district_id, p_ds_division_id, p_gn_division_id
  ) as m;

  get diagnostics ncount = row_count;

  return jsonb_build_object('id', eid, 'notified', ncount);
end;
$$;

-- Admin broadcast message (notification only — not single-member)
create or replace function public.admin_broadcast_message(
  p_title text,
  p_body text,
  p_audience text,
  p_district_id integer default null,
  p_ds_division_id integer default null,
  p_gn_division_id integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  ncount int := 0;
begin
  if not public.is_super_admin() then
    raise exception 'Admin only';
  end if;
  if p_audience not in ('all', 'district', 'ds', 'gn') then
    raise exception 'Invalid audience';
  end if;
  if p_audience = 'district' and p_district_id is null then
    raise exception 'District required';
  end if;
  if p_audience = 'ds' and p_ds_division_id is null then
    raise exception 'DS division required';
  end if;
  if p_audience = 'gn' and p_gn_division_id is null then
    raise exception 'GN division required';
  end if;

  insert into public.notifications (user_id, title, body, type, data)
  select
    m,
    trim(p_title),
    trim(p_body),
    'admin_message',
    jsonb_build_object('audience', p_audience)
  from public.matching_member_ids(
    p_audience, p_district_id, p_ds_division_id, p_gn_division_id
  ) as m;

  get diagnostics ncount = row_count;

  insert into public.activity_logs (actor_id, action, entity_type, metadata)
  values (
    auth.uid(),
    'admin_broadcast',
    'notification',
    jsonb_build_object(
      'audience', p_audience,
      'district_id', p_district_id,
      'ds_division_id', p_ds_division_id,
      'gn_division_id', p_gn_division_id,
      'notified', ncount
    )
  );

  return jsonb_build_object('notified', ncount);
end;
$$;

grant execute on function public.matching_member_ids(text, integer, integer, integer) to authenticated;
grant execute on function public.member_can_see_audience(text, integer, integer, integer) to authenticated;
grant execute on function public.admin_publish_announcement(text, text, text, integer, integer, integer) to authenticated;
grant execute on function public.admin_publish_event(text, text, timestamptz, text, text, integer, integer, integer) to authenticated;
grant execute on function public.admin_broadcast_message(text, text, text, integer, integer, integer) to authenticated;
