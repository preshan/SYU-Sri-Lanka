-- Admin ↔ member direct chat: open/close, notify members on new messages

alter table public.conversations
  add column if not exists status text not null default 'open',
  add column if not exists closed_at timestamptz,
  add column if not exists closed_by uuid references auth.users (id) on delete set null;

alter table public.conversations drop constraint if exists conversations_status_check;
alter table public.conversations
  add constraint conversations_status_check
  check (status in ('open', 'closed'));

create index if not exists conversations_status_idx
  on public.conversations (status, updated_at desc);

-- Members/admins may only send while the conversation is open
drop policy if exists "messages_insert_member" on public.messages;
create policy "messages_insert_member" on public.messages
  for insert to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1
      from public.conversation_participants cp
      join public.conversations c on c.id = cp.conversation_id
      where cp.conversation_id = conversation_id
        and cp.user_id = auth.uid()
        and c.status = 'open'
    )
  );

-- Notify other participants when a message is sent (members get notified on admin msgs)
create or replace function public.is_super_admin_user(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_roles ur
    join public.roles r on r.id = ur.role_id
    where ur.user_id = p_user_id
      and r.code = 'super_admin'
  );
$$;

create or replace function public.notify_message_recipients()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  sender_name text;
begin
  select coalesce(nullif(trim(p.full_name), ''), 'SYU')
  into sender_name
  from public.profiles p
  where p.id = new.sender_id;

  insert into public.notifications (user_id, title, body, type, data)
  select
    cp.user_id,
    case
      when public.is_super_admin_user(new.sender_id) then 'Message from SYU Admin'
      else 'New message from ' || sender_name
    end,
    left(new.body, 240),
    'message',
    jsonb_build_object(
      'conversation_id', new.conversation_id,
      'message_id', new.id
    )
  from public.conversation_participants cp
  where cp.conversation_id = new.conversation_id
    and cp.user_id <> new.sender_id;

  update public.conversations
  set updated_at = now()
  where id = new.conversation_id;

  return new;
end;
$$;

drop trigger if exists messages_notify_recipients on public.messages;
create trigger messages_notify_recipients
after insert on public.messages
for each row
when (new.deleted_at is null)
execute function public.notify_message_recipients();

-- Start or reopen a direct chat with a member and send the first message
create or replace function public.admin_start_direct_chat(
  p_member_id uuid,
  p_body text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  admin_id uuid := auth.uid();
  member_name text;
  conv_id uuid;
  msg_id uuid;
  body_text text := trim(p_body);
begin
  if not public.is_super_admin() then
    raise exception 'Admin only';
  end if;
  if body_text is null or body_text = '' then
    raise exception 'Message required';
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

  -- Prefer an existing open direct thread between this admin and member
  select c.id into conv_id
  from public.conversations c
  where c.type = 'direct'
    and c.status = 'open'
    and exists (
      select 1 from public.conversation_participants a
      where a.conversation_id = c.id and a.user_id = admin_id
    )
    and exists (
      select 1 from public.conversation_participants m
      where m.conversation_id = c.id and m.user_id = p_member_id
    )
  order by c.updated_at desc
  limit 1;

  if conv_id is null then
    insert into public.conversations (type, title, created_by, status)
    values ('direct', member_name, admin_id, 'open')
    returning id into conv_id;

    insert into public.conversation_participants (conversation_id, user_id, role)
    values
      (conv_id, admin_id, 'admin'),
      (conv_id, p_member_id, 'member');
  else
    update public.conversations
    set title = coalesce(nullif(title, ''), member_name)
    where id = conv_id;
  end if;

  insert into public.messages (conversation_id, sender_id, body)
  values (conv_id, admin_id, body_text)
  returning id into msg_id;

  insert into public.activity_logs (actor_id, action, entity_type, entity_id, metadata)
  values (
    admin_id,
    'admin_start_chat',
    'conversation',
    conv_id,
    jsonb_build_object('member_id', p_member_id, 'message_id', msg_id)
  );

  return jsonb_build_object(
    'conversation_id', conv_id,
    'message_id', msg_id
  );
end;
$$;

-- Terminate chat: members (and everyone) can no longer reply
create or replace function public.admin_close_conversation(p_conversation_id uuid)
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
    status = 'closed',
    closed_at = now(),
    closed_by = auth.uid(),
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

  insert into public.activity_logs (actor_id, action, entity_type, entity_id, metadata)
  values (
    auth.uid(),
    'admin_close_chat',
    'conversation',
    p_conversation_id,
    '{}'::jsonb
  );

  -- Inform the member that the chat was closed
  insert into public.notifications (user_id, title, body, type, data)
  select
    cp.user_id,
    'Chat closed',
    'An admin ended this conversation. You can no longer reply.',
    'message',
    jsonb_build_object('conversation_id', p_conversation_id, 'closed', true)
  from public.conversation_participants cp
  where cp.conversation_id = p_conversation_id
    and cp.user_id <> auth.uid();

  return jsonb_build_object('conversation_id', p_conversation_id, 'status', 'closed');
end;
$$;

-- Admin inbox: direct chats the current admin participates in
create or replace function public.admin_list_direct_chats()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_super_admin() then
    raise exception 'Admin only';
  end if;

  return coalesce((
    select jsonb_agg(row_to_json(t)::jsonb order by t.updated_at desc)
    from (
      select
        c.id,
        c.title,
        c.status,
        c.updated_at,
        c.created_at,
        (
          select jsonb_build_object(
            'id', p.id,
            'full_name', p.full_name,
            'email', p.email
          )
          from public.conversation_participants cp2
          join public.profiles p on p.id = cp2.user_id
          where cp2.conversation_id = c.id
            and cp2.user_id <> auth.uid()
          limit 1
        ) as member,
        (
          select left(m.body, 120)
          from public.messages m
          where m.conversation_id = c.id
            and m.deleted_at is null
          order by m.created_at desc
          limit 1
        ) as last_message
      from public.conversations c
      join public.conversation_participants cp
        on cp.conversation_id = c.id and cp.user_id = auth.uid()
      where c.type = 'direct'
    ) t
  ), '[]'::jsonb);
end;
$$;

grant execute on function public.is_super_admin_user(uuid) to authenticated;
grant execute on function public.admin_start_direct_chat(uuid, text) to authenticated;
grant execute on function public.admin_close_conversation(uuid) to authenticated;
grant execute on function public.admin_list_direct_chats() to authenticated;
