-- Storage buckets + policies for avatars / message attachments

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 5242880, array['image/jpeg','image/png','image/webp']),
  ('message-attachments', 'message-attachments', false, 10485760, array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Avatars: anyone can read; users write only to their own folder {uid}/...
drop policy if exists "avatars_public_read" on storage.objects;
drop policy if exists "avatars_owner_write" on storage.objects;
drop policy if exists "avatars_owner_update" on storage.objects;
drop policy if exists "avatars_owner_delete" on storage.objects;

create policy "avatars_public_read" on storage.objects
  for select to public using (bucket_id = 'avatars');

create policy "avatars_owner_write" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "avatars_owner_update" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "avatars_owner_delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Message attachments: participants only (folder = conversation_id)
drop policy if exists "msg_attach_read" on storage.objects;
drop policy if exists "msg_attach_write" on storage.objects;

create policy "msg_attach_read" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'message-attachments'
    and exists (
      select 1 from public.conversation_participants cp
      where cp.user_id = auth.uid()
        and cp.conversation_id::text = (storage.foldername(name))[1]
    )
  );

create policy "msg_attach_write" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'message-attachments'
    and exists (
      select 1 from public.conversation_participants cp
      where cp.user_id = auth.uid()
        and cp.conversation_id::text = (storage.foldername(name))[1]
    )
  );
