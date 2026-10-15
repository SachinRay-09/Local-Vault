import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/api.dart' show KeyParameter, ParametersWithIV;
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/export.dart'
    show GCMBlockCipher, AEADParameters, InvalidCipherTextException;
import 'package:pointycastle/key_derivators/api.dart' show Pbkdf2Parameters;
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/stream/sic.dart';

import 'crypto_engine.dart';

// ---------------------------------------------------------------------------
// AuthenticationFailure exception
// ---------------------------------------------------------------------------

/// Thrown by [DartCryptoEngine.unwrapDek] when the GCM authentication tag
/// fails — indicating a wrong key or tampered ciphertext.
///
/// Callers MUST NOT return partial or garbage DEK bytes on this exception.
class AuthenticationFailure implements Exception {
  const AuthenticationFailure([this.message = 'Authentication failed.']);
  final String message;
  @override
  String toString() => 'AuthenticationFailure: $message';
}

// ---------------------------------------------------------------------------
// Top-level workers — must be top-level to cross isolate boundaries.
// ---------------------------------------------------------------------------

/// PBKDF2-HMAC-SHA256 worker for [Isolate.run].
Uint8List _pbkdf2EngineWorker((String, Uint8List, int, int) args) {
  final (password, salt, iterations, outLen) = args;
  final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(salt, iterations, outLen));
  return derivator.process(Uint8List.fromList(utf8.encode(password)));
}

/// Concrete [CryptoEngine] implementation using PointyCastle.
///
/// v0: AES-256-CTR (SICStreamCipher) — legacy, unchanged.
/// v1: AES-256-GCM (GCMBlockCipher) with chunked AEAD and LVCRYPT1 header.
class DartCryptoEngine implements CryptoEngine {
  // v0 uses a 64 KB read buffer; v1 uses 512 KB chunks.
  static const int _v0ChunkSize = 64 * 1024;
  static const int _v1ChunkSize = 524288; // 512 KB

  // v1 header layout constants
  static const int _kHeaderRawSize = 60;
  static const int _kHeaderTagSize = 16;

  static const List<int> _kMagic = [
    0x4C, 0x56, 0x43, 0x52, 0x59, 0x50, 0x54, 0x31 // 'LVCRYPT1'
  ];

  static Uint8List _randomBytes(int length) {
    final r = Random.secure();
    return Uint8List.fromList(
        List<int>.generate(length, (_) => r.nextInt(256)));
  }

  // -------------------------------------------------------------------------
  // Nonce construction for v1 chunks
  // -------------------------------------------------------------------------
  // base_nonce is 12 bytes. Bytes [0..7] are random; bytes [8..11] are
  // overwritten per chunk with uint32_be(chunkIndex). This gives a 64-bit
  // random prefix + 32-bit counter — deterministic nonce construction per
  // NIST SP 800-38D.
  static Uint8List _chunkNonce(Uint8List baseNonce, int index) {
    final nonce = Uint8List(12);
    nonce.setRange(0, 12, baseNonce);
    nonce[8] = (index >> 24) & 0xFF;
    nonce[9] = (index >> 16) & 0xFF;
    nonce[10] = (index >> 8) & 0xFF;
    nonce[11] = index & 0xFF;
    return nonce;
  }

  // -------------------------------------------------------------------------
  // Build 60-byte header buffer
  // -------------------------------------------------------------------------
  static Uint8List _buildHeader(
      int originalSize, Uint8List fileId, Uint8List baseNonce) {
    final buf = Uint8List(_kHeaderRawSize);
    final bd = ByteData.view(buf.buffer);

    // [0..7]   magic: "LVCRYPT1"
    for (var i = 0; i < 8; i++) {
      buf[i] = _kMagic[i];
    }
    // [8..9]   format_version = 1 (big-endian uint16)
    bd.setUint16(8, 1, Endian.big);
    // [10..11] algorithm_id = 1 (AES-256-GCM, big-endian uint16)
    bd.setUint16(10, 1, Endian.big);
    // [12..15] chunk_size = 524288 (big-endian uint32)
    bd.setUint32(12, _v1ChunkSize, Endian.big);
    // [16..23] original_size (big-endian uint64 — Dart int is 64-bit)
    bd.setUint32(16, (originalSize >> 32) & 0xFFFFFFFF, Endian.big);
    bd.setUint32(20, originalSize & 0xFFFFFFFF, Endian.big);
    // [24..39] file_id (16 bytes)
    buf.setRange(24, 40, fileId);
    // [40..51] base_nonce (12 bytes)
    buf.setRange(40, 52, baseNonce);
    // [52..59] reserved (zeroed — already 0 from Uint8List init)

    return buf;
  }

  // -------------------------------------------------------------------------
  // GCM helper: encrypt with given nonce and AAD, return ciphertext + tag
  // -------------------------------------------------------------------------
  static Uint8List _gcmEncrypt(
      Uint8List key, Uint8List nonce, Uint8List aad, Uint8List plain) {
    final gcm = GCMBlockCipher(AESEngine());
    gcm.init(true, AEADParameters(KeyParameter(key), 128, nonce, aad));
    return gcm.process(plain);
  }

  // -------------------------------------------------------------------------
  // GCM helper: decrypt ciphertext+tag, return plaintext or throw FormatException
  // -------------------------------------------------------------------------
  static Uint8List _gcmDecrypt(
      Uint8List key, Uint8List nonce, Uint8List aad, Uint8List cipherAndTag,
      {required String errorContext}) {
    final gcm = GCMBlockCipher(AESEngine());
    gcm.init(false, AEADParameters(KeyParameter(key), 128, nonce, aad));
    try {
      return gcm.process(cipherAndTag);
    } on InvalidCipherTextException catch (e) {
      throw FormatException('$errorContext: ${e.message}');
    } catch (e) {
      throw FormatException('$errorContext: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Compute 16-byte header auth tag
  // Uses sentinel nonce index 0xFFFFFFFF to avoid sharing the nonce with
  // data chunk 0 (which uses index 0). AES-GCM requires strict (key, nonce)
  // uniqueness; reusing the chunk-0 nonce for both the header tag and the
  // first data chunk would break GCM security.
  // -------------------------------------------------------------------------
  static Uint8List _computeHeaderTag(
      Uint8List key, Uint8List baseNonce, Uint8List header60) {
    // 0xFFFFFFFF sentinel — never collides with any valid data chunk index.
    final nonceHdr = _chunkNonce(baseNonce, 0xFFFFFFFF);
    // Encrypt empty plaintext with AAD=header → result is just the 16-byte tag
    final tagBytes = _gcmEncrypt(key, nonceHdr, header60, Uint8List(0));
    return tagBytes; // GCMBlockCipher.process on empty input = 16-byte tag
  }

  // -------------------------------------------------------------------------
  // v1 Encrypt
  // -------------------------------------------------------------------------
  Future<EncryptResult> _encryptFileV1(
      String sourcePath, String destPath, Uint8List key) async {
    final sourceFile = File(sourcePath);
    final originalSize = await sourceFile.length();

    final fileId = _randomBytes(16);
    final baseNonce = _randomBytes(12);

    final header60 = _buildHeader(originalSize, fileId, baseNonce);
    final headerTag = _computeHeaderTag(key, baseNonce, header60);

    final out = File(destPath).openWrite();
    try {
      // Write 60-byte header + 16-byte header auth tag
      out.add(header60);
      out.add(headerTag);

      final raf = sourceFile.openSync();
      try {
        var chunkIndex = 0;
        while (true) {
          final chunk = raf.readSync(_v1ChunkSize);
          if (chunk.isEmpty) break;
          final nonce = _chunkNonce(baseNonce, chunkIndex);
          // AAD for data chunks is empty
          final cipherAndTag = _gcmEncrypt(key, nonce, Uint8List(0), chunk);
          out.add(cipherAndTag);
          chunkIndex++;
        }
      } finally {
        raf.closeSync();
      }

      await out.flush();
    } finally {
      await out.close();
    }

    return EncryptResult(
      ivBase64: '', // v1: nonce is embedded in header
      byteSize: originalSize,
      formatVersion: 1,
    );
  }

  // -------------------------------------------------------------------------
  // v1 Decrypt
  // -------------------------------------------------------------------------
  Future<void> _decryptFileV1(
      String sourcePath, String destPath, Uint8List key) async {
    final raf = File(sourcePath).openSync();
    try {
      // Read 60-byte header
      final header60 = raf.readSync(_kHeaderRawSize);
      if (header60.length < _kHeaderRawSize) {
        throw FormatException(
            'Truncated v1 header (got ${header60.length} bytes)');
      }

      // Read 16-byte header auth tag
      final headerTag = raf.readSync(_kHeaderTagSize);
      if (headerTag.length < _kHeaderTagSize) {
        throw const FormatException('Truncated v1 header tag');
      }

      // Verify magic
      final magic = String.fromCharCodes(header60.sublist(0, 8));
      if (magic != 'LVCRYPT1') {
        throw FormatException('Invalid magic: $magic');
      }

      // Extract fields from header
      final bd = ByteData.view(header60.buffer, header60.offsetInBytes);
      // chunk_size at [12..15] big-endian uint32
      final chunkSize = bd.getUint32(12, Endian.big);
      // original_size at [16..23] big-endian uint64 (two uint32 reads)
      final origHigh = bd.getUint32(16, Endian.big);
      final origLow = bd.getUint32(20, Endian.big);
      final originalSize = (origHigh << 32) | origLow;

      // base_nonce at [40..51]
      final baseNonce = Uint8List.fromList(header60.sublist(40, 52));

      // Verify header auth tag: GCM-decrypt empty ciphertext with AAD=header
      // Sentinel index 0xFFFFFFFF matches the nonce used during encryption.
      final nonceHdr = _chunkNonce(baseNonce, 0xFFFFFFFF);
      // headerTag from file is the 16-byte tag; combine empty ciphertext + tag
      _gcmDecrypt(key, nonceHdr, header60, headerTag,
          errorContext: 'Header auth tag mismatch');

      // Decrypt data chunks
      final out = File(destPath).openWrite();
      try {
        var chunkIndex = 0;
        var totalDecrypted = 0;

        while (true) {
          // Read one full encrypted chunk: up to chunkSize + 16-byte tag
          final inBuf = raf.readSync(chunkSize + _kHeaderTagSize);
          if (inBuf.isEmpty) break;

          if (inBuf.length <= _kHeaderTagSize) {
            throw FormatException(
                'Truncated chunk $chunkIndex: only ${inBuf.length} bytes');
          }

          final nonce = _chunkNonce(baseNonce, chunkIndex);
          final plain = _gcmDecrypt(key, nonce, Uint8List(0), inBuf,
              errorContext: 'Chunk $chunkIndex auth tag mismatch');

          out.add(plain);
          totalDecrypted += plain.length;
          chunkIndex++;
        }

        await out.flush();

        // Sanity check: decoded bytes must equal declared original size
        if (totalDecrypted != originalSize) {
          throw FormatException(
              'Decrypted size mismatch: got $totalDecrypted, expected $originalSize');
        }
      } finally {
        await out.close();
      }
    } finally {
      raf.closeSync();
    }
  }

  // -------------------------------------------------------------------------
  // CryptoEngine interface implementation
  // -------------------------------------------------------------------------

  @override
  Future<EncryptResult> encryptFile({
    required String sourcePath,
    required String destPath,
    required Uint8List key,
    EncryptionOptions options = const EncryptionOptions(),
  }) async {
    if (key.length != 32) {
      throw ArgumentError('key must be 32 bytes for AES-256.');
    }

    if (options.formatVersion == 1) {
      return _encryptFileV1(sourcePath, destPath, key);
    }

    // ---- v0: legacy AES-256-CTR path (UNCHANGED) ----
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
          final chunk = raf.readSync(_v0ChunkSize);
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
      formatVersion: 0,
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

    // Auto-detect format: read first 8 bytes
    final raf = File(sourcePath).openSync();
    final probe = raf.readSync(8);
    raf.closeSync();

    if (probe.length == 8 && String.fromCharCodes(probe) == 'LVCRYPT1') {
      return _decryptFileV1(sourcePath, destPath, key);
    }

    // ---- v0: legacy AES-256-CTR path (UNCHANGED) ----
    final ivBytes = base64Decode(ivBase64);
    final cipher = SICStreamCipher(AESEngine())
      ..init(false, ParametersWithIV(KeyParameter(key), ivBytes));

    final out = File(destPath).openWrite();
    try {
      final rafDecrypt = File(sourcePath).openSync();
      try {
        while (true) {
          final chunk = rafDecrypt.readSync(_v0ChunkSize);
          if (chunk.isEmpty) break;
          out.add(cipher.process(chunk));
        }
      } finally {
        rafDecrypt.closeSync();
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

  // ---------------------------------------------------------------------------
  // Phase 5: DEK wrapping / unwrapping
  // ---------------------------------------------------------------------------

  /// Derives a 32-byte Key Encryption Key (KEK) from [password] + [salt] using
  /// PBKDF2-HMAC-SHA256 with [iterations] rounds.
  ///
  /// Runs in [Isolate.run] to keep the UI thread free.
  /// Zero the returned bytes after use.
  static Future<Uint8List> deriveKek(
      String password, Uint8List salt, int iterations) {
    return Isolate.run(
      () => _pbkdf2EngineWorker((password, salt, iterations, 32)),
    );
  }

  /// Wraps [dek] with [kek] using AES-256-GCM.
  ///
  /// AAD = UTF-8("local_vault_dek_wrap_v1") — domain-separates this GCM
  /// operation from file-level AEAD.
  ///
  /// Returns a named record with three independent byte arrays:
  ///   - nonce       12 bytes (cryptographically random)
  ///   - ciphertext  32 bytes (encrypted DEK)
  ///   - tag         16 bytes (GCM authentication tag)
  ///
  /// Store each field separately in [VaultKeyEnvelope] — do NOT concatenate.
  static ({Uint8List nonce, Uint8List ciphertext, Uint8List tag}) wrapDek(
      Uint8List dek, Uint8List kek) {
    assert(kek.length == 32, 'KEK must be 32 bytes');
    assert(dek.length == 32, 'DEK must be 32 bytes');

    final nonce = _randomBytes(12);
    final aad = Uint8List.fromList(utf8.encode('local_vault_dek_wrap_v1'));

    final gcm = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(kek), 128, nonce, aad));
    // GCM.process on 32-byte input returns 48 bytes: 32 ciphertext + 16 tag.
    final cipherAndTag = gcm.process(dek);

    return (
      nonce: nonce,
      ciphertext: Uint8List.sublistView(cipherAndTag, 0, 32),
      tag: Uint8List.sublistView(cipherAndTag, 32, 48),
    );
  }

  /// Unwraps a wrapped DEK.
  ///
  /// [ciphertext] — 32-byte encrypted DEK.
  /// [tag]        — 16-byte GCM authentication tag.
  /// [nonce]      — 12-byte GCM nonce.
  /// [kek]        — 32-byte Key Encryption Key.
  ///
  /// Throws [AuthenticationFailure] if the tag does not match (wrong password
  /// or tampered storage).  NEVER returns garbage plaintext bytes.
  static Uint8List unwrapDek(
      Uint8List ciphertext, Uint8List tag, Uint8List nonce, Uint8List kek) {
    assert(kek.length == 32, 'KEK must be 32 bytes');
    assert(ciphertext.length == 32, 'Ciphertext must be 32 bytes');
    assert(tag.length == 16, 'Tag must be 16 bytes');
    assert(nonce.length == 12, 'Nonce must be 12 bytes');

    // Reconstruct the combined ciphertext+tag that GCM expects on decryption.
    final combined = Uint8List(48)
      ..setRange(0, 32, ciphertext)
      ..setRange(32, 48, tag);

    final aad = Uint8List.fromList(utf8.encode('local_vault_dek_wrap_v1'));
    final gcm = GCMBlockCipher(AESEngine())
      ..init(false, AEADParameters(KeyParameter(kek), 128, nonce, aad));

    try {
      return gcm.process(combined); // returns 32-byte plaintext DEK
    } on InvalidCipherTextException {
      throw const AuthenticationFailure(
          'DEK unwrap failed: wrong password or tampered envelope.');
    } catch (e) {
      throw AuthenticationFailure('DEK unwrap failed: $e');
    }
  }
}
