import 'dart:io';

import '../models/vault_file.dart';
import 'file_crypto_service.dart';
import 'file_open_service.dart';
import 'secure_storage_service.dart';
import 'vault_paths.dart';

class VaultOpenService {
  VaultOpenService({
    required this.crypto,
    required this.secureStorage,
    required this.opener,
  });

  final FileCryptoService crypto;
  final SecureStorageService secureStorage;
  final FileOpenService opener;

  Future<File> decryptToCachedTempFile(VaultFile file) async {
    final masterKey32 = await secureStorage.getOrCreateMasterKey32();

    final dir = await VaultPaths.ensureTempDir();
    await _bestEffortCleanup(dir);

    // Deterministic cache name prevents repeated decrypts.
    final safeName = _safeFilename(file.originalName);
    final outFile = File('${dir.path}${Platform.pathSeparator}${file.storedBlobName}--$safeName');
    if (await outFile.exists()) {
      final len = await outFile.length();
      if (len > 0) return outFile;
    }

    await crypto.decryptBlobToFile(
      storedBlobName: file.storedBlobName,
      ivBase64: file.ivBase64,
      masterKey32: masterKey32,
      outputFile: outFile,
    );
    return outFile;
  }

  Future<String> decryptToTempAndOpen(VaultFile file) async {
    final outFile = await decryptToCachedTempFile(file);
    await opener.openFile(outFile.path);
    return outFile.path;
  }

  /// Decrypt a file to a specific path (used by Android manga service)
  Future<void> decryptToSpecificPath(VaultFile file, String outputPath) async {
    final masterKey32 = await secureStorage.getOrCreateMasterKey32();
    final outputFile = File(outputPath);
    
    // Ensure output directory exists
    await outputFile.parent.create(recursive: true);
    
    await crypto.decryptBlobToFile(
      storedBlobName: file.storedBlobName,
      ivBase64: file.ivBase64,
      masterKey32: masterKey32,
      outputFile: outputFile,
    );
  }

  /// Decrypt a file to bytes (used by encrypted export service)
  Future<List<int>> decryptToBytes(VaultFile file) async {
    final tempFile = await decryptToCachedTempFile(file);
    return await tempFile.readAsBytes();
  }

  static String _safeFilename(String name) {
    // Avoid path traversal and invalid characters (esp. Windows).
    final base = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
    return base.isEmpty ? 'file.bin' : base;
  }

  static Future<void> _bestEffortCleanup(Directory dir) async {
    // Keep it lightweight: delete temp files older than 24h.
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    try {
      final entries = dir.listSync();
      for (final e in entries) {
        if (e is File) {
          final stat = e.statSync();
          if (stat.modified.isBefore(cutoff)) {
            try {
              e.deleteSync();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }
}

