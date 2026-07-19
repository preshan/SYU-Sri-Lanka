-- Private admin notes on members (staff only; never exposed to the member).

create table if not exists public.member_admin_notes (
  member_id uuid primary key references public.profiles (id) on delete cascade,
  note text not null default '',
  updated_by uuid references auth.users (id) on delete set null,
  updated_at timestamptz not null default now(),
  constraint member_admin_notes_len check (char_length(note) <= 1024)
);

alter table public.member_admin_notes enable row level security;

revoke all on table public.member_admin_notes from anon, authenticated;

drop trigger if exists member_admin_notes_set_updated_at on public.member_admin_notes;
create trigger member_admin_notes_set_updated_at
  before update on public.member_admin_notes
  for each row
  execute function public.set_updated_at();

-- True when the signed-in staff admin may manage this member's profile (scope match).
create or replace function public.admin_can_access_member(p_member_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_district int;
  v_ds int;
begin
  if p_member_id is null then
    return false;
  end if;

  if public.is_super_admin() then
    return true;
  end if;

  select p.district_id, p.ds_division_id
  into v_district, v_ds
  from public.profiles p
  where p.id = p_member_id;

  if not found then
    return false;
  end if;

  if public.is_district_admin()
     and v_district is not null
     and v_district = any (public.my_district_admin_district_ids()) then
    return true;
  end if;

  if public.is_division_admin()
     and v_ds is not null
     and v_ds = any (public.my_division_admin_ds_ids()) then
    return true;
  end if;

  return false;
end;
$$;

grant execute on function public.admin_can_access_member(uuid) to authenticated;

create or replace function public.get_member_admin_note(p_member_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_staff_admin() then
    raise exception 'Not allowed';
  end if;
  if not public.admin_can_access_member(p_member_id) then
    raise exception 'Member out of scope';
  end if;

  return coalesce(
    (select n.note from public.member_admin_notes n where n.member_id = p_member_id),
    ''
  );
end;
$$;

grant execute on function public.get_member_admin_note(uuid) to authenticated;

create or replace function public.set_member_admin_note(
  p_member_id uuid,
  p_note text
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_note text := coalesce(p_note, '');
begin
  if not public.is_staff_admin() then
    raise exception 'Not allowed';
  end if;
  if not public.admin_can_access_member(p_member_id) then
    raise exception 'Member out of scope';
  end if;

  if char_length(v_note) > 1024 then
    raise exception 'Note must be 1024 characters or fewer';
  end if;

  if trim(v_note) = '' then
    delete from public.member_admin_notes where member_id = p_member_id;
    return '';
  end if;

  insert into public.member_admin_notes (member_id, note, updated_by)
  values (p_member_id, v_note, auth.uid())
  on conflict (member_id) do update
    set note = excluded.note,
        updated_by = excluded.updated_by,
        updated_at = now();

  return v_note;
end;
$$;

grant execute on function public.set_member_admin_note(uuid, text) to authenticated;

-- Which of the given members already have a note (for list icons).
create or replace function public.members_with_admin_notes(p_member_ids uuid[])
returns uuid[]
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_staff_admin() then
    return '{}';
  end if;

  return coalesce((
    select array_agg(n.member_id)
    from public.member_admin_notes n
    where n.member_id = any (coalesce(p_member_ids, '{}'::uuid[]))
      and public.admin_can_access_member(n.member_id)
      and char_length(trim(n.note)) > 0
  ), '{}');
end;
$$;

grant execute on function public.members_with_admin_notes(uuid[]) to authenticated;
