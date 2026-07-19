-- Divisional organizers: contact cards per DS (managed by district admins).

create table if not exists public.divisional_organizers (
  id uuid primary key default gen_random_uuid(),
  district_id integer not null references public.districts (id) on delete cascade,
  ds_division_id integer not null references public.ds_divisions (id) on delete cascade,
  full_name text not null,
  mobile text not null,
  landline text,
  email text,
  updated_by uuid references auth.users (id) on delete set null,
  updated_at timestamptz not null default now(),
  constraint divisional_organizers_ds_unique unique (ds_division_id),
  constraint divisional_organizers_name_len check (char_length(trim(full_name)) between 2 and 120),
  constraint divisional_organizers_mobile_len check (char_length(trim(mobile)) between 7 and 20)
);

create index if not exists divisional_organizers_district_idx
  on public.divisional_organizers (district_id);

alter table public.divisional_organizers enable row level security;

revoke all on table public.divisional_organizers from anon, authenticated;
grant select on table public.divisional_organizers to authenticated;

drop policy if exists "divisional_organizers_select_staff" on public.divisional_organizers;
create policy "divisional_organizers_select_staff"
  on public.divisional_organizers
  for select
  to authenticated
  using (public.is_staff_admin());

drop trigger if exists divisional_organizers_set_updated_at on public.divisional_organizers;
create trigger divisional_organizers_set_updated_at
  before update on public.divisional_organizers
  for each row
  execute function public.set_updated_at();

create or replace function public.list_divisional_organizers(
  p_district_id int,
  p_ds_division_id int default null
)
returns table (
  id uuid,
  district_id int,
  ds_division_id int,
  ds_division_name text,
  full_name text,
  mobile text,
  landline text,
  email text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_staff_admin() then
    raise exception 'Not allowed';
  end if;

  if public.is_district_admin()
     and not public.is_super_admin()
     and not (p_district_id = any (public.my_district_admin_district_ids())) then
    raise exception 'District out of scope';
  end if;

  if public.is_division_admin()
     and not public.is_super_admin()
     and not public.is_district_admin() then
    raise exception 'Not allowed';
  end if;

  return query
  select
    o.id,
    o.district_id,
    o.ds_division_id,
    d.name::text as ds_division_name,
    o.full_name,
    o.mobile,
    o.landline,
    o.email
  from public.divisional_organizers o
  join public.ds_divisions d on d.id = o.ds_division_id
  where o.district_id = p_district_id
    and (p_ds_division_id is null or o.ds_division_id = p_ds_division_id)
  order by d.name, o.full_name;
end;
$$;

grant execute on function public.list_divisional_organizers(int, int) to authenticated;

create or replace function public.upsert_divisional_organizer(
  p_district_id int,
  p_ds_division_id int,
  p_full_name text,
  p_mobile text,
  p_landline text default null,
  p_email text default null,
  p_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_name text := trim(coalesce(p_full_name, ''));
  v_mobile text := trim(coalesce(p_mobile, ''));
  v_landline text := nullif(trim(coalesce(p_landline, '')), '');
  v_email text := nullif(trim(coalesce(p_email, '')), '');
  v_ds_district int;
begin
  if not (public.is_super_admin() or public.is_district_admin()) then
    raise exception 'Only district or super admins can manage organizers';
  end if;

  if public.is_district_admin()
     and not public.is_super_admin()
     and not (p_district_id = any (public.my_district_admin_district_ids())) then
    raise exception 'District out of scope';
  end if;

  select d.district_id into v_ds_district
  from public.ds_divisions d
  where d.id = p_ds_division_id;

  if v_ds_district is null then
    raise exception 'Unknown DS division';
  end if;
  if v_ds_district <> p_district_id then
    raise exception 'DS division does not belong to this district';
  end if;

  if char_length(v_name) < 2 then
    raise exception 'Name is required';
  end if;
  if char_length(v_mobile) < 7 then
    raise exception 'Mobile number is required';
  end if;

  if p_id is not null then
    update public.divisional_organizers o
    set
      district_id = p_district_id,
      ds_division_id = p_ds_division_id,
      full_name = v_name,
      mobile = v_mobile,
      landline = v_landline,
      email = v_email,
      updated_by = auth.uid(),
      updated_at = now()
    where o.id = p_id
    returning o.id into v_id;

    if v_id is null then
      raise exception 'Organizer not found';
    end if;
    return v_id;
  end if;

  insert into public.divisional_organizers (
    district_id, ds_division_id, full_name, mobile, landline, email, updated_by
  )
  values (
    p_district_id, p_ds_division_id, v_name, v_mobile, v_landline, v_email, auth.uid()
  )
  on conflict (ds_division_id) do update
    set full_name = excluded.full_name,
        mobile = excluded.mobile,
        landline = excluded.landline,
        email = excluded.email,
        district_id = excluded.district_id,
        updated_by = excluded.updated_by,
        updated_at = now()
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function public.upsert_divisional_organizer(
  int, int, text, text, text, text, uuid
) to authenticated;

create or replace function public.delete_divisional_organizer(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_district int;
begin
  if not (public.is_super_admin() or public.is_district_admin()) then
    raise exception 'Only district or super admins can manage organizers';
  end if;

  select district_id into v_district
  from public.divisional_organizers
  where id = p_id;

  if v_district is null then
    return;
  end if;

  if public.is_district_admin()
     and not public.is_super_admin()
     and not (v_district = any (public.my_district_admin_district_ids())) then
    raise exception 'District out of scope';
  end if;

  delete from public.divisional_organizers where id = p_id;
end;
$$;

grant execute on function public.delete_divisional_organizer(uuid) to authenticated;

-- Seed Kilinochchi (district 1) organizers.
insert into public.divisional_organizers (
  district_id, ds_division_id, full_name, mobile
)
values
  (1, 4, 'Antony Miuton', '0767860722'),
  (1, 3, 'Sujeewan', '+94768124195'),
  (1, 1, 'Arunasalam Partheeban', '+94778623543'),
  (1, 2, 'Sajeeban', '+94772810003')
on conflict (ds_division_id) do update
  set full_name = excluded.full_name,
      mobile = excluded.mobile,
      district_id = excluded.district_id,
      updated_at = now();
