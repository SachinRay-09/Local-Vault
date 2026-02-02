import 'dart:io';

import 'package:path_provider/path_provider.dart';

class VaultPaths {
  static const String _blobsFolderName = 'vault_blobs';
  static const String _tempFolderName = 'vault_tmp';

  static Future<Directory> vaultRootDir() async {
    // Support dir is a good default for app-private, non-user-facing data.
    // On Windows this lands under AppData; on Android under app-private storage.
    return getApplicationSupportDirectory();
  }

  static Future<Directory> vaultBlobsDir() async {
    final root = await vaultRootDir();
    return Directory('${root.path}${Platform.pathSeparator}$_blobsFolderName');
  }

  static Future<Directory> ensureVaultBlobsDir() async {
    final dir = await vaultBlobsDir();
    await dir.create(recursive: true);
    return dir;
  }

  static Future<Directory> tempDir() async {
    final root = await getTemporaryDirectory();
    return Directory('${root.path}${Platform.pathSeparator}$_tempFolderName');
  }

  static Future<Directory> ensureTempDir() async {
    final dir = await tempDir();
    await dir.create(recursive: true);
    return dir;
  }
}

