import 'package:flutter_test/flutter_test.dart';
import 'package:syu_sri_lanka/core/validation/nic_and_age.dart';
import 'package:syu_sri_lanka/features/profile/domain/profile_completeness.dart';

void main() {
  group('ProfileCompleteness', () {
    test('scores empty profile low', () {
      final c = ProfileCompleteness.fromProfile({});
      expect(c.percent, 0);
      expect(c.missing, isNotEmpty);
    });

    test('scores complete profile high', () {
      final c = ProfileCompleteness.fromProfile({
        'full_name': 'A',
        'phone': '0771234567',
        'nic': '123456789V',
        'date_of_birth': '2000-01-01',
        'district_id': 1,
        'avatar_path': 'uid/avatar.jpg',
      });
      expect(c.percent, 100);
      expect(c.missing, isEmpty);
    });
  });

  group('NicValidator regression', () {
    test('old format', () {
      expect(NicValidator.isValid('123456789V'), isTrue);
    });
  });
}
