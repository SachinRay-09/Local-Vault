import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import 'vault_repository.dart';

class BulkImportResult {
  BulkImportResult({
    required this.foldersCreated,
    required this.filesImported,
    required this.errors,
    required this.totalProcessed,
  });

  final int foldersCreated;
  final int filesImported;
  final List<String> errors;
  final int totalProcessed;
}

class BulkImportService {
  BulkImportService({
    required this.repo,
    required this.crypto,
    required this.secureStorage,
  });

  final VaultRepository repo;
  final dynamic crypto; // FileCryptoService
  final dynamic secureStorage; // SecureStorageService

  static const List<String> _supportedImageExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.bmp',
    '.webp',
    '.svg',
    '.apng',
    '.avif'
  ];

  /// Import a folder and all its contents into the vault using isolate-based processing
  Future<BulkImportResult> importFolder({
    required String sourceFolderPath,
    required int? destinationFolderId,
    required Function(String) onProgress,
  }) async {
    final sourceDir = Directory(sourceFolderPath);
    if (!await sourceDir.exists()) {
      throw Exception('Source folder does not exist: $sourceFolderPath');
    }

    int foldersCreated = 0;
    int filesImported = 0;
    final List<String> errors = [];
    int totalProcessed = 0;

    try {
      // First, count total files for progress tracking
      final allFiles = await _getAllFiles(sourceDir);
      final totalFiles = allFiles.length;

      onProgress('Found $totalFiles files to import...');

      // Create the root folder in vault
      final rootFolderName = path.basename(sourceFolderPath);
      final rootFolder = await repo.createFolder(
        name: rootFolderName,
        parentId: destinationFolderId,
      );
      foldersCreated++;

      // Process files in smaller batches with isolate-based encryption
      const batchSize = 3; // Reduced batch size for isolate processing
      final swBatch = Stopwatch()..start();
      int batchBytesTotal = 0;
      for (int i = 0; i < allFiles.length; i += batchSize) {
        final batch = allFiles.skip(i).take(batchSize).toList();

        // Process batch using isolates for better performance
        await _processBatchWithIsolates(
          batch,
          rootFolder.id,
          onProgress,
          totalFiles,
          totalProcessed,
          (processed) => totalProcessed = processed,
          (imported) => filesImported += imported,
          (error) => errors.add(error),
          (bytes) => batchBytesTotal += bytes,
        );

        // Longer delay between batches to prevent CPU overload
        await Future.delayed(const Duration(milliseconds: 100));
      }
      swBatch.stop();
      if (swBatch.elapsedMilliseconds > 0) {
        final filesPerSecond =
            filesImported / (swBatch.elapsedMilliseconds / 1000.0);
        final mbPerSecond = (batchBytesTotal / (1024 * 1024)) /
            (swBatch.elapsedMilliseconds / 1000.0);
        debugPrint(
            '[Benchmark] Import: ${filesPerSecond.toStringAsFixed(1)} files/s, ${mbPerSecond.toStringAsFixed(2)} MB/s');
      }
    } catch (e) {
      errors.add('Import failed: $e');
      rethrow;
    }

    return BulkImportResult(
      foldersCreated: foldersCreated,
      filesImported: filesImported,
      errors: errors,
      totalProcessed: totalProcessed,
    );
  }

  /// Process a batch of files using isolate-based encryption
  Future<void> _processBatchWithIsolates(
    List<_FileInfo> batch,
    int rootFolderId,
    Function(String) onProgress,
    int totalFiles,
    int currentProcessed,
    Function(int) updateProcessed,
    Function(int) updateImported,
    Function(String) addError,
    Function(int) addBytes,
  ) async {
    for (final fileInfo in batch) {
      try {
        currentProcessed++;
        onProgress(
            'Processing ${fileInfo.relativePath} ($currentProcessed/$totalFiles)');

        // Create folder structure if needed
        final folderPath = path.dirname(fileInfo.relativePath);
        int? parentFolderId = rootFolderId;

        if (folderPath != '.') {
          parentFolderId = await _ensureFolderStructure(
            folderPath,
            rootFolderId,
          );
        }

        // Measure per-file import duration and byte count
        final swFile = Stopwatch()..start();
        final fileBytes = await fileInfo.file.length();
        await _importFileWithIsolate(
          fileInfo.file,
          parentFolderId,
        );
        swFile.stop();
        addBytes(fileBytes);

        final fileMb = fileBytes / (1024 * 1024);
        final fileMbs = swFile.elapsedMilliseconds > 0
            ? fileMb / (swFile.elapsedMilliseconds / 1000.0)
            : 0.0;
        debugPrint(
            '[Benchmark] Import: file $fileBytes bytes in ${swFile.elapsedMilliseconds}ms (${fileMbs.toStringAsFixed(2)} MB/s)');

        updateImported(1);
        updateProcessed(currentProcessed);
      } catch (e) {
        addError('Failed to import ${fileInfo.relativePath}: $e');
        debugPrint('Import error: $e');
      }
    }
  }

  /// Import a single file using isolate-based encryption
  Future<void> _importFileWithIsolate(File file, int? parentFolderId) async {
    // For now, use the existing repo.addMedia method
    // TODO: Replace with isolate-based encryption when integrating with FileCryptoService
    await repo.addMedia(
      originalName: path.basename(file.path),
      parentFolderId: parentFolderId,
      sourcePath: file.path,
      bytes: null,
      mimeType: _getMimeType(file.path),
    );
  }

  /// Get all supported files from a directory recursively
  /// Files are sorted naturally (1, 2, 3... 10... 100) to preserve folder structure
  Future<List<_FileInfo>> _getAllFiles(Directory dir) async {
    final List<_FileInfo> files = [];
    final basePath = dir.path;

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final extension = path.extension(entity.path).toLowerCase();
        if (_supportedImageExtensions.contains(extension)) {
          final relativePath = path.relative(entity.path, from: basePath);
          files.add(_FileInfo(file: entity, relativePath: relativePath));
        }
      }
    }

    // CRITICAL: Sort files naturally to preserve folder structure
    // Directory.list() returns files in platform-dependent order:
    // - Windows: alphabetical (1, 10, 100, 2...)
    // - Mac/Linux: unpredictable
    // Natural sort ensures: 1, 2, 3... 10... 100
    files.sort((a, b) => _compareNatural(a.relativePath, b.relativePath));

    return files;
  }

  /// Natural/alphanumeric comparison for proper sorting (1, 2, 3... 10... 100)
  /// Based on "The Alphanum Algorithm" - http://www.davekoelle.com/alphanum.html
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

  /// Ensure folder structure exists, creating folders as needed
  Future<int> _ensureFolderStructure(
      String folderPath, int rootFolderId) async {
    final parts = path.split(folderPath);
    int currentParentId = rootFolderId;

    for (final part in parts) {
      if (part.isEmpty || part == '.') continue;

      // Check if folder already exists
      final existingFolders = await repo.listFolders(parentId: currentParentId);
      final existingFolder =
          existingFolders.where((f) => f.name == part).firstOrNull;

      if (existingFolder != null) {
        currentParentId = existingFolder.id;
      } else {
        // Create new folder
        final newFolder = await repo.createFolder(
          name: part,
          parentId: currentParentId,
        );
        currentParentId = newFolder.id;
      }
    }

    return currentParentId;
  }

  String? _getMimeType(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.bmp':
        return 'image/bmp';
      case '.svg':
        return 'image/svg+xml';
      default:
        return null;
    }
  }
}

class _FileInfo {
  _FileInfo({required this.file, required this.relativePath});

  final File file;
  final String relativePath;
}

class _NumberExtraction {
  _NumberExtraction({required this.value, required this.endIndex});

  final int value;
  final int endIndex;
}
