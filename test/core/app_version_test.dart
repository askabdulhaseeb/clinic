import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/core/app_version.dart';

void main() {
  test('AppVersion.current matches the version in pubspec.yaml', () {
    // `flutter test` runs with the project root as the working directory.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml has a version line');
    expect(AppVersion.current, match!.group(1));
    expect(AppVersion.build, int.parse(match.group(2)!));
    expect(AppVersion.label, 'v${AppVersion.current}');
  });
}
