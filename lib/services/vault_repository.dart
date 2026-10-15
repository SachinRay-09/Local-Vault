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
        ? _isar.vaultFolders.filter().parentIdIsNull()
        : _isar.vaultFolders.filter().parentIdEqualTo(parentId);
    final folders = await q.findAll();

    // Apply natural sort for proper numeric ordering (1, 2, 3... 10... 100)
    // This ensures folders named "1.folder", "2.folder", "10.folder" sort correctly
    folders.sort((a, b) => _compareNatural(a.name, b.name));

    return folders;
  }

  Future<List<VaultFile>> listFiles({
    required int? parentId,
    int? limit,
    int? offset,
  }) async {
    final baseQuery = parentId == null
        ? _isar.vaultFiles.filter().parentFolderIdIsNull()
        : _isar.vaultFiles.filter().parentFolderIdEqualTo(parentId);

    List<VaultFile> files;
    if (offset != null && limit != null) {
      files = await baseQuery
          .sortBySortOrder()
          .offset(offset)
          .limit(limit)
          .findAll();
    } else if (offset != null) {
      files = await baseQuery.sortBySortOrder().offset(offset).findAll();
    } else if (limit != null) {
      files = await baseQuery.sortBySortOrder().limit(limit).findAll();
    } else {
      files = await baseQuery.sortBySortOrder().findAll();
    }

    // Sorted by sortOrder - preserves original file system order
    return files;
  }

  /// Natural/alphanumeric comparison for proper sorting (1, 2, 3... 10... 100)
  /// Based on "The Alphanum Algorithm" - http://www.davekoelle.com/alphanum.html
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
    // Load settings once — used for both the storage cap check and the counter update.
    AppSettings settings =
        await _isar.appSettings.where().anyId().findFirst() ?? AppSettings();

    final maxBytes = settings.maxStorageBytes;

    final incomingBytes = sourcePath != null
        ? await File(sourcePath).length()
        : (bytes?.length ?? 0);

    // O(1) storage cap check — use the running counter instead of a full scan.
    if (maxBytes != null) {
      if (settings.totalBytesUsed + incomingBytes > maxBytes) {
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

    // Get the next sortOrder for this folder
    final maxSortOrder = await _getMaxSortOrder(parentFolderId);

    final file = VaultFile()
      ..parentFolderId = parentFolderId
      ..originalName = originalName
      ..storedBlobName = writeResult.storedBlobName
      ..byteSize = writeResult.byteSize
      ..mimeType = mimeType
      ..ivBase64 = writeResult.ivBase64
      ..createdAt = DateTime.now()
      ..sortOrder = maxSortOrder + 1;

    // Update the running counter in the same transaction.
    settings.totalBytesUsed += writeResult.byteSize;

    await _isar.writeTxn(() async {
      await _isar.vaultFiles.put(file);
      await _isar.appSettings.put(settings);
    });
    return file;
  }

  /// Get the maximum sortOrder for files in a folder
  Future<int> _getMaxSortOrder(int? parentFolderId) async {
    final query = parentFolderId == null
        ? _isar.vaultFiles.filter().parentFolderIdIsNull()
        : _isar.vaultFiles.filter().parentFolderIdEqualTo(parentFolderId);

    final files = await query.sortBySortOrderDesc().limit(1).findAll();
    return files.isEmpty ? -1 : files.first.sortOrder;
  }

  /// Batch save multiple files to database (for import optimization)
  /// Files should already have encrypted blobs written to disk
  Future<void> batchSaveFiles(List<VaultFile> files) async {
    if (files.isEmpty) return;

    await _isar.writeTxn(() async {
      await _isar.vaultFiles.putAll(files);
    });
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

    // Decrement the running counter in the same transaction.
    final settings =
        await _isar.appSettings.where().anyId().findFirst() ?? AppSettings();
    settings.totalBytesUsed = (settings.totalBytesUsed - file.byteSize)
        .clamp(0, double.maxFinite.toInt());

    await _isar.writeTxn(() async {
      await _isar.vaultFiles.delete(fileId);
      await _isar.appSettings.put(settings);
    });

    // Best-effort delete blob on disk.
    try {
      final blobsDir = await VaultPaths.ensureVaultBlobsDir();
      final blob = File(
          '${blobsDir.path}${Platform.pathSeparator}${file.storedBlobName}');
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

    var totalDeletedBytes = 0;

    while (toVisit.isNotEmpty) {
      final current = toVisit.removeLast();
      final childFolders =
          await _isar.vaultFolders.filter().parentIdEqualTo(current).findAll();
      for (final f in childFolders) {
        folderIds.add(f.id);
        toVisit.add(f.id);
      }

      final files = await _isar.vaultFiles
          .filter()
          .parentFolderIdEqualTo(current)
          .findAll();
      for (final vf in files) {
        fileIds.add(vf.id);
        blobNames.add(vf.storedBlobName);
        totalDeletedBytes += vf.byteSize;
      }
    }

    // Decrement the running storage counter in the same transaction.
    final settings =
        await _isar.appSettings.where().anyId().findFirst() ?? AppSettings();
    settings.totalBytesUsed = (settings.totalBytesUsed - totalDeletedBytes)
        .clamp(0, double.maxFinite.toInt());

    await _isar.writeTxn(() async {
      for (final id in fileIds) {
        await _isar.vaultFiles.delete(id);
      }
      for (final id in folderIds) {
        await _isar.vaultFolders.delete(id);
      }
      await _isar.appSettings.put(settings);
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

  Future<List<VaultFolder>> searchFolders(String query,
      {int limit = 50}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    // Case-insensitive contains - no sorting, preserve original order
    final folders = await _isar.vaultFolders
        .filter()
        .nameContains(q, caseSensitive: false)
        .limit(limit)
        .findAll();
    return folders;
  }

  Future<List<VaultFile>> searchFiles(String query, {int limit = 50}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final files = await _isar.vaultFiles
        .filter()
        .originalNameContains(q, caseSensitive: false)
        .sortBySortOrder() // Sort by sortOrder to preserve file system order
        .limit(limit)
        .findAll();
    return files;
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
      final invalid =
          await _isAncestorOrSelf(ancestorId: folderId, nodeId: newParentId);
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

  /// Batch move multiple folders to a new parent
  /// Validates that no folder is moved into itself or its descendants
  Future<void> batchMoveFolders({
    required List<int> folderIds,
    required int? newParentId,
  }) async {
    if (folderIds.isEmpty) return;

    // Validate each folder
    for (final folderId in folderIds) {
      if (newParentId == folderId) {
        throw StateError('Cannot move a folder into itself.');
      }
      if (newParentId != null) {
        final invalid =
            await _isAncestorOrSelf(ancestorId: folderId, nodeId: newParentId);
        if (invalid) {
          throw StateError('Cannot move a folder into one of its subfolders.');
        }
      }
    }

    // Batch update in single transaction for performance
    await _isar.writeTxn(() async {
      final now = DateTime.now();
      for (final folderId in folderIds) {
        final folder = await _isar.vaultFolders.get(folderId);
        if (folder != null) {
          folder.parentId = newParentId;
          folder.updatedAt = now;
          await _isar.vaultFolders.put(folder);
        }
      }
    });
  }

  Future<bool> _isAncestorOrSelf(
      {required int ancestorId, required int nodeId}) async {
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

  /// Natural/alphanumeric comparison for proper sorting (1, 2, 3... 10... 100)
  /// Based on "The Alphanum Algorithm" - http://www.davekoelle.com/alphanum.html
  /// This ensures folders named "1.folder", "2.folder", "10.folder" sort correctly
  int _compareNatural(String a, String b) {
    final aLower = a.toLowerCase();
    final bLower = b.toLowerCase();

    int aIndex = 0;
    int bIndex = 0;

    while (aIndex < aLower.length && bIndex < bLower.length) {
      final aChar = aLower[aIndex];
      final bChar = bLower[bIndex];

      // Check if both are digits
      if (_isDigit(aChar) && _isDigit(bChar)) {
        // Extract full numbers
        final aNum = _extractNumber(aLower, aIndex);
        final bNum = _extractNumber(bLower, bIndex);

        // Compare numbers numerically
        if (aNum.value != bNum.value) {
          return aNum.value.compareTo(bNum.value);
        }

        // Move indices past the numbers
        aIndex = aNum.endIndex;
        bIndex = bNum.endIndex;
      } else {
        // Compare characters normally
        if (aChar != bChar) {
          return aChar.compareTo(bChar);
        }
        aIndex++;
        bIndex++;
      }
    }

    // If one string is a prefix of the other
    return aLower.length.compareTo(bLower.length);
  }

  bool _isDigit(String char) {
    return char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57;
  }

  _NumberExtraction _extractNumber(String str, int startIndex) {
    int endIndex = startIndex;
    while (endIndex < str.length && _isDigit(str[endIndex])) {
      endIndex++;
    }
    final numStr = str.substring(startIndex, endIndex);
    return _NumberExtraction(
      value: int.parse(numStr),
      endIndex: endIndex,
    );
  }

  /// Recomputes `AppSettings.totalBytesUsed` by summing all VaultFile rows.
  /// Call on startup when `lastReconciledAt` is null to handle files that were
  /// added before the running counter existed.
  Future<void> reconcileStorageCounter() async {
    final allFiles = await _isar.vaultFiles.where().anyId().findAll();
    var total = 0;
    for (final f in allFiles) {
      total += f.byteSize;
    }

    final settings =
        await _isar.appSettings.where().anyId().findFirst() ?? AppSettings();
    settings.totalBytesUsed = total;
    settings.lastReconciledAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.appSettings.put(settings);
    });
  }

  /// Disposes resources (override in subclasses if needed)
  void dispose() {
    // Base implementation - override in subclasses
  }
}

/// Helper class for natural sort number extraction
class _NumberExtraction {
  _NumberExtraction({required this.value, required this.endIndex});

  final int value;
  final int endIndex;
}
