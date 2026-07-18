-- Fix return type mismatch: ds_divisions.name is varchar, function declared text.
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
    nullif(trim(coalesce(p.full_name, '')), '')::text as full_name,
    nullif(trim(coalesce(p.phone, '')), '')::text as phone,
    d.id as ds_division_id,
    d.name::text as ds_division_name
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
