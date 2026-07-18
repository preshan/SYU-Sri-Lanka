-- TEMPORARY: client-side Gmail send (Flutter reads SMTP secrets).
-- Replace with server-only mail (Auth SMTP / Edge Function) before production hardening.

alter table public.profiles
  add column if not exists app_email_verified boolean not null default false;

-- Existing accounts are treated as already verified.
update public.profiles set app_email_verified = true where app_email_verified = false;

create table if not exists public.app_email_otps (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  purpose text not null check (purpose in ('signup', 'recovery')),
  code text not null,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists app_email_otps_email_purpose_idx
  on public.app_email_otps (lower(email), purpose, created_at desc);

alter table public.app_email_otps enable row level security;
revoke all on table public.app_email_otps from anon, authenticated;

-- TEMPORARY: expose SMTP password to the Flutter client.
create or replace function public.get_smtp_credentials()
returns table (
  smtp_host text,
  smtp_port int,
  smtp_user text,
  smtp_pass text,
  from_email text,
  from_name text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  select
    s.smtp_host,
    s.smtp_port,
    s.smtp_user,
    s.smtp_pass,
    s.from_email,
    s.from_name
  from public.app_mail_settings s
  where s.id = 1
    and length(trim(s.smtp_user)) > 0
    and length(trim(s.smtp_pass)) > 0;
end;
$$;

grant execute on function public.get_smtp_credentials() to anon, authenticated;

-- Issue a 6-digit OTP (max 5 / email / purpose / hour). Returns plaintext code for Flutter to email.
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
begin
  if v_email is null or v_email = '' then
    raise exception 'email required';
  end if;
  if v_purpose not in ('signup', 'recovery') then
    raise exception 'invalid purpose';
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

grant execute on function public.issue_app_email_otp(text, text) to anon, authenticated;

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
begin
  if length(v_code) <> 6 then
    raise exception 'invalid code';
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

grant execute on function public.verify_app_signup_otp(text, text) to anon, authenticated;

create or replace function public.verify_app_recovery_otp(
  p_email text,
  p_code text,
  p_new_password text
)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_email text := lower(trim(p_email));
  v_code text := trim(p_code);
  v_id uuid;
  v_uid uuid;
begin
  if length(v_code) <> 6 then
    raise exception 'invalid code';
  end if;
  if p_new_password is null or length(p_new_password) < 8 then
    raise exception 'password too short';
  end if;

  select o.id into v_id
  from public.app_email_otps o
  where lower(o.email) = v_email
    and o.purpose = 'recovery'
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

  select u.id into v_uid from auth.users u where lower(u.email) = v_email;
  if v_uid is null then
    raise exception 'invalid or expired code';
  end if;

  update auth.users
  set
    encrypted_password = crypt(p_new_password, gen_salt('bf')),
    email_confirmed_at = coalesce(email_confirmed_at, now()),
    updated_at = now()
  where id = v_uid;

  update public.profiles
  set app_email_verified = true, updated_at = now()
  where id = v_uid;

  return true;
end;
$$;

grant execute on function public.verify_app_recovery_otp(text, text, text) to anon, authenticated;

create or replace function public.is_app_email_verified()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select p.app_email_verified from public.profiles p where p.id = auth.uid()),
    false
  );
$$;

grant execute on function public.is_app_email_verified() to authenticated;

-- New signups start unverified for app OTP gate.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, status, app_email_verified)
  values (new.id, new.email, 'active', false)
  on conflict (id) do nothing;
  return new;
end;
$$;
