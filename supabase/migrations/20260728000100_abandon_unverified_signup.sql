-- Allow an unverified signup to abandon and free the email for a new registration.
-- Only the signed-in user can delete their own account, and only while
-- app_email_verified is still false.

create or replace function public.abandon_unverified_signup()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_email text;
  v_verified boolean;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select lower(u.email), coalesce(p.app_email_verified, false)
    into v_email, v_verified
  from auth.users u
  left join public.profiles p on p.id = u.id
  where u.id = v_uid;

  if v_email is null then
    raise exception 'user not found';
  end if;

  if v_verified then
    raise exception 'email already verified';
  end if;

  delete from public.app_email_otps
  where lower(email) = v_email
    and purpose = 'signup';

  -- Cascades to profiles and related rows via FK on delete.
  delete from auth.users
  where id = v_uid;
end;
$$;

revoke all on function public.abandon_unverified_signup() from public;
grant execute on function public.abandon_unverified_signup() to authenticated;
