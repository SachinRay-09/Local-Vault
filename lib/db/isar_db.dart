import 'dart:io';

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_settings.dart';
import '../models/vault_file.dart';
import '../models/vault_folder.dart';
import '../services/vault_paths.dart';

class IsarDb {
  IsarDb._();

  static Isar? _isar;

  static Isar get instance {
    final db = _isar;
    if (db == null) {
      throw StateError('IsarDb not initialized. Call IsarDb.open() first.');
    }
    return db;
  }

  static Future<Isar> open() async {
    if (_isar != null) return _isar!;

    final Directory supportDir = await getApplicationSupportDirectory();
    final Directory blobsDir = await VaultPaths.ensureVaultBlobsDir();

    // Ensure directories exist (especially useful on desktop).
    await supportDir.create(recursive: true);
    await blobsDir.create(recursive: true);

    final isar = await Isar.open(
      [
        VaultFolderSchema,
        VaultFileSchema,
        AppSettingsSchema,
      ],
      directory: supportDir.path,
      name: 'local_vault',
    );

    _isar = isar;

    // Reconcile the storage counter on first open (when lastReconciledAt is null).
    // This handles files that were added before the running counter existed.
    final settings = await isar.appSettings.where().anyId().findFirst();
    if (settings == null || settings.lastReconciledAt == null) {
      await _reconcileStorageCounter(isar);
    }

    return isar;
  }

  /// Sums all VaultFile.byteSize values and writes the total to AppSettings.
  /// Called once on first open to seed the running counter from legacy data.
  static Future<void> _reconcileStorageCounter(Isar isar) async {
    final allFiles = await isar.vaultFiles.where().anyId().findAll();
    var total = 0;
    for (final f in allFiles) {
      total += f.byteSize;
    }
    final s =
        await isar.appSettings.where().anyId().findFirst() ?? AppSettings();
    s.totalBytesUsed = total;
    s.lastReconciledAt = DateTime.now();
    await isar.writeTxn(() async {
      await isar.appSettings.put(s);
    });
  }
}
