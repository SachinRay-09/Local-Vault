import 'package:isar/isar.dart';

import '../db/isar_db.dart';
import '../models/app_settings.dart';
import '../models/vault_file.dart';
import '../models/vault_folder.dart';

class VaultStats {
  VaultStats({
    required this.folderCount,
    required this.fileCount,
    required this.totalBytes,
  });

  final int folderCount;
  final int fileCount;
  final int totalBytes;
}

class SettingsService {
  Isar get _isar => IsarDb.instance;

  Future<AppSettings> getOrCreate() async {
    final existing = await _isar.appSettings.where().anyId().findFirst();
    if (existing != null) return existing;

    final created = AppSettings();
    await _isar.writeTxn(() async {
      await _isar.appSettings.put(created);
    });
    return created;
  }

  /// Get current settings (alias for getOrCreate for consistency)
  Future<AppSettings> getSettings() async {
    return getOrCreate();
  }

  /// Save settings to database
  Future<void> saveSettings(AppSettings settings) async {
    await _isar.writeTxn(() async {
      await _isar.appSettings.put(settings);
    });
  }

  Future<void> setMaxStorageBytes(int? bytes) async {
    final s = await getOrCreate();
    s.maxStorageBytes = bytes;
    await _isar.writeTxn(() async {
      await _isar.appSettings.put(s);
    });
  }

  /// Set custom temp folder path for Android manga reader integration
  Future<void> setCustomTempFolderPath(String? path) async {
    final s = await getOrCreate();
    s.customTempFolderPath = path;
    await _isar.writeTxn(() async {
      await _isar.appSettings.put(s);
    });
  }

  Future<VaultStats> stats() async {
    final folders = await _isar.vaultFolders.where().anyId().findAll();
    final fileCount = await _isar.vaultFiles.where().anyId().count();
    // Use the O(1) running counter instead of scanning all files.
    final settings = await _isar.appSettings.where().anyId().findFirst();
    final total = settings?.totalBytesUsed ?? 0;
    return VaultStats(
      folderCount: folders.length,
      fileCount: fileCount,
      totalBytes: total,
    );
  }
}

