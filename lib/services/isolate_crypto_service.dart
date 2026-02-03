import 'dart:isolate';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Isolate-based encryption service for CPU-intensive operations
/// Moves encryption/decryption off the main thread to prevent UI blocking
class IsolateCryptoService {
  static const int _defaultChunkSize = 64 * 1024; // 64KB chunks

  /// Encrypt a file using background isolate with chunked processing
  static Future<void> encryptFileInIsolate({
    required String sourcePath,
    required String destPath,
    required Uint8List key,
    Function(double progress)? onProgress,
  }) async {
    final params = _EncryptionParams(
      sourcePath: sourcePath,
      destPath: destPath,
      key: key,
      chunkSize: _defaultChunkSize,
    );

    if (onProgress != null) {
      // Use isolate with progress reporting
      await _encryptWithProgress(params, onProgress);
    } else {
      // Simple compute for basic encryption
      await compute(_encryptFileWorker, params);
    }
  }

  /// Decrypt a file using background isolate with chunked processing
  static Future<void> decryptFileInIsolate({
    required String sourcePath,
    required String destPath,
    required Uint8List key,
    Function(double progress)? onProgress,
  }) async {
    final params = _DecryptionParams(
      sourcePath: sourcePath,
      destPath: destPath,
      key: key,
      chunkSize: _defaultChunkSize,
    );

    if (onProgress != null) {
      // Use isolate with progress reporting
      await _decryptWithProgress(params, onProgress);
    } else {
      // Simple compute for basic decryption
      await compute(_decryptFileWorker, params);
    }
  }

  /// Encrypt multiple files in batch using isolate
  static Future<void> encryptBatchInIsolate({
    required List<String> sourcePaths,
    required List<String> destPaths,
    required Uint8List key,
    Function(int completed, int total)? onProgress,
  }) async {
    final params = _BatchEncryptionParams(
      sourcePaths: sourcePaths,
      destPaths: destPaths,
      key: key,
      chunkSize: _defaultChunkSize,
    );

    if (onProgress != null) {
      await _encryptBatchWithProgress(params, onProgress);
    } else {
      await compute(_encryptBatchWorker, params);
    }
  }

  /// Encrypt with progress reporting using isolate communication
  static Future<void> _encryptWithProgress(
    _EncryptionParams params,
    Function(double progress) onProgress,
  ) async {
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(
      _encryptFileWithProgressWorker,
      _IsolateMessage(params, receivePort.sendPort),
    );

    await for (final message in receivePort) {
      if (message is double) {
        onProgress(message);
      } else if (message is String && message == 'done') {
        break;
      } else if (message is String && message.startsWith('error:')) {
        isolate.kill();
        receivePort.close();
        throw Exception(message.substring(6));
      }
    }

    isolate.kill();
    receivePort.close();
  }

  /// Decrypt with progress reporting using isolate communication
  static Future<void> _decryptWithProgress(
    _DecryptionParams params,
    Function(double progress) onProgress,
  ) async {
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(
      _decryptFileWithProgressWorker,
      _IsolateMessage(params, receivePort.sendPort),
    );

    await for (final message in receivePort) {
      if (message is double) {
        onProgress(message);
      } else if (message is String && message == 'done') {
        break;
      } else if (message is String && message.startsWith('error:')) {
        isolate.kill();
        receivePort.close();
        throw Exception(message.substring(6));
      }
    }

    isolate.kill();
    receivePort.close();
  }

  /// Encrypt batch with progress reporting
  static Future<void> _encryptBatchWithProgress(
    _BatchEncryptionParams params,
    Function(int completed, int total) onProgress,
  ) async {
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(
      _encryptBatchWithProgressWorker,
      _IsolateMessage(params, receivePort.sendPort),
    );

    await for (final message in receivePort) {
      if (message is int) {
        onProgress(message, params.sourcePaths.length);
      } else if (message is String && message == 'done') {
        break;
      } else if (message is String && message.startsWith('error:')) {
        isolate.kill();
        receivePort.close();
        throw Exception(message.substring(6));
      }
    }

    isolate.kill();
    receivePort.close();
  }
}

/// Worker function for file encryption (runs in isolate)
Future<void> _encryptFileWorker(_EncryptionParams params) async {
  try {
    final sourceFile = File(params.sourcePath);
    final destFile = File(params.destPath);
    
    // Ensure destination directory exists
    await destFile.parent.create(recursive: true);
    
    final sourceStream = sourceFile.openRead();
    final destSink = destFile.openWrite();
    
    await for (final chunk in sourceStream) {
      // Simulate encryption (replace with actual encryption logic)
      final encryptedChunk = _encryptChunk(chunk, params.key);
      destSink.add(encryptedChunk);
    }
    
    await destSink.close();
  } catch (e) {
    debugPrint('Encryption error: $e');
    rethrow;
  }
}

/// Worker function for file decryption (runs in isolate)
Future<void> _decryptFileWorker(_DecryptionParams params) async {
  try {
    final sourceFile = File(params.sourcePath);
    final destFile = File(params.destPath);
    
    // Ensure destination directory exists
    await destFile.parent.create(recursive: true);
    
    final sourceStream = sourceFile.openRead();
    final destSink = destFile.openWrite();
    
    await for (final chunk in sourceStream) {
      // Simulate decryption (replace with actual decryption logic)
      final decryptedChunk = _decryptChunk(chunk, params.key);
      destSink.add(decryptedChunk);
    }
    
    await destSink.close();
  } catch (e) {
    debugPrint('Decryption error: $e');
    rethrow;
  }
}

/// Worker function for batch encryption (runs in isolate)
Future<void> _encryptBatchWorker(_BatchEncryptionParams params) async {
  for (int i = 0; i < params.sourcePaths.length; i++) {
    final encryptParams = _EncryptionParams(
      sourcePath: params.sourcePaths[i],
      destPath: params.destPaths[i],
      key: params.key,
      chunkSize: params.chunkSize,
    );
    await _encryptFileWorker(encryptParams);
  }
}

/// Worker with progress reporting for encryption
void _encryptFileWithProgressWorker(_IsolateMessage message) async {
  final params = message.params as _EncryptionParams;
  final sendPort = message.sendPort;
  
  try {
    final sourceFile = File(params.sourcePath);
    final destFile = File(params.destPath);
    final fileSize = await sourceFile.length();
    
    await destFile.parent.create(recursive: true);
    
    final sourceStream = sourceFile.openRead();
    final destSink = destFile.openWrite();
    
    int bytesProcessed = 0;
    
    await for (final chunk in sourceStream) {
      final encryptedChunk = _encryptChunk(chunk, params.key);
      destSink.add(encryptedChunk);
      
      bytesProcessed += chunk.length;
      final progress = bytesProcessed / fileSize;
      sendPort.send(progress);
    }
    
    await destSink.close();
    sendPort.send('done');
  } catch (e) {
    sendPort.send('error: $e');
  }
}

/// Worker with progress reporting for decryption
void _decryptFileWithProgressWorker(_IsolateMessage message) async {
  final params = message.params as _DecryptionParams;
  final sendPort = message.sendPort;
  
  try {
    final sourceFile = File(params.sourcePath);
    final destFile = File(params.destPath);
    final fileSize = await sourceFile.length();
    
    await destFile.parent.create(recursive: true);
    
    final sourceStream = sourceFile.openRead();
    final destSink = destFile.openWrite();
    
    int bytesProcessed = 0;
    
    await for (final chunk in sourceStream) {
      final decryptedChunk = _decryptChunk(chunk, params.key);
      destSink.add(decryptedChunk);
      
      bytesProcessed += chunk.length;
      final progress = bytesProcessed / fileSize;
      sendPort.send(progress);
    }
    
    await destSink.close();
    sendPort.send('done');
  } catch (e) {
    sendPort.send('error: $e');
  }
}

/// Worker with progress reporting for batch encryption
void _encryptBatchWithProgressWorker(_IsolateMessage message) async {
  final params = message.params as _BatchEncryptionParams;
  final sendPort = message.sendPort;
  
  try {
    for (int i = 0; i < params.sourcePaths.length; i++) {
      final encryptParams = _EncryptionParams(
        sourcePath: params.sourcePaths[i],
        destPath: params.destPaths[i],
        key: params.key,
        chunkSize: params.chunkSize,
      );
      await _encryptFileWorker(encryptParams);
      sendPort.send(i + 1); // Send completed count
    }
    sendPort.send('done');
  } catch (e) {
    sendPort.send('error: $e');
  }
}

/// Placeholder encryption function (replace with actual AES encryption)
Uint8List _encryptChunk(List<int> chunk, Uint8List key) {
  // TODO: Replace with actual AES-256 encryption
  // For now, just return the chunk as-is to test isolate performance
  return Uint8List.fromList(chunk);
}

/// Placeholder decryption function (replace with actual AES decryption)
Uint8List _decryptChunk(List<int> chunk, Uint8List key) {
  // TODO: Replace with actual AES-256 decryption
  // For now, just return the chunk as-is to test isolate performance
  return Uint8List.fromList(chunk);
}

/// Parameters for encryption operations
class _EncryptionParams {
  final String sourcePath;
  final String destPath;
  final Uint8List key;
  final int chunkSize;

  _EncryptionParams({
    required this.sourcePath,
    required this.destPath,
    required this.key,
    required this.chunkSize,
  });
}

/// Parameters for decryption operations
class _DecryptionParams {
  final String sourcePath;
  final String destPath;
  final Uint8List key;
  final int chunkSize;

  _DecryptionParams({
    required this.sourcePath,
    required this.destPath,
    required this.key,
    required this.chunkSize,
  });
}

/// Parameters for batch encryption operations
class _BatchEncryptionParams {
  final List<String> sourcePaths;
  final List<String> destPaths;
  final Uint8List key;
  final int chunkSize;

  _BatchEncryptionParams({
    required this.sourcePaths,
    required this.destPaths,
    required this.key,
    required this.chunkSize,
  });
}

/// Message wrapper for isolate communication
class _IsolateMessage {
  final dynamic params;
  final SendPort sendPort;

  _IsolateMessage(this.params, this.sendPort);
}