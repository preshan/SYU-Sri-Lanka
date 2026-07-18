-- Chat list: only conversations with messages; paginated; staff admins allowed.

create or replace function public.admin_list_direct_chats(
  p_limit int default 30,
  p_offset int default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_limit int := greatest(1, least(coalesce(p_limit, 30), 100));
  v_offset int := greatest(0, coalesce(p_offset, 0));
  v_total bigint;
  v_items jsonb;
begin
  if not public.is_staff_admin() then
    raise exception 'Admin only';
  end if;

  select count(*)::bigint
  into v_total
  from public.conversations c
  join public.conversation_participants cp
    on cp.conversation_id = c.id and cp.user_id = auth.uid()
  where c.type = 'direct'
    and exists (
      select 1
      from public.messages m
      where m.conversation_id = c.id
        and m.deleted_at is null
    );

  select coalesce(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb)
  into v_items
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
      and exists (
        select 1
        from public.messages m
        where m.conversation_id = c.id
          and m.deleted_at is null
      )
    order by c.updated_at desc
    offset v_offset
    limit v_limit
  ) t;

  return jsonb_build_object(
    'items', v_items,
    'total', v_total,
    'limit', v_limit,
    'offset', v_offset
  );
end;
$$;

grant execute on function public.admin_list_direct_chats(int, int) to authenticated;

create or replace function public.member_list_conversations(
  p_limit int default 30,
  p_offset int default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_limit int := greatest(1, least(coalesce(p_limit, 30), 100));
  v_offset int := greatest(0, coalesce(p_offset, 0));
  v_total bigint;
  v_items jsonb;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select count(*)::bigint
  into v_total
  from public.conversations c
  join public.conversation_participants cp
    on cp.conversation_id = c.id and cp.user_id = auth.uid()
  where exists (
    select 1
    from public.messages m
    where m.conversation_id = c.id
      and m.deleted_at is null
  );

  select coalesce(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb)
  into v_items
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
    where exists (
      select 1
      from public.messages m
      where m.conversation_id = c.id
        and m.deleted_at is null
    )
    order by c.updated_at desc
    offset v_offset
    limit v_limit
  ) t;

  return jsonb_build_object(
    'items', v_items,
    'total', v_total,
    'limit', v_limit,
    'offset', v_offset
  );
end;
$$;

grant execute on function public.member_list_conversations(int, int) to authenticated;

-- Drop old 0-arg overloads if present so clients call paginated versions.
drop function if exists public.admin_list_direct_chats();
drop function if exists public.member_list_conversations();

notify pgrst, 'reload schema';
