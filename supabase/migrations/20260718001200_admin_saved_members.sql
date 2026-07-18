-- Per-admin saved members for quick access

create table if not exists public.admin_saved_members (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid not null references auth.users (id) on delete cascade,
  member_id uuid not null references public.profiles (id) on delete cascade,
  note text,
  created_at timestamptz not null default now(),
  unique (admin_id, member_id)
);

create index if not exists admin_saved_members_admin_idx
  on public.admin_saved_members (admin_id, created_at desc);

alter table public.admin_saved_members enable row level security;

drop policy if exists "admin_saved_select_own" on public.admin_saved_members;
create policy "admin_saved_select_own" on public.admin_saved_members
  for select to authenticated
  using (admin_id = auth.uid() and public.is_super_admin());

drop policy if exists "admin_saved_insert_own" on public.admin_saved_members;
create policy "admin_saved_insert_own" on public.admin_saved_members
  for insert to authenticated
  with check (admin_id = auth.uid() and public.is_super_admin());

drop policy if exists "admin_saved_update_own" on public.admin_saved_members;
create policy "admin_saved_update_own" on public.admin_saved_members
  for update to authenticated
  using (admin_id = auth.uid() and public.is_super_admin())
  with check (admin_id = auth.uid() and public.is_super_admin());

drop policy if exists "admin_saved_delete_own" on public.admin_saved_members;
create policy "admin_saved_delete_own" on public.admin_saved_members
  for delete to authenticated
  using (admin_id = auth.uid() and public.is_super_admin());

create or replace function public.admin_save_member(
  p_member_id uuid,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  rid uuid;
begin
  if not public.is_super_admin() then
    raise exception 'Admin only';
  end if;
  if p_member_id = auth.uid() then
    raise exception 'Cannot save yourself';
  end if;
  if not exists (select 1 from public.profiles where id = p_member_id) then
    raise exception 'Member not found';
  end if;

  insert into public.admin_saved_members (admin_id, member_id, note)
  values (auth.uid(), p_member_id, nullif(trim(coalesce(p_note, '')), ''))
  on conflict (admin_id, member_id) do update
    set note = coalesce(excluded.note, public.admin_saved_members.note)
  returning id into rid;

  return jsonb_build_object('id', rid, 'member_id', p_member_id, 'saved', true);
end;
$$;

create or replace function public.admin_unsave_member(p_member_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_super_admin() then
    raise exception 'Admin only';
  end if;

  delete from public.admin_saved_members
  where admin_id = auth.uid()
    and member_id = p_member_id;

  return jsonb_build_object('member_id', p_member_id, 'saved', false);
end;
$$;

grant execute on function public.admin_save_member(uuid, text) to authenticated;
grant execute on function public.admin_unsave_member(uuid) to authenticated;
