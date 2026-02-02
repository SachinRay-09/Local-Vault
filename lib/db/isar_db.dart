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
    return isar;
  }
}

