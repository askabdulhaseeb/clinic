import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/core/utils/tokens.dart';

void main() {
  group('Tokens', () {
    test('label uses upper-case department code', () {
      expect(Tokens.label('E', 12), 'E-12');
      expect(Tokens.label('h', 5), 'H-5');
    });

    test('next is max + 1, starting at 1', () {
      expect(Tokens.next(const []), 1);
      expect(Tokens.next(const [1, 2, 3]), 4);
      expect(Tokens.next(const [7, 2, 5]), 8);
    });
  });
}
