import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/vault_key_envelope.dart';
import 'secure_storage_service.dart';

/// Thin wrapper around [SecureStorageService] that exposes credential data as
/// typed values for use by [AuthSession] and any other auth consumers.
class CredentialRepository {
  CredentialRepository({SecureStorageService? storage})
      : _storage = storage ?? SecureStorageService.instance;

  final SecureStorageService _storage;

  // Phase 5 envelope storage keys.
  static const String _kEnvelopeJson = 'vault_key_envelope_v2';
  static const String _kRollbackKey = 'vault_key_rollback_v2';

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

  // ---------------------------------------------------------------------------
  // Phase 5: envelope storage methods
  // ---------------------------------------------------------------------------

  /// Serialises [envelope] to JSON and stores it in secure storage.
  Future<void> storeEnvelope(VaultKeyEnvelope envelope) async {
    await _storage.writeString(_kEnvelopeJson, jsonEncode(envelope.toJson()));
  }

  /// Loads and deserialises the stored envelope, or returns null if none
  /// exists or the stored JSON cannot be parsed.
  Future<VaultKeyEnvelope?> loadEnvelope() async {
    final s = await _storage.readString(_kEnvelopeJson);
    if (s == null || s.isEmpty) return null;
    try {
      return VaultKeyEnvelope.fromJson(
          Map<String, dynamic>.from(jsonDecode(s) as Map));
    } catch (e) {
      debugPrint('[CredentialRepository] Failed to parse envelope: $e');
      return null;
    }
  }

  /// Returns true if a Phase 5 envelope is present in secure storage.
  Future<bool> hasEnvelope() async {
    final s = await _storage.readString(_kEnvelopeJson);
    return s != null && s.isNotEmpty;
  }

  /// Stores [legacyMasterKey] under the rollback key as base64.
  ///
  /// INVARIANT: call this BEFORE every [storeEnvelope] call so the old key
  /// is recoverable if the process is killed mid-migration.
  Future<void> storeRollbackMarker(Uint8List legacyMasterKey) async {
    await _storage.writeString(_kRollbackKey, base64Encode(legacyMasterKey));
  }

  /// Deletes the rollback marker after a successful migration or password
  /// change.
  Future<void> deleteRollbackMarker() async {
    await _storage.delete(_kRollbackKey);
  }

  /// Deletes the envelope.  Used on migration failure or password-change
  /// rollback.
  Future<void> deleteEnvelope() async {
    await _storage.delete(_kEnvelopeJson);
  }
}
