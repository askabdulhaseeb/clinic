import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/core/utils/phone.dart';

void main() {
  group('Phone', () {
    test('normalize accepts all common PK formats', () {
      const want = '03001234567';
      expect(Phone.normalize('03001234567'), want);
      expect(Phone.normalize('0300 1234567'), want);
      expect(Phone.normalize('0300-123-4567'), want);
      expect(Phone.normalize('+92 300 1234567'), want);
      expect(Phone.normalize('923001234567'), want);
      expect(Phone.normalize('00923001234567'), want);
      expect(Phone.normalize('3001234567'), want);
      expect(Phone.normalize('(0300) 1234567'), want);
    });

    test('normalize rejects landlines, short and foreign numbers', () {
      expect(Phone.normalize('0421234567'), isNull);
      expect(Phone.normalize('0300123'), isNull);
      expect(Phone.normalize('+44 7700 900123'), isNull);
      expect(Phone.normalize('abc'), isNull);
      expect(Phone.normalize(''), isNull);
    });

    test('display and international', () {
      expect(Phone.display('03001234567'), '0300 1234567');
      expect(Phone.international('03001234567'), '923001234567');
    });

    test('whatsAppLink encodes the message', () {
      final uri = Phone.whatsAppLink(
        '03001234567',
        'Reminder: visit tomorrow & bring reports',
      );
      expect(uri.host, 'wa.me');
      expect(uri.path, '/923001234567');
      expect(
        uri.queryParameters['text'],
        'Reminder: visit tomorrow & bring reports',
      );
      expect(uri.toString(), contains('text=Reminder'));
    });
  });
}
