-- Language skills on profiles + admin filter support (GS = GN division)

alter table public.profiles
  add column if not exists speaks_sinhala boolean not null default false,
  add column if not exists speaks_tamil boolean not null default false,
  add column if not exists speaks_english boolean not null default false;

comment on column public.profiles.speaks_sinhala is 'Member language skill: Sinhala';
comment on column public.profiles.speaks_tamil is 'Member language skill: Tamil';
comment on column public.profiles.speaks_english is 'Member language skill: English';

create index if not exists profiles_language_skills_idx
  on public.profiles (speaks_sinhala, speaks_tamil, speaks_english)
  where speaks_sinhala or speaks_tamil or speaks_english;

create index if not exists profiles_district_ds_gn_created_idx
  on public.profiles (district_id, ds_division_id, gn_division_id, created_at desc);

-- Extend registration RPC with language skills
drop function if exists public.submit_member_registration(
  text, text, text, date, text, integer, integer, integer, uuid, uuid[], text
);

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
  p_qualification_ids uuid[],
  p_requested_youth_club_name text default null,
  p_speaks_sinhala boolean default false,
  p_speaks_tamil boolean default false,
  p_speaks_english boolean default false
)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  nic_norm text := upper(trim(p_nic));
  club_name text := nullif(trim(coalesce(p_requested_youth_club_name, '')), '');
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
    requested_youth_club_name = club_name,
    speaks_sinhala = coalesce(p_speaks_sinhala, false),
    speaks_tamil = coalesce(p_speaks_tamil, false),
    speaks_english = coalesce(p_speaks_english, false),
    status = 'active',
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
    jsonb_build_object(
      'status', 'active',
      'requested_youth_club_name', club_name,
      'speaks_sinhala', coalesce(p_speaks_sinhala, false),
      'speaks_tamil', coalesce(p_speaks_tamil, false),
      'speaks_english', coalesce(p_speaks_english, false)
    )
  );

  return row;
end;
$$;

revoke all on function public.submit_member_registration(
  text, text, text, date, text, integer, integer, integer, uuid, uuid[], text,
  boolean, boolean, boolean
) from public;

grant execute on function public.submit_member_registration(
  text, text, text, date, text, integer, integer, integer, uuid, uuid[], text,
  boolean, boolean, boolean
) to authenticated;
