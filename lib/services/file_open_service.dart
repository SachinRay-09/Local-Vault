import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class FileOpenService {
  static const MethodChannel _channel = MethodChannel('local_vault/file_opener');

  Future<void> openFile(String absolutePath) async {
    if (kIsWeb) {
      throw UnsupportedError('Web is not supported.');
    }

    if (Platform.isWindows) {
      // Use the shell association (default app) via: cmd /c start "" "path"
      await Process.run(
        'cmd',
        ['/c', 'start', '', absolutePath],
        runInShell: true,
      );
      return;
    }

    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('openFile', {'path': absolutePath});
      return;
    }

    throw UnsupportedError('Platform not supported yet: ${Platform.operatingSystem}');
  }
}

