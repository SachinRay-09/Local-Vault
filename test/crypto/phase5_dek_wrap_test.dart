// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_vault/models/vault_key_envelope.dart';
import 'package:local_vault/services/dart_crypto_engine.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Uint8List _randomBytes(int n) {
  final r = Random.secure();
  return Uint8List.fromList(List<int>.generate(n, (_) => r.nextInt(256)));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DEK wrap / unwrap (DartCryptoEngine)', () {
    test('1. Round-trip: wrapDek then unwrapDek with same KEK returns same DEK',
        () {
      final dek = _randomBytes(32);
      final kek = _randomBytes(32);

      final wrapped = DartCryptoEngine.wrapDek(dek, kek);
      final recovered = DartCryptoEngine.unwrapDek(
          wrapped.ciphertext, wrapped.tag, wrapped.nonce, kek);

      expect(recovered, equals(dek));
    });

    test('2. Wrong KEK: unwrapDek throws AuthenticationFailure', () {
      final dek = _randomBytes(32);
      final kek = _randomBytes(32);
      final wrongKek = _randomBytes(32);

      final wrapped = DartCryptoEngine.wrapDek(dek, kek);

      expect(
        () => DartCryptoEngine.unwrapDek(
            wrapped.ciphertext, wrapped.tag, wrapped.nonce, wrongKek),
        throwsA(isA<AuthenticationFailure>()),
      );
    });

    test('3. Tampered ciphertext: unwrapDek throws AuthenticationFailure', () {
      final dek = _randomBytes(32);
      final kek = _randomBytes(32);

      final wrapped = DartCryptoEngine.wrapDek(dek, kek);

      // Flip first byte of ciphertext.
      final tampered = Uint8List.fromList(wrapped.ciphertext);
      tampered[0] ^= 0xFF;

      expect(
        () => DartCryptoEngine.unwrapDek(
            tampered, wrapped.tag, wrapped.nonce, kek),
        throwsA(isA<AuthenticationFailure>()),
      );
    });

    test('4. Tampered tag: unwrapDek throws AuthenticationFailure', () {
      final dek = _randomBytes(32);
      final kek = _randomBytes(32);

      final wrapped = DartCryptoEngine.wrapDek(dek, kek);

      // Flip first byte of tag.
      final tamperedTag = Uint8List.fromList(wrapped.tag);
      tamperedTag[0] ^= 0xFF;

      expect(
        () => DartCryptoEngine.unwrapDek(
            wrapped.ciphertext, tamperedTag, wrapped.nonce, kek),
        throwsA(isA<AuthenticationFailure>()),
      );
    });

    test('5. Tampered nonce: unwrapDek throws AuthenticationFailure', () {
      final dek = _randomBytes(32);
      final kek = _randomBytes(32);

      final wrapped = DartCryptoEngine.wrapDek(dek, kek);

      // Use a completely different nonce.
      final wrongNonce = _randomBytes(12);

      expect(
        () => DartCryptoEngine.unwrapDek(
            wrapped.ciphertext, wrapped.tag, wrongNonce, kek),
        throwsA(isA<AuthenticationFailure>()),
      );
    });

    test('6. wrapDek output sizes: nonce=12, ciphertext=32, tag=16', () {
      final dek = _randomBytes(32);
      final kek = _randomBytes(32);

      final wrapped = DartCryptoEngine.wrapDek(dek, kek);

      expect(wrapped.nonce.length, equals(12));
      expect(wrapped.ciphertext.length, equals(32));
      expect(wrapped.tag.length, equals(16));
    });

    test('7. wrapDek: two calls produce DIFFERENT nonces (random nonces)', () {
      final dek = _randomBytes(32);
      final kek = _randomBytes(32);

      final w1 = DartCryptoEngine.wrapDek(dek, kek);
      final w2 = DartCryptoEngine.wrapDek(dek, kek);

      // Nonces are random; collision probability is negligible (2^-96).
      expect(w1.nonce, isNot(equals(w2.nonce)));
    });
  });

  group('VaultKeyEnvelope JSON round-trip', () {
    VaultKeyEnvelope makeEnvelope() {
      return VaultKeyEnvelope(
        vaultVersion: 2,
        kdfAlgorithm: 'pbkdf2_sha256',
        kdfSalt: base64Encode(_randomBytes(16)),
        kdfParams: {'iterations': 200000},
        wrappedDek: base64Encode(_randomBytes(32)),
        wrappedDekNonce: base64Encode(_randomBytes(12)),
        wrappedDekTag: base64Encode(_randomBytes(16)),
      );
    }

    test('8. fromJson(toJson()) round-trip preserves all fields', () {
      final original = makeEnvelope();
      final roundTripped = VaultKeyEnvelope.fromJson(original.toJson());

      expect(roundTripped.vaultVersion, equals(original.vaultVersion));
      expect(roundTripped.kdfAlgorithm, equals(original.kdfAlgorithm));
      expect(roundTripped.kdfSalt, equals(original.kdfSalt));
      expect(roundTripped.kdfParams, equals(original.kdfParams));
      expect(roundTripped.wrappedDek, equals(original.wrappedDek));
      expect(roundTripped.wrappedDekNonce, equals(original.wrappedDekNonce));
      expect(roundTripped.wrappedDekTag, equals(original.wrappedDekTag));
    });

    test('9. fromJson with missing required key throws', () {
      final json = {
        'vault_version': 2,
        'kdf_algorithm': 'pbkdf2_sha256',
        // 'kdf_salt' intentionally missing
        'kdf_params': {'iterations': 200000},
        'wrapped_dek': base64Encode(_randomBytes(32)),
        'wrapped_dek_nonce': base64Encode(_randomBytes(12)),
        'wrapped_dek_tag': base64Encode(_randomBytes(16)),
      };
      expect(
        () => VaultKeyEnvelope.fromJson(json),
        throwsA(anything),
      );
    });
  });

  group('deriveKek', () {
    test('12. deriveKek is deterministic (same inputs → same output)',
        () async {
      const password = 'test-password-phase5';
      final salt = _randomBytes(16);
      const iters = 1; // low for tests; correctness only

      final k1 = await DartCryptoEngine.deriveKek(password, salt, iters);
      final k2 = await DartCryptoEngine.deriveKek(password, salt, iters);

      expect(k1, equals(k2));
      expect(k1.length, equals(32));
    });

    test('13. deriveKek: same inputs → same bytes (runs in isolate)', () async {
      final salt = Uint8List.fromList(List.generate(16, (i) => i));
      final k1 = await DartCryptoEngine.deriveKek('password', salt, 1);
      final k2 = await DartCryptoEngine.deriveKek('password', salt, 1);
      expect(k1, equals(k2));
    });

    test('14. deriveKek: different salts → different bytes', () async {
      final salt1 = _randomBytes(16);
      final salt2 = _randomBytes(16);
      final k1 = await DartCryptoEngine.deriveKek('password', salt1, 1);
      final k2 = await DartCryptoEngine.deriveKek('password', salt2, 1);
      expect(k1, isNot(equals(k2)));
    });
  });

  group('Migration round-trip (unit logic)', () {
    test('10. Migration: unwrapDek result matches original masterKey',
        () async {
      final masterKey = _randomBytes(32);
      const password = 'migration-test-password';
      const iters = 1;
      final salt = _randomBytes(16);

      // Simulate _migrateToEnvelope logic.
      final kek = await DartCryptoEngine.deriveKek(password, salt, iters);
      final wrapped = DartCryptoEngine.wrapDek(masterKey, kek);

      final kek2 = await DartCryptoEngine.deriveKek(password, salt, iters);
      final recovered = DartCryptoEngine.unwrapDek(
          wrapped.ciphertext, wrapped.tag, wrapped.nonce, kek2);

      expect(recovered, equals(masterKey));
    });

    test(
        '11. Migration failure: tampered envelope throws AuthenticationFailure',
        () async {
      final masterKey = _randomBytes(32);
      const password = 'migration-test-password';
      const iters = 1;
      final salt = _randomBytes(16);

      final kek = await DartCryptoEngine.deriveKek(password, salt, iters);
      final wrapped = DartCryptoEngine.wrapDek(masterKey, kek);

      // Tamper with the ciphertext.
      final tampered = Uint8List.fromList(wrapped.ciphertext);
      tampered[0] ^= 0xFF;

      final kek2 = await DartCryptoEngine.deriveKek(password, salt, iters);
      expect(
        () => DartCryptoEngine.unwrapDek(
            tampered, wrapped.tag, wrapped.nonce, kek2),
        throwsA(isA<AuthenticationFailure>()),
      );
    });
  });
}
