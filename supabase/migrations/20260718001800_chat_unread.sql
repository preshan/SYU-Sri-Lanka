-- Unread chat indicator: mark-as-read + has-unread helpers

drop policy if exists "participants_update_own" on public.conversation_participants;
create policy "participants_update_own" on public.conversation_participants
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create or replace function public.mark_conversation_read(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  update public.conversation_participants
  set last_read_at = now()
  where conversation_id = p_conversation_id
    and user_id = auth.uid();
end;
$$;

create or replace function public.has_unread_chats()
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return false;
  end if;

  return exists (
    select 1
    from public.conversation_participants cp
    join public.messages m
      on m.conversation_id = cp.conversation_id
     and m.deleted_at is null
     and m.sender_id <> auth.uid()
     and m.created_at > coalesce(cp.last_read_at, '-infinity'::timestamptz)
    where cp.user_id = auth.uid()
  );
end;
$$;

grant execute on function public.mark_conversation_read(uuid) to authenticated;
grant execute on function public.has_unread_chats() to authenticated;
