-- Singleton SMTP settings for Auth mail (synced to Supabase Auth via Edge Function).
-- smtp_pass is never returned to clients; use get_mail_settings / upsert_mail_settings.

create table if not exists public.app_mail_settings (
  id int primary key default 1 check (id = 1),
  smtp_host text not null default 'smtp.gmail.com',
  smtp_port int not null default 465 check (smtp_port > 0),
  smtp_user text not null default '',
  smtp_pass text not null default '',
  from_email text not null default '',
  from_name text not null default 'SYU Sri Lanka',
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id) on delete set null
);

insert into public.app_mail_settings (id)
values (1)
on conflict (id) do nothing;

alter table public.app_mail_settings enable row level security;

revoke all on table public.app_mail_settings from anon, authenticated;
-- Service role bypasses RLS; no client policies on the base table.

create or replace function public.get_mail_settings()
returns table (
  smtp_host text,
  smtp_port int,
  smtp_user text,
  from_email text,
  from_name text,
  password_set boolean,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_super_admin() then
    raise exception 'not authorized';
  end if;

  return query
  select
    s.smtp_host,
    s.smtp_port,
    s.smtp_user,
    s.from_email,
    s.from_name,
    (length(trim(s.smtp_pass)) > 0) as password_set,
    s.updated_at
  from public.app_mail_settings s
  where s.id = 1;
end;
$$;

create or replace function public.upsert_mail_settings(
  p_smtp_user text,
  p_smtp_pass text default null,
  p_from_email text default null,
  p_from_name text default null,
  p_smtp_host text default null,
  p_smtp_port int default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user text := trim(coalesce(p_smtp_user, ''));
  v_from text;
begin
  if not public.is_super_admin() then
    raise exception 'not authorized';
  end if;

  if v_user = '' then
    raise exception 'smtp_user is required';
  end if;

  v_from := trim(coalesce(nullif(trim(coalesce(p_from_email, '')), ''), v_user));

  insert into public.app_mail_settings as s (
    id,
    smtp_host,
    smtp_port,
    smtp_user,
    smtp_pass,
    from_email,
    from_name,
    updated_at,
    updated_by
  )
  values (
    1,
    coalesce(nullif(trim(coalesce(p_smtp_host, '')), ''), 'smtp.gmail.com'),
    coalesce(p_smtp_port, 465),
    v_user,
    coalesce(p_smtp_pass, ''),
    v_from,
    coalesce(nullif(trim(coalesce(p_from_name, '')), ''), 'SYU Sri Lanka'),
    now(),
    auth.uid()
  )
  on conflict (id) do update set
    smtp_host = excluded.smtp_host,
    smtp_port = excluded.smtp_port,
    smtp_user = excluded.smtp_user,
    smtp_pass = case
      when p_smtp_pass is null or trim(p_smtp_pass) = '' then s.smtp_pass
      else p_smtp_pass
    end,
    from_email = excluded.from_email,
    from_name = excluded.from_name,
    updated_at = now(),
    updated_by = auth.uid();
end;
$$;

-- Service-role helper for Edge Function (no client JWT).
create or replace function public.get_mail_settings_internal()
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
  where s.id = 1;
end;
$$;

grant execute on function public.get_mail_settings() to authenticated;
grant execute on function public.upsert_mail_settings(text, text, text, text, text, int) to authenticated;
-- Internal: callable with service role only (revoke from authenticated).
revoke all on function public.get_mail_settings_internal() from public, anon, authenticated;
grant execute on function public.get_mail_settings_internal() to service_role;
