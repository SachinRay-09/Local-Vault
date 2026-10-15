import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'crypto_engine.dart';
import 'dart_crypto_engine.dart';

/// Native crypto backend for Windows (BCrypt/CNG) and Android (javax.crypto).
///
/// For v1 blobs: routes to the platform's native AES-256-GCM implementation.
/// For v0 blobs: always falls back to [DartCryptoEngine] (AES-256-CTR).
/// For key derivation: always delegates to [DartCryptoEngine].
class NativeCryptoEngine implements CryptoEngine {
  NativeCryptoEngine() : _fallback = DartCryptoEngine();

  static const _channel = MethodChannel('local_vault/crypto_native');

  final DartCryptoEngine _fallback;

  @override
  Future<EncryptResult> encryptFile({
    required String sourcePath,
    required String destPath,
    required Uint8List key,
    EncryptionOptions options = const EncryptionOptions(),
  }) async {
    if (options.formatVersion != 1) {
      // v0 always handled by Dart engine
      return _fallback.encryptFile(
          sourcePath: sourcePath,
          destPath: destPath,
          key: key,
          options: options);
    }

    if (Platform.isWindows || Platform.isAndroid) {
      final result =
          await _channel.invokeMethod<Map<Object?, Object?>>('encryptFile', {
        'sourcePath': sourcePath,
        'destPath': destPath,
        'keyBase64': base64Encode(key),
      });
      final byteSize = (result!['byteSize'] as int);
      return EncryptResult(
        ivBase64: '',
        byteSize: byteSize,
        formatVersion: 1,
      );
    }

    // Unsupported platform — fall back to Dart v1 path
    return _fallback.encryptFile(
        sourcePath: sourcePath, destPath: destPath, key: key, options: options);
  }

  @override
  Future<void> decryptFile({
    required String sourcePath,
    required String destPath,
    required Uint8List key,
    required String ivBase64,
  }) async {
    // Auto-detect format: probe first 8 bytes
    final raf = File(sourcePath).openSync();
    final probe = raf.readSync(8);
    raf.closeSync();
    final isV1 = probe.length == 8 && String.fromCharCodes(probe) == 'LVCRYPT1';

    if (!isV1) {
      // v0 blob — always use Dart CTR fallback
      return _fallback.decryptFile(
          sourcePath: sourcePath,
          destPath: destPath,
          key: key,
          ivBase64: ivBase64);
    }

    if (Platform.isWindows || Platform.isAndroid) {
      await _channel.invokeMethod<void>('decryptFile', {
        'sourcePath': sourcePath,
        'destPath': destPath,
        'keyBase64': base64Encode(key),
        'ivBase64': ivBase64,
      });
      return;
    }

    // Unsupported platform — fall back to Dart v1 path
    return _fallback.decryptFile(
        sourcePath: sourcePath,
        destPath: destPath,
        key: key,
        ivBase64: ivBase64);
  }

  @override
  Future<Uint8List> deriveKey(
    String password,
    Uint8List salt,
    int iterations,
    int outLen,
  ) =>
      _fallback.deriveKey(password, salt, iterations, outLen);
}

/// Factory: returns [NativeCryptoEngine] for v1 on Windows/Android,
/// [DartCryptoEngine] everywhere else (or for v0).
CryptoEngine buildCryptoEngine({int formatVersion = 0}) {
  if (formatVersion == 1 && (Platform.isWindows || Platform.isAndroid)) {
    return NativeCryptoEngine();
  }
  return DartCryptoEngine();
}
