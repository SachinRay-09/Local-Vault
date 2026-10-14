import 'dart:convert';
import 'dart:typed_data';

import 'secure_storage_service.dart';

/// Thin wrapper around [SecureStorageService] that exposes credential data as
/// typed values for use by [AuthSession] and any other auth consumers.
class CredentialRepository {
  CredentialRepository({SecureStorageService? storage})
      : _storage = storage ?? SecureStorageService.instance;

  final SecureStorageService _storage;

  /// Returns the raw master-key bytes stored under [SecureStorageService.kMasterKeyB64],
  /// or null if none has been created yet.
  Future<Uint8List?> loadMasterKey() async {
    final b64 = await _storage.readString(SecureStorageService.kMasterKeyB64);
    if (b64 == null || b64.isEmpty) return null;
    return base64Decode(b64);
  }

  /// Returns the stored PBKDF2 hash string (base-64 encoded), or null.
  Future<String?> loadPasswordHash() async {
    return _storage.readString(SecureStorageService.kPasswordHashB64);
  }

  /// Returns the stored salt bytes, or null.
  Future<Uint8List?> loadSalt() async {
    final b64 =
        await _storage.readString(SecureStorageService.kPasswordSaltB64);
    if (b64 == null || b64.isEmpty) return null;
    return base64Decode(b64);
  }

  /// Returns the stored PBKDF2 iteration count, or null if not set.
  Future<int?> loadIterations() async {
    final raw =
        await _storage.readString(SecureStorageService.kPasswordIterations);
    return raw != null ? int.tryParse(raw) : null;
  }

  /// Returns true if [derivedBytes] matches [storedHashB64] (constant-time).
  Future<bool> verifyHash(Uint8List derivedBytes, String storedHashB64) async {
    final expected = base64Decode(storedHashB64);
    return _constantTimeEquals(derivedBytes, expected);
  }

  static bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
