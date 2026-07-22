import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';

/// Auth mail helper — always sends via Edge Function `send-app-otp`.
///
/// SMTP credentials stay server-side (`app_mail_settings` + service role).
/// Never call a client-facing RPC that returns `smtp_pass`.
class ClientSmtpMailer {
  ClientSmtpMailer._();

  static Future<void> sendVerificationCode({
    required String toEmail,
    required String purpose,
  }) async {
    final res = await SupabaseBootstrap.client.functions.invoke(
      'send-app-otp',
      body: {
        'email': toEmail.trim(),
        'purpose': purpose,
      },
    );
    final data = res.data;
    if (res.status != 200) {
      final err = data is Map ? data['error'] : data;
      throw Exception(err ?? 'Failed to send email (${res.status})');
    }
    if (data is Map && data['error'] != null) {
      throw Exception(data['error']);
    }
  }
}
