import 'dart:io';

import 'vault_paths.dart';

/// Manages the lifecycle of blob files written to the vault blobs directory.
///
/// Each blob progresses: `.partial` → `.bin` (via [commitPartial]).
class BlobStore {
  /// Returns the absolute path for the in-progress partial file.
  ///
  /// Ensures the blobs directory exists but does NOT create the file itself.
  Future<String> createPartialPath(String blobId) async {
    final blobsDir = await VaultPaths.ensureVaultBlobsDir();
    return '${blobsDir.path}${Platform.pathSeparator}$blobId.partial';
  }

  /// Renames `<blobId>.partial` → `<blobId>.bin`, making the blob permanent.
  ///
  /// Throws [FileSystemException] if the partial file does not exist.
  Future<void> commitPartial(String blobId) async {
    final blobsDir = await VaultPaths.ensureVaultBlobsDir();
    final basePath = '${blobsDir.path}${Platform.pathSeparator}$blobId';
    final partial = File('$basePath.partial');
    if (!partial.existsSync()) {
      throw FileSystemException(
        'Partial blob not found; cannot commit.',
        '$basePath.partial',
      );
    }
    partial.renameSync('$basePath.bin');
  }

  /// Deletes `<blobId>.partial` and `<blobId>.bin` if they exist.
  ///
  /// Swallows [FileSystemException] so it is safe to call even when the
  /// files were never created or have already been deleted.
  Future<void> deleteBlobIfExists(String blobId) async {
    final blobsDir = await VaultPaths.ensureVaultBlobsDir();
    final basePath = '${blobsDir.path}${Platform.pathSeparator}$blobId';

    for (final suffix in ['.partial', '.bin']) {
      try {
        final file = File('$basePath$suffix');
        if (file.existsSync()) {
          file.deleteSync();
        }
      } on FileSystemException {
        // Already gone — that is fine.
      }
    }
  }
}
