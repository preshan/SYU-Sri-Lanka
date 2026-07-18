import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syu_sri_lanka/core/config/env.dart';

class SupabaseBootstrap {
  SupabaseBootstrap._();

  static Future<void> init() async {
    final publishable = Env.supabasePublishableKey;
    if (publishable.isNotEmpty) {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: publishable,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
    } else {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: Env.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
}
