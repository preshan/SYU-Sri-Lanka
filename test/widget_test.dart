import 'package:flutter_test/flutter_test.dart';
import 'package:syu_sri_lanka/core/validation/nic_and_age.dart';

void main() {
  test('widget smoke placeholder keeps suite green', () {
    expect(NicValidator.isValid('123456789V'), isTrue);
  });
}
