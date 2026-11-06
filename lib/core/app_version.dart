/// The app version shown in the shell (UI_DESIGN §2.1, Phase 10). Kept by
/// hand next to `pubspec.yaml`; `test/core/app_version_test.dart` fails when
/// the two drift, so no runtime package is needed.
abstract final class AppVersion {
  /// `pubspec.yaml` `version` before the `+`.
  static const String current = '1.0.0';

  /// `pubspec.yaml` build number after the `+`.
  static const int build = 1;

  /// `v1.0.0`, the sidebar footer text.
  static const String label = 'v$current';
}
