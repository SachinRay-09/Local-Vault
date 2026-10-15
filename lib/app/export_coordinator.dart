import 'dart:io';
import 'dart:math';

import 'package:isar/isar.dart';
import 'package:path/path.dart' as path;

import '../db/isar_db.dart';
import '../models/operation_job.dart';
import '../models/vault_file.dart';
import '../models/vault_folder.dart';
import '../services/archive_writer.dart';
import '../services/file_crypto_service.dart';
import '../services/job_repository.dart';
import '../services/secure_storage_service.dart';
import '../services/vault_repository.dart';
import 'job_runner.dart';

/// Progress snapshot emitted by [ExportCoordinator.exportFolder].
class ExportProgress {
  const ExportProgress({
    required this.completedFiles,
    required this.totalFiles,
    required this.processedBytes,
    required this.totalBytes,
  });

  final int completedFiles;
  final int totalFiles;
  final int processedBytes;
  final int totalBytes;
}

/// Exports a vault folder subtree to a ZIP file, decrypting ONE file at a
/// time into a temp path and deleting the plaintext immediately after it has
/// been added to the archive (fixes B3).
///
/// Windows-only — asserted in the constructor.
class ExportCoordinator {
  ExportCoordinator({
    required this.repo,
    required this.crypto,
    required this.storage,
    required this.jobRepo,
  }) : assert(Platform.isWindows, 'ExportCoordinator is Windows-only');

  final VaultRepository repo;
  final FileCryptoService crypto;
  final SecureStorageService storage;
  final JobRepository jobRepo;

  /// Exports the folder identified by [folderId] and all its descendants to
  /// the ZIP at [destinationZipPath].
  ///
  /// Only the target subtree is queried — not every folder in the vault.
  /// Each file is decrypted to a unique temp path, added to the ZIP, then
  /// deleted before the next file is processed.
  Stream<ExportProgress> exportFolder(
    int folderId,
    String destinationZipPath, {
    CancellationToken? token,
  }) async* {
    final isar = IsarDb.instance;

    // ------------------------------------------------------------------ //
    // 1. BFS to collect descendant folder ids (target subtree only)
    //    — delegated to a plain async helper to avoid QueryBuilder
    //    inference issues inside async* generators.
    // ------------------------------------------------------------------ //
    final descendantIds = await _collectDescendantIds(isar, folderId);

    // ------------------------------------------------------------------ //
    // 2. Collect files in the subtree
    // ------------------------------------------------------------------ //
    final files = await _collectFilesInSubtree(isar, descendantIds);

    if (files.isEmpty) {
      // Nothing to export — create an empty ZIP and return.
      final writer = ArchiveWriter(destinationZipPath);
      await writer.open();
      await writer.close();
      return;
    }

    var totalBytes = 0;
    for (final f in files) {
      totalBytes += f.byteSize;
    }

    // ------------------------------------------------------------------ //
    // 3. Create OperationJob record
    // ------------------------------------------------------------------ //
    final now = DateTime.now();
    final job = OperationJob()
      ..type = JobType.export
      ..state = JobState.queued
      ..totalItems = files.length
      ..completedItems = 0
      ..totalBytes = totalBytes
      ..processedBytes = 0
      ..createdAt = now
      ..destinationDescriptor = destinationZipPath;
    await jobRepo.createJob(job);
    await jobRepo.markJobState(job.id, JobState.running);

    // ------------------------------------------------------------------ //
    // 4. Build folder-path memo for relative entry paths inside the ZIP
    // ------------------------------------------------------------------ //
    // Load only the folders in the subtree.
    final folderMap = await _loadFolderMap(isar, descendantIds);

    // Relative path from the root folder of the export.
    final pathMemo = <int, String>{};

    String folderRelPath(int id) {
      final cached = pathMemo[id];
      if (cached != null) return cached;
      final folder = folderMap[id];
      if (folder == null) return '';
      final parentId = folder.parentId;
      // If parent is outside our subtree (or null), this IS the root.
      if (parentId == null || !descendantIds.contains(parentId)) {
        pathMemo[id] = folder.name;
        return folder.name;
      }
      final parentPath = folderRelPath(parentId);
      final p = '$parentPath/${folder.name}';
      pathMemo[id] = p;
      return p;
    }

    // ------------------------------------------------------------------ //
    // 5. Open archive, process files one at a time
    // ------------------------------------------------------------------ //
    final masterKey = await storage.getOrCreateMasterKey32();
    final writer = ArchiveWriter(destinationZipPath);
    await writer.open();

    var completedFiles = 0;
    var processedBytes = 0;

    try {
      for (final file in files) {
        // Cancellation check.
        if (token?.isCancelled ?? false) {
          await jobRepo.markJobState(job.id, JobState.cancelled);
          return;
        }

        // Unique temp file path — one plaintext on disk at a time (fixes B3).
        final tempPath = path.join(
          Directory.systemTemp.path,
          'lv_export_${_randomHex(8)}.tmp',
        );

        try {
          // Decrypt blob → temp file.
          await crypto.decryptBlobToFile(
            storedBlobName: file.storedBlobName,
            ivBase64: file.ivBase64,
            masterKey32: masterKey,
            outputFile: File(tempPath),
          );

          // Compute entry path inside ZIP.
          final folderRel = file.parentFolderId != null
              ? folderRelPath(file.parentFolderId!)
              : '';
          final entryName = folderRel.isEmpty
              ? file.originalName
              : '$folderRel/${file.originalName}';

          // Add to ZIP.
          await writer.addFile(entryName, tempPath);
        } finally {
          // Delete the temp plaintext file regardless of success or failure.
          try {
            final tmp = File(tempPath);
            if (tmp.existsSync()) tmp.deleteSync();
          } catch (_) {}
        }

        completedFiles++;
        processedBytes += file.byteSize;

        yield ExportProgress(
          completedFiles: completedFiles,
          totalFiles: files.length,
          processedBytes: processedBytes,
          totalBytes: totalBytes,
        );
      }
    } finally {
      await writer.close();
    }

    await jobRepo.markJobState(job.id, JobState.completed);
  }

  // -----------------------------------------------------------------------
  // Private static helpers — extracted from the async* generator so Isar
  // queries run inside plain async functions where QueryBuilder type
  // inference is unambiguous.
  // -----------------------------------------------------------------------

  static Future<Set<int>> _collectDescendantIds(Isar isar, int rootId) async {
    final descendantIds = <int>{rootId};
    final toVisit = <int>[rootId];
    while (toVisit.isNotEmpty) {
      final current = toVisit.removeLast();
      final children =
          await isar.vaultFolders.filter().parentIdEqualTo(current).findAll();
      for (final child in children) {
        if (descendantIds.add(child.id)) {
          toVisit.add(child.id);
        }
      }
    }
    return descendantIds;
  }

  static Future<List<VaultFile>> _collectFilesInSubtree(
    Isar isar,
    Set<int> ids,
  ) async {
    final files = <VaultFile>[];
    for (final id in ids) {
      final folderFiles =
          await isar.vaultFiles.filter().parentFolderIdEqualTo(id).findAll();
      files.addAll(folderFiles);
    }
    return files;
  }

  static Future<Map<int, VaultFolder>> _loadFolderMap(
    Isar isar,
    Set<int> ids,
  ) async {
    final map = <int, VaultFolder>{};
    for (final id in ids) {
      final folder = await isar.vaultFolders.get(id);
      if (folder != null) map[id] = folder;
    }
    return map;
  }

  static String _randomHex(int bytes) {
    final r = Random.secure();
    return List<int>.generate(bytes, (_) => r.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
