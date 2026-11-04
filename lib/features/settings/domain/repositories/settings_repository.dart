import 'dart:typed_data';

import '../entities/clinic_settings.dart';
import '../entities/initial_setup_input.dart';

/// One emission of the settings listener. [settings] is null while the
/// document does not exist; [fromCache] marks a value that may be stale or
/// an absence that is not yet confirmed by the server.
class SettingsSnapshot {
  const SettingsSnapshot({required this.settings, required this.fromCache});

  final ClinicSettings? settings;
  final bool fromCache;

  bool get exists => settings != null;
}

/// `settings/general` plus first-run setup. Admin-only writes.
abstract class SettingsRepository {
  Stream<SettingsSnapshot> watchSettings();

  /// Writes the whole document (merge), stamping `updatedAt` / `updatedBy`.
  Future<void> saveSettings(ClinicSettings settings);

  /// Uploads `clinic/logo.png`, stores its URL on the settings document and
  /// returns the URL.
  Future<String> uploadLogo({
    required Uint8List bytes,
    required String contentType,
  });

  /// Creates `branches/main`, `settings/general` and the seed departments and
  /// visit types in one batch. Seed records already present are merged, so
  /// running it twice is safe.
  Future<void> runInitialSetup(InitialSetupInput input);
}
