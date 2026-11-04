import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/auth/domain/entities/user_role.dart';

void main() {
  test('parses known keys and ignores unknown', () {
    expect(UserRole.tryParse('admin'), UserRole.admin);
    expect(UserRole.tryParse('Admin'), isNull);
    expect(UserRole.tryParse(null), isNull);
    expect(UserRole.parseList(['doctor', 'nurse', 'reception', 3]), [
      UserRole.doctor,
      UserRole.reception,
    ]);
    expect(UserRole.parseList('admin'), isEmpty);
  });
}
