import 'dart:typed_data';

/// Options controlling the on-disk format written by [CryptoEngine.encryptFile].
class EncryptionOptions {
  const EncryptionOptions({this.formatVersion = 1});

  /// 0 = legacy AES-256-CTR (backward compat — v0 blobs still decrypt via auto-detect)
  /// 1 = versioned chunked AES-256-GCM (LVCRYPT1 format) — default from Task 4.4
  final int formatVersion;
}

/// Result returned by [CryptoEngine.encryptFile].
class EncryptResult {
  const EncryptResult({
    required this.ivBase64,
    required this.byteSize,
    this.formatVersion = 0,
  });

  /// Base64-encoded IV for v0 blobs. Empty string for v1 (nonce is in the blob header).
  final String ivBase64;

  /// Number of plaintext bytes encrypted (= original file size).
  final int byteSize;

  /// Format version written: 0 = CTR, 1 = AEAD v1.
  final int formatVersion;
}

/// Abstract interface for file-level AES encryption/decryption and key derivation.
abstract class CryptoEngine {
  /// Encrypts [sourcePath] → [destPath].
  ///
  /// [key] must be exactly 32 bytes (AES-256).
  /// [options] selects the on-disk format; default is v0 (CTR) until Task 4.4.
  Future<EncryptResult> encryptFile({
    required String sourcePath,
    required String destPath,
    required Uint8List key,
    EncryptionOptions options = const EncryptionOptions(),
  });

  /// Decrypts [sourcePath] → [destPath].
  ///
  /// Auto-detects format: reads first 8 bytes; if == "LVCRYPT1" → v1 path;
  /// otherwise → legacy CTR path using [ivBase64].
  ///
  /// [key] must be exactly 32 bytes (AES-256).
  Future<void> decryptFile({
    required String sourcePath,
    required String destPath,
    required Uint8List key,
    required String ivBase64,
  });

  /// Derives a key from [password] using PBKDF2-HMAC-SHA256.
  Future<Uint8List> deriveKey(
    String password,
    Uint8List salt,
    int iterations,
    int outLen,
  );
}
