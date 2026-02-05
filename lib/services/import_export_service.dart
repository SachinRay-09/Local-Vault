import 'dart:io';
import 'dart:math';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

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
      type: FileType.any,
    );
  }

  Future<String?> pickImportZipPath() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import vault ZIP',
      type: FileType.any,
      allowMultiple: false,
      withData: false, // Don't load large files into memory
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
    // Use documents directory instead of cache for better reliability on Android
    final docsDir = await getApplicationDocumentsDirectory();
    final importId = DateTime.now().millisecondsSinceEpoch.toString();
    final extractDir = Directory(path.join(docsDir.path, 'vault_import_$importId'));
    
    try {
      // Use robust ZIP extraction with documents directory
      await _extractZipManually(zipPath, extractDir.path, password);
      return _importExtractedTree(extractDir, destinationFolderId: destinationFolderId);
    } finally {
      try {
        await extractDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  /// Completely robust ZIP extraction with proper file system handling
  Future<void> _extractZipManually(String zipPath, String extractPath, String password) async {
    try {
      debugPrint('Starting robust ZIP extraction from: $zipPath');
      
      // Verify the ZIP file exists and is accessible
      final zipFile = File(zipPath);
      if (!await zipFile.exists()) {
        throw Exception('ZIP file not found at path: $zipPath');
      }

      // Read the ZIP file bytes with size check
      final fileSize = await zipFile.length();
      debugPrint('ZIP file size: $fileSize bytes');
      
      if (fileSize == 0) {
        throw Exception('ZIP file is empty');
      }
      
      if (fileSize > 500 * 1024 * 1024) { // 500MB limit
        throw Exception('ZIP file is too large (${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB). Maximum supported size is 500 MB.');
      }

      final bytes = await zipFile.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('ZIP file could not be read or is empty');
      }

      debugPrint('Successfully read ${bytes.length} bytes from ZIP file');

      // Decode the ZIP archive with enhanced error handling and proper password support
      Archive archive;
      try {
        if (password.isNotEmpty) {
          debugPrint('Attempting to decode password-protected ZIP');
          archive = ZipDecoder().decodeBytes(
            bytes, 
            password: password,
            verify: true, // Throws if password is wrong
          );
        } else {
          debugPrint('Attempting to decode unprotected ZIP');
          archive = ZipDecoder().decodeBytes(bytes);
        }
      } catch (e) {
        debugPrint('ZIP decode error: $e');
        if (e.toString().toLowerCase().contains('password') || 
            e.toString().toLowerCase().contains('wrong') ||
            e.toString().toLowerCase().contains('invalid') ||
            e.toString().toLowerCase().contains('bad')) {
          throw Exception('Incorrect password for ZIP file');
        } else if (e.toString().toLowerCase().contains('zip')) {
          throw Exception('Invalid or corrupted ZIP file: $e');
        }
        throw Exception('Failed to decode ZIP file. The file may be corrupted or use an unsupported format. Error: $e');
      }

      if (archive.isEmpty) {
        throw Exception('ZIP file contains no files');
      }

      debugPrint('ZIP archive contains ${archive.length} entries');

      // Create extraction directory with proper permissions
      final extractDir = Directory(extractPath);
      await extractDir.create(recursive: true);
      
      // Verify the extraction directory was created
      if (!await extractDir.exists()) {
        throw Exception('Failed to create extraction directory: $extractPath');
      }

      // Extract files using completely robust approach
      int extractedCount = 0;
      int skippedCount = 0;
      
      for (int i = 0; i < archive.length; i++) {
        final entry = archive[i];
        
        if (entry.isFile && entry.content != null) {
          try {
            // Use path.join for proper path handling
            final filePath = path.join(extractPath, entry.name);
            debugPrint('Extracting file: ${entry.name} -> $filePath');
            
            final outputFile = File(filePath);
            
            // Create parent directories recursively and verify they exist
            await outputFile.parent.create(recursive: true);
            
            // Double-check parent directory exists
            if (!await outputFile.parent.exists()) {
              debugPrint('Failed to create parent directory for: ${entry.name}');
              skippedCount++;
              continue;
            }
            
            // Write file content with proper error handling
            final content = entry.content as List<int>;
            if (content.isNotEmpty) {
              // Write the file and immediately verify it exists
              await outputFile.writeAsBytes(content, flush: true);
              
              // Verify the file was actually written
              if (await outputFile.exists()) {
                final writtenSize = await outputFile.length();
                if (writtenSize == content.length) {
                  extractedCount++;
                  debugPrint('Successfully extracted: ${entry.name} ($writtenSize bytes)');
                } else {
                  debugPrint('File size mismatch for ${entry.name}: expected ${content.length}, got $writtenSize');
                  skippedCount++;
                }
              } else {
                debugPrint('File was not created: ${entry.name}');
                skippedCount++;
              }
              
              // Log progress for every 5 files or on last file
              if (extractedCount % 5 == 0 || i == archive.length - 1) {
                debugPrint('Progress: $extractedCount/${archive.length} files extracted...');
              }
            } else {
              debugPrint('Skipping empty file: ${entry.name}');
              skippedCount++;
            }
          } catch (e) {
            // Log individual file extraction errors but continue with others
            debugPrint('Error extracting file ${entry.name}: $e');
            skippedCount++;
          }
        } else if (entry.isFile) {
          // File without content
          debugPrint('Skipping file without content: ${entry.name}');
          skippedCount++;
        } else {
          // Directory entry - create it explicitly
          try {
            final dirPath = path.join(extractPath, entry.name);
            final dir = Directory(dirPath);
            await dir.create(recursive: true);
            debugPrint('Created directory: ${entry.name}');
          } catch (e) {
            debugPrint('Failed to create directory ${entry.name}: $e');
          }
          skippedCount++;
        }
      }

      if (extractedCount == 0) {
        throw Exception('No files were successfully extracted from the ZIP. The archive may be empty or corrupted.');
      }

      debugPrint('ZIP extraction completed: $extractedCount files extracted, $skippedCount skipped');
      
      // Final verification - list all files in extraction directory
      final extractedFiles = <String>[];
      await for (final entity in extractDir.list(recursive: true)) {
        if (entity is File) {
          extractedFiles.add(entity.path);
        }
      }
      debugPrint('Final verification: ${extractedFiles.length} files found in extraction directory');
      
    } catch (e) {
      // Clean up extraction directory on failure
      try {
        final extractDir = Directory(extractPath);
        if (await extractDir.exists()) {
          await extractDir.delete(recursive: true);
          debugPrint('Cleaned up failed extraction directory');
        }
      } catch (cleanupError) {
        debugPrint('Failed to cleanup extraction directory: $cleanupError');
      }
      rethrow;
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

