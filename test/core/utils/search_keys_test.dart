import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/core/utils/search_keys.dart';

void main() {
  group('SearchKeys', () {
    test('normalize lowercases, strips punctuation and collapses spaces', () {
      expect(SearchKeys.normalize('  Ali   KHAN. '), 'ali khan');
      expect(SearchKeys.normalize('M. Umar-ud-Din'), 'm umar ud din');
    });

    test('build contains word prefixes and phrase prefixes', () {
      final keys = SearchKeys.build('Ali Khan');
      expect(keys, containsAll(['a', 'al', 'ali', 'k', 'kh', 'khan']));
      expect(keys, containsAll(['ali ', 'ali k', 'ali khan']));
      expect(keys, isNot(contains('khan ali')));
      expect(keys.toSet().length, keys.length, reason: 'no duplicates');
      expect(keys, orderedEquals([...keys]..sort()));
    });

    test('build caps prefix length', () {
      final long = 'a' * 40;
      final keys = SearchKeys.build(long);
      expect(keys.length, SearchKeys.maxPrefix);
      expect(keys.last.length, SearchKeys.maxPrefix);
    });

    test('build on empty or symbol-only input is empty', () {
      expect(SearchKeys.build(''), isEmpty);
      expect(SearchKeys.build('...'), isEmpty);
    });

    test('queryKey matches what build produces', () {
      final keys = SearchKeys.build('Fatima Noor');
      expect(keys, contains(SearchKeys.queryKey('FAT')));
      expect(keys, contains(SearchKeys.queryKey('fatima n')));
      expect(keys, contains(SearchKeys.queryKey('noo')));
    });
  });
}
