import 'package:syu_sri_lanka/l10n/app_localizations.dart';

/// Sri Lanka NIC validation (old 9-digit+letter and new 12-digit formats).
class NicValidator {
  NicValidator._();

  static final _old = RegExp(r'^[0-9]{9}[vVxX]$');
  static final _new = RegExp(r'^[0-9]{12}$');

  static bool isValid(String raw) {
    final nic = raw.trim();
    return _old.hasMatch(nic) || _new.hasMatch(nic);
  }

  static String? errorText(String? raw, AppLocalizations l10n) {
    if (raw == null || raw.trim().isEmpty) return l10n.nicRequired;
    if (!isValid(raw)) return l10n.nicInvalid;
    return null;
  }

  /// Old: `YYDDDXXXXV` (year = 1900+YY). New: `YYYYDDDXXXXX`.
  /// Day-of-year > 500 means female (subtract 500).
  static DateTime? dobFromNic(String raw) {
    final nic = raw.trim().toUpperCase();
    int? year;
    int? dayOfYear;

    if (_old.hasMatch(nic)) {
      year = 1900 + int.parse(nic.substring(0, 2));
      dayOfYear = int.parse(nic.substring(2, 5));
    } else if (_new.hasMatch(nic)) {
      year = int.parse(nic.substring(0, 4));
      dayOfYear = int.parse(nic.substring(4, 7));
    } else {
      return null;
    }

    var days = dayOfYear;
    if (days > 500) days -= 500;
    if (days < 1 || days > 366) return null;

    final candidate = DateTime(year, 1, 1).add(Duration(days: days - 1));
    if (candidate.year != year) return null;
    return DateTime(candidate.year, candidate.month, candidate.day);
  }

  /// `male` / `female` from day-of-year encoding, or null if unknown.
  static String? genderFromNic(String raw) {
    final nic = raw.trim().toUpperCase();
    int? dayOfYear;
    if (_old.hasMatch(nic)) {
      dayOfYear = int.tryParse(nic.substring(2, 5));
    } else if (_new.hasMatch(nic)) {
      dayOfYear = int.tryParse(nic.substring(4, 7));
    }
    if (dayOfYear == null) return null;
    if (dayOfYear > 500) return 'female';
    if (dayOfYear >= 1) return 'male';
    return null;
  }

  /// @Deprecated — use [dobFromNic].
  static DateTime? tentativeDob(String raw) => dobFromNic(raw);
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

  static String? eligibilityError(DateTime? dob, AppLocalizations l10n) {
    if (dob == null) return l10n.dobRequired;
    final age = ageOn(dob);
    if (age < minAge) return l10n.ageTooYoung(minAge);
    if (age > maxAge) return l10n.ageTooOld(maxAge);
    return null;
  }
}
