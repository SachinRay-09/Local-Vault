import 'package:flutter/foundation.dart';

/// Service for managing performance optimizations
class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  // LRU cache for expensive computations
  final _cache = <String, dynamic>{};
  static const int _maxCacheSize = 100;

  /// Cache expensive computation results
  T? getCached<T>(String key) {
    if (_cache.containsKey(key)) {
      // Move to end (most recently used)
      final value = _cache.remove(key);
      _cache[key] = value;
      return value as T?;
    }
    return null;
  }

  /// Store computation result in cache
  void setCached<T>(String key, T value) {
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    } else if (_cache.length >= _maxCacheSize) {
      // Remove least recently used
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }

  /// Clear cache to free memory
  void clearCache() {
    _cache.clear();
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'size': _cache.length,
      'maxSize': _maxCacheSize,
      'keys': _cache.keys.toList(),
    };
  }

  /// Debounce function calls to reduce excessive operations
  static final Map<String, Timer?> _debounceTimers = {};
  
  static void debounce(String key, Duration delay, VoidCallback callback) {
    _debounceTimers[key]?.cancel();
    _debounceTimers[key] = Timer(delay, () {
      callback();
      _debounceTimers.remove(key);
    });
  }

  /// Cancel all debounce timers
  static void cancelAllDebounce() {
    for (final timer in _debounceTimers.values) {
      timer?.cancel();
    }
    _debounceTimers.clear();
  }
}

/// Timer implementation for debouncing
class Timer {
  Timer(Duration duration, VoidCallback callback) {
    Future.delayed(duration, callback);
  }
  
  void cancel() {
    // Implementation would cancel the future if needed
  }
}