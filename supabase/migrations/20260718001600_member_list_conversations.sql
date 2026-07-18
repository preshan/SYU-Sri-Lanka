-- Reliable member inbox (avoids PostgREST embed + RLS edge cases).
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
        ) as last_message
      from public.conversations c
      join public.conversation_participants cp
        on cp.conversation_id = c.id
       and cp.user_id = auth.uid()
    ) t
  ), '[]'::jsonb);
end;
$$;

grant execute on function public.member_list_conversations() to authenticated;
