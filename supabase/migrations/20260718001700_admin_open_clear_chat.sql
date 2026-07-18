-- Open existing admin↔member thread (with history) or create an empty open one.
-- Clear chat: soft-delete all messages and close so the member cannot send.

create or replace function public.admin_open_direct_chat(p_member_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  admin_id uuid := auth.uid();
  member_name text;
  conv_id uuid;
  conv_status text;
begin
  if not public.is_super_admin() then
    raise exception 'Admin only';
  end if;
  if p_member_id = admin_id then
    raise exception 'Cannot message yourself';
  end if;

  select coalesce(nullif(trim(full_name), ''), email, 'Member')
  into member_name
  from public.profiles
  where id = p_member_id and status = 'active';

  if member_name is null then
    raise exception 'Active member not found';
  end if;

  -- Prefer an open thread; otherwise the most recent direct thread (for history).
  select c.id, c.status into conv_id, conv_status
  from public.conversations c
  where c.type = 'direct'
    and exists (
      select 1 from public.conversation_participants a
      where a.conversation_id = c.id and a.user_id = admin_id
    )
    and exists (
      select 1 from public.conversation_participants m
      where m.conversation_id = c.id and m.user_id = p_member_id
    )
  order by
    case when c.status = 'open' then 0 else 1 end,
    c.updated_at desc
  limit 1;

  if conv_id is null then
    insert into public.conversations (type, title, created_by, status)
    values ('direct', member_name, admin_id, 'open')
    returning id, status into conv_id, conv_status;

    insert into public.conversation_participants (conversation_id, user_id, role)
    values
      (conv_id, admin_id, 'admin'),
      (conv_id, p_member_id, 'member');
  else
    update public.conversations
    set title = coalesce(nullif(title, ''), member_name)
    where id = conv_id;
  end if;

  return jsonb_build_object(
    'conversation_id', conv_id,
    'status', conv_status,
    'member_name', member_name
  );
end;
$$;

create or replace function public.admin_clear_conversation(p_conversation_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  cleared int := 0;
begin
  if not public.is_super_admin() then
    raise exception 'Admin only';
  end if;

  if not exists (
    select 1 from public.conversation_participants cp
    where cp.conversation_id = p_conversation_id
      and cp.user_id = auth.uid()
  ) then
    raise exception 'Conversation not found';
  end if;

  update public.messages
  set deleted_at = now()
  where conversation_id = p_conversation_id
    and deleted_at is null;
  get diagnostics cleared = row_count;

  update public.conversations
  set
    status = 'closed',
    closed_at = now(),
    closed_by = auth.uid(),
    updated_at = now()
  where id = p_conversation_id;

  insert into public.activity_logs (actor_id, action, entity_type, entity_id, metadata)
  values (
    auth.uid(),
    'admin_clear_chat',
    'conversation',
    p_conversation_id,
    jsonb_build_object('cleared_messages', cleared)
  );

  insert into public.notifications (user_id, title, body, type, data)
  select
    cp.user_id,
    'Chat cleared',
    'An admin cleared this conversation. You can no longer reply.',
    'message',
    jsonb_build_object('conversation_id', p_conversation_id, 'cleared', true)
  from public.conversation_participants cp
  where cp.conversation_id = p_conversation_id
    and cp.user_id <> auth.uid();

  return jsonb_build_object(
    'conversation_id', p_conversation_id,
    'status', 'closed',
    'cleared_messages', cleared
  );
end;
$$;

-- Allow admin to reopen a closed thread to continue messaging.
create or replace function public.admin_reopen_conversation(p_conversation_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_super_admin() then
    raise exception 'Admin only';
  end if;

  update public.conversations
  set
    status = 'open',
    closed_at = null,
    closed_by = null,
    updated_at = now()
  where id = p_conversation_id
    and exists (
      select 1 from public.conversation_participants cp
      where cp.conversation_id = p_conversation_id
        and cp.user_id = auth.uid()
    );

  if not found then
    raise exception 'Conversation not found';
  end if;

  return jsonb_build_object('conversation_id', p_conversation_id, 'status', 'open');
end;
$$;

grant execute on function public.admin_open_direct_chat(uuid) to authenticated;
grant execute on function public.admin_clear_conversation(uuid) to authenticated;
grant execute on function public.admin_reopen_conversation(uuid) to authenticated;
