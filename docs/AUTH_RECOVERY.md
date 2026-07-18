# Auth redirects & email verification

## Email confirmation — 6-digit PIN (OTP)

Signup confirmation uses a **6-digit code** from the email, entered in the app
(`ConfirmEmailScreen` → `AuthRepository.verifySignupOtp` → Supabase `verifyOTP`).

### Email delivery (Resend SMTP)

Auth mail is sent via **Resend** as Supabase custom SMTP (not the default Supabase mailer).

| Setting | Value |
|---------|--------|
| Host | `smtp.resend.com` |
| Port | `465` |
| User | `resend` |
| Pass | Resend API key (`re_…`) — stored in `.env.local.management` only |
| From | `onboarding@resend.dev` (Resend test domain) |

**Confirm signup** subject: `{{ .Token }} is your SYU verification code`  
(e.g. `032645 is your SYU verification code`)  
Body includes `{{ .Token }}` (6 digits). No magic link.

> **Resend test domain:** `onboarding@resend.dev` can only deliver to the email
> address of the Resend account owner until you verify your own domain.

Secrets live in `.env.local.management` (`RESEND_API_KEY`, service role, etc.) — never
in Flutter assets or git.

To re-apply SMTP + template via Management API (after rotating the key):

```bash
# set RESEND_API_KEY in .env.local.management, then PATCH
# /v1/projects/$REF/config/auth with smtp_* + mailer_templates_confirmation_content
```

### Flutter wiring

| Call | Behaviour |
|------|-----------|
| `signUp` | Supabase emails the OTP via Resend. App opens `/confirm-email`. |
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

1. Delete any previous test Auth user if needed.
2. Register in the app with the Resend account email (while using `onboarding@resend.dev`).
3. Open the mail → copy the **6-digit code**.
4. Enter it on the confirm screen → Home.

### Password recovery

Still uses a link template until customized the same way (`{{ .ConfirmationURL }}`
or a recovery PIN). Deep link: `syu://auth/callback`.
