import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syu_sri_lanka/core/auth/auth_redirects.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';

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

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: AuthRedirects.emailRedirectTo,
      data: {
        if (fullName != null && fullName.trim().isNotEmpty)
          'full_name': fullName.trim(),
      },
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> resetPassword(String email) {
    return _client.auth.resetPasswordForEmail(
      email,
      redirectTo: AuthRedirects.emailRedirectTo,
    );
  }

  Future<void> resendSignupEmail(String email) {
    return _client.auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: AuthRedirects.emailRedirectTo,
    );
  }

  /// Confirm signup with the 6-digit code from the email (`{{ .Token }}`).
  Future<AuthResponse> verifySignupOtp({
    required String email,
    required String token,
  }) {
    return _client.auth.verifyOTP(
      type: OtpType.signup,
      email: email.trim(),
      token: token.trim(),
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);
