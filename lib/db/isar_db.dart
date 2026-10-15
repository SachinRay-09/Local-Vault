import 'dart:io';

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_settings.dart';
import '../models/file_tag.dart';
import '../models/operation_job.dart';
import '../models/operation_job_item.dart';
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
        OperationJobSchema,
        OperationJobItemSchema,
        FileTagSchema,
        FileTagAssignmentSchema,
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
    // Use a property query to sum only byteSize — avoids loading full objects
    // into memory for vaults with thousands of files (PERF-006).
    final sizes =
        await isar.vaultFiles.where().anyId().byteSizeProperty().findAll();
    var total = 0;
    for (final s in sizes) {
      total += s;
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
