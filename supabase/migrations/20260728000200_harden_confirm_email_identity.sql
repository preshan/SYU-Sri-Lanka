-- Harden email OTP / abandon flows so URL query params cannot target another account.
-- abandon_unverified_signup already deletes only auth.uid(); keep that invariant.
-- When signed in, signup OTP issue/verify must target the signed-in user's email only.

create or replace function public.issue_app_email_otp(
  p_email text,
  p_purpose text default 'signup'
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text := lower(trim(p_email));
  v_purpose text := lower(trim(p_purpose));
  v_code text;
  v_count int;
  v_uid uuid := auth.uid();
  v_session_email text;
begin
  if v_email is null or v_email = '' then
    raise exception 'email required';
  end if;
  if v_purpose not in ('signup', 'recovery') then
    raise exception 'invalid purpose';
  end if;

  -- Signed-in signup/resend cannot target a different address via client args.
  if v_purpose = 'signup' and v_uid is not null then
    select lower(u.email) into v_session_email
    from auth.users u
    where u.id = v_uid;
    if v_session_email is null or v_session_email <> v_email then
      raise exception 'email does not match signed-in user';
    end if;
  end if;

  select count(*)::int into v_count
  from public.app_email_otps o
  where lower(o.email) = v_email
    and o.purpose = v_purpose
    and o.created_at > now() - interval '1 hour';

  if v_count >= 5 then
    raise exception 'email rate limit exceeded';
  end if;

  if v_purpose = 'signup' then
    if not exists (
      select 1 from auth.users u where lower(u.email) = v_email
    ) then
      raise exception 'user not found';
    end if;
  elsif v_purpose = 'recovery' then
    if not exists (
      select 1 from auth.users u where lower(u.email) = v_email
    ) then
      -- Do not reveal whether the account exists; still consume a slot with a dummy no-op code path.
      -- Return a fake-looking code that will never verify (not stored).
      return lpad((floor(random() * 1000000))::int::text, 6, '0');
    end if;
  end if;

  v_code := lpad((floor(random() * 1000000))::int::text, 6, '0');

  insert into public.app_email_otps (email, purpose, code, expires_at)
  values (v_email, v_purpose, v_code, now() + interval '30 minutes');

  return v_code;
end;
$$;

create or replace function public.verify_app_signup_otp(
  p_email text,
  p_code text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text := lower(trim(p_email));
  v_code text := trim(p_code);
  v_id uuid;
  v_uid uuid;
  v_session uuid := auth.uid();
  v_session_email text;
begin
  if length(v_code) <> 6 then
    raise exception 'invalid code';
  end if;

  -- Signed-in verify cannot confirm a different address via URL/query args.
  if v_session is not null then
    select lower(u.email) into v_session_email
    from auth.users u
    where u.id = v_session;
    if v_session_email is null or v_session_email <> v_email then
      raise exception 'email does not match signed-in user';
    end if;
  end if;

  select o.id into v_id
  from public.app_email_otps o
  where lower(o.email) = v_email
    and o.purpose = 'signup'
    and o.code = v_code
    and o.consumed_at is null
    and o.expires_at > now()
  order by o.created_at desc
  limit 1;

  if v_id is null then
    raise exception 'invalid or expired code';
  end if;

  update public.app_email_otps
  set consumed_at = now()
  where id = v_id;

  update auth.users
  set email_confirmed_at = coalesce(email_confirmed_at, now())
  where lower(email) = v_email
  returning id into v_uid;

  if v_uid is not null then
    update public.profiles
    set app_email_verified = true, updated_at = now()
    where id = v_uid;
  end if;

  return true;
end;
$$;

-- Reaffirm: delete only the caller, never an email passed from the client.
create or replace function public.abandon_unverified_signup()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_email text;
  v_verified boolean;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select lower(u.email), coalesce(p.app_email_verified, false)
    into v_email, v_verified
  from auth.users u
  left join public.profiles p on p.id = u.id
  where u.id = v_uid;

  if v_email is null then
    raise exception 'user not found';
  end if;

  if v_verified then
    raise exception 'email already verified';
  end if;

  delete from public.app_email_otps
  where lower(email) = v_email
    and purpose = 'signup';

  delete from auth.users
  where id = v_uid;
end;
$$;

revoke all on function public.abandon_unverified_signup() from public;
grant execute on function public.abandon_unverified_signup() to authenticated;
