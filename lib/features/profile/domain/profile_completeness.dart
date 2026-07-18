class ProfileCompleteness {
  const ProfileCompleteness({
    required this.percent,
    required this.missing,
  });

  final int percent;
  final List<String> missing;

  static ProfileCompleteness fromProfile(Map<String, dynamic>? row) {
    if (row == null) {
      return const ProfileCompleteness(
        percent: 0,
        missing: ['profile'],
      );
    }
    final checks = <String, bool>{
      'Full name': (row['full_name'] as String?)?.trim().isNotEmpty == true,
      'Phone': (row['phone'] as String?)?.trim().isNotEmpty == true,
      'NIC': (row['nic'] as String?)?.trim().isNotEmpty == true,
      'Date of birth': row['date_of_birth'] != null,
      'District': row['district_id'] != null,
      'Photo': (row['avatar_path'] as String?)?.trim().isNotEmpty == true,
    };
    final missing = checks.entries
        .where((e) => !e.value)
        .map((e) => e.key)
        .toList();
    final done = checks.length - missing.length;
    final percent = ((done / checks.length) * 100).round();
    return ProfileCompleteness(percent: percent, missing: missing);
  }
}
