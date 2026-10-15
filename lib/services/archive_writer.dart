import 'dart:io';

import 'package:archive/archive_io.dart';

/// Thin wrapper around [ZipFileEncoder] that adds one file at a time.
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
  ZipFileEncoder? _encoder;

  /// Creates the ZIP file at the destination path and opens it for writing.
  ///
  /// Must be called before [addFile].
  Future<void> open() async {
    _encoder = ZipFileEncoder();
    _encoder!.create(_destinationZipPath);
  }

  /// Adds the file at [filePath] to the archive under the entry name
  /// [entryName].
  ///
  /// [entryName] is the path stored inside the ZIP (e.g. `"folder/image.jpg"`).
  /// Call [open] before calling this method.
  Future<void> addFile(String entryName, String filePath) async {
    final encoder = _encoder;
    if (encoder == null) {
      throw StateError('ArchiveWriter.open() must be called before addFile().');
    }
    // ZipFileEncoder.addFile signature (archive 3.6.1):
    //   Future<void> addFile(File file, [String? filename, int? level])
    await encoder.addFile(File(filePath), entryName);
  }

  /// Finalises the ZIP and closes the underlying stream.
  ///
  /// After calling [close] the writer may not be used again.
  Future<void> close() async {
    await _encoder?.close();
    _encoder = null;
  }
}
