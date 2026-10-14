import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'vault_paths.dart';

/// Container-based folder encryption for high-performance bulk operations
@Deprecated(
    'Quarantined Phase 1 — TAR container strategy is not suitable for manga import. Do not use.')
class FolderCryptoService {
  static const String _containerVersion = '2.0';

  /// Determines if folder should use container encryption based on file count and types
  static bool shouldUseContainerEncryption(List<File> files) {
    if (files.length <= 20) {
      return false; // Small folders use individual encryption
    }

    // Check if majority are images/videos (good candidates for container)
    final mediaFiles = files.where((f) => _isMediaFile(f.path)).length;
    return mediaFiles > files.length * 0.7; // 70% media files
  }

  static bool _isMediaFile(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.webp',
      '.mp4',
      '.mkv',
      '.avi',
      '.mov'
    ].contains(ext);
  }

  /// Creates an encrypted container from multiple files
  Future<ContainerResult> createEncryptedContainer({
    required List<File> sourceFiles,
    required String containerName,
    required List<int> masterKey32,
    Function(double)? onProgress,
  }) async {
    try {
      debugPrint(
          'Creating encrypted container for ${sourceFiles.length} files');

      // Create container in vault blobs directory
      final blobsDir = await VaultPaths.ensureVaultBlobsDir();
      final containerFileName =
          '${DateTime.now().millisecondsSinceEpoch}_${containerName}_container.vault_container';
      final containerFile = File(path.join(blobsDir.path, containerFileName));

      // Create manifest with file metadata
      final manifest = ContainerManifest(
        version: _containerVersion,
        containerName: containerName,
        createdAt: DateTime.now(),
        files: [],
      );

      // Create temporary archive
      final tempDir = await getTemporaryDirectory();
      final archiveDir = Directory(path.join(
          tempDir.path, 'container_${DateTime.now().millisecondsSinceEpoch}'));
      await archiveDir.create(recursive: true);

      try {
        int totalSize = 0;
        int processedSize = 0;

        // Calculate total size for progress
        for (final file in sourceFiles) {
          totalSize += await file.length();
        }

        // Copy files to archive directory and build manifest
        for (int i = 0; i < sourceFiles.length; i++) {
          final sourceFile = sourceFiles[i];
          final fileName = path.basename(sourceFile.path);
          final targetFile = File(path.join(archiveDir.path, fileName));

          // Copy file
          await sourceFile.copy(targetFile.path);

          // Add to manifest
          final fileSize = await sourceFile.length();
          manifest.files.add(ContainerFileEntry(
            name: fileName,
            size: fileSize,
            checksum: await _calculateChecksum(sourceFile),
            mimeType: _getMimeType(fileName),
          ));

          processedSize += fileSize;
          onProgress
              ?.call(processedSize / totalSize * 0.7); // 70% for file copying
        }

        // Create TAR archive
        final tarBytes = await _createTarArchive(archiveDir);
        onProgress?.call(0.8); // 80% for archive creation

        // Encrypt the archive
        final encryptedData = await _encryptData(tarBytes, masterKey32);
        onProgress?.call(0.9); // 90% for encryption

        // Write encrypted container
        await containerFile.writeAsBytes(encryptedData);

        // Calculate final container size
        final containerSize = await containerFile.length();

        onProgress?.call(1.0); // 100% complete

        debugPrint(
            'Container created successfully: ${containerFile.path} ($containerSize bytes)');

        return ContainerResult(
          success: true,
          containerPath: containerFile.path,
          containerFileName: containerFileName,
          manifest: manifest,
          totalFiles: sourceFiles.length,
          containerSize: containerSize,
        );
      } finally {
        // Clean up temporary directory
        try {
          await archiveDir.delete(recursive: true);
        } catch (e) {
          debugPrint('Failed to cleanup temp directory: $e');
        }
      }
    } catch (e) {
      debugPrint('Failed to create encrypted container: $e');
      return ContainerResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Extracts a single file from encrypted container without full decryption
  Future<Uint8List?> extractFileFromContainer({
    required String containerPath,
    required String fileName,
    required List<int> masterKey32,
  }) async {
    try {
      debugPrint('Extracting $fileName from container: $containerPath');

      // Read and decrypt container
      final containerFile = File(containerPath);
      if (!await containerFile.exists()) {
        throw Exception('Container file not found: $containerPath');
      }

      final encryptedData = await containerFile.readAsBytes();
      final decryptedData = await _decryptData(encryptedData, masterKey32);

      // Extract TAR archive
      final archive = TarDecoder().decodeBytes(decryptedData);

      // Find and extract specific file
      for (final entry in archive) {
        if (entry.name == fileName && entry.isFile) {
          return Uint8List.fromList(entry.content as List<int>);
        }
      }

      throw Exception('File not found in container: $fileName');
    } catch (e) {
      debugPrint('Failed to extract file from container: $e');
      return null;
    }
  }

  /// Lists all files in an encrypted container
  Future<List<String>> listContainerFiles({
    required String containerPath,
    required List<int> masterKey32,
  }) async {
    try {
      final containerFile = File(containerPath);
      if (!await containerFile.exists()) return [];

      final encryptedData = await containerFile.readAsBytes();
      final decryptedData = await _decryptData(encryptedData, masterKey32);
      final archive = TarDecoder().decodeBytes(decryptedData);

      return archive
          .where((entry) => entry.isFile)
          .map((entry) => entry.name)
          .toList();
    } catch (e) {
      debugPrint('Failed to list container files: $e');
      return [];
    }
  }

  /// Creates TAR archive from directory
  Future<Uint8List> _createTarArchive(Directory sourceDir) async {
    final archive = Archive();

    await for (final entity in sourceDir.list(recursive: true)) {
      if (entity is File) {
        final relativePath = path.relative(entity.path, from: sourceDir.path);
        final fileBytes = await entity.readAsBytes();

        final archiveFile = ArchiveFile(
          relativePath,
          fileBytes.length,
          fileBytes,
        );
        archive.addFile(archiveFile);
      }
    }

    return Uint8List.fromList(TarEncoder().encode(archive));
  }

  /// Encrypts data using AES-256-GCM
  Future<Uint8List> _encryptData(Uint8List data, List<int> masterKey32) async {
    final key = encrypt.Key(Uint8List.fromList(masterKey32));
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter =
        encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));

    final encrypted = encrypter.encryptBytes(data, iv: iv);

    // Prepend IV to encrypted data
    final result = Uint8List(16 + encrypted.bytes.length);
    result.setRange(0, 16, iv.bytes);
    result.setRange(16, result.length, encrypted.bytes);

    return result;
  }

  /// Decrypts data using AES-256-GCM
  Future<Uint8List> _decryptData(
      Uint8List encryptedData, List<int> masterKey32) async {
    if (encryptedData.length < 16) {
      throw Exception('Invalid encrypted data: too short');
    }

    final key = encrypt.Key(Uint8List.fromList(masterKey32));
    final iv = encrypt.IV(encryptedData.sublist(0, 16));
    final cipherBytes = encryptedData.sublist(16);

    final encrypter =
        encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));
    final encrypted = encrypt.Encrypted(cipherBytes);

    return Uint8List.fromList(encrypter.decryptBytes(encrypted, iv: iv));
  }

  /// Calculates SHA-256 checksum of file
  Future<String> _calculateChecksum(File file) async {
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Gets MIME type from file extension
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
}

/// Container creation result
class ContainerResult {
  final bool success;
  final String? containerPath;
  final String? containerFileName;
  final ContainerManifest? manifest;
  final int? totalFiles;
  final int? containerSize;
  final String? error;

  ContainerResult({
    required this.success,
    this.containerPath,
    this.containerFileName,
    this.manifest,
    this.totalFiles,
    this.containerSize,
    this.error,
  });
}

/// Container manifest for metadata
class ContainerManifest {
  final String version;
  final String containerName;
  final DateTime createdAt;
  final List<ContainerFileEntry> files;

  ContainerManifest({
    required this.version,
    required this.containerName,
    required this.createdAt,
    required this.files,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'containerName': containerName,
        'createdAt': createdAt.toIso8601String(),
        'files': files.map((f) => f.toJson()).toList(),
      };

  factory ContainerManifest.fromJson(Map<String, dynamic> json) =>
      ContainerManifest(
        version: json['version'],
        containerName: json['containerName'],
        createdAt: DateTime.parse(json['createdAt']),
        files: (json['files'] as List)
            .map((f) => ContainerFileEntry.fromJson(f))
            .toList(),
      );
}

/// Individual file entry in container
class ContainerFileEntry {
  final String name;
  final int size;
  final String checksum;
  final String mimeType;

  ContainerFileEntry({
    required this.name,
    required this.size,
    required this.checksum,
    required this.mimeType,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'size': size,
        'checksum': checksum,
        'mimeType': mimeType,
      };

  factory ContainerFileEntry.fromJson(Map<String, dynamic> json) =>
      ContainerFileEntry(
        name: json['name'],
        size: json['size'],
        checksum: json['checksum'],
        mimeType: json['mimeType'],
      );
}
