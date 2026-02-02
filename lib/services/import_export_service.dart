import 'dart:io';
import 'dart:math';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:isar/isar.dart';

import '../db/isar_db.dart';
import '../models/vault_file.dart';
import '../models/vault_folder.dart';
import 'file_crypto_service.dart';
import 'secure_storage_service.dart';
import 'vault_repository.dart';

class ExportAllResult {
  ExportAllResult({required this.zipPath, required this.password});

  final String zipPath;
  final String password;
}

class ImportResult {
  ImportResult({required this.foldersCreated, required this.filesImported});

  final int foldersCreated;
  final int filesImported;
}

class ImportExportService {
  ImportExportService({
    required this.repo,
    required this.crypto,
    required this.secureStorage,
  });

  final VaultRepository repo;
  final FileCryptoService crypto;
  final SecureStorageService secureStorage;

  Future<String?> pickExportPath() {
    return FilePicker.platform.saveFile(
      dialogTitle: 'Export vault',
      fileName: 'local_vault_export.zip',
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
  }

  Future<String?> pickImportZipPath() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import vault ZIP',
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.single.path;
  }

  Future<ExportAllResult> exportAllToZip({required String outputZipPath}) async {
    final password = _randomExportPassword();

    final staging = await Directory.systemTemp.createTemp('local_vault_export_');
    try {
      await _writeStagingFromDb(staging);

      final encoder = ZipFileEncoder(password: password);
      encoder.create(outputZipPath);
      await encoder.addDirectory(staging, includeDirName: false);
      await encoder.close();

      return ExportAllResult(zipPath: outputZipPath, password: password);
    } finally {
      try {
        await staging.delete(recursive: true);
      } catch (_) {}
    }
  }

  Future<ImportResult> importFromZip({
    required String zipPath,
    required String password,
    required int? destinationFolderId,
  }) async {
    final extractDir = await Directory.systemTemp.createTemp('local_vault_import_');
    try {
      await extractFileToDisk(zipPath, extractDir.path, password: password);
      return _importExtractedTree(extractDir, destinationFolderId: destinationFolderId);
    } finally {
      try {
        await extractDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  Future<void> _writeStagingFromDb(Directory stagingRoot) async {
    final isar = IsarDb.instance;
    // Use a filter query so `.findAll()` is available in this generated API.
    final folders = await isar.vaultFolders.filter().idGreaterThan(0).findAll();
    final files = await isar.vaultFiles.filter().idGreaterThan(0).findAll();

    final folderById = <int, VaultFolder>{for (final f in folders) f.id: f};
    final pathMemo = <int, String>{};

    String folderRelPath(int folderId) {
      final cached = pathMemo[folderId];
      if (cached != null) return cached;
      final folder = folderById[folderId];
      if (folder == null) return '';
      final parentId = folder.parentId;
      final parentPath = parentId == null ? '' : folderRelPath(parentId);
      final p = parentPath.isEmpty ? folder.name : '$parentPath/${folder.name}';
      pathMemo[folderId] = p;
      return p;
    }

    final masterKey32 = await secureStorage.getOrCreateMasterKey32();

    for (final file in files) {
      final relDir = file.parentFolderId == null ? '' : folderRelPath(file.parentFolderId!);
      final outDir = relDir.isEmpty ? stagingRoot : Directory('${stagingRoot.path}${Platform.pathSeparator}$relDir');
      await outDir.create(recursive: true);

      final outPath = _uniqueFilePath(outDir, file.originalName);
      await crypto.decryptBlobToFile(
        storedBlobName: file.storedBlobName,
        ivBase64: file.ivBase64,
        masterKey32: masterKey32,
        outputFile: File(outPath),
      );
    }
  }

  Future<ImportResult> _importExtractedTree(
    Directory extractRoot, {
    required int? destinationFolderId,
  }) async {
    // Map relative directory path -> vault folder id
    final folderIdByRelPath = <String, int?>{'': destinationFolderId};

    final directories = <Directory>[];
    final files = <File>[];

    await for (final entity in extractRoot.list(recursive: true, followLinks: false)) {
      if (entity is Directory) directories.add(entity);
      if (entity is File) files.add(entity);
    }

    // Create folders in increasing depth order.
    directories.sort((a, b) => a.path.length.compareTo(b.path.length));
    var foldersCreated = 0;
    for (final dir in directories) {
      final rel = _relativePath(extractRoot.path, dir.path);
      if (rel.isEmpty) continue;
      final parentRel = _parentRelPath(rel);
      final parentId = folderIdByRelPath[parentRel] ?? destinationFolderId;
      final name = _basename(rel);
      final created = await repo.createFolder(name: name, parentId: parentId);
      folderIdByRelPath[rel] = created.id;
      foldersCreated++;
    }

    var filesImported = 0;
    for (final f in files) {
      final rel = _relativePath(extractRoot.path, f.path);
      final parentRel = _parentRelPath(rel);
      final parentId = folderIdByRelPath[parentRel] ?? destinationFolderId;
      final name = _basename(rel);
      await repo.addMedia(
        originalName: name,
        parentFolderId: parentId,
        sourcePath: f.path,
        bytes: null,
      );
      filesImported++;
    }

    return ImportResult(foldersCreated: foldersCreated, filesImported: filesImported);
  }

  static String _uniqueFilePath(Directory dir, String desiredName) {
    final sep = Platform.pathSeparator;
    final base = desiredName;
    var candidate = '${dir.path}$sep$base';
    if (!File(candidate).existsSync()) return candidate;

    final dot = base.lastIndexOf('.');
    final name = dot > 0 ? base.substring(0, dot) : base;
    final ext = dot > 0 ? base.substring(dot) : '';

    var i = 1;
    while (true) {
      candidate = '${dir.path}$sep$name ($i)$ext';
      if (!File(candidate).existsSync()) return candidate;
      i++;
    }
  }

  static String _relativePath(String root, String full) {
    var r = root;
    if (!r.endsWith(Platform.pathSeparator)) r = '$r${Platform.pathSeparator}';
    var rel = full.startsWith(r) ? full.substring(r.length) : full;
    rel = rel.replaceAll('\\', '/');
    return rel;
  }

  static String _parentRelPath(String rel) {
    final cleaned = rel.replaceAll('\\', '/');
    final idx = cleaned.lastIndexOf('/');
    if (idx <= 0) return '';
    return cleaned.substring(0, idx);
  }

  static String _basename(String rel) {
    final cleaned = rel.replaceAll('\\', '/');
    final idx = cleaned.lastIndexOf('/');
    return idx >= 0 ? cleaned.substring(idx + 1) : cleaned;
  }

  static String _randomExportPassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    final r = Random.secure();
    final buf = StringBuffer();
    for (var i = 0; i < 12; i++) {
      buf.write(chars[r.nextInt(chars.length)]);
      if (i == 3 || i == 7) buf.write('-');
    }
    return buf.toString();
  }
}

