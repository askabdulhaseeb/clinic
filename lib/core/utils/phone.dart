/// Pakistani phone numbers. Stored form is `03XXXXXXXXX` (11 digits).
abstract final class Phone {
  /// Normalises `+92 300 1234567`, `92-300-1234567`, `0300 1234567`,
  /// `3001234567` to `03001234567`. Returns null when not a PK mobile number.
  static String? normalize(String raw) {
    var s = raw.replaceAll(RegExp(r'[\s\-()]'), '');
    if (s.startsWith('+')) s = s.substring(1);
    if (s.startsWith('0092')) s = s.substring(4);
    if (!RegExp(r'^\d+$').hasMatch(s)) return null;
    if (s.startsWith('92') && s.length == 12) s = '0${s.substring(2)}';
    if (s.length == 10 && s.startsWith('3')) s = '0$s';
    if (s.length == 11 && s.startsWith('03')) return s;
    return null;
  }

  /// `03001234567` → `0300 1234567`.
  static String display(String stored) {
    if (stored.length != 11) return stored;
    return '${stored.substring(0, 4)} ${stored.substring(4)}';
  }

  /// `03001234567` → `923001234567` for wa.me links.
  static String international(String stored) => '92${stored.substring(1)}';

  /// Pre-filled WhatsApp Web link.
  static Uri whatsAppLink(String stored, String message) =>
      Uri.https('wa.me', '/${international(stored)}', {'text': message});
}
