import 'dart:io';
import 'dart:math';

import 'package:archive/archive_io.dart';

class ExportResult {
  ExportResult({required this.zipPath, required this.password});

  final String zipPath;
  final String password;
}

class ExportService {
  const ExportService();

  /// Creates a password-protected ZIP using the archive package.
  ///
  /// Per spec: use `ZipFileEncoder(password: ...)` and do NOT manually encrypt
  /// the zip bytes unless truly necessary.
  ///
  /// Note: This is a scaffold. The actual implementation should:
  /// - Traverse virtual folders/files from Isar
  /// - Decrypt each blob and write it into the ZIP under the original path/name
  Future<ExportResult> exportToPasswordProtectedZip({
    required Directory stagingDir,
    required String outputZipPath,
  }) async {
    final password = _randomExportPassword();

    final encoder = ZipFileEncoder(password: password);
    encoder.create(outputZipPath);
    await encoder.addDirectory(stagingDir, includeDirName: false);
    await encoder.close();

    return ExportResult(zipPath: outputZipPath, password: password);
  }

  static String _randomExportPassword() {
    // Short, shareable. You can tune length/charset later.
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    final r = Random.secure();
    final buf = StringBuffer();
    for (var i = 0; i < 12; i++) {
      buf.write(chars[r.nextInt(chars.length)]);
      if (i == 3 || i == 7) buf.write('-');
    }
    return buf.toString();
  }
}

