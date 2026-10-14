import 'dart:io';

import 'package:flutter/foundation.dart';

/// Battery awareness service for adaptive processing based on battery level and charging state
class BatteryAwarenessService {
  static BatteryAwarenessService? _instance;
  static BatteryAwarenessService get instance =>
      _instance ??= BatteryAwarenessService._();

  BatteryAwarenessService._();

  int? _lastKnownBatteryLevel;
  bool? _lastKnownChargingState;
  DateTime _lastBatteryCheck = DateTime.now();

  /// Get current battery processing configuration
  Future<BatteryProcessingConfig> getProcessingConfig({
    int baseBatchSize = 5,
    int baseDelayMs = 0,
  }) async {
    try {
      // Only check battery on Android (where it matters most)
      if (!Platform.isAndroid) {
        return BatteryProcessingConfig(
          batchSize: baseBatchSize,
          delayMs: baseDelayMs,
          strategy: BatteryStrategy.normal,
          reasoning: 'Desktop platform - full performance',
        );
      }

      final batteryInfo = await _getBatteryInfo();
      final config = _calculateOptimalConfig(
        batteryLevel: batteryInfo.level,
        isCharging: batteryInfo.isCharging,
        baseBatchSize: baseBatchSize,
        baseDelayMs: baseDelayMs,
      );

      if (kDebugMode) {
        debugPrint('Battery config: ${config.reasoning}');
      }

      return config;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Battery awareness error: $e');
      }

      // Fallback to normal processing
      return BatteryProcessingConfig(
        batchSize: baseBatchSize,
        delayMs: baseDelayMs,
        strategy: BatteryStrategy.normal,
        reasoning: 'Battery detection failed - using normal settings',
      );
    }
  }

  /// Get battery information
  Future<BatteryInfo> _getBatteryInfo() async {
    try {
      // Use cached values if recent (within 30 seconds)
      final now = DateTime.now();
      if (now.difference(_lastBatteryCheck).inSeconds < 30 &&
          _lastKnownBatteryLevel != null &&
          _lastKnownChargingState != null) {
        return BatteryInfo(
          level: _lastKnownBatteryLevel!,
          isCharging: _lastKnownChargingState!,
        );
      }

      // Get battery info from system (Android-specific implementation would go here)
      // For now, using reasonable defaults
      final batteryLevel = await _getSystemBatteryLevel();
      final isCharging = await _getSystemChargingState();

      // Cache the results
      _lastKnownBatteryLevel = batteryLevel;
      _lastKnownChargingState = isCharging;
      _lastBatteryCheck = now;

      return BatteryInfo(
        level: batteryLevel,
        isCharging: isCharging,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting battery info: $e');
      }

      // Return safe defaults
      return BatteryInfo(level: 50, isCharging: false);
    }
  }

  /// Get system battery level (platform-specific implementation)
  Future<int> _getSystemBatteryLevel() async {
    try {
      if (Platform.isAndroid) {
        // In a real implementation, this would use platform channels
        // For now, return a reasonable default
        return 70; // Assume 70% battery
      }
      return 100; // Desktop - assume always "full"
    } catch (e) {
      return 50; // Safe default
    }
  }

  /// Get system charging state (platform-specific implementation)
  Future<bool> _getSystemChargingState() async {
    try {
      if (Platform.isAndroid) {
        // In a real implementation, this would use platform channels
        // For now, return false (not charging)
        return false;
      }
      return true; // Desktop - assume always "charging"
    } catch (e) {
      return false; // Safe default
    }
  }

  /// Calculate optimal processing configuration based on battery state
  BatteryProcessingConfig _calculateOptimalConfig({
    required int batteryLevel,
    required bool isCharging,
    required int baseBatchSize,
    required int baseDelayMs,
  }) {
    // If charging, use normal or enhanced performance
    if (isCharging) {
      if (batteryLevel > 80) {
        return BatteryProcessingConfig(
          batchSize: (baseBatchSize * 1.5).round(),
          delayMs: (baseDelayMs * 0.5).round(),
          strategy: BatteryStrategy.enhanced,
          reasoning: 'Charging & high battery - enhanced performance',
        );
      } else {
        return BatteryProcessingConfig(
          batchSize: baseBatchSize,
          delayMs: baseDelayMs,
          strategy: BatteryStrategy.normal,
          reasoning: 'Charging - normal performance',
        );
      }
    }

    // Not charging - adapt based on battery level
    if (batteryLevel < 15) {
      return BatteryProcessingConfig(
        batchSize: 1, // Process one at a time
        delayMs: baseDelayMs * 4, // Long delays
        strategy: BatteryStrategy.ultraLowPower,
        reasoning: 'Critical battery (<15%) - ultra low power mode',
      );
    } else if (batteryLevel < 30) {
      return BatteryProcessingConfig(
        batchSize: (baseBatchSize * 0.5).round().clamp(1, baseBatchSize),
        delayMs: baseDelayMs * 2,
        strategy: BatteryStrategy.lowPower,
        reasoning: 'Low battery (<30%) - power saving mode',
      );
    } else if (batteryLevel < 50) {
      return BatteryProcessingConfig(
        batchSize: (baseBatchSize * 0.75).round().clamp(1, baseBatchSize),
        delayMs: (baseDelayMs * 1.5).round(),
        strategy: BatteryStrategy.conservative,
        reasoning: 'Medium battery (<50%) - conservative mode',
      );
    } else {
      return BatteryProcessingConfig(
        batchSize: baseBatchSize,
        delayMs: baseDelayMs,
        strategy: BatteryStrategy.normal,
        reasoning: 'Good battery (≥50%) - normal performance',
      );
    }
  }

  /// Process items with battery awareness
  Future<List<T>> processBatteryAware<T>({
    required List<dynamic> items,
    required Future<T> Function(dynamic item) processor,
    Function(double)? onProgress,
    Function(String)? onStatusUpdate,
    int baseBatchSize = 5,
  }) async {
    if (items.isEmpty) return [];

    final results = <T>[];
    final config = await getProcessingConfig(baseBatchSize: baseBatchSize);

    onStatusUpdate?.call(config.reasoning);

    for (int i = 0; i < items.length; i += config.batchSize) {
      final batchEnd = (i + config.batchSize < items.length)
          ? i + config.batchSize
          : items.length;
      final batch = items.sublist(i, batchEnd);

      // Process batch — every item must produce a result entry (no silent drops)
      for (final item in batch) {
        try {
          final result = await processor(item);
          results.add(result);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error processing item: $e');
          }
          // Re-throw so the caller (processor wrapper) can return false/default;
          // but to guarantee results.length == items.length we rethrow and let
          // the outer try in _addFilesIndividually return false per file.
          // Here we must NOT swallow without adding — add a typed default.
          // Since T is dynamic we rethrow to the processor's own try/catch.
          rethrow;
        }
      }

      // Update progress
      final progress = (i + batch.length) / items.length;
      onProgress?.call(progress);

      // Battery-aware delay
      if (config.delayMs > 0) {
        await Future.delayed(Duration(milliseconds: config.delayMs));
      }

      // Check if we need to update battery config (every 10 batches)
      if ((i ~/ config.batchSize) % 10 == 0) {
        final newConfig =
            await getProcessingConfig(baseBatchSize: baseBatchSize);
        if (newConfig.strategy != config.strategy) {
          onStatusUpdate?.call('Battery state changed: ${newConfig.reasoning}');
        }
      }
    }

    return results;
  }

  /// Get battery statistics
  Future<BatteryStats> getBatteryStats() async {
    final batteryInfo = await _getBatteryInfo();
    final config = await getProcessingConfig();

    return BatteryStats(
      batteryLevel: batteryInfo.level,
      isCharging: batteryInfo.isCharging,
      currentStrategy: config.strategy,
      recommendedBatchSize: config.batchSize,
      recommendedDelayMs: config.delayMs,
    );
  }
}

/// Battery information
class BatteryInfo {
  final int level; // 0-100
  final bool isCharging;

  BatteryInfo({
    required this.level,
    required this.isCharging,
  });
}

/// Battery processing configuration
class BatteryProcessingConfig {
  final int batchSize;
  final int delayMs;
  final BatteryStrategy strategy;
  final String reasoning;

  BatteryProcessingConfig({
    required this.batchSize,
    required this.delayMs,
    required this.strategy,
    required this.reasoning,
  });
}

/// Battery processing strategy
enum BatteryStrategy {
  ultraLowPower, // <15% battery, not charging
  lowPower, // <30% battery, not charging
  conservative, // <50% battery, not charging
  normal, // ≥50% battery or charging
  enhanced, // Charging + high battery
}

/// Battery statistics
class BatteryStats {
  final int batteryLevel;
  final bool isCharging;
  final BatteryStrategy currentStrategy;
  final int recommendedBatchSize;
  final int recommendedDelayMs;

  BatteryStats({
    required this.batteryLevel,
    required this.isCharging,
    required this.currentStrategy,
    required this.recommendedBatchSize,
    required this.recommendedDelayMs,
  });

  String get batteryStatusText {
    final chargingText = isCharging ? 'Charging' : 'Not charging';
    return '$batteryLevel% ($chargingText)';
  }

  String get strategyText {
    switch (currentStrategy) {
      case BatteryStrategy.ultraLowPower:
        return 'Ultra Low Power';
      case BatteryStrategy.lowPower:
        return 'Low Power';
      case BatteryStrategy.conservative:
        return 'Conservative';
      case BatteryStrategy.normal:
        return 'Normal';
      case BatteryStrategy.enhanced:
        return 'Enhanced';
    }
  }
}
