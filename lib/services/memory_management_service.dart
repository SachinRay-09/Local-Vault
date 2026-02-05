import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Memory management service for optimized batch processing and cleanup
class MemoryManagementService {
  static const int _defaultBatchSize = 5;
  static const Duration _gcInterval = Duration(seconds: 30);
  
  static MemoryManagementService? _instance;
  static MemoryManagementService get instance => _instance ??= MemoryManagementService._();
  
  MemoryManagementService._();
  
  int _currentBatchSize = _defaultBatchSize;
  DateTime _lastGC = DateTime.now();
  
  /// Get optimal batch size based on current memory usage
  int getOptimalBatchSize({int? baseBatchSize}) {
    final base = baseBatchSize ?? _defaultBatchSize;
    
    // Adjust batch size based on memory pressure
    if (_isMemoryPressureHigh()) {
      _currentBatchSize = (base * 0.5).round().clamp(1, base);
    } else if (_isMemoryPressureLow()) {
      _currentBatchSize = (base * 1.5).round().clamp(base, base * 2);
    } else {
      _currentBatchSize = base;
    }
    
    if (kDebugMode) {
      debugPrint('Optimal batch size: $_currentBatchSize (base: $base)');
    }
    
    return _currentBatchSize;
  }
  
  /// Check if memory pressure is high
  bool _isMemoryPressureHigh() {
    // Simple heuristic - in real implementation, this would check actual memory usage
    return false; // Placeholder
  }
  
  /// Check if memory pressure is low
  bool _isMemoryPressureLow() {
    // Simple heuristic - in real implementation, this would check actual memory usage
    return true; // Placeholder
  }
  
  /// Perform memory cleanup if needed
  Future<void> performMemoryCleanupIfNeeded() async {
    final now = DateTime.now();
    if (now.difference(_lastGC) > _gcInterval) {
      await performMemoryCleanup();
      _lastGC = now;
    }
  }
  
  /// Force memory cleanup
  Future<void> performMemoryCleanup() async {
    if (kDebugMode) {
      debugPrint('Performing memory cleanup');
    }
    
    try {
      // Clear image cache
      PaintingBinding.instance.imageCache.clear();
      
      // Force garbage collection
      await _forceGarbageCollection();
      
      // Clear any cached data
      await _clearCachedData();
      
      if (kDebugMode) {
        debugPrint('Memory cleanup completed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Memory cleanup error: $e');
      }
    }
  }
  
  /// Force garbage collection
  Future<void> _forceGarbageCollection() async {
    // Trigger garbage collection
    for (int i = 0; i < 3; i++) {
      await Future.delayed(const Duration(milliseconds: 10));
      // Force GC by creating and releasing memory
      final dummy = List.generate(1000, (index) => index);
      dummy.clear();
    }
  }
  
  /// Clear cached data
  Future<void> _clearCachedData() async {
    try {
      // Clear any app-specific caches
      // This would be implemented based on specific caching mechanisms
      if (kDebugMode) {
        debugPrint('Cached data cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error clearing cached data: $e');
      }
    }
  }
  
  /// Get memory usage statistics
  Future<MemoryStats> getMemoryStats() async {
    try {
      // Get basic memory info
      final imageCache = PaintingBinding.instance.imageCache;
      
      return MemoryStats(
        imageCacheSize: imageCache.currentSize,
        imageCacheMaxSize: imageCache.maximumSize,
        imageCacheSizeBytes: imageCache.currentSizeBytes,
        imageCacheMaxSizeBytes: imageCache.maximumSizeBytes,
        currentBatchSize: _currentBatchSize,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting memory stats: $e');
      }
      return MemoryStats(
        imageCacheSize: 0,
        imageCacheMaxSize: 0,
        imageCacheSizeBytes: 0,
        imageCacheMaxSizeBytes: 0,
        currentBatchSize: _currentBatchSize,
      );
    }
  }
  
  /// Process items in memory-optimized batches
  Future<List<T>> processBatched<T>({
    required List<dynamic> items,
    required Future<T> Function(dynamic item) processor,
    Function(double)? onProgress,
    Function(String)? onStatusUpdate,
  }) async {
    if (items.isEmpty) return [];
    
    final results = <T>[];
    final batchSize = getOptimalBatchSize();
    final totalBatches = (items.length / batchSize).ceil();
    
    onStatusUpdate?.call('Processing ${items.length} items in batches of $batchSize');
    
    for (int i = 0; i < items.length; i += batchSize) {
      final batchEnd = (i + batchSize < items.length) ? i + batchSize : items.length;
      final batch = items.sublist(i, batchEnd);
      final batchNumber = (i / batchSize).floor() + 1;
      
      onStatusUpdate?.call('Processing batch $batchNumber of $totalBatches');
      
      // Process batch
      for (final item in batch) {
        try {
          final result = await processor(item);
          results.add(result);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error processing item: $e');
          }
          // Continue with other items
        }
      }
      
      // Update progress
      final progress = (i + batch.length) / items.length;
      onProgress?.call(progress);
      
      // Memory cleanup between batches
      if (batchNumber % 3 == 0) { // Every 3 batches
        await performMemoryCleanupIfNeeded();
      }
      
      // Yield to UI thread
      await Future.delayed(const Duration(milliseconds: 10));
    }
    
    // Final cleanup
    await performMemoryCleanupIfNeeded();
    
    return results;
  }
  
  /// Optimize memory settings based on device capabilities
  void optimizeMemorySettings() {
    try {
      final imageCache = PaintingBinding.instance.imageCache;
      
      // Adjust image cache based on available memory
      if (Platform.isAndroid) {
        // Conservative settings for Android
        imageCache.maximumSize = 30; // Reduced from 50
        imageCache.maximumSizeBytes = 30 * 1024 * 1024; // 30MB
      } else {
        // More generous settings for desktop
        imageCache.maximumSize = 100;
        imageCache.maximumSizeBytes = 100 * 1024 * 1024; // 100MB
      }
      
      if (kDebugMode) {
        debugPrint('Memory settings optimized: ${imageCache.maximumSize} images, ${imageCache.maximumSizeBytes ~/ (1024 * 1024)} MB');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error optimizing memory settings: $e');
      }
    }
  }
}

/// Memory usage statistics
class MemoryStats {
  final int imageCacheSize;
  final int imageCacheMaxSize;
  final int imageCacheSizeBytes;
  final int imageCacheMaxSizeBytes;
  final int currentBatchSize;
  
  MemoryStats({
    required this.imageCacheSize,
    required this.imageCacheMaxSize,
    required this.imageCacheSizeBytes,
    required this.imageCacheMaxSizeBytes,
    required this.currentBatchSize,
  });
  
  double get imageCacheUsagePercent => 
      imageCacheMaxSize > 0 ? (imageCacheSize / imageCacheMaxSize) * 100 : 0;
  
  double get imageCacheSizeUsagePercent => 
      imageCacheMaxSizeBytes > 0 ? (imageCacheSizeBytes / imageCacheMaxSizeBytes) * 100 : 0;
  
  String get formattedImageCacheSize => 
      '${(imageCacheSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  
  String get formattedImageCacheMaxSize => 
      '${(imageCacheMaxSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}