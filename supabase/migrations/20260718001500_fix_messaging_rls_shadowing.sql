-- Fix RLS column shadowing in messaging policies.
-- Unqualified `id` / `conversation_id` inside EXISTS subqueries resolved to
-- conversation_participants columns, so:
--   conversations_select: cp.conversation_id = cp.id  (always false)
--   messages_*:            cp.conversation_id = cp.conversation_id (always true)
-- That blocked JOINs to conversations under RLS, so follow-up message inserts failed
-- with a generic client error after admin_start_direct_chat (security definer) worked.

create or replace function public.is_conversation_participant(p_conversation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.conversation_participants
    where conversation_id = p_conversation_id
      and user_id = auth.uid()
  );
$$;

create or replace function public.can_send_in_conversation(p_conversation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.conversation_participants cp
    join public.conversations c on c.id = cp.conversation_id
    where cp.conversation_id = p_conversation_id
      and cp.user_id = auth.uid()
      and c.status = 'open'
  );
$$;

grant execute on function public.is_conversation_participant(uuid) to authenticated;
grant execute on function public.can_send_in_conversation(uuid) to authenticated;

drop policy if exists "conversations_select_member" on public.conversations;
create policy "conversations_select_member" on public.conversations
  for select to authenticated
  using (public.is_conversation_participant(id));

drop policy if exists "messages_select_member" on public.messages;
create policy "messages_select_member" on public.messages
  for select to authenticated
  using (
    deleted_at is null
    and public.is_conversation_participant(conversation_id)
  );

drop policy if exists "messages_insert_member" on public.messages;
create policy "messages_insert_member" on public.messages
  for insert to authenticated
  with check (
    sender_id = auth.uid()
    and public.can_send_in_conversation(conversation_id)
  );
