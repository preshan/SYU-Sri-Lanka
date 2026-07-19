import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syu_sri_lanka/core/auth/auth_redirects.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/features/auth/data/client_smtp_mailer.dart';

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => SupabaseBootstrap.client,
);

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

final currentSessionProvider = Provider<Session?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(supabaseClientProvider).auth.currentSession;
});

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<bool> isAppEmailVerified() async {
    final v = await _client.rpc('is_app_email_verified');
    return v == true;
  }

  Future<bool> mustChangePassword() async {
    final v = await _client.rpc('must_change_password');
    return v == true;
  }

  Future<bool> isAccountSuspended() async {
    final v = await _client.rpc('is_account_suspended');
    return v == true;
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: AuthRedirects.emailRedirectTo,
      data: {
        if (fullName != null && fullName.trim().isNotEmpty)
          'full_name': fullName.trim(),
      },
    );
    // TEMPORARY: Flutter sends the OTP via Gmail (DB credentials).
    await sendAppEmailOtp(email: email, purpose: 'signup');
    return res;
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Issues OTP + sends via Flutter SMTP / Edge Function (not Supabase Auth mailer).
  Future<void> sendAppEmailOtp({
    required String email,
    required String purpose,
  }) {
    return ClientSmtpMailer.sendVerificationCode(
      toEmail: email.trim(),
      purpose: purpose,
    );
  }

  Future<void> resetPassword(String email) {
    return sendAppEmailOtp(email: email, purpose: 'recovery');
  }

  Future<void> resendSignupEmail(String email) {
    return sendAppEmailOtp(email: email, purpose: 'signup');
  }

  /// Confirm signup with the 6-digit code emailed by Flutter SMTP.
  Future<void> verifySignupOtp({
    required String email,
    required String token,
  }) async {
    await _client.rpc(
      'verify_app_signup_otp',
      params: {
        'p_email': email.trim(),
        'p_code': token.trim(),
      },
    );
  }

  Future<void> verifyRecoveryOtp({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    await _client.rpc(
      'verify_app_recovery_otp',
      params: {
        'p_email': email.trim(),
        'p_code': token.trim(),
        'p_new_password': newPassword,
      },
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);
