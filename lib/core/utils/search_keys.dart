/// Builds the `searchKeys` array stored on patients and families so Firestore
/// can answer prefix searches with `array-contains`.
///
/// For `Ali Khan` the keys include `a`, `al`, `ali`, `k`, `kh`, `khan`,
/// and prefixes of the whole string `ali khan` such as `ali k`, `ali kh`.
abstract final class SearchKeys {
  /// Longest prefix kept per word or phrase. Keeps array sizes bounded.
  static const int maxPrefix = 20;

  static String normalize(String input) => input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9؀-ۿ ]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static List<String> build(String name) {
    final full = normalize(name);
    if (full.isEmpty) return const [];
    final keys = <String>{};
    void addPrefixes(String s) {
      final limit = s.length < maxPrefix ? s.length : maxPrefix;
      for (var i = 1; i <= limit; i++) {
        keys.add(s.substring(0, i));
      }
    }

    addPrefixes(full);
    for (final word in full.split(' ')) {
      addPrefixes(word);
    }
    final list = keys.toList()..sort();
    return list;
  }

  /// The key to query for a user's search text.
  static String queryKey(String text) {
    final n = normalize(text);
    return n.length <= maxPrefix ? n : n.substring(0, maxPrefix);
  }
}
