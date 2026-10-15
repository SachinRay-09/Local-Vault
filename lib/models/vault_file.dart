import 'package:isar/isar.dart';

part 'vault_file.g.dart';

@collection
class VaultFile {
  Id id = Isar.autoIncrement;

  /// Null means root.
  @Index()
  int? parentFolderId;

  /// The original user-visible name (stored in DB plaintext).
  late String originalName;

  /// Random blob filename stored on disk, e.g. `3948-2394.bin`.
  late String storedBlobName;

  late int byteSize;

  /// Best-effort metadata.
  String? mimeType;

  /// Base64-encoded IV used for file encryption.
  late String ivBase64;

  late DateTime createdAt;

  /// Sort order to preserve original file system sequence
  /// Files are assigned sequential numbers during import (0, 1, 2, 3...)
  /// This ensures files display in exact same order as source folder
  @Index()
  int sortOrder = 0;

  /// Encryption format version stored on disk.
  /// 0 = legacy AES-256-CTR (no header; IV in DB as ivBase64)
  /// 1 = versioned chunked AES-256-GCM (LVCRYPT1 header in blob)
  int formatVersion = 0;
}
