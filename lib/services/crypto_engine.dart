import 'dart:typed_data';

/// Result returned by [CryptoEngine.encryptFile].
class EncryptResult {
  const EncryptResult({required this.ivBase64, required this.byteSize});

  /// Base64-encoded initialisation vector used for this encryption.
  final String ivBase64;

  /// Number of plaintext bytes encrypted.
  final int byteSize;
}

/// Abstract interface for file-level AES encryption/decryption and key
/// derivation.  Implementations may run on a background isolate.
abstract class CryptoEngine {
  /// Encrypts the file at [sourcePath] and writes the cipher-text to [destPath].
  ///
  /// [key] must be exactly 32 bytes (AES-256).
  /// Returns an [EncryptResult] containing the IV and original byte count.
  Future<EncryptResult> encryptFile({
    required String sourcePath,
    required String destPath,
    required Uint8List key,
  });

  /// Decrypts the file at [sourcePath] and writes the plain-text to [destPath].
  ///
  /// [key] must be exactly 32 bytes (AES-256).
  /// [ivBase64] is the Base64-encoded IV that was returned by [encryptFile].
  Future<void> decryptFile({
    required String sourcePath,
    required String destPath,
    required Uint8List key,
    required String ivBase64,
  });

  /// Derives a key from [password] using PBKDF2-HMAC-SHA256.
  ///
  /// [salt] should be at least 16 random bytes.
  /// [iterations] is the PBKDF2 iteration count (≥ 100 000 recommended).
  /// [outLen] is the desired output length in bytes.
  Future<Uint8List> deriveKey(
    String password,
    Uint8List salt,
    int iterations,
    int outLen,
  );
}
