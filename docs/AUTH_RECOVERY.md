# Auth redirects & password recovery

## Email confirmation

- Supabase Auth: **Confirm email** enabled (`mailer_autoconfirm = false`).
- After sign-up, the app routes to `/confirm-email` with resend support.

## Password recovery

### App routes

| Route | Purpose |
|-------|---------|
| `/forgot-password` | Request reset email |
| `/login` | Return after send |

### Supabase Dashboard checklist

1. **Authentication → URL Configuration**
   - Site URL: production web/admin URL when available; for mobile testing use a deep link or HTTPS landing page.
   - Redirect URLs include:
     - `io.supabase.syu://login-callback/` (optional mobile deep link)
     - `https://<your-domain>/auth/reset` (when admin web exists)
2. **Authentication → Email Templates → Reset Password**
   - Confirm template uses `{{ .ConfirmationURL }}`.
3. Until deep links are wired, users open the email link in a browser and set the password via Supabase-hosted or admin-web flow.

### Flutter

`AuthRepository.resetPassword(email)` calls `resetPasswordForEmail` without a custom `redirectTo` until the deep-link scheme is registered in Android/iOS manifests.
