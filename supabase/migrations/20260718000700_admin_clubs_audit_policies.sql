-- Admin write policies for clubs + audit log visibility

drop policy if exists "youth_clubs_admin_all" on public.youth_clubs;
create policy "youth_clubs_admin_all" on public.youth_clubs
  for all to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

drop policy if exists "activity_logs_admin_select" on public.activity_logs;
create policy "activity_logs_admin_select" on public.activity_logs
  for select to authenticated
  using (public.is_super_admin() or actor_id = auth.uid());

drop policy if exists "activity_logs_admin_insert" on public.activity_logs;
create policy "activity_logs_admin_insert" on public.activity_logs
  for insert to authenticated
  with check (public.is_super_admin() or actor_id = auth.uid());
