import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uri_content/uri_content.dart';

import '../db/isar_db.dart';
import '../models/vault_file.dart';
import 'file_crypto_service.dart';
import 'import_export_service.dart';
import 'vault_repository.dart';

/// SAF-compatible ZIP import service for Android 15+ scoped storage
class SafZipImportService {
  final UriContent _uriContent = UriContent();
  final VaultRepository _repo;
  
  Isar get _isar => IsarDb.instance;

  SafZipImportService({required VaultRepository repo}) : _repo = repo;

  /// Import ZIP using SAF-compatible approach with URI streams
  Future<ImportResult> importFromZipUri({
    required Uri zipUri,
    required String password,
    required int? destinationFolderId,
    required Function(ImportResult) onImportComplete,
    Function(int current, int total, String filename)? onProgress,
    Function(String)? onStatusUpdate,
  }) async {
    try {
      debugPrint('Starting SAF ZIP import from URI: $zipUri');
      onStatusUpdate?.call('Preparing to read ZIP file...');
      
      // Create temp directory in app documents (guaranteed accessible)
      final docsDir = await getApplicationDocumentsDirectory();
      final importId = DateTime.now().millisecondsSinceEpoch.toString();
      final extractDir = Directory(path.join(docsDir.path, 'saf_import_$importId'));
      await extractDir.create(recursive: true);
      
      // Create temp ZIP file path
      final tempZipPath = path.join(extractDir.path, 'temp_import.zip');
      
      try {
        // Copy ZIP to temp location (handles large files better than loading into memory)
        onStatusUpdate?.call('Reading ZIP file (this may take a few minutes for large files)...');
        await _copyZipToTemp(zipUri, tempZipPath, onStatusUpdate);
        
        onStatusUpdate?.call('Extracting ZIP archive...');
        
        // Extract ZIP from temp file
        await _extractZipFromFile(tempZipPath, extractDir.path, password, onProgress, onStatusUpdate);
        
        // Delete the temp ZIP file before importing to prevent it from being imported
        try {
          final tempZipFile = File(tempZipPath);
          if (await tempZipFile.exists()) {
            await tempZipFile.delete();
            debugPrint('Deleted temp ZIP file before import');
          }
        } catch (e) {
          debugPrint('Failed to delete temp ZIP file: $e');
        }
        
        onStatusUpdate?.call('Importing files to vault...');
        
        // Import extracted files using existing logic
        final result = await _importExtractedTree(extractDir, destinationFolderId, onProgress, onStatusUpdate);
        
        debugPrint('SAF ZIP import completed: ${result.filesImported} files, ${result.foldersCreated} folders');
        return result;
        
      } finally {
        // Always clean up temp directory
        try {
          await extractDir.delete(recursive: true);
          debugPrint('Cleaned up SAF import temp directory');
        } catch (e) {
          debugPrint('Failed to cleanup SAF temp directory: $e');
        }
      }
      
    } catch (e) {
      debugPrint('SAF ZIP import failed: $e');
      rethrow;
    }
  }

  /// Copy ZIP from URI to temp file (handles large files)
  Future<void> _copyZipToTemp(Uri zipUri, String tempPath, Function(String)? onStatusUpdate) async {
    try {
      debugPrint('Copying ZIP from URI to temp file: $zipUri');
      
      // Convert URI to file path if it's a file:// URI
      if (zipUri.scheme == 'file') {
        final sourceFile = File(zipUri.toFilePath());
        final destFile = File(tempPath);
        
        // Get file size for progress
        final fileSize = await sourceFile.length();
        final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(1);
        onStatusUpdate?.call('Reading ZIP file ($fileSizeMB MB)...');
        
        // Copy file in chunks to avoid memory issues
        final source = sourceFile.openRead();
        final sink = destFile.openWrite();
        
        int bytesRead = 0;
        await for (final chunk in source) {
          sink.add(chunk);
          bytesRead += chunk.length;
          
          // Update progress every 10MB
          if (bytesRead % (10 * 1024 * 1024) == 0) {
            final progressMB = (bytesRead / (1024 * 1024)).toStringAsFixed(1);
            onStatusUpdate?.call('Reading ZIP: $progressMB / $fileSizeMB MB...');
          }
        }
        
        await sink.flush();
        await sink.close();
        
        debugPrint('Successfully copied ZIP file: $fileSize bytes');
        return;
      }
      
      // For content:// URIs, use uri_content but with better error handling
      onStatusUpdate?.call('Reading ZIP from content URI...');
      final content = await _uriContent.from(zipUri);
      
      if (content.isEmpty) {
        throw Exception('ZIP file is empty or could not be read');
      }
      
      final destFile = File(tempPath);
      await destFile.writeAsBytes(content);
      
      debugPrint('Successfully read ${content.length} bytes from content URI');
      
    } catch (e) {
      throw Exception('Failed to read ZIP file: $e');
    }
  }

  /// Extract ZIP from file using streaming (memory-efficient for large files)
  Future<void> _extractZipFromFile(
    String zipPath,
    String extractPath, 
    String password,
    Function(int current, int total, String filename)? onProgress,
    Function(String)? onStatusUpdate,
  ) async {
    try {
      debugPrint('Extracting ZIP from file: $zipPath');
      onStatusUpdate?.call('Decoding ZIP archive...');
      
      final zipFile = File(zipPath);
      if (!await zipFile.exists()) {
        throw Exception('ZIP file not found at temp location');
      }
      
      Archive archive;
      
      // For password-protected ZIPs, we must use decodeBytes (not streaming)
      // because password decryption requires full data access
      if (password.isNotEmpty) {
        debugPrint('Reading password-protected ZIP into memory...');
        onStatusUpdate?.call('Reading encrypted ZIP...');
        
        try {
          final bytes = await zipFile.readAsBytes();
          debugPrint('Decoding password-protected ZIP...');
          onStatusUpdate?.call('Decoding encrypted ZIP...');
          
          archive = ZipDecoder().decodeBytes(bytes, password: password, verify: true);
          
          // Don't clear bytes here - archive entries reference this data
          // Memory will be freed when archive is cleared after extraction
        } catch (e) {
          debugPrint('Failed to decode password-protected ZIP: $e');
          if (e.toString().toLowerCase().contains('password') || 
              e.toString().toLowerCase().contains('wrong') ||
              e.toString().toLowerCase().contains('bad') ||
              e.toString().toLowerCase().contains('decrypt')) {
            throw Exception('Incorrect password for ZIP file');
          }
          throw Exception('Failed to decode encrypted ZIP: $e');
        }
      } else {
        // For non-encrypted ZIPs, use streaming for memory efficiency
        debugPrint('Using streaming for non-encrypted ZIP...');
        onStatusUpdate?.call('Extracting ZIP archive...');
        
        final inputStream = InputFileStream(zipPath);
        try {
          archive = ZipDecoder().decodeBuffer(inputStream);
        } catch (e) {
          await inputStream.close();
          throw Exception('Failed to decode ZIP: $e');
        }
        // Note: Don't close stream yet for non-encrypted, close after extraction
      }

      if (archive.isEmpty) {
        throw Exception('ZIP archive is empty');
      }

      debugPrint('ZIP contains ${archive.length} entries');
      final totalFiles = archive.where((e) => e.isFile).length;
      onStatusUpdate?.call('Extracting $totalFiles files...');

      // Extract files - different approach for encrypted vs non-encrypted
      int extractedCount = 0;
      
      if (password.isNotEmpty) {
        // For encrypted: Use entry.content (already decrypted in memory)
        for (final entry in archive) {
          if (entry.isFile) {
            try {
              final filePath = path.join(extractPath, entry.name);
              final outputFile = File(filePath);
              
              // Create parent directories
              await outputFile.parent.create(recursive: true);
              
              // Get decrypted content (already in memory from decodeBytes)
              final content = entry.content as List<int>;
              await outputFile.writeAsBytes(content, flush: true);
              
              // Verify file was written
              if (await outputFile.exists()) {
                extractedCount++;
                onProgress?.call(extractedCount, totalFiles, path.basename(entry.name));
                
                // Update status every 100 files
                if (extractedCount % 100 == 0) {
                  onStatusUpdate?.call('Extracted $extractedCount / $totalFiles files...');
                }
              }
              
              // Don't clear entry for password-protected ZIPs - causes "fixed-length list" error
              // The archive will be cleared as a whole after extraction
              
            } catch (e) {
              debugPrint('Failed to extract ${entry.name}: $e');
            }
          }
        }
      } else {
        // For non-encrypted: Use writeContent (streaming)
        for (final entry in archive) {
          if (entry.isFile) {
            try {
              final filePath = path.join(extractPath, entry.name);
              final outputFile = File(filePath);
              
              // Create parent directories
              await outputFile.parent.create(recursive: true);
              
              // Stream to disk (memory-efficient)
              final outputStream = OutputFileStream(filePath);
              try {
                entry.writeContent(outputStream);
                await outputStream.close();
              } catch (e) {
                await outputStream.close();
                rethrow;
              }
              
              // Verify file was written
              if (await outputFile.exists()) {
                extractedCount++;
                onProgress?.call(extractedCount, totalFiles, path.basename(entry.name));
                
                // Update status every 100 files
                if (extractedCount % 100 == 0) {
                  onStatusUpdate?.call('Extracted $extractedCount / $totalFiles files...');
                }
              }
              
              // Clear entry from memory
              entry.clear();
              
            } catch (e) {
              debugPrint('Failed to extract ${entry.name}: $e');
            }
          }
        }
      }

      // Clear archive from memory
      archive.clear();

      if (extractedCount == 0) {
        throw Exception('No files were successfully extracted');
      }

      debugPrint('Successfully extracted $extractedCount files');
      onStatusUpdate?.call('EXTRACTED:$extractedCount files extracted successfully');
      
    } catch (e) {
      throw Exception('ZIP extraction failed: $e');
    }
  }

  /// Import extracted files using isolate-based encryption for speed
  Future<ImportResult> _importExtractedTree(
    Directory extractDir, 
    int? destinationFolderId,
    Function(int current, int total, String filename)? onProgress,
    Function(String)? onStatusUpdate,
  ) async {
    // Map relative directory path -> vault folder id
    final folderIdByRelPath = <String, int?>{'': destinationFolderId};

    final directories = <Directory>[];
    final files = <File>[];

    await for (final entity in extractDir.list(recursive: true, followLinks: false)) {
      if (entity is Directory) directories.add(entity);
      if (entity is File) files.add(entity);
    }

    // Create folders in increasing depth order
    directories.sort((a, b) => a.path.length.compareTo(b.path.length));
    var foldersCreated = 0;
    
    onStatusUpdate?.call('Creating folder structure...');
    for (final dir in directories) {
      final rel = _relativePath(extractDir.path, dir.path);
      if (rel.isEmpty) continue;
      final parentRel = _parentRelPath(rel);
      final parentId = folderIdByRelPath[parentRel] ?? destinationFolderId;
      final name = _basename(rel);
      final created = await _repo.createFolder(name: name, parentId: parentId);
      folderIdByRelPath[rel] = created.id;
      foldersCreated++;
    }

    // CRITICAL: Sort files naturally to preserve folder structure
    // Directory.list() returns files in platform-dependent order
    // Natural sort ensures: 1, 2, 3... 10... 100 (not 1, 10, 100, 2...)
    files.sort((a, b) => _compareNatural(a.path, b.path));

    var filesImported = 0;
    final totalFiles = files.length;
    onStatusUpdate?.call('Encrypting $totalFiles files...');
    
    // Get master key for encryption
    final masterKey32 = await _repo.secureStorage.getOrCreateMasterKey32();
    final masterKeyBytes = Uint8List.fromList(masterKey32);
    
    // Encrypt files on main thread with batching and yielding
    // NOTE: Isolate encryption doesn't work because isolates can't access temp file paths
    const crypto = FileCryptoService();
    const batchSize = 10; // Smaller batches for more frequent UI updates
    int sortOrder = 0;
    int encryptedCount = 0;
    
    for (int i = 0; i < files.length; i += batchSize) {
      final batchEnd = (i + batchSize).clamp(0, files.length);
      final batch = files.sublist(i, batchEnd);
      
      for (final file in batch) {
        try {
          // Update progress BEFORE encryption so UI shows current file
          onProgress?.call(encryptedCount + 1, totalFiles, path.basename(file.path));
          
          // Yield to UI thread to allow progress update to render
          await Future.delayed(const Duration(milliseconds: 1));
          
          // Encrypt file
          final result = await crypto.encryptFileToBlob(
            sourceFile: file,
            masterKey32: masterKeyBytes,
          );
          
          encryptedCount++;
          
          // Get file metadata
          final rel = _relativePath(extractDir.path, file.path);
          final parentRel = _parentRelPath(rel);
          final parentId = folderIdByRelPath[parentRel] ?? destinationFolderId;
          final name = _basename(rel);
          
          // Create VaultFile entry with sortOrder to preserve file system order
          final vaultFile = VaultFile()
            ..parentFolderId = parentId
            ..originalName = name
            ..storedBlobName = result.storedBlobName
            ..byteSize = result.byteSize
            ..mimeType = _getMimeType(name)
            ..ivBase64 = result.ivBase64
            ..createdAt = DateTime.now()
            ..sortOrder = sortOrder++;
          
          // Save to database
          await _isar.writeTxn(() async {
            await _isar.vaultFiles.put(vaultFile);
          });
          
          filesImported++;
          
        } catch (e) {
          debugPrint('Failed to encrypt/save file ${file.path}: $e');
        }
      }
      
      // Yield to UI thread after each batch (longer delay for UI responsiveness)
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Update status every 100 files
      if (encryptedCount % 100 == 0) {
        onStatusUpdate?.call('Encrypted $encryptedCount / $totalFiles files...');
      }
    }
    
    debugPrint('Encryption and save completed: $filesImported files');
    onStatusUpdate?.call('ENCRYPTED:$encryptedCount files encrypted');
    onStatusUpdate?.call('SAVED:$filesImported files saved to database');

    return ImportResult(foldersCreated: foldersCreated, filesImported: filesImported);
  }
  
  /// Get MIME type from file extension
  String _getMimeType(String fileName) {
    final ext = path.extension(fileName).toLowerCase();
    switch (ext) {
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
      case '.mp4':
        return 'video/mp4';
      case '.mkv':
        return 'video/x-matroska';
      case '.avi':
        return 'video/x-msvideo';
      case '.mov':
        return 'video/quicktime';
      default:
        return 'application/octet-stream';
    }
  }

  // Helper methods for path manipulation
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

  /// Check if device supports SAF (Android 4.4+)
  static bool get isSafSupported {
    return Platform.isAndroid;
  }

  /// Get user-friendly error message for SAF issues
  static String getSafErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('permission')) {
      return 'Permission denied. Please grant storage access and try again.';
    } else if (errorStr.contains('not found')) {
      return 'File not found. The file may have been moved or deleted.';
    } else if (errorStr.contains('password')) {
      return 'Incorrect password for ZIP file.';
    } else if (errorStr.contains('corrupt') || errorStr.contains('invalid')) {
      return 'ZIP file is corrupted or invalid.';
    } else {
      return 'Import failed: $error';
    }
  }
}

/// Helper class for natural sort number extraction
class _NumberExtraction {
  _NumberExtraction({required this.value, required this.endIndex});
  
  final int value;
  final int endIndex;
}