import 'dart:convert';
import 'dart:typed_data';

/// Typed representation of the vault_key_envelope_v2 JSON stored in
/// flutter_secure_storage.
///
/// The envelope wraps the 32-byte vault DEK (Data Encryption Key) with a
/// Key Encryption Key (KEK) derived from the user's password via
/// PBKDF2-HMAC-SHA256.  This means the user's password is cryptographically
/// required to decrypt vault files — not merely an app-unlock gate.
class VaultKeyEnvelope {
  const VaultKeyEnvelope({
    required this.vaultVersion,
    required this.kdfAlgorithm,
    required this.kdfSalt,
    required this.kdfParams,
    required this.wrappedDek,
    required this.wrappedDekNonce,
    required this.wrappedDekTag,
  });

  /// Always 2 for Phase 5 envelopes.
  final int vaultVersion;

  /// KDF algorithm identifier, e.g. "pbkdf2_sha256". Extensible for future
  /// Argon2id without format breakage.
  final String kdfAlgorithm;

  /// 16-byte random KDF salt, base64-encoded.
  final String kdfSalt;

  /// KDF parameters map, e.g. {"iterations": 200000}.
  final Map<String, dynamic> kdfParams;

  /// AES-256-GCM ciphertext of the 32-byte DEK — base64, exactly 32 bytes
  /// decoded.
  final String wrappedDek;

  /// 12-byte GCM nonce — base64.
  final String wrappedDekNonce;

  /// 16-byte GCM authentication tag — base64.
  final String wrappedDekTag;

  factory VaultKeyEnvelope.fromJson(Map<String, dynamic> json) =>
      VaultKeyEnvelope(
        vaultVersion: json['vault_version'] as int,
        kdfAlgorithm: json['kdf_algorithm'] as String,
        kdfSalt: json['kdf_salt'] as String,
        kdfParams: Map<String, dynamic>.from(json['kdf_params'] as Map),
        wrappedDek: json['wrapped_dek'] as String,
        wrappedDekNonce: json['wrapped_dek_nonce'] as String,
        wrappedDekTag: json['wrapped_dek_tag'] as String,
      );

  Map<String, dynamic> toJson() => {
        'vault_version': vaultVersion,
        'kdf_algorithm': kdfAlgorithm,
        'kdf_salt': kdfSalt,
        'kdf_params': kdfParams,
        'wrapped_dek': wrappedDek,
        'wrapped_dek_nonce': wrappedDekNonce,
        'wrapped_dek_tag': wrappedDekTag,
      };

  /// Decoded DEK ciphertext bytes (32 bytes).
  Uint8List get wrappedDekBytes => base64Decode(wrappedDek);

  /// Decoded GCM nonce bytes (12 bytes).
  Uint8List get nonceBytes => base64Decode(wrappedDekNonce);

  /// Decoded GCM authentication tag bytes (16 bytes).
  Uint8List get tagBytes => base64Decode(wrappedDekTag);

  /// Decoded KDF salt bytes (16 bytes).
  Uint8List get saltBytes => base64Decode(kdfSalt);

  /// PBKDF2 iteration count from [kdfParams].
  int get iterations => kdfParams['iterations'] as int;
}
