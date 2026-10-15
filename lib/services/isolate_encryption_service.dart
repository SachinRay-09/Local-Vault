import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import 'file_crypto_service.dart';

/// Isolate-based encryption service for high-performance bulk operations
/// Encrypts files in background isolate to keep UI responsive
@Deprecated(
    'Quarantined Phase 1 — placeholder service, do not use in production. Replacement: DartCryptoEngine.')
class IsolateEncryptionService {
  /// Encrypt multiple files in background isolate
  /// Returns list of encryption results
  Future<List<EncryptionResult>> encryptFilesInBackground({
    required List<String> filePaths,
    required Uint8List masterKey32,
    Function(int current, int total, String filename)? onProgress,
  }) async {
    assert(false,
        'IsolateCryptoService is a placeholder — do not call in production');
    try {
      debugPrint('Starting isolate encryption for ${filePaths.length} files');

      // Create parameters for isolate
      final params = _EncryptionParams(
        filePaths: filePaths,
        masterKey32: masterKey32,
      );

      // Use compute for simple isolate execution
      // compute() automatically handles isolate creation and cleanup
      final results = await compute(_encryptFilesInIsolate, params);

      // Send progress updates (compute doesn't support streaming, so we update at end)
      if (onProgress != null) {
        for (int i = 0; i < results.length; i++) {
          onProgress(i + 1, results.length, path.basename(filePaths[i]));
          // Small delay to allow UI updates
          await Future.delayed(const Duration(milliseconds: 1));
        }
      }

      debugPrint('Isolate encryption completed: ${results.length} files');
      return results;
    } catch (e) {
      debugPrint('Isolate encryption failed: $e');
      rethrow;
    }
  }

  /// Top-level function for isolate execution
  /// MUST be top-level or static for isolates
  static Future<List<EncryptionResult>> _encryptFilesInIsolate(
      _EncryptionParams params) async {
    final results = <EncryptionResult>[];
    const crypto = FileCryptoService();

    // Process files in batches to avoid memory issues
    const batchSize = 50;
    for (int batchStart = 0;
        batchStart < params.filePaths.length;
        batchStart += batchSize) {
      final batchEnd =
          (batchStart + batchSize).clamp(0, params.filePaths.length);
      final batch = params.filePaths.sublist(batchStart, batchEnd);

      for (final filePath in batch) {
        try {
          final file = File(filePath);

          // Check if file exists
          if (!await file.exists()) {
            debugPrint('File does not exist: $filePath');
            results.add(EncryptionResult(
              success: false,
              originalPath: filePath,
              error: 'File does not exist',
            ));
            continue;
          }

          // Check file size
          final fileSize = await file.length();
          debugPrint(
              'Encrypting file: ${path.basename(filePath)} ($fileSize bytes)');

          // Encrypt file
          final result = await crypto.encryptFileToBlob(
            sourceFile: file,
            masterKey32: params.masterKey32,
          );

          debugPrint('Encrypted successfully: ${result.storedBlobName}');

          results.add(EncryptionResult(
            success: true,
            originalPath: filePath,
            storedBlobName: result.storedBlobName,
            byteSize: result.byteSize,
            ivBase64: result.ivBase64,
          ));
        } catch (e) {
          debugPrint('Failed to encrypt file $filePath: $e');
          results.add(EncryptionResult(
            success: false,
            originalPath: filePath,
            error: e.toString(),
          ));
        }
      }

      // Yield to isolate event loop after each batch
      await Future.delayed(const Duration(milliseconds: 10));
    }

    return results;
  }
}

/// Parameters for isolate encryption
class _EncryptionParams {
  final List<String> filePaths;
  final Uint8List masterKey32;

  _EncryptionParams({
    required this.filePaths,
    required this.masterKey32,
  });
}

/// Result of file encryption
class EncryptionResult {
  final bool success;
  final String originalPath;
  final String? storedBlobName;
  final int? byteSize;
  final String? ivBase64;
  final String? error;

  EncryptionResult({
    required this.success,
    required this.originalPath,
    this.storedBlobName,
    this.byteSize,
    this.ivBase64,
    this.error,
  });
}
