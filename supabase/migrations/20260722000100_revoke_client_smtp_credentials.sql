-- Phase 6 security: stop shipping SMTP App Password to clients via RPC.
-- Mail is sent only through Edge Function send-app-otp (service_role + get_mail_settings_internal).

revoke all on function public.get_smtp_credentials() from public, anon, authenticated;
drop function if exists public.get_smtp_credentials();

-- Mail settings RPCs already gate on is_super_admin(); still revoke anon execute.
revoke all on function public.get_mail_settings() from public, anon;
revoke all on function public.upsert_mail_settings(text, text, text, text, text, int) from public, anon;
grant execute on function public.get_mail_settings() to authenticated;
grant execute on function public.upsert_mail_settings(text, text, text, text, text, int) to authenticated;
