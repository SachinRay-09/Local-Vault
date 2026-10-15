import 'dart:io';
import 'dart:math';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Represents a successfully extracted archive entry.
class ArchiveEntry {
  const ArchiveEntry({
    required this.name,
    required this.tempPath,
    required this.sizeBytes,
  });

  /// Original entry name inside the archive.
  final String name;

  /// Absolute path to the extracted plaintext file in the system temp dir.
  final String tempPath;

  /// Uncompressed size in bytes.
  final int sizeBytes;
}

/// Represents an archive entry that was skipped during extraction.
class ArchiveEntrySkipped {
  const ArchiveEntrySkipped({
    required this.name,
    required this.reason,
  });

  /// Original entry name inside the archive.
  final String name;

  /// Human-readable reason the entry was not extracted.
  final String reason;
}

/// Streams [ArchiveEntry] / [ArchiveEntrySkipped] objects from a ZIP file
/// without loading the whole archive into memory (archive v3.6.1 API).
///
/// Usage:
/// ```dart
/// await for (final e in ArchiveReader().entries(zipPath)) {
///   if (e is ArchiveEntry) { … }
///   if (e is ArchiveEntrySkipped) { … }
/// }
/// ```
class ArchiveReader {
  /// Maximum bytes per entry before it is skipped (default 2 GB).
  static const int _defaultMaxEntryBytes = 2 * 1024 * 1024 * 1024;

  /// Yields [ArchiveEntry] and [ArchiveEntrySkipped] objects for every file
  /// entry inside the ZIP at [zipPath].
  ///
  /// For unprotected ZIPs an [InputFileStream] is used so the archive is never
  /// fully loaded into RAM.  For password-protected ZIPs the whole archive must
  /// be read into memory because archive 3.x requires [ZipDecoder.decodeBytes]
  /// with a `password` argument — avoid large password-protected ZIPs on
  /// memory-constrained devices.
  ///
  /// Each yielded [ArchiveEntry.tempPath] points to a file in the system temp
  /// directory.  Callers are responsible for deleting those files.
  Stream<Object> entries(
    String zipPath, {
    String password = '',
    int maxEntryBytes = _defaultMaxEntryBytes,
  }) async* {
    if (password.isNotEmpty) {
      // Password-protected: must use decodeBytes (archive 3.x limitation).
      yield* _entriesFromBytes(zipPath,
          password: password, maxEntryBytes: maxEntryBytes);
    } else {
      // Unprotected: use streaming InputFileStream — no full-file read.
      yield* _entriesFromStream(zipPath, maxEntryBytes: maxEntryBytes);
    }
  }

  // -------------------------------------------------------------------------
  // Streaming path (non-encrypted ZIPs)
  // -------------------------------------------------------------------------

  Stream<Object> _entriesFromStream(
    String zipPath, {
    required int maxEntryBytes,
  }) async* {
    final inputStream = InputFileStream(zipPath);
    try {
      final archive = ZipDecoder().decodeBuffer(inputStream);

      for (final entry in archive.files) {
        if (!entry.isFile) continue;

        // Skip symbolic-link entries (mode bit 0xA000 = symlink in Unix tar).
        // archive 3.x sets the high bits of `mode` to indicate file type.
        final mode = entry.mode;
        if ((mode & 0xF000) == 0xA000) {
          yield ArchiveEntrySkipped(name: entry.name, reason: 'symbolic link');
          continue;
        }

        if (_isUnsafePath(entry.name)) {
          yield ArchiveEntrySkipped(name: entry.name, reason: 'unsafe path');
          continue;
        }

        if (entry.size > maxEntryBytes) {
          yield ArchiveEntrySkipped(
              name: entry.name, reason: 'size exceeds limit');
          continue;
        }

        final tempPath = await _createTempPath(entry.name);

        final outStream = OutputFileStream(tempPath);
        try {
          entry.writeContent(outStream);
        } finally {
          outStream.closeSync();
        }

        yield ArchiveEntry(
          name: entry.name,
          tempPath: tempPath,
          sizeBytes: entry.size,
        );

        // Free entry memory immediately after yielding.
        entry.clear();
      }
    } finally {
      inputStream.closeSync();
    }
  }

  // -------------------------------------------------------------------------
  // In-memory path (password-protected ZIPs)
  // -------------------------------------------------------------------------

  Stream<Object> _entriesFromBytes(
    String zipPath, {
    required String password,
    required int maxEntryBytes,
  }) async* {
    final bytes = await File(zipPath).readAsBytes();
    final archive =
        ZipDecoder().decodeBytes(bytes, password: password, verify: false);

    for (final entry in archive.files) {
      if (!entry.isFile) continue;

      // Skip symbolic-link entries.
      final mode = entry.mode;
      if ((mode & 0xF000) == 0xA000) {
        yield ArchiveEntrySkipped(name: entry.name, reason: 'symbolic link');
        continue;
      }

      if (_isUnsafePath(entry.name)) {
        yield ArchiveEntrySkipped(name: entry.name, reason: 'unsafe path');
        continue;
      }

      if (entry.size > maxEntryBytes) {
        yield ArchiveEntrySkipped(
            name: entry.name, reason: 'size exceeds limit');
        continue;
      }

      final tempPath = await _createTempPath(entry.name);

      // For password-protected entries content is already decrypted in memory.
      final content = entry.content as List<int>;
      await File(tempPath).writeAsBytes(content, flush: true);

      yield ArchiveEntry(
        name: entry.name,
        tempPath: tempPath,
        sizeBytes: entry.size,
      );
    }

    archive.clear();
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  /// Returns true for paths that could escape the destination directory.
  static bool _isUnsafePath(String name) {
    if (name.contains('..')) return true;
    if (name.startsWith('/')) return true;
    // Windows absolute paths like C:\... or C:/...
    // Only flag if it looks like a drive letter followed by colon and separator.
    if (name.length > 2 &&
        name[1] == ':' &&
        (name[2] == '\\' || name[2] == '/')) {
      return true;
    }
    return false;
  }

  /// Creates a unique temp file path based on the entry name.
  static Future<String> _createTempPath(String entryName) async {
    final tmpDir = await getTemporaryDirectory();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final rand = Random.secure().nextInt(0xFFFFFF);
    final base = p
        .basename(entryName)
        .replaceAll(RegExp(r'[^\w\-.]'), '_')
        .substring(0, p.basename(entryName).length.clamp(0, 64));
    return p.join(tmpDir.path, 'lv_zip_${stamp}_${rand}_$base');
  }
}
