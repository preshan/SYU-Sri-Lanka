-- Staff admin helper + directory listing by user type (member / district_admin / division_admin).

create or replace function public.is_staff_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_super_admin()
      or public.is_district_admin()
      or public.is_division_admin();
$$;

grant execute on function public.is_staff_admin() to authenticated;

create or replace function public.my_division_admin_ds_ids()
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
    and r.code = 'division_admin'
    and ur.scope_type = 'ds_division'
    and nullif(ur.scope_id, '') is not null;
$$;

grant execute on function public.my_division_admin_ds_ids() to authenticated;

-- Division admins may read member profiles in their DS division(s).
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
    or (
      public.is_division_admin()
      and exists (
        select 1
        from public.user_roles ur
        join public.roles r on r.id = ur.role_id
        where ur.user_id = auth.uid()
          and r.code = 'division_admin'
          and ur.scope_type = 'ds_division'
          and ur.scope_id = profiles.ds_division_id::text
      )
    )
  );

-- Nested quals for division admins too.
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
    or (
      public.is_division_admin()
      and exists (
        select 1
        from public.profiles p
        join public.user_roles ur on ur.user_id = auth.uid()
        join public.roles r on r.id = ur.role_id
        where p.id = member_qualifications.profile_id
          and r.code = 'division_admin'
          and ur.scope_type = 'ds_division'
          and ur.scope_id = p.ds_division_id::text
      )
    )
  );

-- Saved members for any staff admin.
drop policy if exists "admin_saved_select_own" on public.admin_saved_members;
drop policy if exists "admin_saved_insert_own" on public.admin_saved_members;
drop policy if exists "admin_saved_update_own" on public.admin_saved_members;
drop policy if exists "admin_saved_delete_own" on public.admin_saved_members;

create policy "admin_saved_select_own" on public.admin_saved_members
  for select to authenticated
  using (admin_id = auth.uid() and public.is_staff_admin());

create policy "admin_saved_insert_own" on public.admin_saved_members
  for insert to authenticated
  with check (admin_id = auth.uid() and public.is_staff_admin());

create policy "admin_saved_update_own" on public.admin_saved_members
  for update to authenticated
  using (admin_id = auth.uid() and public.is_staff_admin())
  with check (admin_id = auth.uid() and public.is_staff_admin());

create policy "admin_saved_delete_own" on public.admin_saved_members
  for delete to authenticated
  using (admin_id = auth.uid() and public.is_staff_admin());

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
  if not public.is_staff_admin() then
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
  if not public.is_staff_admin() then
    raise exception 'Admin only';
  end if;

  delete from public.admin_saved_members
  where admin_id = auth.uid()
    and member_id = p_member_id;

  return jsonb_build_object('member_id', p_member_id, 'saved', false);
end;
$$;

-- Returns profile ids for the Members directory filtered by user type(s).
create or replace function public.directory_user_ids(
  p_user_types text[],
  p_district_id int default null,
  p_ds_division_id int default null
)
returns uuid[]
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_types text[] := coalesce(p_user_types, array['member']::text[]);
  v_district int := p_district_id;
  v_ds int := p_ds_division_id;
  v_ids uuid[] := '{}';
  v_allow_district_admin boolean;
begin
  if not public.is_staff_admin() then
    raise exception 'not authorized';
  end if;

  -- Normalize types
  select array_agg(distinct t)
  into v_types
  from unnest(v_types) as t
  where t in ('member', 'district_admin', 'division_admin');

  if v_types is null or cardinality(v_types) = 0 then
    v_types := array['member']::text[];
  end if;

  v_allow_district_admin := public.is_super_admin() or public.is_district_admin();

  if 'district_admin' = any (v_types) and not v_allow_district_admin then
    raise exception 'not authorized for district admins';
  end if;

  -- Scope locks
  if public.is_division_admin()
     and not public.is_super_admin()
     and not public.is_district_admin() then
    -- Division-only: lock to their DS (and its district).
    select d.district_id, ds_ids[1]
    into v_district, v_ds
    from (
      select public.my_division_admin_ds_ids() as ds_ids
    ) s
    join public.ds_divisions d on d.id = (s.ds_ids)[1]
    limit 1;

    if v_ds is null then
      return '{}';
    end if;
    -- If caller passed a DS, must match one of theirs
    if p_ds_division_id is not null
       and not (p_ds_division_id = any (public.my_division_admin_ds_ids())) then
      raise exception 'not authorized';
    end if;
    if p_ds_division_id is not null then
      v_ds := p_ds_division_id;
    end if;
  elsif public.is_district_admin() and not public.is_super_admin() then
    if v_district is null then
      select (public.my_district_admin_district_ids())[1] into v_district;
    end if;
    if v_district is null
       or not (v_district = any (public.my_district_admin_district_ids())) then
      raise exception 'not authorized';
    end if;
  end if;

  if 'member' = any (v_types) then
    v_ids := v_ids || coalesce((
      select array_agg(p.id)
      from public.profiles p
      where (v_district is null or p.district_id = v_district)
        and (v_ds is null or p.ds_division_id = v_ds)
        and not exists (
          select 1
          from public.user_roles ur
          join public.roles r on r.id = ur.role_id
          where ur.user_id = p.id
            and r.code in ('district_admin', 'division_admin')
        )
    ), '{}');
  end if;

  if 'district_admin' = any (v_types) and v_allow_district_admin then
    v_ids := v_ids || coalesce((
      select array_agg(distinct ur.user_id)
      from public.user_roles ur
      join public.roles r on r.id = ur.role_id and r.code = 'district_admin'
      join public.profiles p on p.id = ur.user_id
      where ur.scope_type = 'district'
        and (v_district is null or ur.scope_id = v_district::text)
        and (v_ds is null or p.ds_division_id = v_ds)
    ), '{}');
  end if;

  if 'division_admin' = any (v_types) then
    v_ids := v_ids || coalesce((
      select array_agg(distinct ur.user_id)
      from public.user_roles ur
      join public.roles r on r.id = ur.role_id and r.code = 'division_admin'
      join public.ds_divisions d on d.id = nullif(ur.scope_id, '')::int
      where ur.scope_type = 'ds_division'
        and (v_district is null or d.district_id = v_district)
        and (v_ds is null or d.id = v_ds)
    ), '{}');
  end if;

  -- Deduplicate
  select coalesce(array_agg(distinct x), '{}')
  into v_ids
  from unnest(v_ids) as x;

  return v_ids;
end;
$$;

grant execute on function public.directory_user_ids(text[], int, int)
  to authenticated;

-- Division admins may list DN contacts in their district (not district admins).
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

  if not (
    public.is_super_admin()
    or exists (
      select 1
      from public.user_roles ur
      join public.roles r on r.id = ur.role_id
      where ur.user_id = auth.uid()
        and r.code = 'district_admin'
        and ur.scope_type = 'district'
        and ur.scope_id = p_district_id::text
    )
    or (
      public.is_division_admin()
      and exists (
        select 1
        from public.ds_divisions d
        where d.id = any (public.my_division_admin_ds_ids())
          and d.district_id = p_district_id
      )
    )
  ) then
    raise exception 'not authorized';
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

notify pgrst, 'reload schema';
