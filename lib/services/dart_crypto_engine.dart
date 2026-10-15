import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/api.dart' show KeyParameter, ParametersWithIV;
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart' show Pbkdf2Parameters;
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/stream/sic.dart';

import 'crypto_engine.dart';

// ---------------------------------------------------------------------------
// Top-level workers — must be top-level to cross isolate boundaries.
// ---------------------------------------------------------------------------

/// PBKDF2-HMAC-SHA256 worker for [Isolate.run].
Uint8List _pbkdf2EngineWorker(
    (String, Uint8List, int, int) args) {
  final (password, salt, iterations, outLen) = args;
  final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(salt, iterations, outLen));
  return derivator.process(Uint8List.fromList(utf8.encode(password)));
}

/// Concrete [CryptoEngine] implementation using PointyCastle's AES-256-CTR
/// (SICStreamCipher) for file encryption and PBKDF2-HMAC-SHA256 for key
/// derivation.  Heavy work (KDF) runs in a background isolate.
class DartCryptoEngine implements CryptoEngine {
  static const int _chunkSize = 64 * 1024; // 64 KB read buffer

  static Uint8List _randomBytes(int length) {
    final r = Random.secure();
    return Uint8List.fromList(
        List<int>.generate(length, (_) => r.nextInt(256)));
  }

  @override
  Future<EncryptResult> encryptFile({
    required String sourcePath,
    required String destPath,
    required Uint8List key,
  }) async {
    if (key.length != 32) {
      throw ArgumentError('key must be 32 bytes for AES-256.');
    }

    final sourceFile = File(sourcePath);
    final clearSize = await sourceFile.length();

    final ivBytes = _randomBytes(16);
    final cipher = SICStreamCipher(AESEngine())
      ..init(true, ParametersWithIV(KeyParameter(key), ivBytes));

    final out = File(destPath).openWrite();
    try {
      final raf = sourceFile.openSync();
      try {
        while (true) {
          final chunk = raf.readSync(_chunkSize);
          if (chunk.isEmpty) break;
          out.add(cipher.process(chunk));
        }
      } finally {
        raf.closeSync();
      }
      await out.flush();
    } finally {
      await out.close();
    }

    return EncryptResult(
      ivBase64: base64Encode(ivBytes),
      byteSize: clearSize,
    );
  }

  @override
  Future<void> decryptFile({
    required String sourcePath,
    required String destPath,
    required Uint8List key,
    required String ivBase64,
  }) async {
    if (key.length != 32) {
      throw ArgumentError('key must be 32 bytes for AES-256.');
    }

    final ivBytes = base64Decode(ivBase64);
    final cipher = SICStreamCipher(AESEngine())
      ..init(false, ParametersWithIV(KeyParameter(key), ivBytes));

    final out = File(destPath).openWrite();
    try {
      final raf = File(sourcePath).openSync();
      try {
        while (true) {
          final chunk = raf.readSync(_chunkSize);
          if (chunk.isEmpty) break;
          out.add(cipher.process(chunk));
        }
      } finally {
        raf.closeSync();
      }
      await out.flush();
    } finally {
      await out.close();
    }
  }

  @override
  Future<Uint8List> deriveKey(
    String password,
    Uint8List salt,
    int iterations,
    int outLen,
  ) {
    return Isolate.run(
      () => _pbkdf2EngineWorker((password, salt, iterations, outLen)),
    );
  }
}
