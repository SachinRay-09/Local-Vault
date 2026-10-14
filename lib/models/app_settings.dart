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
}
