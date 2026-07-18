-- Free-text other qualification (e.g. NVQ / vocational), max 250 chars.

alter table public.profiles
  add column if not exists other_qualification text;

alter table public.profiles
  drop constraint if exists profiles_other_qualification_len;

alter table public.profiles
  add constraint profiles_other_qualification_len
  check (
    other_qualification is null
    or char_length(other_qualification) <= 250
  );

comment on column public.profiles.other_qualification is
  'Optional free-text qualification (e.g. NVQ / vocational), max 250 characters';

drop function if exists public.submit_member_registration(
  text, text, text, date, text, integer, integer, integer, uuid, uuid[], text,
  boolean, boolean, boolean
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
  p_speaks_english boolean default false,
  p_other_qualification text default null
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
  other_q text := nullif(trim(coalesce(p_other_qualification, '')), '');
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
  if other_q is not null and char_length(other_q) > 250 then
    raise exception 'Other qualification must be 250 characters or fewer';
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
    other_qualification = other_q,
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
      'speaks_english', coalesce(p_speaks_english, false),
      'other_qualification', other_q
    )
  );

  return row;
end;
$$;

revoke all on function public.submit_member_registration(
  text, text, text, date, text, integer, integer, integer, uuid, uuid[], text,
  boolean, boolean, boolean, text
) from public;

grant execute on function public.submit_member_registration(
  text, text, text, date, text, integer, integer, integer, uuid, uuid[], text,
  boolean, boolean, boolean, text
) to authenticated;
