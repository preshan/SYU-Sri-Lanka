/// Deep-link used for Supabase Auth email flows (confirm / reset).
///
/// Must match Android/iOS URL scheme config and Supabase Dashboard
/// Authentication → URL Configuration → Redirect URLs.
///
/// Always use this URI — including when testing on Flutter Web — otherwise
/// Supabase falls back to Dashboard Site URL (often localhost).
abstract final class AuthRedirects {
  /// Custom scheme already registered as `syu` in AndroidManifest / Info.plist.
  static const scheme = 'syu';
  static const host = 'auth';
  static const path = '/callback';

  /// Full redirect URI: `syu://auth/callback`
  static const callback = '$scheme://$host$path';

  /// Passed as `emailRedirectTo` / `redirectTo` on all platforms.
  static const emailRedirectTo = callback;
}
