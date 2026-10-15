import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../app/auth_session.dart';
import '../models/operation_job.dart';
import '../models/operation_job_item.dart';
import '../platform/android/android_thermal_monitor.dart';
import '../services/archive_reader.dart';
import '../services/blob_store.dart';
import '../services/crypto_engine.dart';
import '../services/job_repository.dart';
import '../services/secure_storage_service.dart';
import '../services/vault_repository.dart';
import 'job_runner.dart';

/// Progress snapshot emitted by [ImportCoordinator.importFolder].
class ImportProgress {
  const ImportProgress({
    required this.completedFiles,
    required this.totalFiles,
    required this.processedBytes,
    required this.totalBytes,
    required this.currentFile,
    required this.jobId,
  });

  final int completedFiles;
  final int totalFiles;
  final int processedBytes;
  final int totalBytes;
  final String currentFile;
  final int jobId;
}

/// Supported image/video extensions (mirrors BulkImportService).
const _kImageExtensions = <String>[
  '.jpg',
  '.jpeg',
  '.png',
  '.gif',
  '.bmp',
  '.webp',
  '.svg',
  '.apng',
  '.avif',
];
const _kVideoExtensions = <String>['.mp4', '.mkv', '.avi'];

/// Orchestrates folder imports using [JobRunner] so that each file is
/// encrypted one at a time and the database is updated atomically.
class ImportCoordinator {
  ImportCoordinator({
    required this.repo,
    required this.jobRepo,
    required this.blobStore,
    required this.crypto,
    required this.storage,
    this.thermalMonitor,
  });

  final VaultRepository repo;
  final JobRepository jobRepo;
  final BlobStore blobStore;
  final CryptoEngine crypto;
  final SecureStorageService storage;
  final AndroidThermalMonitor? thermalMonitor;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Imports all supported files under [sourceFolderPath] into the vault,
  /// placing them under [parentFolderId] (null = vault root).
  ///
  /// Yields an [ImportProgress] event after every encrypted file.
  Stream<ImportProgress> importFolder(
    String sourceFolderPath,
    int? parentFolderId, {
    bool includeVideo = false,
    Function(String)? onStatus,
  }) async* {
    final sourceDir = Directory(sourceFolderPath);
    if (!sourceDir.existsSync()) {
      throw ArgumentError('Source folder does not exist: $sourceFolderPath');
    }

    // ------------------------------------------------------------------ //
    // 1. Enumerate files
    // ------------------------------------------------------------------ //
    onStatus?.call('Scanning files…');
    final allFiles = await _getAllFiles(sourceDir, includeVideo: includeVideo);

    var totalBytes = 0;
    for (final f in allFiles) {
      totalBytes += f.file.lengthSync();
    }

    // ------------------------------------------------------------------ //
    // 2. Create root vault folder
    // ------------------------------------------------------------------ //
    onStatus?.call('Creating folder structure…');
    final rootFolderName = path.basename(sourceFolderPath);
    final rootFolder = await repo.createFolder(
      name: rootFolderName,
      parentId: parentFolderId,
    );

    // ------------------------------------------------------------------ //
    // 3. Create OperationJob
    // ------------------------------------------------------------------ //
    final now = DateTime.now();
    final job = OperationJob()
      ..type = JobType.import
      ..state = JobState.queued
      ..totalItems = allFiles.length
      ..completedItems = 0
      ..totalBytes = totalBytes
      ..processedBytes = 0
      ..createdAt = now
      ..sourceDescriptor = sourceFolderPath;
    await jobRepo.createJob(job);

    // ------------------------------------------------------------------ //
    // 4. Build OperationJobItem list (resolve folder structure first)
    // ------------------------------------------------------------------ //
    // folderCache maps relative dir path → vault folder id
    final folderCache = <String, int>{'': rootFolder.id};

    // Build all items first, then batch-insert in a single transaction
    // to avoid N individual write transactions for large folder imports (PERF-003).
    final jobItems = <OperationJobItem>[];
    for (final fileInfo in allFiles) {
      final relDir = path.dirname(fileInfo.relativePath);
      final leafFolderId = (relDir == '.' || relDir == '')
          ? rootFolder.id
          : await _ensureFolderStructure(relDir, rootFolder.id, folderCache);

      final item = OperationJobItem()
        ..jobId = job.id
        ..state = JobItemState.pending
        ..sourcePath = fileInfo.file.path
        ..blobId = _randomBlobId()
        ..partialBlobPath = null
        ..sourceSizeBytes = fileInfo.file.lengthSync()
        ..parentFolderId = leafFolderId;
      jobItems.add(item);
    }
    await jobRepo.createJobItems(jobItems);

    // ------------------------------------------------------------------ //
    // 5. Delegate to JobRunner
    // ------------------------------------------------------------------ //
    // Prefer the in-memory DEK from the active session (OPT-001/CRASH-005).
    final masterKey =
        AuthSession.current?.dek ?? await storage.getOrCreateMasterKey32();
    final runner = JobRunner(
      blobStore: blobStore,
      crypto: crypto,
      repo: repo,
      jobRepo: jobRepo,
      thermalMonitor: thermalMonitor,
    );

    await for (final progress in runner.run(job, masterKey)) {
      onStatus?.call('Importing ${path.basename(progress.currentFile)}…');
      yield ImportProgress(
        completedFiles: progress.completedItems,
        totalFiles: progress.totalItems,
        processedBytes: progress.processedBytes,
        totalBytes: progress.totalBytes,
        currentFile: progress.currentFile,
        jobId: job.id,
      );
    }

    // Mark completed (JobRunner already marks the job record, but update our
    // copy of totalItems/processedBytes for the final event).
    onStatus?.call('Import complete.');
  }

  /// Imports all files inside the ZIP at [zipPath] into the vault, placing
  /// them under [destinationFolderId] (null = vault root).
  ///
  /// Uses [ArchiveReader] for memory-efficient streaming of unprotected ZIPs
  /// (fixes B1: all imports go through [VaultRepository.addEncryptedBlobRecord]
  /// which always updates [AppSettings.totalBytesUsed]).
  ///
  /// Each entry's plaintext temp file is deleted immediately after it is
  /// encrypted — only one plaintext file exists on disk at a time.
  Stream<ImportProgress> importZip(
    String zipPath,
    int? destinationFolderId, {
    String password = '',
    Function(String)? onStatus,
  }) async* {
    onStatus?.call('Opening ZIP…');

    // ------------------------------------------------------------------ //
    // 1. First-pass: count entries (needed for job.totalItems).
    //    We stream twice only if needed; for a first pass we just count.
    //    To avoid a double-open, we materialise a lightweight list of names.
    // ------------------------------------------------------------------ //
    // For simplicity, create a job with totalItems=0 and update as we go.
    // This is acceptable for Phase 2/3 — progress fraction will still work
    // for already-processed items.

    final now = DateTime.now();
    final job = OperationJob()
      ..type = JobType.import
      ..state = JobState.queued
      ..totalItems = 0
      ..completedItems = 0
      ..totalBytes = 0
      ..processedBytes = 0
      ..createdAt = now
      ..sourceDescriptor = zipPath;
    await jobRepo.createJob(job);
    await jobRepo.markJobState(job.id, JobState.running);

    // Prefer the in-memory DEK from the active session (OPT-001/CRASH-005).
    final masterKey =
        AuthSession.current?.dek ?? await storage.getOrCreateMasterKey32();
    final reader = ArchiveReader();

    var completedFiles = 0;
    var processedBytes = 0;
    var totalFiles = 0;
    var totalBytes = 0;

    // folderCache: relative dir path (using '/') → vault folder id
    final folderCache = <String, int>{};
    if (destinationFolderId != null) {
      folderCache[''] = destinationFolderId;
    }

    try {
      await for (final e in reader.entries(zipPath, password: password)) {
        if (e is ArchiveEntrySkipped) {
          debugPrint(
              '[ImportCoordinator.importZip] skipped "${e.name}": ${e.reason}');
          continue;
        }

        if (e is! ArchiveEntry) continue;

        totalFiles += 1;
        totalBytes += e.sizeBytes;

        onStatus?.call('Importing ${path.basename(e.name)}…');

        // ------------------------------------------------------------ //
        // 2. Resolve vault folder for this entry
        // ------------------------------------------------------------ //
        final relDir = _zipEntryRelDir(e.name);
        final leafFolderId = await _ensureZipFolderStructure(
          relDir,
          destinationFolderId,
          folderCache,
        );

        // ------------------------------------------------------------ //
        // 3. Create job item record
        // ------------------------------------------------------------ //
        // NOTE: importZip runs its own inline encrypt-commit loop and does NOT
        // delegate to JobRunner. Items are therefore created directly in the
        // 'running' state. This is intentional: JobRunner.findPendingItems
        // only processes 'pending' items, and these items should never be
        // re-processed by JobRunner. The crash-recovery path in app.dart uses
        // findPendingOrRunningItems so these items ARE swept by recovery.
        final blobId = _randomBlobId();
        final item = OperationJobItem()
          ..jobId = job.id
          ..state = JobItemState.running
          ..sourcePath = e.tempPath
          ..blobId = blobId
          ..partialBlobPath = null
          ..sourceSizeBytes = e.sizeBytes
          ..parentFolderId = leafFolderId;
        await jobRepo.createJobItem(item);

        // ------------------------------------------------------------ //
        // 4. Encrypt → commit blob → register DB record
        // ------------------------------------------------------------ //
        try {
          final partialPath = await blobStore.createPartialPath(blobId);
          // Persist partialPath so crash-recovery can clean up the partial
          // blob if the app is killed before commitPartial is called (ZIP-001).
          await jobRepo.saveItemPartialPath(item.id, partialPath);

          final encryptResult = await crypto.encryptFile(
            sourcePath: e.tempPath,
            destPath: partialPath,
            key: masterKey,
          );

          // Delete the plaintext temp file BEFORE processing the next entry.
          try {
            File(e.tempPath).deleteSync();
          } catch (_) {}

          await blobStore.commitPartial(blobId);

          await repo.addEncryptedBlobRecord(
            originalName: path.basename(e.name),
            parentFolderId: leafFolderId,
            blobId: blobId,
            ivBase64: encryptResult.ivBase64,
            byteSize: encryptResult.byteSize,
            formatVersion: encryptResult.formatVersion,
          );

          await jobRepo.markJobItemState(item.id, JobItemState.completed);

          completedFiles += 1;
          processedBytes += e.sizeBytes;

          yield ImportProgress(
            completedFiles: completedFiles,
            totalFiles: totalFiles,
            processedBytes: processedBytes,
            totalBytes: totalBytes,
            currentFile: e.name,
            jobId: job.id,
          );
        } catch (err) {
          // Clean up temp file on error.
          try {
            File(e.tempPath).deleteSync();
          } catch (_) {}
          await jobRepo.markJobItemState(
            item.id,
            JobItemState.failed,
            failureReason: err.toString(),
          );
          debugPrint('[ImportCoordinator.importZip] item failed: $err');
          // Continue to next entry rather than aborting.
        }
      }

      await jobRepo.markJobState(job.id, JobState.completed);
      onStatus?.call('Import complete.');
    } catch (e) {
      await jobRepo.markJobState(job.id, JobState.failed);
      rethrow;
    }
  }

  /// Imports a list of individual [filePaths] into the vault under
  /// [parentFolderId].  Each file is grouped by the last directory component
  /// of its path so that files from the same source folder are placed together.
  ///
  /// This is the mobile-compatible counterpart to [importFolder] — it accepts
  /// individual file paths from a multi-file picker rather than a directory.
  Stream<ImportProgress> importFileList(
    List<String> filePaths,
    int? parentFolderId, {
    String folderName = 'Imported_Folder',
    Function(String)? onStatus,
  }) async* {
    if (filePaths.isEmpty) return;

    onStatus?.call('Preparing import…');

    var totalBytes = 0;
    final validPaths = <String>[];
    for (final p in filePaths) {
      final f = File(p);
      if (f.existsSync()) {
        totalBytes += f.lengthSync();
        validPaths.add(p);
      }
    }

    if (validPaths.isEmpty) {
      throw ArgumentError('No accessible files in the provided list.');
    }

    // Create a root folder for this import.
    onStatus?.call('Creating folder structure…');
    final rootFolder = await repo.createFolder(
      name: folderName,
      parentId: parentFolderId,
    );

    // Create OperationJob.
    final now = DateTime.now();
    final job = OperationJob()
      ..type = JobType.import
      ..state = JobState.queued
      ..totalItems = validPaths.length
      ..completedItems = 0
      ..totalBytes = totalBytes
      ..processedBytes = 0
      ..createdAt = now
      ..sourceDescriptor = 'file-list:${validPaths.length}';
    await jobRepo.createJob(job);

    // Create job items.
    for (final filePath in validPaths) {
      final item = OperationJobItem()
        ..jobId = job.id
        ..state = JobItemState.pending
        ..sourcePath = filePath
        ..blobId = _randomBlobId()
        ..partialBlobPath = null
        ..sourceSizeBytes = File(filePath).lengthSync()
        ..parentFolderId = rootFolder.id;
      await jobRepo.createJobItem(item);
    }

    // Delegate to JobRunner.
    // Prefer the in-memory DEK from the active session (OPT-001/CRASH-005).
    final masterKey =
        AuthSession.current?.dek ?? await storage.getOrCreateMasterKey32();
    final runner = JobRunner(
      blobStore: blobStore,
      crypto: crypto,
      repo: repo,
      jobRepo: jobRepo,
      thermalMonitor: thermalMonitor,
    );

    await for (final progress in runner.run(job, masterKey)) {
      onStatus?.call('Importing ${path.basename(progress.currentFile)}…');
      yield ImportProgress(
        completedFiles: progress.completedItems,
        totalFiles: progress.totalItems,
        processedBytes: progress.processedBytes,
        totalBytes: progress.totalBytes,
        currentFile: progress.currentFile,
        jobId: job.id,
      );
    }

    onStatus?.call('Import complete.');
  }

  /// Enumerates supported files from [dir] recursively, sorted naturally.
  Future<List<_FileInfo>> _getAllFiles(
    Directory dir, {
    bool includeVideo = false,
  }) async {
    final supported = [
      ..._kImageExtensions,
      if (includeVideo) ..._kVideoExtensions,
    ];

    final files = <_FileInfo>[];
    final basePath = dir.path;

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final ext = path.extension(entity.path).toLowerCase();
        if (supported.contains(ext)) {
          final relativePath = path.relative(entity.path, from: basePath);
          files.add(_FileInfo(file: entity, relativePath: relativePath));
        }
      }
    }

    files.sort((a, b) => _compareNatural(a.relativePath, b.relativePath));
    return files;
  }

  /// Ensures all segments of [folderPath] exist in the vault under
  /// [rootFolderId], creating missing folders as needed.
  /// Returns the id of the deepest folder.
  Future<int> _ensureFolderStructure(
    String folderPath,
    int rootFolderId,
    Map<String, int> cache,
  ) async {
    final parts = path.split(folderPath);
    var currentParentId = rootFolderId;
    var accumulated = '';

    for (final part in parts) {
      if (part.isEmpty || part == '.') continue;

      final key = accumulated.isEmpty ? part : '$accumulated/$part';
      final cached = cache[key];
      if (cached != null) {
        currentParentId = cached;
        accumulated = key;
        continue;
      }

      final existing = await repo.listFolders(parentId: currentParentId);
      final match = existing.where((f) => f.name == part).firstOrNull;
      if (match != null) {
        cache[key] = match.id;
        currentParentId = match.id;
      } else {
        final created =
            await repo.createFolder(name: part, parentId: currentParentId);
        cache[key] = created.id;
        currentParentId = created.id;
      }
      accumulated = key;
    }

    return currentParentId;
  }

  /// Extracts the relative directory part of a ZIP entry name (using '/').
  static String _zipEntryRelDir(String entryName) {
    final normalized = entryName.replaceAll('\\', '/');
    final idx = normalized.lastIndexOf('/');
    if (idx <= 0) return '';
    return normalized.substring(0, idx);
  }

  /// Like [_ensureFolderStructure] but works with ZIP entry relative paths
  /// (directory separator is '/' regardless of platform).
  Future<int?> _ensureZipFolderStructure(
    String relDir,
    int? rootParentId,
    Map<String, int> cache,
  ) async {
    if (relDir.isEmpty) return rootParentId;

    final cached = cache[relDir];
    if (cached != null) return cached;

    final parts = relDir.split('/');
    var currentParentId = rootParentId;
    var accumulated = '';

    for (final part in parts) {
      if (part.isEmpty) continue;
      final key = accumulated.isEmpty ? part : '$accumulated/$part';
      final hit = cache[key];
      if (hit != null) {
        currentParentId = hit;
        accumulated = key;
        continue;
      }
      final existing = await repo.listFolders(parentId: currentParentId);
      final match = existing.where((f) => f.name == part).firstOrNull;
      if (match != null) {
        cache[key] = match.id;
        currentParentId = match.id;
      } else {
        final created =
            await repo.createFolder(name: part, parentId: currentParentId);
        cache[key] = created.id;
        currentParentId = created.id;
      }
      accumulated = key;
    }

    return currentParentId;
  }

  static String _randomBlobId() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return hex;
  }

  /// Natural/alphanumeric sort (mirrors BulkImportService._compareNatural).
  static int _compareNatural(String a, String b) {
    final al = a.toLowerCase();
    final bl = b.toLowerCase();
    var ai = 0;
    var bi = 0;
    while (ai < al.length && bi < bl.length) {
      final ac = al[ai];
      final bc = bl[bi];
      if (_isDigit(ac) && _isDigit(bc)) {
        final an = _extractNumber(al, ai);
        final bn = _extractNumber(bl, bi);
        if (an.value != bn.value) return an.value.compareTo(bn.value);
        ai = an.end;
        bi = bn.end;
      } else {
        if (ac != bc) return ac.compareTo(bc);
        ai++;
        bi++;
      }
    }
    return al.length.compareTo(bl.length);
  }

  static bool _isDigit(String c) =>
      c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

  static _NumResult _extractNumber(String s, int start) {
    var end = start;
    while (end < s.length && _isDigit(s[end])) {
      end++;
    }
    return _NumResult(value: int.parse(s.substring(start, end)), end: end);
  }
}

class _FileInfo {
  _FileInfo({required this.file, required this.relativePath});

  final File file;
  final String relativePath;
}

class _NumResult {
  _NumResult({required this.value, required this.end});

  final int value;
  final int end;
}
