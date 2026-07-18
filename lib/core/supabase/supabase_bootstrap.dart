import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syu_sri_lanka/core/config/env.dart';

class SupabaseBootstrap {
  SupabaseBootstrap._();

  /// Supabase hosted max JWT exp is 7 days (604800s).
  /// Auto-refresh + local persist keep users signed in across restarts;
  /// Pro plan can extend absolute session timebox to 30 days.
  static const int sessionJwtExpSeconds = 60 * 60 * 24 * 7;

  static Future<void> init() async {
    final auth = FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      autoRefreshToken: true,
      // Opens email links (syu://auth/callback) and exchanges code/tokens
      // for a session via app_links — no external hosting required.
      detectSessionInUri: true,
    );

    final publishable = Env.supabasePublishableKey;
    if (publishable.isNotEmpty) {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: publishable,
        authOptions: auth,
      );
    } else {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: Env.supabaseAnonKey,
        authOptions: auth,
      );
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
}
