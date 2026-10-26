import 'package:isar/isar.dart';

part 'app_settings.g.dart';

@collection
class AppSettings {
  Id id = Isar.autoIncrement;

  /// Optional storage cap.
  int? maxStorageBytes;

  /// Custom temp folder path for Android manga reader integration
  String? customTempFolderPath;

  /// Running total of all stored bytes — updated on every add/delete.
  int totalBytesUsed = 0;

  /// When the counter was last reconciled against all VaultFile rows.
  DateTime? lastReconciledAt;

  /// Persisted theme mode. Valid: 'system' | 'light' | 'dark'.
  /// Default 'system' — existing light-mode users see no change.
  String themeMode = 'system';

  /// Whether to block screenshots on Android (FLAG_SECURE).
  /// Default false = screenshots enabled (no change from current behaviour).
  bool blockScreenshots = false;
}
