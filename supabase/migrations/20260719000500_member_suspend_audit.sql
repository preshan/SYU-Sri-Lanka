-- Track who suspended a member; staff admins set status via RPC (scope-checked).

alter table public.profiles
  add column if not exists suspended_by uuid references public.profiles (id) on delete set null;

alter table public.profiles
  add column if not exists suspended_by_name text;

alter table public.profiles
  add column if not exists suspended_by_role text;

alter table public.profiles
  add column if not exists suspended_at timestamptz;

create or replace function public.staff_admin_role_label()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case
    when public.is_super_admin() then 'Super admin'
    when public.is_district_admin() then 'District admin'
    when public.is_division_admin() then 'Division admin'
    else 'Admin'
  end;
$$;

grant execute on function public.staff_admin_role_label() to authenticated;

create or replace function public.admin_set_member_status(
  p_member_id uuid,
  p_status text
)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text := lower(trim(coalesce(p_status, '')));
  v_actor uuid := auth.uid();
  v_name text;
  v_role text;
  row public.profiles;
begin
  if v_actor is null then
    raise exception 'Not authenticated';
  end if;
  if not public.is_staff_admin() then
    raise exception 'Not allowed';
  end if;
  if not public.admin_can_access_member(p_member_id) then
    raise exception 'Member out of scope';
  end if;
  if v_status not in ('active', 'suspended', 'pending_registration') then
    raise exception 'Invalid status';
  end if;

  select coalesce(nullif(trim(p.full_name), ''), nullif(trim(p.email), ''), 'Admin')
  into v_name
  from public.profiles p
  where p.id = v_actor;

  v_role := public.staff_admin_role_label();

  if v_status = 'suspended' then
    update public.profiles
    set
      status = 'suspended',
      suspended_by = v_actor,
      suspended_by_name = v_name,
      suspended_by_role = v_role,
      suspended_at = now(),
      updated_at = now()
    where id = p_member_id
    returning * into row;
  else
    update public.profiles
    set
      status = v_status,
      suspended_by = null,
      suspended_by_name = null,
      suspended_by_role = null,
      suspended_at = null,
      updated_at = now()
    where id = p_member_id
    returning * into row;
  end if;

  if row.id is null then
    raise exception 'Member not found';
  end if;

  insert into public.activity_logs (actor_id, action, entity_type, entity_id, metadata)
  values (
    v_actor,
    'member_status_changed',
    'profile',
    p_member_id,
    jsonb_build_object(
      'status', v_status,
      'suspended_by_name', case when v_status = 'suspended' then v_name else null end,
      'suspended_by_role', case when v_status = 'suspended' then v_role else null end
    )
  );

  return row;
end;
$$;

grant execute on function public.admin_set_member_status(uuid, text) to authenticated;
