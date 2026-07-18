-- New accounts are messageable immediately (admins can nudge incomplete registration).
-- Registration completeness is tracked by profile fields, not by pending_registration status.

alter table public.profiles
  alter column status set default 'active';

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, status)
  values (new.id, new.email, 'active')
  on conflict (id) do nothing;
  return new;
end;
$$;

-- Existing incomplete signups become messageable; leave suspended alone.
update public.profiles
set status = 'active', updated_at = now()
where status in ('pending_registration', 'pending_approval');
