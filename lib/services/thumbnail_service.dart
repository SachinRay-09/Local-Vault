import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/vault_file.dart';
import 'file_crypto_service.dart';
import 'secure_storage_service.dart';
import 'vault_paths.dart';

class ThumbnailService {
  ThumbnailService({
    required this.crypto,
    required this.secureStorage,
  });

  final FileCryptoService crypto;
  final SecureStorageService secureStorage;

  static final Map<String, Uint8List> _memoryCache = {};
  static final Map<String, Future<Uint8List?>> _pendingThumbnails = {};

  /// Generate or retrieve cached thumbnail for an image file.
  /// Returns null if not an image or generation fails.
  Future<Uint8List?> getThumbnail(VaultFile file) async {
    if (!_isImageFile(file.originalName)) return null;

    final cacheKey = '${file.storedBlobName}_thumb';
    
    // Check memory cache first
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey];
    }

    // Check if already generating
    if (_pendingThumbnails.containsKey(cacheKey)) {
      return await _pendingThumbnails[cacheKey];
    }

    // Check disk cache
    final thumbFile = await _getThumbnailFile(file);
    if (await thumbFile.exists()) {
      try {
        final bytes = await thumbFile.readAsBytes();
        _memoryCache[cacheKey] = bytes;
        return bytes;
      } catch (e) {
        // If disk cache is corrupted, delete it
        try {
          await thumbFile.delete();
        } catch (_) {}
      }
    }

    // Generate thumbnail
    final future = _generateThumbnail(file, thumbFile);
    _pendingThumbnails[cacheKey] = future;
    
    try {
      final result = await future;
      _pendingThumbnails.remove(cacheKey);
      if (result != null) {
        _memoryCache[cacheKey] = result;
      }
      return result;
    } catch (e) {
      _pendingThumbnails.remove(cacheKey);
      debugPrint('Thumbnail generation failed for ${file.originalName}: $e');
      return null;
    }
  }

  Future<File> _getThumbnailFile(VaultFile file) async {
    final dir = await VaultPaths.ensureTempDir();
    final thumbDir = Directory('${dir.path}${Platform.pathSeparator}thumbnails');
    await thumbDir.create(recursive: true);
    return File('${thumbDir.path}${Platform.pathSeparator}${file.storedBlobName}_thumb.png');
  }

  Future<Uint8List?> _generateThumbnail(VaultFile file, File thumbFile) async {
    // Skip very large files to avoid memory issues
    if (file.byteSize > 20 * 1024 * 1024) {
      return null;
    }

    try {
      final masterKey32 = await secureStorage.getOrCreateMasterKey32();
      
      // Decrypt the image file
      final decryptedBytes = await crypto.readAndDecryptBlob(
        storedBlobName: file.storedBlobName,
        ivBase64: file.ivBase64,
        masterKey32: masterKey32,
      );

      // Use compute for heavy image processing
      final thumbnailBytes = await compute(_createThumbnail, decryptedBytes);
      
      if (thumbnailBytes != null) {
        // Save to disk cache
        try {
          await thumbFile.writeAsBytes(thumbnailBytes);
        } catch (e) {
          debugPrint('Failed to cache thumbnail: $e');
        }
      }
      
      return thumbnailBytes;
    } catch (e) {
      debugPrint('Thumbnail generation failed for ${file.originalName}: $e');
      return null;
    }
  }

  static bool _isImageFile(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext);
  }

  /// Clear thumbnail caches to free memory
  static void clearCache() {
    _memoryCache.clear();
    _pendingThumbnails.clear();
  }
}

// Isolate function for thumbnail generation
Uint8List? _createThumbnail(Uint8List imageBytes) {
  try {
    // For now, return a simple placeholder since ui.instantiateImageCodec
    // doesn't work well in compute isolates. We'll use the original approach
    // but with better error handling.
    return null;
  } catch (e) {
    return null;
  }
}