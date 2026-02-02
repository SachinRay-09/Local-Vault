import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/api.dart' show KeyParameter, ParametersWithIV;
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/stream/sic.dart';

import 'vault_paths.dart';

class EncryptedBlobWriteResult {
  EncryptedBlobWriteResult({
    required this.storedBlobName,
    required this.ivBase64,
    required this.byteSize,
    required this.absolutePath,
  });

  final String storedBlobName;
  final String ivBase64;
  final int byteSize;
  final String absolutePath;
}

class FileCryptoService {
  const FileCryptoService();

  /// Encrypts a file **streaming** (AES-CTR) into `vault_blobs/<random>.bin`.
  ///
  /// This avoids loading large videos into RAM and avoids storing any plaintext
  /// copy in the vault directory.
  Future<EncryptedBlobWriteResult> encryptFileToBlob({
    required File sourceFile,
    required Uint8List masterKey32,
  }) async {
    if (masterKey32.length != 32) {
      throw ArgumentError('masterKey32 must be 32 bytes for AES-256.');
    }

    final clearSize = await sourceFile.length();
    final storedBlobName = _randomBlobName();
    final blobsDir = await VaultPaths.ensureVaultBlobsDir();
    final blobFile = File('${blobsDir.path}${Platform.pathSeparator}$storedBlobName');

    final ivBytes = _randomBytes(16);
    final cipher = SICStreamCipher(AESEngine())
      ..init(true, ParametersWithIV(KeyParameter(masterKey32), ivBytes));

    final out = blobFile.openWrite();
    try {
      await for (final chunk in sourceFile.openRead()) {
        final encChunk = cipher.process(Uint8List.fromList(chunk));
        out.add(encChunk);
      }
      await out.flush();
    } finally {
      await out.close();
    }

    return EncryptedBlobWriteResult(
      storedBlobName: storedBlobName,
      ivBase64: base64Encode(ivBytes),
      byteSize: clearSize,
      absolutePath: blobFile.path,
    );
  }

  Future<void> decryptBlobToFile({
    required String storedBlobName,
    required String ivBase64,
    required Uint8List masterKey32,
    required File outputFile,
  }) async {
    if (masterKey32.length != 32) {
      throw ArgumentError('masterKey32 must be 32 bytes for AES-256.');
    }

    final blobsDir = await VaultPaths.ensureVaultBlobsDir();
    final blobFile = File('${blobsDir.path}${Platform.pathSeparator}$storedBlobName');

    final ivBytes = base64Decode(ivBase64);
    final cipher = SICStreamCipher(AESEngine())
      ..init(false, ParametersWithIV(KeyParameter(masterKey32), ivBytes));

    final out = outputFile.openWrite();
    try {
      await for (final chunk in blobFile.openRead()) {
        final decChunk = cipher.process(Uint8List.fromList(chunk));
        out.add(decChunk);
      }
      await out.flush();
    } finally {
      await out.close();
    }
  }

  /// Encrypts bytes (AES-256) and writes to `vault_blobs/<random>.bin`.
  ///
  /// Important: DB remains plaintext; only the blob bytes are encrypted.
  Future<EncryptedBlobWriteResult> encryptAndWriteBlob({
    required Uint8List clearBytes,
    required Uint8List masterKey32,
  }) async {
    if (masterKey32.length != 32) {
      throw ArgumentError('masterKey32 must be 32 bytes for AES-256.');
    }

    final key = enc.Key(masterKey32);
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key));

    final encrypted = encrypter.encryptBytes(clearBytes, iv: iv);

    final storedBlobName = _randomBlobName();
    final blobsDir = await VaultPaths.ensureVaultBlobsDir();
    final blobFile = File('${blobsDir.path}${Platform.pathSeparator}$storedBlobName');
    await blobFile.writeAsBytes(encrypted.bytes, flush: true);

    return EncryptedBlobWriteResult(
      storedBlobName: storedBlobName,
      ivBase64: base64Encode(iv.bytes),
      byteSize: clearBytes.length,
      absolutePath: blobFile.path,
    );
  }

  Future<Uint8List> readAndDecryptBlob({
    required String storedBlobName,
    required String ivBase64,
    required Uint8List masterKey32,
  }) async {
    if (masterKey32.length != 32) {
      throw ArgumentError('masterKey32 must be 32 bytes for AES-256.');
    }

    final blobsDir = await VaultPaths.ensureVaultBlobsDir();
    final blobFile = File('${blobsDir.path}${Platform.pathSeparator}$storedBlobName');
    final encryptedBytes = await blobFile.readAsBytes();

    final key = enc.Key(masterKey32);
    final iv = enc.IV(base64Decode(ivBase64));
    final encrypter = enc.Encrypter(enc.AES(key));

    return Uint8List.fromList(encrypter.decryptBytes(enc.Encrypted(encryptedBytes), iv: iv));
  }

  static String _randomBlobName() {
    // Simple random name, no extra dependencies.
    final r = Random.secure();
    final bytes = Uint8List.fromList(List<int>.generate(16, (_) => r.nextInt(256)));
    final token = base64UrlEncode(bytes).replaceAll('=', '');
    return '$token.bin';
  }

  static Uint8List _randomBytes(int length) {
    final r = Random.secure();
    return Uint8List.fromList(List<int>.generate(length, (_) => r.nextInt(256)));
  }
}

