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
    '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.svg', '.apng', '.avif'
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
        );

        // Longer delay between batches to prevent CPU overload
        await Future.delayed(const Duration(milliseconds: 100));
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
  ) async {
    for (final fileInfo in batch) {
      try {
        currentProcessed++;
        onProgress('Processing ${fileInfo.relativePath} ($currentProcessed/$totalFiles)');

        // Create folder structure if needed
        final folderPath = path.dirname(fileInfo.relativePath);
        int? parentFolderId = rootFolderId;
        
        if (folderPath != '.') {
          parentFolderId = await _ensureFolderStructure(
            folderPath,
            rootFolderId,
          );
        }

        // Import the file using isolate-based processing
        await _importFileWithIsolate(
          fileInfo.file,
          parentFolderId,
        );
        
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

    return files;
  }

  /// Ensure folder structure exists, creating folders as needed
  Future<int> _ensureFolderStructure(String folderPath, int rootFolderId) async {
    final parts = path.split(folderPath);
    int currentParentId = rootFolderId;

    for (final part in parts) {
      if (part.isEmpty || part == '.') continue;

      // Check if folder already exists
      final existingFolders = await repo.listFolders(parentId: currentParentId);
      final existingFolder = existingFolders.where((f) => f.name == part).firstOrNull;

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