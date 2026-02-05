import 'dart:io';
import 'dart:typed_data';

import 'package:isar/isar.dart';

import '../db/isar_db.dart';
import '../models/app_settings.dart';
import '../models/vault_file.dart';
import '../models/vault_folder.dart';
import 'file_crypto_service.dart';
import 'secure_storage_service.dart';
import 'vault_paths.dart';

class VaultRepository {
  VaultRepository({
    required this.crypto,
    required this.secureStorage,
  });

  final FileCryptoService crypto;
  final SecureStorageService secureStorage;

  Isar get _isar => IsarDb.instance;

  Future<List<VaultFolder>> listFolders({required int? parentId}) async {
    final q = parentId == null
        ? _isar.vaultFolders.filter().parentIdIsNull().sortByName()
        : _isar.vaultFolders.filter().parentIdEqualTo(parentId).sortByName();
    return q.findAll();
  }

  Future<List<VaultFile>> listFiles({
    required int? parentId,
    int? limit,
    int? offset,
  }) async {
    final baseQuery = parentId == null
        ? _isar.vaultFiles.filter().parentFolderIdIsNull()
        : _isar.vaultFiles.filter().parentFolderIdEqualTo(parentId);
    
    final sortedQuery = baseQuery.sortByOriginalName();
    
    if (offset != null && limit != null) {
      return sortedQuery.offset(offset).limit(limit).findAll();
    } else if (offset != null) {
      return sortedQuery.offset(offset).findAll();
    } else if (limit != null) {
      return sortedQuery.limit(limit).findAll();
    } else {
      return sortedQuery.findAll();
    }
  }

  Future<int> countFiles({required int? parentId}) async {
    final q = parentId == null
        ? _isar.vaultFiles.filter().parentFolderIdIsNull()
        : _isar.vaultFiles.filter().parentFolderIdEqualTo(parentId);
    return q.count();
  }

  Future<VaultFolder> createFolder({
    required String name,
    required int? parentId,
  }) async {
    final now = DateTime.now();
    final folder = VaultFolder()
      ..name = name
      ..parentId = parentId
      ..createdAt = now
      ..updatedAt = now;

    await _isar.writeTxn(() async {
      await _isar.vaultFolders.put(folder);
    });
    return folder;
  }

  Future<VaultFile> addMedia({
    required String originalName,
    required int? parentFolderId,
    required String? sourcePath,
    required Uint8List? bytes,
    String? mimeType,
  }) async {
    final settings = await _isar.appSettings.where().anyId().findFirst();
    final maxBytes = settings?.maxStorageBytes;

    final incomingBytes = sourcePath != null
        ? await File(sourcePath).length()
        : (bytes?.length ?? 0);

    if (maxBytes != null) {
      final allFiles = await _isar.vaultFiles.where().anyId().findAll();
      var used = 0;
      for (final f in allFiles) {
        used += f.byteSize;
      }
      if (used + incomingBytes > maxBytes) {
        throw StateError('Storage limit reached. Increase limit in Settings.');
      }
    }

    final masterKey32 = await secureStorage.getOrCreateMasterKey32();

    EncryptedBlobWriteResult writeResult;
    if (sourcePath != null) {
      writeResult = await crypto.encryptFileToBlob(
        sourceFile: File(sourcePath),
        masterKey32: masterKey32,
      );
    } else {
      final data = bytes ?? Uint8List(0);
      writeResult = await crypto.encryptAndWriteBlob(
        clearBytes: data,
        masterKey32: masterKey32,
      );
    }

    final file = VaultFile()
      ..parentFolderId = parentFolderId
      ..originalName = originalName
      ..storedBlobName = writeResult.storedBlobName
      ..byteSize = writeResult.byteSize
      ..mimeType = mimeType
      ..ivBase64 = writeResult.ivBase64
      ..createdAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.vaultFiles.put(file);
    });
    return file;
  }

  Future<void> renameFolder({
    required int folderId,
    required String newName,
  }) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) throw ArgumentError('Folder name cannot be empty.');

    final folder = await _isar.vaultFolders.get(folderId);
    if (folder == null) return;

    folder.name = trimmed;
    folder.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.vaultFolders.put(folder);
    });
  }

  Future<void> renameFile({
    required int fileId,
    required String newName,
  }) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) throw ArgumentError('File name cannot be empty.');

    final file = await _isar.vaultFiles.get(fileId);
    if (file == null) return;
    file.originalName = trimmed;
    await _isar.writeTxn(() async {
      await _isar.vaultFiles.put(file);
    });
  }

  Future<void> deleteFile({
    required int fileId,
  }) async {
    final file = await _isar.vaultFiles.get(fileId);
    if (file == null) return;

    await _isar.writeTxn(() async {
      await _isar.vaultFiles.delete(fileId);
    });

    // Best-effort delete blob on disk.
    try {
      final blobsDir = await VaultPaths.ensureVaultBlobsDir();
      final blob = File('${blobsDir.path}${Platform.pathSeparator}${file.storedBlobName}');
      if (await blob.exists()) {
        await blob.delete();
      }
    } catch (_) {}
  }

  Future<void> deleteFolderRecursive({
    required int folderId,
  }) async {
    // Collect descendants via iterative walk.
    final toVisit = <int>[folderId];
    final folderIds = <int>{folderId};
    final fileIds = <int>[];
    final blobNames = <String>[];

    while (toVisit.isNotEmpty) {
      final current = toVisit.removeLast();
      final childFolders = await _isar.vaultFolders.filter().parentIdEqualTo(current).findAll();
      for (final f in childFolders) {
        folderIds.add(f.id);
        toVisit.add(f.id);
      }

      final files = await _isar.vaultFiles.filter().parentFolderIdEqualTo(current).findAll();
      for (final vf in files) {
        fileIds.add(vf.id);
        blobNames.add(vf.storedBlobName);
      }
    }

    await _isar.writeTxn(() async {
      for (final id in fileIds) {
        await _isar.vaultFiles.delete(id);
      }
      for (final id in folderIds) {
        await _isar.vaultFolders.delete(id);
      }
    });

    // Best-effort delete blobs.
    try {
      final blobsDir = await VaultPaths.ensureVaultBlobsDir();
      for (final name in blobNames) {
        try {
          final blob = File('${blobsDir.path}${Platform.pathSeparator}$name');
          if (await blob.exists()) await blob.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<List<VaultFolder>> folderPathToRoot({required int folderId}) async {
    final path = <VaultFolder>[];
    var currentId = folderId;
    while (true) {
      final folder = await _isar.vaultFolders.get(currentId);
      if (folder == null) break;
      path.add(folder);
      final parent = folder.parentId;
      if (parent == null) break;
      currentId = parent;
    }
    return path.reversed.toList();
  }

  Future<List<VaultFolder>> searchFolders(String query, {int limit = 50}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    // Case-insensitive contains.
    return _isar.vaultFolders
        .filter()
        .nameContains(q, caseSensitive: false)
        .sortByName()
        .limit(limit)
        .findAll();
  }

  Future<List<VaultFile>> searchFiles(String query, {int limit = 50}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    return _isar.vaultFiles
        .filter()
        .originalNameContains(q, caseSensitive: false)
        .sortByOriginalName()
        .limit(limit)
        .findAll();
  }

  Future<void> moveFile({
    required int fileId,
    required int? newParentFolderId,
  }) async {
    final file = await _isar.vaultFiles.get(fileId);
    if (file == null) return;
    file.parentFolderId = newParentFolderId;
    await _isar.writeTxn(() async {
      await _isar.vaultFiles.put(file);
    });
  }

  Future<void> moveFolder({
    required int folderId,
    required int? newParentId,
  }) async {
    if (newParentId == folderId) {
      throw StateError('Cannot move a folder into itself.');
    }
    if (newParentId != null) {
      final invalid = await _isAncestorOrSelf(ancestorId: folderId, nodeId: newParentId);
      if (invalid) {
        throw StateError('Cannot move a folder into one of its subfolders.');
      }
    }

    final folder = await _isar.vaultFolders.get(folderId);
    if (folder == null) return;
    folder.parentId = newParentId;
    folder.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.vaultFolders.put(folder);
    });
  }

  Future<bool> _isAncestorOrSelf({required int ancestorId, required int nodeId}) async {
    var currentId = nodeId;
    while (true) {
      if (currentId == ancestorId) return true;
      final folder = await _isar.vaultFolders.get(currentId);
      if (folder == null) return false;
      final parent = folder.parentId;
      if (parent == null) return false;
      currentId = parent;
    }
  }

  /// Disposes resources (override in subclasses if needed)
  void dispose() {
    // Base implementation - override in subclasses
  }
}

