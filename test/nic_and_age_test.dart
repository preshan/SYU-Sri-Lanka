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
