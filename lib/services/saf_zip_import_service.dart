import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uri_content/uri_content.dart';

import 'import_export_service.dart';
import 'vault_repository.dart';

/// SAF-compatible ZIP import service for Android 15+ scoped storage
class SafZipImportService {
  final UriContent _uriContent = UriContent();
  final VaultRepository _repo;

  SafZipImportService({required VaultRepository repo}) : _repo = repo;

  /// Import ZIP using SAF-compatible approach with URI streams
  Future<ImportResult> importFromZipUri({
    required Uri zipUri,
    required String password,
    required int? destinationFolderId,
    required Function(ImportResult) onImportComplete,
  }) async {
    try {
      debugPrint('Starting SAF ZIP import from URI: $zipUri');
      
      // Create temp directory in app documents (guaranteed accessible)
      final docsDir = await getApplicationDocumentsDirectory();
      final importId = DateTime.now().millisecondsSinceEpoch.toString();
      final extractDir = Directory(path.join(docsDir.path, 'saf_import_$importId'));
      await extractDir.create(recursive: true);
      
      try {
        // Read ZIP content via URI stream (SAF-compatible)
        final zipBytes = await _readZipFromUri(zipUri);
        
        // Extract ZIP using bytes (no file path dependencies)
        await _extractZipFromBytes(zipBytes, extractDir.path, password);
        
        // Import extracted files using existing logic
        final result = await _importExtractedTree(extractDir, destinationFolderId);
        
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

  /// Read ZIP file content from URI using SAF streams
  Future<List<int>> _readZipFromUri(Uri zipUri) async {
    try {
      debugPrint('Reading ZIP content from URI: $zipUri');
      
      // Use uri_content to read from content:// URI
      final content = await _uriContent.from(zipUri);
      
      if (content.isEmpty) {
        throw Exception('ZIP file is empty or could not be read from URI');
      }
      
      debugPrint('Successfully read ${content.length} bytes from ZIP URI');
      return content;
      
    } catch (e) {
      throw Exception('Failed to read ZIP from URI: $e');
    }
  }

  /// Extract ZIP from bytes (no file path dependencies)
  Future<void> _extractZipFromBytes(List<int> zipBytes, String extractPath, String password) async {
    try {
      debugPrint('Extracting ZIP from ${zipBytes.length} bytes');
      
      // Decode ZIP archive from bytes
      Archive archive;
      try {
        if (password.isNotEmpty) {
          archive = ZipDecoder().decodeBytes(zipBytes, password: password, verify: true);
        } else {
          archive = ZipDecoder().decodeBytes(zipBytes);
        }
      } catch (e) {
        if (e.toString().toLowerCase().contains('password') || 
            e.toString().toLowerCase().contains('wrong') ||
            e.toString().toLowerCase().contains('bad')) {
          throw Exception('Incorrect password for ZIP file');
        }
        throw Exception('Failed to decode ZIP: $e');
      }

      if (archive.isEmpty) {
        throw Exception('ZIP archive is empty');
      }

      debugPrint('ZIP contains ${archive.length} entries');

      // Extract files to app documents directory (guaranteed writable)
      int extractedCount = 0;
      for (final entry in archive) {
        if (entry.isFile && entry.content != null) {
          try {
            // Use path.join for proper path handling
            final filePath = path.join(extractPath, entry.name);
            final outputFile = File(filePath);
            
            // Create parent directories
            await outputFile.parent.create(recursive: true);
            
            // Write file content
            final content = entry.content as List<int>;
            await outputFile.writeAsBytes(content, flush: true);
            
            // Verify file was written
            if (await outputFile.exists() && await outputFile.length() == content.length) {
              extractedCount++;
              debugPrint('Extracted: ${entry.name}');
            } else {
              debugPrint('Failed to verify extracted file: ${entry.name}');
            }
            
          } catch (e) {
            debugPrint('Failed to extract ${entry.name}: $e');
          }
        }
      }

      if (extractedCount == 0) {
        throw Exception('No files were successfully extracted');
      }

      debugPrint('Successfully extracted $extractedCount files');
      
    } catch (e) {
      throw Exception('ZIP extraction failed: $e');
    }
  }

  /// Import extracted files using existing vault logic
  Future<ImportResult> _importExtractedTree(Directory extractDir, int? destinationFolderId) async {
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

    var filesImported = 0;
    for (final f in files) {
      final rel = _relativePath(extractDir.path, f.path);
      final parentRel = _parentRelPath(rel);
      final parentId = folderIdByRelPath[parentRel] ?? destinationFolderId;
      final name = _basename(rel);
      await _repo.addMedia(
        originalName: name,
        parentFolderId: parentId,
        sourcePath: f.path,
        bytes: null,
      );
      filesImported++;
    }

    return ImportResult(foldersCreated: foldersCreated, filesImported: filesImported);
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