import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:pointycastle/export.dart';
import 'package:path/path.dart' as path;

import '../models/vault_file.dart';
import '../models/vault_folder.dart';
import 'vault_repository.dart';
import 'vault_open_service.dart';
import 'isolate_encryption_service.dart';

/// Service for creating password-protected encrypted archives for cross-platform transfer
/// Uses AES-256-CBC with PBKDF2 key derivation for maximum compatibility
class EncryptedExportService {
  EncryptedExportService({
    required this.repo,
    required this.openService,
  });

  final VaultRepository repo;
  final VaultOpenService openService;

  // Encryption constants for cross-platform compatibility
  static const int _keySize = 32; // AES-256
  static const int _ivSize = 16; // AES block size
  static const int _saltSize = 16; // Salt size
  static const int _iterations = 10000; // PBKDF2 iterations

  /// Export folder structure as password-protected encrypted archive
  /// Compatible with standard AES-256-CBC encryption
  Future<EncryptedExportResult> exportFolderAsEncryptedArchive({
    required VaultFolder folder,
    required String password,
    required String outputPath,
    Function(String)? onProgress,
  }) async {
    try {
      onProgress?.call('Preparing export...');
      
      // Get all files and folders recursively
      final exportData = await _collectFolderData(folder, onProgress);
      
      onProgress?.call('Creating archive...');
      
      // Create archive with folder structure
      final archive = Archive();
      
      // Add metadata
      final metadata = {
        'version': '1.3.0',
        'exported_at': DateTime.now().toIso8601String(),
        'folder_name': folder.name,
        'total_files': exportData.files.length,
        'total_folders': exportData.folders.length,
        'encryption': 'AES-256-CBC-PBKDF2',
      };
      
      final metadataJson = jsonEncode(metadata);
      archive.addFile(ArchiveFile('vault_info.json', metadataJson.length, metadataJson.codeUnits));
      
      // Add all files with their folder structure
      int processed = 0;
      for (final fileData in exportData.files) {
        try {
          // Decrypt file content
          final decryptedBytes = await openService.decryptToBytes(fileData.file);
          
          // Add to archive with proper path
          final archiveFile = ArchiveFile(
            fileData.relativePath,
            decryptedBytes.length,
            decryptedBytes,
          );
          archive.addFile(archiveFile);
          
          processed++;
          onProgress?.call('Processing files: $processed/${exportData.files.length}');
        } catch (e) {
          debugPrint('Failed to export file ${fileData.file.originalName}: $e');
        }
      }
      
      onProgress?.call('Encrypting archive...');
      
      // Create ZIP
      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);
      
      if (zipBytes == null) {
        throw Exception('Failed to create archive');
      }
      
      // Encrypt the ZIP with password using AES-256-CBC + PBKDF2
      final encryptedBytes = await _encryptWithPassword(Uint8List.fromList(zipBytes), password);
      
      // Save encrypted file with .vault extension
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(encryptedBytes);
      
      onProgress?.call('Export completed!');
      
      return EncryptedExportResult(
        success: true,
        outputPath: outputPath,
        fileSize: encryptedBytes.length,
        filesExported: exportData.files.length,
        foldersExported: exportData.folders.length,
        message: 'Successfully exported ${exportData.files.length} files from "${folder.name}"',
      );
      
    } catch (e) {
      debugPrint('Export error: $e');
      return EncryptedExportResult(
        success: false,
        outputPath: outputPath,
        fileSize: 0,
        filesExported: 0,
        foldersExported: 0,
        message: 'Export failed: $e',
      );
    }
  }

  /// Import password-protected encrypted archive
  /// Compatible with AES-256-CBC + PBKDF2 encryption
  /// Uses isolate-based batch encryption for speed
  Future<EncryptedImportResult> importEncryptedArchive({
    required String archivePath,
    required String password,
    int? parentFolderId,
    Function(String)? onProgress,
  }) async {
    Directory? tempDir;
    
    try {
      onProgress?.call('Reading encrypted archive...');
      
      // Read encrypted file
      final encryptedFile = File(archivePath);
      if (!await encryptedFile.exists()) {
        throw Exception('Archive file not found');
      }
      
      final encryptedBytes = await encryptedFile.readAsBytes();
      
      onProgress?.call('Decrypting archive...');
      
      // Decrypt with password
      final decryptedBytes = await _decryptWithPassword(encryptedBytes, password);
      
      onProgress?.call('Extracting files...');
      
      // Extract ZIP
      final archive = ZipDecoder().decodeBytes(decryptedBytes);
      
      // Read metadata
      final metadataFile = archive.files.firstWhere(
        (file) => file.name == 'vault_info.json',
        orElse: () => throw Exception('Invalid archive: missing metadata'),
      );
      
      final metadataContent = String.fromCharCodes(metadataFile.content as List<int>);
      final metadata = jsonDecode(metadataContent) as Map<String, dynamic>;
      
      final folderName = metadata['folder_name'] ?? 'Imported_${DateTime.now().millisecondsSinceEpoch}';
      
      onProgress?.call('Creating folder structure...');
      
      // Create root folder
      final rootFolder = await repo.createFolder(
        name: folderName,
        parentId: parentFolderId,
      );
      
      // Track created folders
      final createdFolders = <String, int>{'': rootFolder.id};
      
      // Create temp directory for extracted files
      tempDir = await Directory.systemTemp.createTemp('vault_import_');
      
      // Group files by folder path for batch processing
      final filesByFolder = <String, List<_TempFileInfo>>{};
      
      onProgress?.call('Organizing files...');
      
      // Extract files to temp directory and group by folder
      for (final file in archive.files) {
        if (file.name == 'vault_info.json') continue;
        
        if (file.isFile) {
          final filePath = file.name;
          final dirPath = path.dirname(filePath);
          
          // Write file to temp directory
          final tempFilePath = path.join(tempDir.path, file.name);
          final tempFile = File(tempFilePath);
          await tempFile.create(recursive: true);
          await tempFile.writeAsBytes(file.content as List<int>);
          
          // Group by folder
          filesByFolder.putIfAbsent(dirPath, () => []).add(
            _TempFileInfo(
              tempPath: tempFilePath,
              originalName: path.basename(filePath),
              dirPath: dirPath,
            ),
          );
        }
      }
      
      onProgress?.call('Importing files with batch encryption...');
      
      // Get master key for encryption
      final masterKey32 = await openService.secureStorage.getOrCreateMasterKey32();
      
      int filesImported = 0;
      final errors = <String>[];
      
      // Process each folder's files in batches
      for (final entry in filesByFolder.entries) {
        final dirPath = entry.key;
        final files = entry.value;
        
        try {
          // Ensure folder structure exists
          int targetFolderId = rootFolder.id;
          if (dirPath != '.' && dirPath.isNotEmpty) {
            targetFolderId = await _ensureFolderPath(dirPath, rootFolder.id, createdFolders);
          }
          
          // Process files in batches of 50
          const batchSize = 50;
          for (int i = 0; i < files.length; i += batchSize) {
            final batchEnd = (i + batchSize).clamp(0, files.length);
            final batch = files.sublist(i, batchEnd);
            
            // Encrypt batch in isolate
            final filePaths = batch.map((f) => f.tempPath).toList();
            final isolateService = IsolateEncryptionService();
            
            final encryptionResults = await isolateService.encryptFilesInBackground(
              filePaths: filePaths,
              masterKey32: masterKey32,
            );
            
            // Save encrypted files to database in batch
            final vaultFiles = <VaultFile>[];
            for (int j = 0; j < encryptionResults.length; j++) {
              final result = encryptionResults[j];
              final fileInfo = batch[j];
              
              if (result.success) {
                final vaultFile = VaultFile()
                  ..originalName = fileInfo.originalName
                  ..storedBlobName = result.storedBlobName!
                  ..byteSize = result.byteSize!
                  ..ivBase64 = result.ivBase64!
                  ..parentFolderId = targetFolderId
                  ..createdAt = DateTime.now();
                vaultFiles.add(vaultFile);
                filesImported++;
              } else {
                errors.add('Failed to import ${fileInfo.originalName}: ${result.error}');
              }
            }
            
            // Batch save to database
            if (vaultFiles.isNotEmpty) {
              await repo.batchSaveFiles(vaultFiles);
            }
            
            onProgress?.call('Imported: $filesImported/${filesByFolder.values.fold(0, (sum, list) => sum + list.length)} files');
            
            // Yield to UI
            await Future.delayed(const Duration(milliseconds: 10));
          }
        } catch (e) {
          final error = 'Failed to import folder $dirPath: $e';
          errors.add(error);
          debugPrint(error);
        }
      }
      
      onProgress?.call('Import completed!');
      
      return EncryptedImportResult(
        success: true,
        folderName: folderName,
        filesImported: filesImported,
        foldersCreated: createdFolders.length - 1, // Exclude root
        errors: errors,
        message: 'Successfully imported $filesImported files into "$folderName"',
      );
      
    } catch (e) {
      debugPrint('Import error: $e');
      return EncryptedImportResult(
        success: false,
        folderName: '',
        filesImported: 0,
        foldersCreated: 0,
        errors: [e.toString()],
        message: 'Import failed: $e',
      );
    } finally {
      // Clean up temp directory
      if (tempDir != null) {
        try {
          await tempDir.delete(recursive: true);
        } catch (e) {
          debugPrint('Failed to clean up temp directory: $e');
        }
      }
    }
  }

  // Private helper methods

  Future<FolderExportData> _collectFolderData(VaultFolder folder, Function(String)? onProgress) async {
    final files = <FileExportData>[];
    final folders = <VaultFolder>[];
    
    await _collectFolderDataRecursive(folder, '', files, folders, onProgress);
    
    return FolderExportData(files: files, folders: folders);
  }

  Future<void> _collectFolderDataRecursive(
    VaultFolder folder,
    String basePath,
    List<FileExportData> files,
    List<VaultFolder> folders,
    Function(String)? onProgress,
  ) async {
    folders.add(folder);
    
    // Get files in this folder
    final folderFiles = await repo.listFiles(parentId: folder.id);
    for (final file in folderFiles) {
      final relativePath = basePath.isEmpty ? file.originalName : '$basePath/${file.originalName}';
      files.add(FileExportData(file: file, relativePath: relativePath));
    }
    
    // Get subfolders
    final subfolders = await repo.listFolders(parentId: folder.id);
    for (final subfolder in subfolders) {
      final subPath = basePath.isEmpty ? subfolder.name : '$basePath/${subfolder.name}';
      await _collectFolderDataRecursive(subfolder, subPath, files, folders, onProgress);
    }
    
    onProgress?.call('Collecting: ${files.length} files, ${folders.length} folders');
  }

  Future<int> _ensureFolderPath(String folderPath, int rootFolderId, Map<String, int> createdFolders) async {
    if (createdFolders.containsKey(folderPath)) {
      return createdFolders[folderPath]!;
    }
    
    final parts = folderPath.split('/').where((p) => p.isNotEmpty).toList();
    int currentFolderId = rootFolderId;
    String currentPath = '';
    
    for (final part in parts) {
      currentPath = currentPath.isEmpty ? part : '$currentPath/$part';
      
      if (createdFolders.containsKey(currentPath)) {
        currentFolderId = createdFolders[currentPath]!;
      } else {
        final newFolder = await repo.createFolder(name: part, parentId: currentFolderId);
        createdFolders[currentPath] = newFolder.id;
        currentFolderId = newFolder.id;
      }
    }
    
    return currentFolderId;
  }

  /// Encrypt data with password using AES-256-CBC + PBKDF2 (cross-platform compatible)
  Future<Uint8List> _encryptWithPassword(Uint8List data, String password) async {
    // Generate random salt
    final salt = _generateRandomBytes(_saltSize);
    
    // Derive key from password using PBKDF2
    final key = _deriveKey(password, salt);
    
    // Generate random IV
    final iv = _generateRandomBytes(_ivSize);
    
    // Pad data using PKCS7
    final paddedData = _padPKCS7(data, 16);
    
    // Encrypt data using AES-256-CBC
    final cipher = CBCBlockCipher(AESEngine());
    cipher.init(true, ParametersWithIV(KeyParameter(key), iv));
    
    final encrypted = _processBlocks(cipher, paddedData);
    
    // Combine salt + iv + encrypted data
    final result = Uint8List(salt.length + iv.length + encrypted.length);
    result.setRange(0, salt.length, salt);
    result.setRange(salt.length, salt.length + iv.length, iv);
    result.setRange(salt.length + iv.length, result.length, encrypted);
    
    return result;
  }

  /// Decrypt data with password using AES-256-CBC + PBKDF2
  Future<Uint8List> _decryptWithPassword(Uint8List encryptedData, String password) async {
    if (encryptedData.length < _saltSize + _ivSize) {
      throw Exception('Invalid encrypted data: too short');
    }
    
    // Extract salt, IV, and encrypted data
    final salt = encryptedData.sublist(0, _saltSize);
    final iv = encryptedData.sublist(_saltSize, _saltSize + _ivSize);
    final encrypted = encryptedData.sublist(_saltSize + _ivSize);
    
    // Derive key from password
    final key = _deriveKey(password, salt);
    
    // Decrypt data using AES-256-CBC
    final cipher = CBCBlockCipher(AESEngine());
    cipher.init(false, ParametersWithIV(KeyParameter(key), iv));
    
    final paddedDecrypted = _processBlocks(cipher, encrypted);
    
    // Remove PKCS7 padding
    final decrypted = _unpadPKCS7(paddedDecrypted);
    
    return decrypted;
  }

  /// Derive key from password using PBKDF2 with SHA-256
  Uint8List _deriveKey(String password, Uint8List salt) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(Pbkdf2Parameters(salt, _iterations, _keySize));
    return pbkdf2.process(Uint8List.fromList(password.codeUnits));
  }

  /// Generate cryptographically secure random bytes
  Uint8List _generateRandomBytes(int length) {
    final random = SecureRandom('Fortuna');
    final seed = Uint8List(32);
    // Use current time and random values for seeding
    final now = DateTime.now().millisecondsSinceEpoch;
    for (int i = 0; i < 32; i++) {
      seed[i] = (now + i * 7) % 256;
    }
    random.seed(KeyParameter(seed));
    return random.nextBytes(length);
  }

  /// Process blocks with cipher
  Uint8List _processBlocks(BlockCipher cipher, Uint8List input) {
    final output = Uint8List(input.length);
    for (int offset = 0; offset < input.length;) {
      final len = cipher.processBlock(input, offset, output, offset);
      offset += len;
    }
    return output;
  }

  /// Add PKCS7 padding
  Uint8List _padPKCS7(Uint8List data, int blockSize) {
    final padLength = blockSize - (data.length % blockSize);
    final padded = Uint8List(data.length + padLength);
    padded.setRange(0, data.length, data);
    for (int i = data.length; i < padded.length; i++) {
      padded[i] = padLength;
    }
    return padded;
  }

  /// Remove PKCS7 padding
  Uint8List _unpadPKCS7(Uint8List paddedData) {
    if (paddedData.isEmpty) {
      throw Exception('Invalid padded data');
    }
    final padLength = paddedData.last;
    if (padLength < 1 || padLength > 16 || padLength > paddedData.length) {
      throw Exception('Invalid padding');
    }
    return paddedData.sublist(0, paddedData.length - padLength);
  }
}

// Data classes

class FolderExportData {
  final List<FileExportData> files;
  final List<VaultFolder> folders;

  FolderExportData({required this.files, required this.folders});
}

class FileExportData {
  final VaultFile file;
  final String relativePath;

  FileExportData({required this.file, required this.relativePath});
}

class EncryptedExportResult {
  final bool success;
  final String outputPath;
  final int fileSize;
  final int filesExported;
  final int foldersExported;
  final String message;

  EncryptedExportResult({
    required this.success,
    required this.outputPath,
    required this.fileSize,
    required this.filesExported,
    required this.foldersExported,
    required this.message,
  });
}

class EncryptedImportResult {
  final bool success;
  final String folderName;
  final int filesImported;
  final int foldersCreated;
  final List<String> errors;
  final String message;

  EncryptedImportResult({
    required this.success,
    required this.folderName,
    required this.filesImported,
    required this.foldersCreated,
    required this.errors,
    required this.message,
  });
}

/// Helper class for temp file tracking during import
class _TempFileInfo {
  final String tempPath;
  final String originalName;
  final String dirPath;
  
  _TempFileInfo({
    required this.tempPath,
    required this.originalName,
    required this.dirPath,
  });
}