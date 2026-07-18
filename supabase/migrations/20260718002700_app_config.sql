-- Public app config (key/value). Change values in DB later without an app release.
-- Example: update public.app_config set value = 'https://example.com/' where key = 'website_url';

create table if not exists public.app_config (
  key text primary key,
  value text not null,
  description text,
  updated_at timestamptz not null default now()
);

insert into public.app_config (key, value, description)
values (
  'website_url',
  'https://syusrilanka.com/',
  'Official SYU website (Settings → SYU website)'
)
on conflict (key) do nothing;

alter table public.app_config enable row level security;

revoke all on table public.app_config from anon, authenticated;
grant select on table public.app_config to anon, authenticated;

drop policy if exists "app_config_read_all" on public.app_config;
create policy "app_config_read_all"
  on public.app_config
  for select
  to anon, authenticated
  using (true);

drop policy if exists "app_config_admin_write" on public.app_config;
create policy "app_config_admin_write"
  on public.app_config
  for all
  to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

drop trigger if exists app_config_set_updated_at on public.app_config;
create trigger app_config_set_updated_at
  before update on public.app_config
  for each row
  execute function public.set_updated_at();
