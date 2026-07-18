# Auth redirects & email verification

## Email confirmation — 6-digit PIN (OTP)

**TEMPORARY mail path:** Codes for signup and password reset are sent with Gmail
credentials stored in `app_mail_settings`. The Flutter app triggers send via Edge
Function `send-app-otp` (browsers cannot open raw SMTP sockets). The App Password
stays in the DB / function — not baked into the APK as a constant.

Supabase Auth **autoconfirm** is enabled so Auth does not send its own mail
(avoids Auth rate limits). App gate: `profiles.app_email_verified`.

| Limit | Value |
|-------|--------|
| OTP emails | **5 / email / purpose / hour** (`issue_app_email_otp`) |

### Where credentials live

| Store | Value |
|-------|--------|
| Table | `public.app_mail_settings` (`id = 1`) |
| Update | Directly in the DB (`smtp_user`, `smtp_pass`, `from_email`, `from_name`) |

### Flutter wiring

| Call | Behaviour |
|------|-----------|
| `signUp` | Creates user → `send-app-otp` (signup) → `/confirm-email` |
| `verify_app_signup_otp` | Sets `app_email_verified` + confirms Auth email |
| Recovery | `send-app-otp` (recovery) → code + new password → `verify_app_recovery_otp` |

```text
syu://auth/callback
```
