import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/vault_file.dart';
import 'file_crypto_service.dart';
import 'secure_storage_service.dart';

/// Progressive loading service for optimized image display with thumbnail-first approach
class ProgressiveLoadingService {
  static ProgressiveLoadingService? _instance;
  static ProgressiveLoadingService get instance => _instance ??= ProgressiveLoadingService._();
  
  ProgressiveLoadingService._();
  
  final FileCryptoService _crypto = const FileCryptoService();
  final Map<String, Uint8List> _thumbnailCache = {};
  final Map<String, Uint8List> _fullImageCache = {};
  
  /// Build progressive image widget with thumbnail-first loading
  Widget buildProgressiveImage({
    required VaultFile file,
    required BoxFit fit,
    double? width,
    double? height,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return FutureBuilder<Uint8List?>(
      future: _loadThumbnail(file),
      builder: (context, thumbnailSnapshot) {
        if (thumbnailSnapshot.hasError) {
          return errorWidget ?? _buildErrorWidget(file.originalName);
        }
        
        if (!thumbnailSnapshot.hasData) {
          return placeholder ?? _buildLoadingWidget();
        }
        
        final thumbnail = thumbnailSnapshot.data!;
        
        return FutureBuilder<Uint8List?>(
          future: _loadFullImage(file),
          builder: (context, fullImageSnapshot) {
            final imageData = fullImageSnapshot.data ?? thumbnail;
            
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Image.memory(
                imageData,
                key: ValueKey(fullImageSnapshot.hasData ? 'full' : 'thumb'),
                fit: fit,
                width: width,
                height: height,
                errorBuilder: (context, error, stackTrace) {
                  return errorWidget ?? _buildErrorWidget(file.originalName);
                },
              ),
            );
          },
        );
      },
    );
  }
  
  /// Load thumbnail (fast, cached)
  Future<Uint8List?> _loadThumbnail(VaultFile file) async {
    try {
      // Check cache first
      final cacheKey = '${file.storedBlobName}_thumb';
      if (_thumbnailCache.containsKey(cacheKey)) {
        return _thumbnailCache[cacheKey];
      }
      
      // Generate thumbnail from full image
      final fullImageData = await _loadFullImage(file);
      if (fullImageData == null) return null;
      
      final thumbnail = await _generateThumbnail(fullImageData);
      if (thumbnail != null) {
        _thumbnailCache[cacheKey] = thumbnail;
        
        // Limit cache size
        if (_thumbnailCache.length > 50) {
          final firstKey = _thumbnailCache.keys.first;
          _thumbnailCache.remove(firstKey);
        }
      }
      
      return thumbnail;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading thumbnail for ${file.originalName}: $e');
      }
      return null;
    }
  }
  
  /// Load full image (slower, cached)
  Future<Uint8List?> _loadFullImage(VaultFile file) async {
    try {
      // Check cache first
      final cacheKey = file.storedBlobName;
      if (_fullImageCache.containsKey(cacheKey)) {
        return _fullImageCache[cacheKey];
      }
      
      // Decrypt full image
      final masterKey32 = await SecureStorageService.instance.getOrCreateMasterKey32();
      final imageData = await _crypto.readAndDecryptBlob(
        storedBlobName: file.storedBlobName,
        ivBase64: file.ivBase64,
        masterKey32: masterKey32,
      );
      
      // Cache with size limit
      if (imageData.length < 5 * 1024 * 1024) { // Only cache images < 5MB
        _fullImageCache[cacheKey] = imageData;
        
        // Limit cache size
        if (_fullImageCache.length > 20) {
          final firstKey = _fullImageCache.keys.first;
          _fullImageCache.remove(firstKey);
        }
      }
      
      return imageData;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading full image for ${file.originalName}: $e');
      }
      return null;
    }
  }
  
  /// Generate thumbnail from full image data
  Future<Uint8List?> _generateThumbnail(Uint8List imageData) async {
    try {
      // Decode image
      final codec = await ui.instantiateImageCodec(
        imageData,
        targetWidth: 150, // Thumbnail width
        targetHeight: 150, // Thumbnail height
      );
      
      final frame = await codec.getNextFrame();
      final image = frame.image;
      
      // Convert to bytes
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      
      return byteData.buffer.asUint8List();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error generating thumbnail: $e');
      }
      return null;
    }
  }
  
  /// Build loading widget
  Widget _buildLoadingWidget() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
  
  /// Build error widget
  Widget _buildErrorWidget(String fileName) {
    return Container(
      color: Colors.grey[100],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            color: Colors.grey[400],
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'Failed to load',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Preload images for better performance
  Future<void> preloadImages(List<VaultFile> files) async {
    try {
      // Preload thumbnails for visible images
      final futures = files.take(10).map((file) => _loadThumbnail(file));
      await Future.wait(futures);
      
      if (kDebugMode) {
        debugPrint('Preloaded ${files.length} thumbnails');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error preloading images: $e');
      }
    }
  }
  
  /// Clear caches to free memory
  void clearCaches() {
    _thumbnailCache.clear();
    _fullImageCache.clear();
    
    if (kDebugMode) {
      debugPrint('Progressive loading caches cleared');
    }
  }
  
  /// Get cache statistics
  ProgressiveLoadingStats getCacheStats() {
    int thumbnailCacheSize = 0;
    int fullImageCacheSize = 0;
    
    for (final data in _thumbnailCache.values) {
      thumbnailCacheSize += data.length;
    }
    
    for (final data in _fullImageCache.values) {
      fullImageCacheSize += data.length;
    }
    
    return ProgressiveLoadingStats(
      thumbnailCount: _thumbnailCache.length,
      fullImageCount: _fullImageCache.length,
      thumbnailCacheSizeBytes: thumbnailCacheSize,
      fullImageCacheSizeBytes: fullImageCacheSize,
    );
  }
}

/// Progressive loading statistics
class ProgressiveLoadingStats {
  final int thumbnailCount;
  final int fullImageCount;
  final int thumbnailCacheSizeBytes;
  final int fullImageCacheSizeBytes;
  
  ProgressiveLoadingStats({
    required this.thumbnailCount,
    required this.fullImageCount,
    required this.thumbnailCacheSizeBytes,
    required this.fullImageCacheSizeBytes,
  });
  
  int get totalCacheSizeBytes => thumbnailCacheSizeBytes + fullImageCacheSizeBytes;
  
  String get formattedTotalSize => 
      '${(totalCacheSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  
  String get formattedThumbnailSize => 
      '${(thumbnailCacheSizeBytes / 1024).toStringAsFixed(1)} KB';
  
  String get formattedFullImageSize => 
      '${(fullImageCacheSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}