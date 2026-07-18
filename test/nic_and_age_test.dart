import 'package:flutter_test/flutter_test.dart';
import 'package:syu_sri_lanka/core/validation/nic_and_age.dart';

void main() {
  group('NicValidator', () {
    test('accepts old and new formats', () {
      expect(NicValidator.isValid('123456789V'), isTrue);
      expect(NicValidator.isValid('123456789v'), isTrue);
      expect(NicValidator.isValid('199512345678'), isTrue);
    });

    test('rejects invalid', () {
      expect(NicValidator.isValid('123'), isFalse);
      expect(NicValidator.isValid('ABCDEFGHIJ'), isFalse);
      expect(NicValidator.errorText(''), isNotNull);
    });
  });

  group('AgeRules', () {
    test('calculates age and eligibility', () {
      final dob = DateTime(DateTime.now().year - 20, 1, 1);
      expect(AgeRules.ageOn(dob), greaterThanOrEqualTo(19));
      expect(AgeRules.eligibilityError(dob), isNull);
      expect(
        AgeRules.eligibilityError(DateTime(DateTime.now().year - 10, 1, 1)),
        isNotNull,
      );
    });
  });
}
