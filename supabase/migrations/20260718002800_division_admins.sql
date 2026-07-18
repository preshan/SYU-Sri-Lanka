-- Division admins (DS-scoped) + district-admin member visibility.
-- Assign with:
--   insert into user_roles (user_id, role_id, scope_type, scope_id)
--   select '<user-uuid>', id, 'ds_division', '<ds_division_id>'
--   from roles where code = 'division_admin';

insert into public.roles (code, name, description) values
  (
    'division_admin',
    'Division Admin',
    'DS division-level administrator (name + phone required)'
  )
on conflict (code) do nothing;

-- Allow ds_division scope on user_roles
alter table public.user_roles
  drop constraint if exists user_roles_scope_type_check;

alter table public.user_roles
  add constraint user_roles_scope_type_check
  check (scope_type is null or scope_type in (
    'national', 'district', 'club', 'ds_division'
  ));

create or replace function public.is_district_admin()
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
      and r.code = 'district_admin'
  );
$$;

create or replace function public.is_division_admin()
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
      and r.code = 'division_admin'
  );
$$;

-- Super admin or district admin (member tools / home dashboard).
create or replace function public.is_org_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_super_admin() or public.is_district_admin();
$$;

grant execute on function public.is_district_admin() to authenticated;
grant execute on function public.is_division_admin() to authenticated;
grant execute on function public.is_org_admin() to authenticated;

-- District admins may read member profiles in their scoped district(s).
drop policy if exists "profiles_admin_select" on public.profiles;
create policy "profiles_admin_select" on public.profiles
  for select to authenticated
  using (
    public.is_super_admin()
    or auth.uid() = id
    or (
      public.is_district_admin()
      and exists (
        select 1
        from public.user_roles ur
        join public.roles r on r.id = ur.role_id
        where ur.user_id = auth.uid()
          and r.code = 'district_admin'
          and ur.scope_type = 'district'
          and ur.scope_id = profiles.district_id::text
      )
    )
  );

-- Nested quals on member list for district admins.
drop policy if exists "member_qualifications_admin_select" on public.member_qualifications;
create policy "member_qualifications_admin_select"
  on public.member_qualifications
  for select to authenticated
  using (
    public.is_super_admin()
    or profile_id = auth.uid()
    or (
      public.is_district_admin()
      and exists (
        select 1
        from public.profiles p
        join public.user_roles ur on ur.user_id = auth.uid()
        join public.roles r on r.id = ur.role_id
        where p.id = member_qualifications.profile_id
          and r.code = 'district_admin'
          and ur.scope_type = 'district'
          and ur.scope_id = p.district_id::text
      )
    )
  );

-- Saved members for district admins too.
drop policy if exists "admin_saved_select_own" on public.admin_saved_members;
drop policy if exists "admin_saved_insert_own" on public.admin_saved_members;
drop policy if exists "admin_saved_update_own" on public.admin_saved_members;
drop policy if exists "admin_saved_delete_own" on public.admin_saved_members;

create policy "admin_saved_select_own" on public.admin_saved_members
  for select to authenticated
  using (admin_id = auth.uid() and public.is_org_admin());

create policy "admin_saved_insert_own" on public.admin_saved_members
  for insert to authenticated
  with check (admin_id = auth.uid() and public.is_org_admin());

create policy "admin_saved_update_own" on public.admin_saved_members
  for update to authenticated
  using (admin_id = auth.uid() and public.is_org_admin())
  with check (admin_id = auth.uid() and public.is_org_admin());

create policy "admin_saved_delete_own" on public.admin_saved_members
  for delete to authenticated
  using (admin_id = auth.uid() and public.is_org_admin());

create or replace function public.admin_save_member(
  p_member_id uuid,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  rid uuid;
begin
  if not public.is_org_admin() then
    raise exception 'Admin only';
  end if;
  if p_member_id = auth.uid() then
    raise exception 'Cannot save yourself';
  end if;
  if not exists (select 1 from public.profiles where id = p_member_id) then
    raise exception 'Member not found';
  end if;

  insert into public.admin_saved_members (admin_id, member_id, note)
  values (auth.uid(), p_member_id, nullif(trim(coalesce(p_note, '')), ''))
  on conflict (admin_id, member_id) do update
    set note = coalesce(excluded.note, public.admin_saved_members.note)
  returning id into rid;

  return jsonb_build_object('id', rid, 'member_id', p_member_id, 'saved', true);
end;
$$;

create or replace function public.admin_unsave_member(p_member_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_org_admin() then
    raise exception 'Admin only';
  end if;

  delete from public.admin_saved_members
  where admin_id = auth.uid()
    and member_id = p_member_id;

  return jsonb_build_object('member_id', p_member_id, 'saved', false);
end;
$$;

-- Division admins for a district (name + phone), for district/super admins.
create or replace function public.list_division_admins_for_district(
  p_district_id int,
  p_ds_division_id int default null
)
returns table (
  user_id uuid,
  full_name text,
  phone text,
  ds_division_id int,
  ds_division_name text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if p_district_id is null then
    raise exception 'district is required';
  end if;

  if not public.is_super_admin() then
    if not exists (
      select 1
      from public.user_roles ur
      join public.roles r on r.id = ur.role_id
      where ur.user_id = auth.uid()
        and r.code = 'district_admin'
        and ur.scope_type = 'district'
        and ur.scope_id = p_district_id::text
    ) then
      raise exception 'not authorized';
    end if;
  end if;

  return query
  select
    p.id as user_id,
    nullif(trim(coalesce(p.full_name, '')), '') as full_name,
    nullif(trim(coalesce(p.phone, '')), '') as phone,
    d.id as ds_division_id,
    d.name as ds_division_name
  from public.user_roles ur
  join public.roles r on r.id = ur.role_id and r.code = 'division_admin'
  join public.profiles p on p.id = ur.user_id
  join public.ds_divisions d
    on d.id = nullif(ur.scope_id, '')::int
   and d.district_id = p_district_id
  where ur.scope_type = 'ds_division'
    and (p_ds_division_id is null or d.id = p_ds_division_id)
  order by d.name, p.full_name nulls last;
end;
$$;

grant execute on function public.list_division_admins_for_district(int, int)
  to authenticated;

-- District id(s) for the current district_admin (from user_roles scope).
create or replace function public.my_district_admin_district_ids()
returns int[]
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(array_agg(distinct nullif(ur.scope_id, '')::int), '{}'::int[])
  from public.user_roles ur
  join public.roles r on r.id = ur.role_id
  where ur.user_id = auth.uid()
    and r.code = 'district_admin'
    and ur.scope_type = 'district'
    and nullif(ur.scope_id, '') is not null;
$$;

grant execute on function public.my_district_admin_district_ids() to authenticated;
