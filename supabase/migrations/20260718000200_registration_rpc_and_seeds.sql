-- Sprint 2: registration constraints, safe submit RPC, seed clubs

-- Unique NIC when present (case-insensitive via upper)
create unique index if not exists profiles_nic_unique_idx
  on public.profiles (upper(nic))
  where nic is not null and length(trim(nic)) > 0;

-- Age eligibility helper (15–35 inclusive by default)
create or replace function public.syu_age_years(dob date)
returns integer
language sql
immutable
as $$
  select extract(year from age(current_date, dob))::integer;
$$;

create or replace function public.syu_is_eligible_age(dob date)
returns boolean
language sql
immutable
as $$
  select dob is not null
    and public.syu_age_years(dob) between 15 and 35;
$$;

-- Safe registration submit (atomic profile + qualifications)
create or replace function public.submit_member_registration(
  p_full_name text,
  p_phone text,
  p_nic text,
  p_date_of_birth date,
  p_gender text,
  p_district_id integer,
  p_ds_division_id integer,
  p_gn_division_id integer,
  p_youth_club_id uuid,
  p_qualification_ids uuid[]
)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  nic_norm text := upper(trim(p_nic));
  row public.profiles;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_full_name is null or length(trim(p_full_name)) < 2 then
    raise exception 'Full name is required';
  end if;
  if p_phone is null or length(trim(p_phone)) < 9 then
    raise exception 'Valid phone is required';
  end if;
  if nic_norm is null or nic_norm !~ '^[0-9]{9}[VvXx]$' and nic_norm !~ '^[0-9]{12}$' then
    raise exception 'Invalid NIC';
  end if;
  if not public.syu_is_eligible_age(p_date_of_birth) then
    raise exception 'Age must be between 15 and 35';
  end if;
  if p_district_id is null then
    raise exception 'District is required';
  end if;

  update public.profiles set
    full_name = trim(p_full_name),
    phone = trim(p_phone),
    nic = nic_norm,
    date_of_birth = p_date_of_birth,
    gender = p_gender,
    district_id = p_district_id,
    ds_division_id = p_ds_division_id,
    gn_division_id = p_gn_division_id,
    youth_club_id = p_youth_club_id,
    status = 'pending_approval',
    updated_at = now()
  where id = uid
  returning * into row;

  if row.id is null then
    raise exception 'Profile not found';
  end if;

  delete from public.member_qualifications where profile_id = uid;
  if p_qualification_ids is not null and array_length(p_qualification_ids, 1) is not null then
    insert into public.member_qualifications (profile_id, qualification_id)
    select uid, qid
    from unnest(p_qualification_ids) as qid;
  end if;

  insert into public.activity_logs (actor_id, action, entity_type, entity_id, metadata)
  values (
    uid,
    'registration_submitted',
    'profile',
    uid,
    jsonb_build_object('status', 'pending_approval')
  );

  return row;
end;
$$;

revoke all on function public.submit_member_registration(
  text, text, text, date, text, integer, integer, integer, uuid, uuid[]
) from public;
grant execute on function public.submit_member_registration(
  text, text, text, date, text, integer, integer, integer, uuid, uuid[]
) to authenticated;

-- Seed sample youth clubs (linked to first few districts when present)
insert into public.youth_clubs (code, name, district_id, is_active)
select v.code, v.name, d.id, true
from (values
  ('colombo-central', 'Colombo Central Youth Club'),
  ('kandy-east', 'Kandy East Youth Club'),
  ('galle-south', 'Galle South Youth Club'),
  ('jaffna-north', 'Jaffna North Youth Club'),
  ('national-unassigned', 'National (Unassigned Pool)')
) as v(code, name)
left join lateral (
  select id from public.districts
  where lower(name) like
    case
      when v.code like 'colombo%' then '%colombo%'
      when v.code like 'kandy%' then '%kandy%'
      when v.code like 'galle%' then '%galle%'
      when v.code like 'jaffna%' then '%jaffna%'
      else '%'
    end
  order by id
  limit 1
) d on true
on conflict (code) do update set
  name = excluded.name,
  is_active = true;

-- Ensure qualifications seed remains present
insert into public.qualifications (code, name_en, level_order) values
  ('ol', 'G.C.E. Ordinary Level', 10),
  ('al', 'G.C.E. Advanced Level', 20),
  ('diploma', 'Diploma', 30),
  ('bachelor', 'Bachelor Degree', 40),
  ('master', 'Master Degree', 50),
  ('other', 'Other', 99)
on conflict (code) do nothing;
