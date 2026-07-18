import 'package:syu_sri_lanka/l10n/app_localizations.dart';

class ProfileCompleteness {
  const ProfileCompleteness({
    required this.percent,
    required this.missingKeys,
  });

  final int percent;

  /// Stable keys: fullName, phone, nic, dob, district, profile
  final List<String> missingKeys;

  static ProfileCompleteness fromProfile(Map<String, dynamic>? row) {
    if (row == null) {
      return const ProfileCompleteness(
        percent: 0,
        missingKeys: ['profile'],
      );
    }
    final checks = <String, bool>{
      'fullName': (row['full_name'] as String?)?.trim().isNotEmpty == true,
      'phone': (row['phone'] as String?)?.trim().isNotEmpty == true,
      'nic': (row['nic'] as String?)?.trim().isNotEmpty == true,
      'dob': row['date_of_birth'] != null,
      'district': row['district_id'] != null,
    };
    final missing = checks.entries
        .where((e) => !e.value)
        .map((e) => e.key)
        .toList();
    final done = checks.length - missing.length;
    final percent = ((done / checks.length) * 100).round();
    return ProfileCompleteness(percent: percent, missingKeys: missing);
  }

  String localizedMissing(AppLocalizations l10n) {
    return missingKeys.map((k) => labelFor(k, l10n)).join(', ');
  }

  static String labelFor(String key, AppLocalizations l10n) {
    return switch (key) {
      'fullName' => l10n.fullName,
      'phone' => l10n.phone,
      'nic' => l10n.nic,
      'dob' => l10n.dob,
      'district' => l10n.district,
      'profile' => l10n.fieldProfile,
      _ => key,
    };
  }
}
