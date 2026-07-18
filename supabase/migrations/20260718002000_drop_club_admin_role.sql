-- Remove unused club_admin role (app only uses member + district_admin + super_admin).

delete from public.user_roles
where role_id in (select id from public.roles where code = 'club_admin');

delete from public.roles
where code = 'club_admin';
