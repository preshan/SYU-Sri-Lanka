# Auth redirects & email verification

## Email confirmation — 6-digit PIN (OTP)

Signup confirmation uses a **6-digit code** from the email, entered in the app
(`ConfirmEmailScreen` → `AuthRepository.verifySignupOtp` → Supabase `verifyOTP`).

### Email delivery (Gmail SMTP via DB)

Auth mail is sent through **Supabase custom SMTP**. Credentials live in Postgres
so super-admins can rotate them **without redeploying** the Flutter app.

| Store | Value |
|-------|--------|
| Table | `public.app_mail_settings` (singleton `id = 1`) |
| Gmail | column `smtp_user` |
| App Password | column `smtp_pass` (**never returned to clients**) |
| From | `from_email` / `from_name` |

**Where to save in the app:** Admin dashboard → **Other tools** → **Mail** →
enter Gmail + App Password → **Save and apply**.

That writes the DB row and invokes Edge Function `sync-auth-smtp`, which PATCHes
Supabase Auth SMTP (`smtp.gmail.com:465`).

RPCs (super_admin only):

- `get_mail_settings()` — host/user/from + `password_set` (no secret)
- `upsert_mail_settings(...)` — empty password keeps the existing secret

Edge Function secrets (Dashboard → Edge Functions → Secrets, not Flutter):

- Auto-injected: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`
- Custom: `MANAGEMENT_ACCESS_TOKEN` (Supabase management / personal access token)

**Confirm signup** subject: `{{ .Token }} is your SYU verification code`  
Body includes `{{ .Token }}` (6 digits). No magic link.

> Create a Google [App Password](https://myaccount.google.com/apppasswords)
> (2FA required). Do not use your normal Gmail password.

### Flutter wiring

| Call | Behaviour |
|------|-----------|
| `signUp` | Supabase emails the OTP via configured SMTP. App opens `/confirm-email`. |
| `resend` (`OtpType.signup`) | Sends a new code. |
| `verifyOTP` (`OtpType.signup`) | User enters 6 digits → session → `/home`. |

Password recovery deep link:

```text
syu://auth/callback
```

### URL configuration

| Field | Value |
|-------|--------|
| **Site URL** | `syu://auth/callback` |
| **Additional Redirect URLs** | `syu://auth/callback`, `http://localhost:5280` |

OTP length: **6**. OTP expiry: **7 days** (`mailer_otp_exp` = 604800).

### Manual test

1. As super_admin, open **Mail** and save Gmail + App Password (Save and apply).
2. Delete any previous test Auth user if needed.
3. Register in the app → open the mail → copy the **6-digit code**.
4. Enter it on the confirm screen → Home.

### Password recovery

Still uses a link template until customized the same way (`{{ .ConfirmationURL }}`
or a recovery PIN). Deep link: `syu://auth/callback`.
