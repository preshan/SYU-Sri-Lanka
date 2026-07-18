-- Chat UX: peer profile for headers + allow reading peer last_read_at for seen receipts

drop policy if exists "participants_select_same_conversation"
  on public.conversation_participants;
create policy "participants_select_same_conversation"
  on public.conversation_participants
  for select to authenticated
  using (
    exists (
      select 1
      from public.conversation_participants me
      where me.conversation_id = conversation_participants.conversation_id
        and me.user_id = auth.uid()
    )
  );

create or replace function public.member_list_conversations()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  return coalesce((
    select jsonb_agg(row_to_json(t)::jsonb order by t.updated_at desc)
    from (
      select
        c.id,
        c.title,
        c.type,
        c.status,
        c.updated_at,
        c.created_at,
        (
          select left(m.body, 120)
          from public.messages m
          where m.conversation_id = c.id
            and m.deleted_at is null
          order by m.created_at desc
          limit 1
        ) as last_message,
        (
          select jsonb_build_object(
            'id', p.id,
            'email', p.email,
            'full_name', p.full_name,
            'district', d.name
          )
          from public.conversation_participants cp2
          join public.profiles p on p.id = cp2.user_id
          left join public.districts d on d.id = p.district_id
          where cp2.conversation_id = c.id
            and cp2.user_id <> auth.uid()
          limit 1
        ) as peer,
        (
          select cp2.last_read_at
          from public.conversation_participants cp2
          where cp2.conversation_id = c.id
            and cp2.user_id <> auth.uid()
          limit 1
        ) as peer_last_read_at
      from public.conversations c
      join public.conversation_participants cp
        on cp.conversation_id = c.id
       and cp.user_id = auth.uid()
    ) t
  ), '[]'::jsonb);
end;
$$;

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
            'email', p.email,
            'district', d.name
          )
          from public.conversation_participants cp2
          join public.profiles p on p.id = cp2.user_id
          left join public.districts d on d.id = p.district_id
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
        ) as last_message,
        (
          select cp2.last_read_at
          from public.conversation_participants cp2
          where cp2.conversation_id = c.id
            and cp2.user_id <> auth.uid()
          limit 1
        ) as peer_last_read_at
      from public.conversations c
      join public.conversation_participants cp
        on cp.conversation_id = c.id and cp.user_id = auth.uid()
      where c.type = 'direct'
    ) t
  ), '[]'::jsonb);
end;
$$;
