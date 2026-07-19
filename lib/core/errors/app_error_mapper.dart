import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps exceptions to safe, user-facing copy (no PII / raw dumps).
class AppErrorMapper {
  AppErrorMapper._();

  static String message(Object error) {
    if (error is AuthException) {
      final raw = error.message.toLowerCase();
      if (raw.contains('email not confirmed')) {
        return 'Confirm your email before signing in.';
      }
      if (raw.contains('invalid login') || raw.contains('invalid credentials')) {
        return 'Email or password is incorrect.';
      }
      if (raw.contains('user already registered')) {
        return 'An account with this email already exists.';
      }
      if (raw.contains('password')) {
        return 'Password does not meet requirements.';
      }
      if (raw.contains('rate') || raw.contains('too many')) {
        return 'Too many attempts. Please wait and try again.';
      }
      if (raw.contains('error sending') ||
          raw.contains('smtp') ||
          raw.contains('confirmation email')) {
        return 'Could not send the verification email. Try again shortly.';
      }
      // Surface short Auth messages in debug; keep release copy generic.
      if (kDebugMode && error.message.isNotEmpty) {
        return error.message;
      }
      return 'Authentication failed. Please try again.';
    }

    if (error is PostgrestException) {
      final code = error.code ?? '';
      if (code == '42501' || (error.message.toLowerCase().contains('row-level security'))) {
        return 'You do not have permission to do that.';
      }
      if (kDebugMode && error.message.isNotEmpty) {
        return error.message;
      }
    }

    final text = error.toString().toLowerCase();
    if (text.contains('csv download is only available') ||
        text.contains('csv export is not supported') ||
        text.contains('sharing is not available')) {
      return 'Could not export the file on this device.';
    }
    if (text.contains('socket') ||
        text.contains('network') ||
        text.contains('failed host lookup') ||
        text.contains('connection')) {
      return 'Network error. Check your connection and try again.';
    }
    if (text.contains('timeout')) {
      return 'The request timed out. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  static void log(Object error, [StackTrace? stack]) {
    // Keep logs free of secrets; only print in debug.
    if (kDebugMode) {
      debugPrint('AppError: $error');
      if (stack != null) debugPrintStack(stackTrace: stack);
    }
  }

  static void showSnackBar(BuildContext context, Object error) {
    log(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message(error))),
    );
  }
}
