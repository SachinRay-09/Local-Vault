import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/api.dart' show KeyDerivator;
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart' show Pbkdf2Parameters;
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';

class SecureStorageService {
  SecureStorageService._(this._storage);

  static const FlutterSecureStorage _sharedStorage = FlutterSecureStorage();

  static SecureStorageService get instance => SecureStorageService._(_sharedStorage);

  // Keys (secure storage)
  static const String kMasterKeyB64 = 'master_key_b64';
  static const String kPasswordHashB64 = 'password_hash_b64';
  static const String kPasswordSaltB64 = 'password_salt_b64';
  static const String kPasswordIterations = 'password_pbkdf2_iters';

  static const String kFailedAttempts = 'auth_failed_attempts';
  static const String kLockUntilMs = 'auth_lock_until_ms';

  final FlutterSecureStorage _storage;

  Future<bool> hasPassword() async {
    final h = await _storage.read(key: kPasswordHashB64);
    final s = await _storage.read(key: kPasswordSaltB64);
    return (h != null && h.isNotEmpty) && (s != null && s.isNotEmpty);
  }

  Future<void> setPassword(String password) async {
    final salt = _randomBytes(16);
    const iters = 120000;
    final hash = _pbkdf2Sha256(password, salt, iterations: iters, outLen: 32);
    await _storage.write(key: kPasswordSaltB64, value: base64Encode(salt));
    await _storage.write(key: kPasswordHashB64, value: base64Encode(hash));
    await _storage.write(key: kPasswordIterations, value: iters.toString());

    // Reset lock state when password changes.
    await _storage.write(key: kFailedAttempts, value: '0');
    await _storage.delete(key: kLockUntilMs);
  }

  Future<bool> verifyPassword(String password) async {
    final locked = await isLockedOut();
    if (locked) return false;

    final saltB64 = await _storage.read(key: kPasswordSaltB64);
    final hashB64 = await _storage.read(key: kPasswordHashB64);
    if (saltB64 == null || hashB64 == null) return false;
    final salt = base64Decode(saltB64);
    final expected = base64Decode(hashB64);
    final itersStr = await _storage.read(key: kPasswordIterations);

    final bool ok;
    if (itersStr == null) {
      // Legacy (salted sha256). If it matches, migrate to PBKDF2.
      final gotLegacy = _saltedSha256(password, salt);
      ok = _constantTimeEquals(gotLegacy, expected);
      if (ok) {
        await setPassword(password);
      }
    } else {
      final iters = int.tryParse(itersStr) ?? 120000;
      final got = _pbkdf2Sha256(password, salt, iterations: iters, outLen: expected.length);
      ok = _constantTimeEquals(got, expected);
    }

    await _updateLockStateAfterAttempt(ok);
    return ok;
  }

  Future<void> writeString(String key, String value) => _storage.write(key: key, value: value);
  Future<String?> readString(String key) => _storage.read(key: key);

  Future<Uint8List> getOrCreateMasterKey32() async {
    final existing = await _storage.read(key: kMasterKeyB64);
    if (existing != null && existing.isNotEmpty) {
      return base64Decode(existing);
    }

    final keyBytes = _randomBytes(32);
    await _storage.write(key: kMasterKeyB64, value: base64Encode(keyBytes));
    return keyBytes;
  }

  static Uint8List _randomBytes(int length) {
    final r = Random.secure();
    return Uint8List.fromList(List<int>.generate(length, (_) => r.nextInt(256)));
  }

  static Uint8List _saltedSha256(String secret, Uint8List salt) {
    final data = <int>[...utf8.encode(secret), ...salt];
    return Uint8List.fromList(sha256.convert(data).bytes);
  }

  static Uint8List _pbkdf2Sha256(
    String password,
    Uint8List salt, {
    required int iterations,
    required int outLen,
  }) {
    final KeyDerivator derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, outLen));
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  Future<bool> isLockedOut() async {
    final untilStr = await _storage.read(key: kLockUntilMs);
    final untilMs = int.tryParse(untilStr ?? '');
    if (untilMs == null) return false;
    return DateTime.now().millisecondsSinceEpoch < untilMs;
  }

  Future<Duration?> lockRemaining() async {
    final untilStr = await _storage.read(key: kLockUntilMs);
    final untilMs = int.tryParse(untilStr ?? '');
    if (untilMs == null) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = untilMs - now;
    if (diff <= 0) return null;
    return Duration(milliseconds: diff);
  }

  Future<void> _updateLockStateAfterAttempt(bool ok) async {
    if (ok) {
      await _storage.write(key: kFailedAttempts, value: '0');
      await _storage.delete(key: kLockUntilMs);
      return;
    }

    final attemptsStr = await _storage.read(key: kFailedAttempts);
    final attempts = (int.tryParse(attemptsStr ?? '') ?? 0) + 1;
    await _storage.write(key: kFailedAttempts, value: attempts.toString());

    // Simple exponential-ish backoff:
    // 5 tries -> 30s, 8 tries -> 2m, 10+ -> 5m
    Duration? lock;
    if (attempts >= 10) {
      lock = const Duration(minutes: 5);
    } else if (attempts >= 8) {
      lock = const Duration(minutes: 2);
    } else if (attempts >= 5) {
      lock = const Duration(seconds: 30);
    }

    if (lock != null) {
      final until = DateTime.now().add(lock).millisecondsSinceEpoch;
      await _storage.write(key: kLockUntilMs, value: until.toString());
    }
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

