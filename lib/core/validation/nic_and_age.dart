/// Sri Lanka NIC validation (old 9-digit+letter and new 12-digit formats).
class NicValidator {
  NicValidator._();

  static final _old = RegExp(r'^[0-9]{9}[vVxX]$');
  static final _new = RegExp(r'^[0-9]{12}$');

  static bool isValid(String raw) {
    final nic = raw.trim();
    return _old.hasMatch(nic) || _new.hasMatch(nic);
  }

  static String? errorText(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'NIC is required';
    if (!isValid(raw)) {
      return 'Enter a valid NIC (123456789V or 12 digits)';
    }
    return null;
  }

  /// Best-effort DOB extraction for new-format NICs (YYYYDDD...).
  /// Returns null when format does not encode a reliable date.
  static DateTime? tentativeDob(String raw) {
    final nic = raw.trim();
    if (!_new.hasMatch(nic)) return null;
    final year = int.tryParse(nic.substring(0, 4));
    final dayOfYear = int.tryParse(nic.substring(4, 7));
    if (year == null || dayOfYear == null) return null;
    var days = dayOfYear;
    // Female NICs traditionally add 500 to day-of-year.
    if (days > 500) days -= 500;
    if (days < 1 || days > 366) return null;
    final start = DateTime(year);
    return start.add(Duration(days: days - 1));
  }
}

/// Age helpers for SYU eligibility.
class AgeRules {
  AgeRules._();

  /// Confirm with SYU policy; defaults cover typical youth membership.
  static const int minAge = 15;
  static const int maxAge = 35;

  static int ageOn(DateTime dob, [DateTime? asOf]) {
    final now = asOf ?? DateTime.now();
    var age = now.year - dob.year;
    final hadBirthday = (now.month > dob.month) ||
        (now.month == dob.month && now.day >= dob.day);
    if (!hadBirthday) age -= 1;
    return age;
  }

  static String? eligibilityError(DateTime? dob) {
    if (dob == null) return 'Date of birth is required';
    final age = ageOn(dob);
    if (age < minAge) return 'You must be at least $minAge years old';
    if (age > maxAge) return 'Membership age limit is $maxAge';
    return null;
  }
}
