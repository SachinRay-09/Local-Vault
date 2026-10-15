import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_vault/services/dart_crypto_engine.dart';
import 'package:local_vault/services/crypto_engine.dart';

// Cross-platform round-trip note:
// On non-Windows/Android hosts (e.g. CI), NativeCryptoEngine delegates all
// v0 and v1 operations to DartCryptoEngine as a fallback, so the cross-engine
// tests below verify the shared code path.
//
// On real Windows/Android devices the native MethodChannel (BCrypt or
// javax.crypto) handles v1 blobs. Full cross-platform hardware verification
// (Dart→Windows native→Dart, Dart→Android native→Dart) requires running the
// app on those devices; that step is outside of CI unit tests.
//
// TODO(phase4-verification): Run flutter integration_test on a real Windows
// build and on an Android device to confirm Dart↔native round-trips produce
// identical plaintext. Tracked as finding #2 in phase4-review.md.

void main() {
  final engine = DartCryptoEngine();
  // Fixed test key: 32 bytes of 0xAB
  final key = Uint8List(32)..fillRange(0, 32, 0xAB);
  const opts = EncryptionOptions(formatVersion: 1);

  // ── Helpers ──────────────────────────────────────────────────────────────

  File makeTempFile(String name, int size, [int fillByte = 0x42]) {
    final f = File('${Directory.systemTemp.path}/$name');
    f.writeAsBytesSync(Uint8List(size)..fillRange(0, size, fillByte));
    return f;
  }

  bool filesEqual(String a, String b) {
    final ab = File(a).readAsBytesSync();
    final bb = File(b).readAsBytesSync();
    if (ab.length != bb.length) return false;
    for (var i = 0; i < ab.length; i++) {
      if (ab[i] != bb[i]) return false;
    }
    return true;
  }

  String tmpPath(String name) => '${Directory.systemTemp.path}/$name';

  // ─── Test 1: Empty file round-trip ───────────────────────────────────────

  test('1. Empty file round-trip', () async {
    final src = makeTempFile('v1_t1_src.bin', 0);
    final enc = tmpPath('v1_t1_enc.bin');
    final dec = tmpPath('v1_t1_dec.bin');

    await engine.encryptFile(
        sourcePath: src.path, destPath: enc, key: key, options: opts);
    await engine.decryptFile(
        sourcePath: enc, destPath: dec, key: key, ivBase64: '');

    expect(filesEqual(src.path, dec), isTrue);
  });

  // ─── Test 2: 1-byte round-trip ───────────────────────────────────────────

  test('2. 1-byte file round-trip', () async {
    final src = makeTempFile('v1_t2_src.bin', 1, 0x7F);
    final enc = tmpPath('v1_t2_enc.bin');
    final dec = tmpPath('v1_t2_dec.bin');

    await engine.encryptFile(
        sourcePath: src.path, destPath: enc, key: key, options: opts);
    await engine.decryptFile(
        sourcePath: enc, destPath: dec, key: key, ivBase64: '');

    expect(filesEqual(src.path, dec), isTrue);
  });

  // ─── Test 3: chunk_size - 1 bytes (single chunk) ─────────────────────────

  test('3. chunk_size-1 bytes round-trip (single chunk)', () async {
    const size = 524288 - 1;
    final src = makeTempFile('v1_t3_src.bin', size, 0x55);
    final enc = tmpPath('v1_t3_enc.bin');
    final dec = tmpPath('v1_t3_dec.bin');

    await engine.encryptFile(
        sourcePath: src.path, destPath: enc, key: key, options: opts);
    await engine.decryptFile(
        sourcePath: enc, destPath: dec, key: key, ivBase64: '');

    expect(filesEqual(src.path, dec), isTrue);
  });

  // ─── Test 4: exactly chunk_size bytes (single chunk) ─────────────────────

  test('4. chunk_size exactly round-trip (single chunk)', () async {
    const size = 524288;
    final src = makeTempFile('v1_t4_src.bin', size, 0xAA);
    final enc = tmpPath('v1_t4_enc.bin');
    final dec = tmpPath('v1_t4_dec.bin');

    await engine.encryptFile(
        sourcePath: src.path, destPath: enc, key: key, options: opts);
    await engine.decryptFile(
        sourcePath: enc, destPath: dec, key: key, ivBase64: '');

    expect(filesEqual(src.path, dec), isTrue);
  });

  // ─── Test 5: chunk_size + 1 bytes (two chunks) ───────────────────────────

  test('5. chunk_size+1 bytes round-trip (two chunks)', () async {
    const size = 524288 + 1;
    final src = makeTempFile('v1_t5_src.bin', size, 0x33);
    final enc = tmpPath('v1_t5_enc.bin');
    final dec = tmpPath('v1_t5_dec.bin');

    await engine.encryptFile(
        sourcePath: src.path, destPath: enc, key: key, options: opts);
    await engine.decryptFile(
        sourcePath: enc, destPath: dec, key: key, ivBase64: '');

    expect(filesEqual(src.path, dec), isTrue);
  });

  // ─── Test 6: Tamper one byte in chunk ciphertext → throws ────────────────

  test('6. Tamper one byte in chunk ciphertext → decrypt throws', () async {
    final src = makeTempFile('v1_t6_src.bin', 100, 0x11);
    final enc = tmpPath('v1_t6_enc.bin');
    final dec = tmpPath('v1_t6_dec.bin');

    await engine.encryptFile(
        sourcePath: src.path, destPath: enc, key: key, options: opts);

    // Flip one byte at offset 76 = first byte of chunk 0 ciphertext
    final encBytes = File(enc).readAsBytesSync();
    encBytes[76] ^= 0xFF;
    File(enc).writeAsBytesSync(encBytes);

    await expectLater(
      engine.decryptFile(
          sourcePath: enc, destPath: dec, key: key, ivBase64: ''),
      throwsA(isA<FormatException>()),
    );
  });

  // ─── Test 7: Truncate file after header → decrypt throws ─────────────────

  test('7. Truncate after header → decrypt throws', () async {
    // Encrypt a 1-byte file: header=76 bytes, chunk=1+16=17 bytes, total=93.
    // Truncate to 77 bytes (header + 1 byte, no full 16-byte tag).
    final src = makeTempFile('v1_t7_src.bin', 1, 0x22);
    final enc = tmpPath('v1_t7_enc.bin');
    final dec = tmpPath('v1_t7_dec.bin');

    await engine.encryptFile(
        sourcePath: src.path, destPath: enc, key: key, options: opts);

    final encBytes = File(enc).readAsBytesSync();
    File(enc).writeAsBytesSync(encBytes.sublist(0, 77));

    await expectLater(
      engine.decryptFile(
          sourcePath: enc, destPath: dec, key: key, ivBase64: ''),
      throwsA(anything),
    );
  });

  // ─── Test 8: Wrong key → decrypt throws ──────────────────────────────────

  test('8. Wrong key → decrypt throws', () async {
    final src = makeTempFile('v1_t8_src.bin', 64, 0x99);
    final enc = tmpPath('v1_t8_enc.bin');
    final dec = tmpPath('v1_t8_dec.bin');

    await engine.encryptFile(
        sourcePath: src.path, destPath: enc, key: key, options: opts);

    final wrongKey = Uint8List(32)..fillRange(0, 32, 0xFF);
    await expectLater(
      engine.decryptFile(
          sourcePath: enc, destPath: dec, key: wrongKey, ivBase64: ''),
      throwsA(isA<FormatException>()),
    );
  });

  // ─── Test 9: Legacy v0 blob still decrypts correctly ─────────────────────

  test('9. Legacy v0 blob still decrypts correctly', () async {
    final src = makeTempFile('v0_t9_src.bin', 1024, 0x7E);
    final enc = tmpPath('v0_t9_enc.bin');
    final dec = tmpPath('v0_t9_dec.bin');

    const v0opts = EncryptionOptions(formatVersion: 0);
    final result = await engine.encryptFile(
        sourcePath: src.path, destPath: enc, key: key, options: v0opts);

    expect(result.formatVersion, equals(0));

    await engine.decryptFile(
        sourcePath: enc, destPath: dec, key: key, ivBase64: result.ivBase64);

    expect(filesEqual(src.path, dec), isTrue);
  });

  // ─── Test 10: Header auth tag tamper → decrypt throws ────────────────────

  test('10. Header auth tag tamper → decrypt throws', () async {
    final src = makeTempFile('v1_t10_src.bin', 64, 0xCC);
    final enc = tmpPath('v1_t10_enc.bin');
    final dec = tmpPath('v1_t10_dec.bin');

    await engine.encryptFile(
        sourcePath: src.path, destPath: enc, key: key, options: opts);

    // Flip first byte of header_auth_tag at offset 60
    final encBytes = File(enc).readAsBytesSync();
    encBytes[60] ^= 0xFF;
    File(enc).writeAsBytesSync(encBytes);

    await expectLater(
      engine.decryptFile(
          sourcePath: enc, destPath: dec, key: key, ivBase64: ''),
      throwsA(isA<FormatException>()),
    );
  });

  // ─── Test 11: Cross-instance v1 round-trip ───────────────────────────────
  //
  // Verifies that a blob produced by one DartCryptoEngine instance decrypts
  // correctly with a second independent DartCryptoEngine instance. This
  // confirms the format is deterministic and self-describing (no shared state).
  //
  // On Windows/Android with the native bridge registered, replace either
  // engine with NativeCryptoEngine to verify the Dart↔native wire format.
  // That step requires a full app build and is tracked separately.

  test('11. Cross-instance v1 round-trip (two chunks)', () async {
    final encEngine = DartCryptoEngine();
    final decEngine = DartCryptoEngine();

    final src = makeTempFile('v1_t11_src.bin', 524288 + 512, 0xDE);
    final enc = tmpPath('v1_t11_enc.bin');
    final dec = tmpPath('v1_t11_dec.bin');

    await encEngine.encryptFile(
        sourcePath: src.path, destPath: enc, key: key, options: opts);
    await decEngine.decryptFile(
        sourcePath: enc, destPath: dec, key: key, ivBase64: '');

    expect(filesEqual(src.path, dec), isTrue);
  });
}
