import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import '../models/vault_key_envelope.dart';
import 'credential_repository.dart';
import 'dart_crypto_engine.dart';
import 'secure_storage_service.dart';

class AuthState {
  const AuthState({required this.isSetup});

  final bool isSetup;
}

class AuthService {
  AuthService({required this.secureStorage});

  final SecureStorageService secureStorage;

  static const String kQ1Text = 'security_q1_text';
  static const String kQ1SaltB64 = 'security_q1_salt_b64';
  static const String kQ1HashB64 = 'security_q1_hash_b64';
  static const String kQ2Text = 'security_q2_text';
  static const String kQ2SaltB64 = 'security_q2_salt_b64';
  static const String kQ2HashB64 = 'security_q2_hash_b64';

  Future<AuthState> loadState() async {
    final isSetup = await secureStorage.hasPassword();
    return AuthState(isSetup: isSetup);
  }

  Future<void> setup({
    required String password,
    required String q1Text,
    required String q1Answer,
    required String q2Text,
    required String q2Answer,
  }) async {
    // 1. Generate a fresh random 32-byte DEK.
    final dek = SecureStorageService.generateRandomBytes(32);

    // 2. Store as master_key_b64 (belt-and-suspenders / legacy compat).
    await secureStorage.writeString(
        SecureStorageService.kMasterKeyB64, base64Encode(dek));

    // 3. Store the password hash (for login verification).
    await secureStorage.setPassword(password);

    // 4. Derive KEK + wrap DEK into envelope — off UI thread via deriveKek.
    const kekIterations = 200000;
    final salt = SecureStorageService.generateRandomBytes(16);
    final kek = await DartCryptoEngine.deriveKek(password, salt, kekIterations);
    final wrapped = DartCryptoEngine.wrapDek(dek, kek);

    final envelope = VaultKeyEnvelope(
      vaultVersion: 2,
      kdfAlgorithm: 'pbkdf2_sha256',
      kdfSalt: base64Encode(salt),
      kdfParams: {'iterations': kekIterations},
      wrappedDek: base64Encode(wrapped.ciphertext),
      wrappedDekNonce: base64Encode(wrapped.nonce),
      wrappedDekTag: base64Encode(wrapped.tag),
    );

    // No rollback marker needed during initial setup (no legacy key exists yet).
    final repo = CredentialRepository(storage: secureStorage);
    await repo.storeEnvelope(envelope);

    // Zero the ephemeral KEK.
    kek.fillRange(0, kek.length, 0);

    // 5. Store security questions (unchanged).
    await _setSecurityQuestions(
      q1Text: q1Text,
      q1Answer: q1Answer,
      q2Text: q2Text,
      q2Answer: q2Answer,
    );
  }

  Future<bool> verifyPassword(String password) async {
    return secureStorage.verifyPassword(password);
  }

  Future<Duration?> lockRemaining() => secureStorage.lockRemaining();

  Future<bool> verifySecurityAnswers({
    required String q1Answer,
    required String q2Answer,
  }) async {
    final q1SaltB64 = await secureStorage.readString(kQ1SaltB64);
    final q1HashB64 = await secureStorage.readString(kQ1HashB64);
    final q2SaltB64 = await secureStorage.readString(kQ2SaltB64);
    final q2HashB64 = await secureStorage.readString(kQ2HashB64);
    if (q1SaltB64 == null ||
        q1HashB64 == null ||
        q2SaltB64 == null ||
        q2HashB64 == null) {
      return false;
    }

    final q1Ok = _verifyWithSaltedHash(
      secret: q1Answer,
      salt: base64Decode(q1SaltB64),
      expectedHash: base64Decode(q1HashB64),
    );
    final q2Ok = _verifyWithSaltedHash(
      secret: q2Answer,
      salt: base64Decode(q2SaltB64),
      expectedHash: base64Decode(q2HashB64),
    );
    return q1Ok && q2Ok;
  }

  Future<void> resetPassword(String newPassword) async {
    // Keep the master key unchanged; only the app password gate changes.
    await secureStorage.setPassword(newPassword);
  }

  Future<Map<String, String>?> getSecurityQuestionTexts() async {
    final q1 = await secureStorage.readString(kQ1Text);
    final q2 = await secureStorage.readString(kQ2Text);
    if (q1 == null || q2 == null) return null;
    return {'q1': q1, 'q2': q2};
  }

  Future<void> _setSecurityQuestions({
    required String q1Text,
    required String q1Answer,
    required String q2Text,
    required String q2Answer,
  }) async {
    final q1Salt = _randomBytes(16);
    final q2Salt = _randomBytes(16);
    final q1Hash = _saltedSha256(q1Answer, q1Salt);
    final q2Hash = _saltedSha256(q2Answer, q2Salt);

    await secureStorage.writeString(kQ1Text, q1Text);
    await secureStorage.writeString(kQ2Text, q2Text);
    await secureStorage.writeString(kQ1SaltB64, base64Encode(q1Salt));
    await secureStorage.writeString(kQ2SaltB64, base64Encode(q2Salt));
    await secureStorage.writeString(kQ1HashB64, base64Encode(q1Hash));
    await secureStorage.writeString(kQ2HashB64, base64Encode(q2Hash));
  }

  static Uint8List _saltedSha256(String secret, Uint8List salt) {
    final data = <int>[...utf8.encode(secret), ...salt];
    // Keep SHA256 here for security questions (good enough for now).
    // App password uses PBKDF2 in SecureStorageService.
    return Uint8List.fromList(crypto.sha256.convert(data).bytes);
  }

  static bool _verifyWithSaltedHash({
    required String secret,
    required Uint8List salt,
    required Uint8List expectedHash,
  }) {
    final got = _saltedSha256(secret, salt);
    return _constantTimeEquals(got, expectedHash);
  }

  static Uint8List _randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List<int>.generate(n, (_) => r.nextInt(256)));
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
