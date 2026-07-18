import 'package:flutter_test/flutter_test.dart';
import 'package:syu_sri_lanka/core/validation/nic_and_age.dart';
import 'package:syu_sri_lanka/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  group('NicValidator', () {
    test('accepts old and new formats', () {
      expect(NicValidator.isValid('123456789V'), isTrue);
      expect(NicValidator.isValid('123456789v'), isTrue);
      expect(NicValidator.isValid('199512345678'), isTrue);
    });

    test('rejects invalid', () {
      expect(NicValidator.isValid('123'), isFalse);
      expect(NicValidator.isValid('ABCDEFGHIJ'), isFalse);
      expect(NicValidator.errorText('', l10n), isNotNull);
    });

    test('dobFromNic parses old format YYDDD…V', () {
      // 1993, day-of-year 292 → 1993-10-19
      final dob = NicValidator.dobFromNic('932923456V');
      expect(dob, isNotNull);
      expect(dob!.year, 1993);
      expect(dob.month, 10);
      expect(dob.day, 19);
      expect(NicValidator.genderFromNic('932923456V'), 'male');
    });

    test('dobFromNic parses old format female (day + 500)', () {
      // 1993, day 292 + 500 = 792
      final dob = NicValidator.dobFromNic('937923456V');
      expect(dob, isNotNull);
      expect(dob!.year, 1993);
      expect(dob.month, 10);
      expect(dob.day, 19);
      expect(NicValidator.genderFromNic('937923456V'), 'female');
    });

    test('dobFromNic parses new 12-digit format', () {
      // 2001, day 32 → 2001-02-01
      final dob = NicValidator.dobFromNic('200103212345');
      expect(dob, DateTime(2001, 2, 1));
      expect(NicValidator.genderFromNic('200103212345'), 'male');
    });
  });

  group('AgeRules', () {
    test('calculates age and eligibility', () {
      final dob = DateTime(DateTime.now().year - 20, 1, 1);
      expect(AgeRules.ageOn(dob), greaterThanOrEqualTo(19));
      expect(AgeRules.eligibilityError(dob, l10n), isNull);
      expect(
        AgeRules.eligibilityError(
          DateTime(DateTime.now().year - 10, 1, 1),
          l10n,
        ),
        isNotNull,
      );
    });
  });
}
