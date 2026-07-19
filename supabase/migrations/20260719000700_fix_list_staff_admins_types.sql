-- Fix list_managed_staff_admins: explicit casts so RETURN QUERY matches OUT types.

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
    p.id::uuid,
    nullif(trim(coalesce(p.full_name, '')), '')::text,
    nullif(trim(coalesce(p.email, '')), '')::text,
    nullif(trim(coalesce(p.phone, '')), '')::text,
    p.status::text,
    r.code::text,
    (
      case
        when r.code = 'district_admin' then nullif(ur.scope_id, '')::int
        else d.district_id
      end
    )::integer,
    (
      case
        when r.code = 'district_admin' then dist.name
        else dist2.name
      end
    )::text,
    (case when r.code = 'division_admin' then d.id else null end)::integer,
    (case when r.code = 'division_admin' then d.name else null end)::text,
    p.suspended_by_name::text,
    p.suspended_by_role::text,
    coalesce(p.must_change_password, false)::boolean,
    p.created_at::timestamptz
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
  order by
    r.code,
    dist.name nulls last,
    dist2.name nulls last,
    d.name nulls last,
    p.full_name nulls last;
end;
$$;
