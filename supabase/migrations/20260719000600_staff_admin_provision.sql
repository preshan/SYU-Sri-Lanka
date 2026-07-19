-- Provision / list / update district & division (DN) admins; login suspend gate.

create or replace function public.is_account_suspended()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select p.status = 'suspended' from public.profiles p where p.id = auth.uid()),
    false
  );
$$;

grant execute on function public.is_account_suspended() to authenticated;

create or replace function public.admin_finalize_staff_admin(
  p_user_id uuid,
  p_full_name text,
  p_phone text,
  p_email text,
  p_role_code text,
  p_district_id integer default null,
  p_ds_division_id integer default null
)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text := trim(coalesce(p_full_name, ''));
  v_phone text := trim(coalesce(p_phone, ''));
  v_email text := lower(trim(coalesce(p_email, '')));
  v_role text := lower(trim(coalesce(p_role_code, '')));
  v_district int := p_district_id;
  v_ds int := p_ds_division_id;
  v_role_id uuid;
  row public.profiles;
begin
  if not (public.is_super_admin() or public.is_district_admin()) then
    raise exception 'Not allowed';
  end if;

  if v_name = '' or char_length(v_name) < 2 then
    raise exception 'Full name is required';
  end if;
  if v_email = '' or position('@' in v_email) = 0 then
    raise exception 'Valid email is required';
  end if;
  if char_length(v_phone) < 9 then
    raise exception 'Valid phone is required';
  end if;

  if v_role = 'district_admin' then
    if not public.is_super_admin() then
      raise exception 'Only super admin can add district admins';
    end if;
    if v_district is null then
      raise exception 'District is required';
    end if;
    v_ds := null;
  elsif v_role = 'division_admin' then
    if v_ds is null then
      raise exception 'Divisional secretariat is required';
    end if;
    select d.district_id into v_district
    from public.ds_divisions d
    where d.id = v_ds;
    if v_district is null then
      raise exception 'Invalid DS division';
    end if;
    if public.is_district_admin() and not public.is_super_admin() then
      if not (v_district = any (public.my_district_admin_district_ids())) then
        raise exception 'DS out of district scope';
      end if;
    end if;
  else
    raise exception 'Invalid role';
  end if;

  select r.id into v_role_id from public.roles r where r.code = v_role;
  if v_role_id is null then
    raise exception 'Role not found';
  end if;

  update public.profiles
  set
    email = v_email,
    full_name = v_name,
    phone = v_phone,
    district_id = v_district,
    ds_division_id = v_ds,
    status = 'active',
    app_email_verified = true,
    must_change_password = true,
    admin_provisioned = true,
    updated_at = now()
  where id = p_user_id
  returning * into row;

  if row.id is null then
    raise exception 'Profile not found for user';
  end if;

  -- Replace this staff role assignment (keep other roles untouched except same code).
  delete from public.user_roles ur
  using public.roles r
  where ur.user_id = p_user_id
    and ur.role_id = r.id
    and r.code in ('district_admin', 'division_admin');

  insert into public.user_roles (user_id, role_id, scope_type, scope_id)
  values (
    p_user_id,
    v_role_id,
    case when v_role = 'district_admin' then 'district' else 'ds_division' end,
    case
      when v_role = 'district_admin' then v_district::text
      else v_ds::text
    end
  );

  insert into public.activity_logs (actor_id, action, entity_type, entity_id, metadata)
  values (
    auth.uid(),
    'admin_provisioned_staff',
    'profile',
    p_user_id,
    jsonb_build_object(
      'email', v_email,
      'full_name', v_name,
      'role', v_role,
      'district_id', v_district,
      'ds_division_id', v_ds
    )
  );

  return row;
end;
$$;

grant execute on function public.admin_finalize_staff_admin(
  uuid, text, text, text, text, integer, integer
) to authenticated;

create or replace function public.list_managed_staff_admins(
  p_role_code text default null,
  p_district_id integer default null,
  p_ds_division_id integer default null
)
returns table (
  user_id uuid,
  full_name text,
  email text,
  phone text,
  status text,
  role_code text,
  district_id integer,
  district_name text,
  ds_division_id integer,
  ds_division_name text,
  suspended_by_name text,
  suspended_by_role text,
  must_change_password boolean,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_role text := nullif(lower(trim(coalesce(p_role_code, ''))), '');
  v_district int := p_district_id;
  v_ds int := p_ds_division_id;
begin
  if not (public.is_super_admin() or public.is_district_admin()) then
    raise exception 'Not allowed';
  end if;

  if public.is_district_admin() and not public.is_super_admin() then
    -- District admins only manage DN admins in their district(s).
    if v_district is null then
      v_district := (public.my_district_admin_district_ids())[1];
    end if;
    if v_district is null
       or not (v_district = any (public.my_district_admin_district_ids())) then
      raise exception 'District out of scope';
    end if;
    v_role := 'division_admin';
  end if;

  return query
  select
    p.id,
    nullif(trim(coalesce(p.full_name, '')), ''),
    nullif(trim(coalesce(p.email, '')), ''),
    nullif(trim(coalesce(p.phone, '')), ''),
    p.status,
    r.code,
    case
      when r.code = 'district_admin' then nullif(ur.scope_id, '')::int
      else d.district_id
    end,
    case
      when r.code = 'district_admin' then dist.name
      else dist2.name
    end,
    case when r.code = 'division_admin' then d.id else null end,
    case when r.code = 'division_admin' then d.name else null end,
    p.suspended_by_name,
    p.suspended_by_role,
    p.must_change_password,
    p.created_at
  from public.user_roles ur
  join public.roles r on r.id = ur.role_id
  join public.profiles p on p.id = ur.user_id
  left join public.districts dist
    on r.code = 'district_admin'
   and dist.id = nullif(ur.scope_id, '')::int
  left join public.ds_divisions d
    on r.code = 'division_admin'
   and ur.scope_type = 'ds_division'
   and d.id = nullif(ur.scope_id, '')::int
  left join public.districts dist2 on dist2.id = d.district_id
  where r.code in ('district_admin', 'division_admin')
    and (v_role is null or r.code = v_role)
    and (
      v_district is null
      or (
        r.code = 'district_admin' and ur.scope_id = v_district::text
      )
      or (
        r.code = 'division_admin' and d.district_id = v_district
      )
    )
    and (v_ds is null or (r.code = 'division_admin' and d.id = v_ds))
  order by r.code, dist.name nulls last, dist2.name nulls last, d.name nulls last, p.full_name nulls last;
end;
$$;

grant execute on function public.list_managed_staff_admins(text, integer, integer)
  to authenticated;

create or replace function public.admin_update_staff_admin(
  p_user_id uuid,
  p_full_name text,
  p_phone text
)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text := trim(coalesce(p_full_name, ''));
  v_phone text := trim(coalesce(p_phone, ''));
  v_role text;
  v_scope_district int;
  row public.profiles;
begin
  if not (public.is_super_admin() or public.is_district_admin()) then
    raise exception 'Not allowed';
  end if;
  if v_name = '' or char_length(v_name) < 2 then
    raise exception 'Full name is required';
  end if;
  if char_length(v_phone) < 9 then
    raise exception 'Valid phone is required';
  end if;

  select r.code,
         case
           when r.code = 'district_admin' then nullif(ur.scope_id, '')::int
           else d.district_id
         end
  into v_role, v_scope_district
  from public.user_roles ur
  join public.roles r on r.id = ur.role_id
  left join public.ds_divisions d
    on r.code = 'division_admin'
   and ur.scope_type = 'ds_division'
   and d.id = nullif(ur.scope_id, '')::int
  where ur.user_id = p_user_id
    and r.code in ('district_admin', 'division_admin')
  limit 1;

  if v_role is null then
    raise exception 'Not a staff admin';
  end if;

  if v_role = 'district_admin' and not public.is_super_admin() then
    raise exception 'Only super admin can edit district admins';
  end if;

  if v_role = 'division_admin'
     and public.is_district_admin()
     and not public.is_super_admin() then
    if v_scope_district is null
       or not (v_scope_district = any (public.my_district_admin_district_ids())) then
      raise exception 'Out of scope';
    end if;
  end if;

  update public.profiles
  set
    full_name = v_name,
    phone = v_phone,
    updated_at = now()
  where id = p_user_id
  returning * into row;

  return row;
end;
$$;

grant execute on function public.admin_update_staff_admin(uuid, text, text)
  to authenticated;

-- District admins may suspend DN admins in scope; super may suspend either.
-- Reuse admin_set_member_status but allow district admin to target DN admins
-- even if profile.district_id is unset — extend access check for staff roles.
create or replace function public.admin_can_access_member(p_member_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_district int;
  v_ds int;
  v_staff_role text;
  v_staff_district int;
begin
  if p_member_id is null then
    return false;
  end if;

  if public.is_super_admin() then
    return true;
  end if;

  select p.district_id, p.ds_division_id
  into v_district, v_ds
  from public.profiles p
  where p.id = p_member_id;

  if not found then
    return false;
  end if;

  if public.is_district_admin() then
    if v_district is not null
       and v_district = any (public.my_district_admin_district_ids()) then
      return true;
    end if;
    -- Staff role scope fallback (DN admins).
    select r.code,
           case
             when r.code = 'division_admin' then d.district_id
             when r.code = 'district_admin' then nullif(ur.scope_id, '')::int
             else null
           end
    into v_staff_role, v_staff_district
    from public.user_roles ur
    join public.roles r on r.id = ur.role_id
    left join public.ds_divisions d
      on r.code = 'division_admin'
     and ur.scope_type = 'ds_division'
     and d.id = nullif(ur.scope_id, '')::int
    where ur.user_id = p_member_id
      and r.code in ('district_admin', 'division_admin')
    limit 1;

    if v_staff_role = 'division_admin'
       and v_staff_district is not null
       and v_staff_district = any (public.my_district_admin_district_ids()) then
      return true;
    end if;
  end if;

  if public.is_division_admin()
     and v_ds is not null
     and v_ds = any (public.my_division_admin_ds_ids()) then
    return true;
  end if;

  return false;
end;
$$;
