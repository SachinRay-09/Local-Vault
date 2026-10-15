import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as path;

import '../models/operation_job.dart';
import '../models/operation_job_item.dart';
import '../platform/android/android_thermal_monitor.dart';
import '../services/blob_store.dart';
import '../services/dart_crypto_engine.dart';
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
  '.jpg', '.jpeg', '.png', '.gif', '.bmp',
  '.webp', '.svg', '.apng', '.avif',
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
  final DartCryptoEngine crypto;
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
      await jobRepo.createJobItem(item);
    }

    // ------------------------------------------------------------------ //
    // 5. Delegate to JobRunner
    // ------------------------------------------------------------------ //
    final masterKey = await storage.getOrCreateMasterKey32();
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

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

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
