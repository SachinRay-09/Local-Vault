import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;

/// Writes a ZIP archive with the heavy [ZipFileEncoder] work offloaded to a
/// long-lived background isolate, so file reads and DEFLATE passes never run
/// on the UI isolate (eliminates export spinner jitter).
///
/// The [ZipFileEncoder] instance lives exclusively inside the worker isolate
/// for the whole lifetime of one export (open -> N add calls -> close) because
/// its handles cannot cross isolate boundaries.
///
/// Already-compressed media extensions are stored with level 0 (STORE) so the
/// ZIP writer skips a pointless recompression pass.
///
/// Usage:
/// ```dart
/// final writer = ArchiveWriter('/path/output.zip');
/// await writer.open();
/// await writer.addFile('folder/image.jpg', '/tmp/decrypted_abc.jpg');
/// await writer.close();
/// ```
class ArchiveWriter {
  ArchiveWriter(this._destinationZipPath);

  final String _destinationZipPath;

  late final Isolate _workerIsolate;
  late final SendPort _workerPort;

  /// Already-compressed media extensions stored with STORE (level 0). These
  /// formats are already compressed, so recompressing wastes CPU without
  /// shrinking the output.
  static const _kMediaExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
    '.avif',
    '.mp4',
    '.mkv',
    '.avi',
  };

  /// Returns [ZipFileEncoder.STORE] (0) for already-compressed media, `null`
  /// (DEFLATE) for everything else.
  ///
  /// Passing `null` to [ZipFileEncoder.addFile] yields DEFLATE because the
  /// archive 3.6.1 body only special-cases STORE: it does
  /// `if (level == STORE) archiveFile.compress = false`, and since
  /// `null != 0` the file stays compressed. This null-is-DEFLATE contract is
  /// intentional and matches the archive API's `[int? level]` parameter.
  static int? _compressionLevel(String entryName) {
    final ext = path.extension(entryName).toLowerCase();
    return _kMediaExtensions.contains(ext) ? ZipFileEncoder.STORE : null;
  }

  /// Spawns the worker isolate, completes the handshake, and sends the
  /// `'open'` command to create the ZIP at the destination path.
  ///
  /// Must be called before [addFile].
  Future<void> open() async {
    final handshake = ReceivePort();
    _workerIsolate = await Isolate.spawn(_zipWorkerEntry, handshake.sendPort);
    _workerPort = await handshake.first as SendPort;

    final reply = ReceivePort();
    _workerPort.send(['open', _destinationZipPath, reply.sendPort]);
    final ack = await reply.first;
    if (ack is List && ack[0] == 'error') {
      throw StateError('ZIP worker open failed: ${ack[1]}');
    }
  }

  /// Adds the file at [filePath] to the archive under the entry name
  /// [entryName].
  ///
  /// [entryName] is the path stored inside the ZIP (e.g. `"folder/image.jpg"`).
  /// When [store] is `true`, or [entryName] has a media extension, the file is
  /// stored with STORE (level 0). Otherwise it is DEFLATE-compressed. Call
  /// [open] before calling this method.
  Future<void> addFile(
    String entryName,
    String filePath, {
    bool store = false,
  }) async {
    final level = store ? ZipFileEncoder.STORE : _compressionLevel(entryName);
    final reply = ReceivePort();
    // Send order: [cmd, entryName, filePath, level, replyPort]
    _workerPort.send(['add', entryName, filePath, level, reply.sendPort]);
    final ack = await reply.first;
    if (ack is List && ack[0] == 'error') {
      throw StateError('ZIP worker addFile failed: ${ack[1]}');
    }
  }

  /// Finalises the ZIP, closes the underlying stream, and disposes the worker
  /// isolate.
  ///
  /// After calling [close] the writer may not be used again.
  Future<void> close() async {
    final reply = ReceivePort();
    _workerPort.send(['close', reply.sendPort]);
    final ack = await reply.first;
    _workerIsolate.kill(priority: Isolate.immediate);
    if (ack is List && ack[0] == 'error') {
      throw StateError('ZIP worker close failed: ${ack[1]}');
    }
  }
}

/// Top-level isolate entry point — must be outside any class so
/// [Isolate.spawn] can cross isolate boundaries.
///
/// Protocol: every command is a `List<Object?>` whose **last** element is a
/// fresh reply [SendPort] used for a single-shot acknowledgement.
///   * `['open', zipPath, replyPort]`
///   * `['add', entryName, filePath, level, replyPort]`
///   * `['close', replyPort]`
///
/// For `'add'`, the entry name is at index 1 (the zip entry name) and the file
/// path is at index 2 (the disk file) — this matches
/// `ZipFileEncoder.addFile(File file, [String? filename, int? level])`.
/// On success the worker replies `'ok'`; on failure it replies
/// `['error', message]`.
void _zipWorkerEntry(SendPort mainPort) {
  final receivePort = ReceivePort();
  mainPort.send(receivePort.sendPort); // handshake: send our port to main

  ZipFileEncoder? encoder;

  receivePort.listen((dynamic msg) async {
    final cmd = msg as List<Object?>;
    // Contract: the last element is always the single-shot reply SendPort.
    final replyPort = cmd.last as SendPort;

    try {
      switch (cmd[0] as String) {
        case 'open':
          encoder = ZipFileEncoder();
          encoder!.create(cmd[1] as String);
          replyPort.send('ok');
        case 'add':
          // cmd[1] = entryName (zip path), cmd[2] = filePath (disk path)
          await encoder!.addFile(
            File(cmd[2] as String), // disk file
            cmd[1] as String, // zip entry name
            cmd[3] as int?, // 0 = STORE, null = DEFLATE
          );
          replyPort.send('ok');
        case 'close':
          await encoder!.close(); // flush and finalize ZIP before ack
          replyPort.send('ok');
          receivePort.close(); // worker exits naturally
      }
    } catch (e) {
      replyPort.send(['error', e.toString()]);
    }
  });
}
