-- Community links: org Facebook page (app_config) + per-DN WhatsApp group.

insert into public.app_config (key, value, description)
values (
  'facebook_page_url',
  '',
  'Official SYU Facebook page URL (Home → Follow FB Page)'
)
on conflict (key) do nothing;

-- One WhatsApp group URL per DS division (managed by that division's DN admin).
create table if not exists public.ds_whatsapp_groups (
  ds_division_id integer primary key references public.ds_divisions (id) on delete cascade,
  url text not null,
  updated_by uuid references auth.users (id) on delete set null,
  updated_at timestamptz not null default now(),
  constraint ds_whatsapp_groups_url_len check (char_length(trim(url)) between 8 and 500)
);

alter table public.ds_whatsapp_groups enable row level security;

revoke all on table public.ds_whatsapp_groups from anon, authenticated;
grant select on table public.ds_whatsapp_groups to authenticated;

drop policy if exists "ds_whatsapp_select_scoped" on public.ds_whatsapp_groups;
create policy "ds_whatsapp_select_scoped"
  on public.ds_whatsapp_groups
  for select
  to authenticated
  using (
    public.is_staff_admin()
    or ds_division_id = (
      select p.ds_division_id
      from public.profiles p
      where p.id = auth.uid()
    )
  );

drop trigger if exists ds_whatsapp_groups_set_updated_at on public.ds_whatsapp_groups;
create trigger ds_whatsapp_groups_set_updated_at
  before update on public.ds_whatsapp_groups
  for each row
  execute function public.set_updated_at();

-- Member home: WhatsApp URL for the signed-in user's DS division.
create or replace function public.member_division_whatsapp_url()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select g.url
  from public.profiles p
  join public.ds_whatsapp_groups g on g.ds_division_id = p.ds_division_id
  where p.id = auth.uid()
  limit 1;
$$;

grant execute on function public.member_division_whatsapp_url() to authenticated;

-- DN admin: current WhatsApp URL for their scoped DS (first scope if several).
create or replace function public.my_division_whatsapp_url()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select g.url
  from public.ds_whatsapp_groups g
  where g.ds_division_id = (
    select (public.my_division_admin_ds_ids())[1]
  )
  limit 1;
$$;

grant execute on function public.my_division_whatsapp_url() to authenticated;

-- DN admin: set or clear WhatsApp group URL for their DS.
create or replace function public.set_my_division_whatsapp_url(p_url text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ds int;
  v_url text := nullif(trim(coalesce(p_url, '')), '');
begin
  if not public.is_division_admin() then
    raise exception 'Only division admins can set the WhatsApp group link';
  end if;

  v_ds := (public.my_division_admin_ds_ids())[1];
  if v_ds is null then
    raise exception 'No DS division scope for this admin';
  end if;

  if v_url is null then
    delete from public.ds_whatsapp_groups where ds_division_id = v_ds;
    return null;
  end if;

  if char_length(v_url) < 8 or char_length(v_url) > 500 then
    raise exception 'WhatsApp link must be between 8 and 500 characters';
  end if;

  if v_url !~* '^https?://' then
    raise exception 'WhatsApp link must start with http:// or https://';
  end if;

  insert into public.ds_whatsapp_groups (ds_division_id, url, updated_by)
  values (v_ds, v_url, auth.uid())
  on conflict (ds_division_id) do update
    set url = excluded.url,
        updated_by = excluded.updated_by,
        updated_at = now();

  return v_url;
end;
$$;

grant execute on function public.set_my_division_whatsapp_url(text) to authenticated;
