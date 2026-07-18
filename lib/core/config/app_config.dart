import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';

/// Reads public key/value rows from `app_config` (editable in Supabase without a release).
abstract final class AppConfig {
  static const websiteUrlKey = 'website_url';
  static const facebookPageUrlKey = 'facebook_page_url';
  static const defaultWebsiteUrl = 'https://syusrilanka.com/';

  static Future<String> websiteUrl() async {
    try {
      final row = await SupabaseBootstrap.client
          .from('app_config')
          .select('value')
          .eq('key', websiteUrlKey)
          .maybeSingle();
      final value = (row?['value'] as String?)?.trim();
      if (value != null && value.isNotEmpty) return value;
    } catch (_) {
      // Fall back when offline or table not yet migrated.
    }
    return defaultWebsiteUrl;
  }

  /// Official Facebook page URL. Empty when not configured in DB.
  static Future<String?> facebookPageUrl() async {
    try {
      final row = await SupabaseBootstrap.client
          .from('app_config')
          .select('value')
          .eq('key', facebookPageUrlKey)
          .maybeSingle();
      final value = (row?['value'] as String?)?.trim();
      if (value != null && value.isNotEmpty) return value;
    } catch (_) {
      // Fall back when offline or table not yet migrated.
    }
    return null;
  }
}
