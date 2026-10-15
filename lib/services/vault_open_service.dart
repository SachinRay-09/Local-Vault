import 'dart:io';
import 'dart:typed_data';

import '../app/auth_session.dart';
import '../models/vault_file.dart';
import 'crypto_engine.dart';
import 'dart_crypto_engine.dart';
import 'file_crypto_service.dart';
import 'file_open_service.dart';
import 'secure_storage_service.dart';
import 'vault_paths.dart';

class VaultOpenService {
  VaultOpenService({
    required this.crypto,
    required this.secureStorage,
    required this.opener,
    CryptoEngine? cryptoEngine,
  }) : _cryptoEngine = cryptoEngine ?? DartCryptoEngine();

  /// Legacy v0-only service — kept for API compatibility; actual decryption
  /// now goes through [_cryptoEngine] which auto-detects v0 vs v1 blobs.
  final FileCryptoService crypto;
  final SecureStorageService secureStorage;
  final FileOpenService opener;

  /// Handles both v0 (AES-256-CTR) and v1 (AES-256-GCM) blobs via
  /// auto-detection. Defaults to [DartCryptoEngine] so existing callers that
  /// don't pass a [cryptoEngine] are automatically upgraded to v1-aware
  /// decryption.
  final CryptoEngine _cryptoEngine;

  Future<File> decryptToCachedTempFile(VaultFile file) async {
    // Prefer the in-memory DEK from the active session — avoids a round-trip
    // to EncryptedSharedPreferences on every file open (OPT-001).
    final masterKey32 = AuthSession.current?.dek ??
        await secureStorage.getOrCreateMasterKey32();

    final dir = await VaultPaths.ensureTempDir();
    await _bestEffortCleanup(dir);

    // Deterministic cache name prevents repeated decrypts.
    final safeName = _safeFilename(file.originalName);
    final outFile = File(
        '${dir.path}${Platform.pathSeparator}${file.storedBlobName}--$safeName');
    if (await outFile.exists()) {
      final len = await outFile.length();
      if (len > 0) return outFile;
    }

    await _decryptBlob(file, masterKey32, outFile);
    return outFile;
  }

  Future<String> decryptToTempAndOpen(VaultFile file) async {
    final outFile = await decryptToCachedTempFile(file);
    await opener.openFile(outFile.path);
    return outFile.path;
  }

  /// Decrypt a file to a specific path (used by Android manga service)
  Future<void> decryptToSpecificPath(VaultFile file, String outputPath) async {
    // Prefer the in-memory DEK from the active session (OPT-001).
    final masterKey32 = AuthSession.current?.dek ??
        await secureStorage.getOrCreateMasterKey32();
    final outputFile = File(outputPath);

    // Ensure output directory exists
    await outputFile.parent.create(recursive: true);

    await _decryptBlob(file, masterKey32, outputFile);
  }

  /// Decrypt a file to bytes (used by encrypted export service)
  Future<List<int>> decryptToBytes(VaultFile file) async {
    final tempFile = await decryptToCachedTempFile(file);
    return await tempFile.readAsBytes();
  }

  // ─── Internal: dispatch to the right decrypt path ──────────────────────

  /// Decrypts [file]'s blob to [outputFile].
  ///
  /// Uses [_cryptoEngine] which auto-detects v0/v1 from the blob header,
  /// so both legacy AES-256-CTR blobs and new AES-256-GCM blobs are handled
  /// correctly.
  Future<void> _decryptBlob(
      VaultFile file, Uint8List masterKey32, File outputFile) async {
    final blobsDir = await VaultPaths.ensureVaultBlobsDir();
    final blobPath =
        '${blobsDir.path}${Platform.pathSeparator}${file.storedBlobName}';
    await _cryptoEngine.decryptFile(
      sourcePath: blobPath,
      destPath: outputFile.path,
      key: masterKey32,
      ivBase64: file.ivBase64,
    );
  }

  static String _safeFilename(String name) {
    // Avoid path traversal and invalid characters (esp. Windows).
    final base = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
    return base.isEmpty ? 'file.bin' : base;
  }

  static Future<void> _bestEffortCleanup(Directory dir) async {
    // Keep it lightweight: delete temp files older than 24h.
    // Use async list/stat to avoid blocking the UI isolate (CRASH-003/PERF-001).
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    try {
      await for (final e in dir.list()) {
        if (e is File) {
          final stat = await e.stat();
          if (stat.modified.isBefore(cutoff)) {
            try {
              await e.delete();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }
}
