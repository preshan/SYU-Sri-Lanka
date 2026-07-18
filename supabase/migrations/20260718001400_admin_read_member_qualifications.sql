-- Allow super admins to read member qualifications for listing

drop policy if exists "member_qualifications_admin_select" on public.member_qualifications;
create policy "member_qualifications_admin_select" on public.member_qualifications
  for select to authenticated
  using (public.is_super_admin() or profile_id = auth.uid());
