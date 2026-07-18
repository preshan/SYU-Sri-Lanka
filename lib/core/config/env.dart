import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Runtime configuration loaded from `.env` (gitignored).
class Env {
  Env._();

  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get supabasePublishableKey =>
      dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ?? '';

  static void validate() {
    final hasKey =
        supabasePublishableKey.isNotEmpty || supabaseAnonKey.isNotEmpty;
    if (supabaseUrl.isEmpty || !hasKey) {
      throw StateError(
        'Missing SUPABASE_URL or key. '
        'Copy .env.example to .env and fill values.',
      );
    }
  }
}
