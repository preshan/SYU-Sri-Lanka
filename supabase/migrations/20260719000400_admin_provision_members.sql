-- Admin-provisioned members: temp password + forced change + email editable until changed.

alter table public.profiles
  add column if not exists must_change_password boolean not null default false;

alter table public.profiles
  add column if not exists admin_provisioned boolean not null default false;

create or replace function public.must_change_password()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select p.must_change_password from public.profiles p where p.id = auth.uid()),
    false
  );
$$;

grant execute on function public.must_change_password() to authenticated;

-- Fill / activate a newly created auth user (service role or staff via edge).
create or replace function public.admin_finalize_provisioned_member(
  p_user_id uuid,
  p_full_name text,
  p_phone text,
  p_email text,
  p_nic text default null,
  p_date_of_birth date default null,
  p_gender text default null,
  p_district_id integer default null,
  p_ds_division_id integer default null,
  p_gn_division_id integer default null,
  p_qualification_ids uuid[] default null,
  p_requested_youth_club_name text default null,
  p_speaks_sinhala boolean default false,
  p_speaks_tamil boolean default false,
  p_speaks_english boolean default false,
  p_other_qualification text default null,
  p_occupation text default null,
  p_youth_club_registration_no text default null
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
  nic_norm text := nullif(upper(trim(coalesce(p_nic, ''))), '');
  club_name text := nullif(trim(coalesce(p_requested_youth_club_name, '')), '');
  other_q text := nullif(trim(coalesce(p_other_qualification, '')), '');
  job text := nullif(trim(coalesce(p_occupation, '')), '');
  club_reg text := nullif(trim(coalesce(p_youth_club_registration_no, '')), '');
  row public.profiles;
  v_district int := p_district_id;
  v_ds int := p_ds_division_id;
begin
  if not (public.is_super_admin() or public.is_district_admin() or public.is_division_admin()) then
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

  -- Scope locks for district / division admins.
  if public.is_division_admin()
     and not public.is_super_admin()
     and not public.is_district_admin() then
    v_ds := (public.my_division_admin_ds_ids())[1];
    if v_ds is null then
      raise exception 'No DS scope';
    end if;
    if p_ds_division_id is not null and p_ds_division_id <> v_ds then
      raise exception 'DS out of scope';
    end if;
    select d.district_id into v_district
    from public.ds_divisions d where d.id = v_ds;
  elsif public.is_district_admin() and not public.is_super_admin() then
    if v_district is null then
      v_district := (public.my_district_admin_district_ids())[1];
    end if;
    if v_district is null
       or not (v_district = any (public.my_district_admin_district_ids())) then
      raise exception 'District out of scope';
    end if;
  end if;

  if nic_norm is not null
     and nic_norm !~ '^[0-9]{9}[VvXx]$'
     and nic_norm !~ '^[0-9]{12}$' then
    raise exception 'Invalid NIC';
  end if;
  if p_date_of_birth is not null and not public.syu_is_eligible_age(p_date_of_birth) then
    raise exception 'Age must be between 15 and 35';
  end if;
  if other_q is not null and char_length(other_q) > 250 then
    raise exception 'Other qualification must be 250 characters or fewer';
  end if;

  update public.profiles
  set
    email = v_email,
    full_name = v_name,
    phone = v_phone,
    nic = nic_norm,
    date_of_birth = p_date_of_birth,
    gender = p_gender,
    district_id = v_district,
    ds_division_id = v_ds,
    gn_division_id = p_gn_division_id,
    requested_youth_club_name = club_name,
    youth_club_registration_no = club_reg,
    speaks_sinhala = coalesce(p_speaks_sinhala, false),
    speaks_tamil = coalesce(p_speaks_tamil, false),
    speaks_english = coalesce(p_speaks_english, false),
    other_qualification = other_q,
    occupation = job,
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

  delete from public.member_qualifications where profile_id = p_user_id;
  if p_qualification_ids is not null and cardinality(p_qualification_ids) > 0 then
    insert into public.member_qualifications (profile_id, qualification_id)
    select p_user_id, q
    from unnest(p_qualification_ids) as q;
  end if;

  insert into public.activity_logs (actor_id, action, entity_type, entity_id, metadata)
  values (
    auth.uid(),
    'admin_provisioned_member',
    'profile',
    p_user_id,
    jsonb_build_object('email', v_email, 'full_name', v_name)
  );

  return row;
end;
$$;

grant execute on function public.admin_finalize_provisioned_member(
  uuid, text, text, text, text, date, text, integer, integer, integer,
  uuid[], text, boolean, boolean, boolean, text, text, text
) to authenticated;

create or replace function public.complete_forced_password_change(p_new_password text)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_new_password is null or length(p_new_password) < 8 then
    raise exception 'Password must be at least 8 characters';
  end if;
  if not coalesce(
    (select must_change_password from public.profiles where id = uid),
    false
  ) then
    raise exception 'Password change not required';
  end if;

  update auth.users
  set
    encrypted_password = crypt(p_new_password, gen_salt('bf')),
    updated_at = now()
  where id = uid;

  update public.profiles
  set must_change_password = false, updated_at = now()
  where id = uid;

  return true;
end;
$$;

grant execute on function public.complete_forced_password_change(text) to authenticated;

-- Admin may change email only while member has not set their own password yet.
create or replace function public.admin_update_provisioned_email(
  p_member_id uuid,
  p_new_email text
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text := lower(trim(coalesce(p_new_email, '')));
  v_must boolean;
begin
  if not (public.is_super_admin() or public.is_district_admin() or public.is_division_admin()) then
    raise exception 'Not allowed';
  end if;
  if not public.admin_can_access_member(p_member_id) then
    raise exception 'Member out of scope';
  end if;

  select must_change_password into v_must
  from public.profiles
  where id = p_member_id;

  if v_must is distinct from true then
    raise exception 'Email can only be changed before the member sets their password';
  end if;

  if v_email = '' or position('@' in v_email) = 0 then
    raise exception 'Valid email is required';
  end if;

  if exists (
    select 1 from public.profiles p
    where lower(p.email) = v_email and p.id <> p_member_id
  ) then
    raise exception 'Email already in use';
  end if;

  update auth.users
  set
    email = v_email,
    email_confirmed_at = coalesce(email_confirmed_at, now()),
    updated_at = now()
  where id = p_member_id;

  update public.profiles
  set email = v_email, updated_at = now()
  where id = p_member_id;

  return v_email;
end;
$$;

grant execute on function public.admin_update_provisioned_email(uuid, text)
  to authenticated;

create or replace function public.member_must_change_password(p_member_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select p.must_change_password
      from public.profiles p
      where p.id = p_member_id
        and public.admin_can_access_member(p_member_id)
    ),
    false
  );
$$;

grant execute on function public.member_must_change_password(uuid) to authenticated;
