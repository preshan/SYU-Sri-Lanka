import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';

/// TEMPORARY auth mail helper.
///
/// - **Web:** Edge Function `send-app-otp` (browsers cannot open SMTP sockets).
/// - **Mobile/desktop:** can send with DB SMTP via `mailer`, with Edge fallback.
///
/// Credentials live in `app_mail_settings`, not as compile-time secrets in the APK.
class ClientSmtpMailer {
  ClientSmtpMailer._();

  static Future<void> sendVerificationCode({
    required String toEmail,
    required String purpose,
  }) async {
    if (kIsWeb) {
      await _sendViaEdge(toEmail: toEmail, purpose: purpose);
      return;
    }
    try {
      await _sendViaDartSmtp(toEmail: toEmail, purpose: purpose);
    } catch (_) {
      await _sendViaEdge(toEmail: toEmail, purpose: purpose);
    }
  }

  static Future<void> _sendViaEdge({
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

  static Future<void> _sendViaDartSmtp({
    required String toEmail,
    required String purpose,
  }) async {
    final code = await SupabaseBootstrap.client.rpc(
      'issue_app_email_otp',
      params: {
        'p_email': toEmail.trim(),
        'p_purpose': purpose,
      },
    );
    final token = '$code'.trim();
    if (token.length != 6) {
      throw StateError('Could not create verification code');
    }

    final rows = await SupabaseBootstrap.client.rpc('get_smtp_credentials');
    final list = List<Map<String, dynamic>>.from(rows as List? ?? const []);
    if (list.isEmpty) {
      throw StateError('Mail is not configured');
    }
    final r = list.first;
    final user = (r['smtp_user'] as String?)?.trim() ?? '';
    final pass = (r['smtp_pass'] as String?)?.trim() ?? '';
    if (user.isEmpty || pass.isEmpty) {
      throw StateError('Mail is not configured');
    }
    final fromEmail = ((r['from_email'] as String?)?.trim().isNotEmpty == true)
        ? (r['from_email'] as String).trim()
        : user;
    final fromName = ((r['from_name'] as String?)?.trim().isNotEmpty == true)
        ? (r['from_name'] as String).trim()
        : 'SYU Sri Lanka';
    final host = (r['smtp_host'] as String?)?.trim().isNotEmpty == true
        ? (r['smtp_host'] as String).trim()
        : 'smtp.gmail.com';
    final port = (r['smtp_port'] as num?)?.toInt() ?? 465;
    final isRecovery = purpose == 'recovery';
    final subject = isRecovery
        ? '$token is your SYU password reset code'
        : '$token is your SYU verification code';
    final body = isRecovery
        ? 'Your SYU Sri Lanka password reset code is:\n\n$token\n\n'
            'It expires in 30 minutes. If you did not request this, ignore this email.'
        : 'Your SYU Sri Lanka verification code is:\n\n$token\n\n'
            'Enter this 6-digit code in the app to finish signing up. It expires in 30 minutes.';

    final message = Message()
      ..from = Address(fromEmail, fromName)
      ..recipients.add(toEmail.trim())
      ..subject = subject
      ..text = body;

    final server = port == 587
        ? gmail(user, pass)
        : SmtpServer(
            host,
            port: port,
            username: user,
            password: pass,
            ssl: port == 465,
          );

    await send(message, server);
  }
}
