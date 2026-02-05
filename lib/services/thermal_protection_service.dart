import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Thermal states based on Android Thermal API
enum ThermalState {
  nominal,    // 0 - No throttling
  light,      // 1 - Light throttling
  moderate,   // 2 - Moderate throttling  
  severe,     // 3 - Severe throttling
  critical,   // 4 - Critical - shutdown imminent
  emergency,  // 5 - Emergency shutdown
  shutdown,   // 6 - Shutdown
}

/// Processing adaptation configuration
class ProcessingConfig {
  final int batchSize;
  final int delayMs;
  final bool shouldPause;
  final String description;
  
  ProcessingConfig({
    required this.batchSize,
    required this.delayMs,
    required this.shouldPause,
    required this.description,
  });
}

/// Lightweight thermal protection service for Android performance management
class ThermalProtectionService {
  static const MethodChannel _channel = MethodChannel('thermal_protection');
  
  static ThermalProtectionService? _instance;
  static ThermalProtectionService get instance => _instance ??= ThermalProtectionService._();
  
  ThermalProtectionService._();
  
  Timer? _monitoringTimer;
  ThermalState _currentState = ThermalState.nominal;
  final List<Function(ThermalState)> _listeners = [];
  
  /// Current thermal state
  ThermalState get currentState => _currentState;
  
  /// Whether thermal protection is available on this platform
  bool get isSupported => Platform.isAndroid;
  
  /// Starts thermal monitoring (lightweight, checks every 5 seconds)
  void startMonitoring() {
    if (!isSupported) {
      debugPrint('Thermal protection not supported on this platform');
      return;
    }
    
    debugPrint('Starting thermal protection monitoring');
    
    _monitoringTimer?.cancel();
    _monitoringTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _checkThermalState();
    });
    
    // Initial check
    _checkThermalState();
  }
  
  /// Stops thermal monitoring
  void stopMonitoring() {
    debugPrint('Stopping thermal protection monitoring');
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
  }
  
  /// Adds listener for thermal state changes
  void addListener(Function(ThermalState) listener) {
    _listeners.add(listener);
  }
  
  /// Removes listener
  void removeListener(Function(ThermalState) listener) {
    _listeners.remove(listener);
  }
  
  /// Gets processing configuration based on current thermal state
  ProcessingConfig getProcessingConfig({int baseBatchSize = 10}) {
    switch (_currentState) {
      case ThermalState.nominal:
        return ProcessingConfig(
          batchSize: baseBatchSize,
          delayMs: 0,
          shouldPause: false,
          description: 'Full speed processing',
        );
        
      case ThermalState.light:
        return ProcessingConfig(
          batchSize: (baseBatchSize * 0.8).round(),
          delayMs: 50,
          shouldPause: false,
          description: 'Slightly reduced processing speed',
        );
        
      case ThermalState.moderate:
        return ProcessingConfig(
          batchSize: (baseBatchSize * 0.6).round(),
          delayMs: 100,
          shouldPause: false,
          description: 'Moderately reduced processing speed',
        );
        
      case ThermalState.severe:
        return ProcessingConfig(
          batchSize: (baseBatchSize * 0.4).round(),
          delayMs: 250,
          shouldPause: false,
          description: 'Severely reduced processing speed',
        );
        
      case ThermalState.critical:
      case ThermalState.emergency:
      case ThermalState.shutdown:
        return ProcessingConfig(
          batchSize: 1,
          delayMs: 1000,
          shouldPause: true,
          description: 'Processing paused - device overheating',
        );
    }
  }
  
  /// Checks current thermal state
  Future<void> _checkThermalState() async {
    try {
      // Try to get thermal state from Android
      final int? stateValue = await _getThermalStateFromAndroid();
      
      if (stateValue != null) {
        final newState = ThermalState.values[stateValue.clamp(0, ThermalState.values.length - 1)];
        
        if (newState != _currentState) {
          final oldState = _currentState;
          _currentState = newState;
          
          debugPrint('Thermal state changed: $oldState -> $newState');
          
          // Notify listeners
          for (final listener in _listeners) {
            try {
              listener(newState);
            } catch (e) {
              debugPrint('Error in thermal state listener: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking thermal state: $e');
      // Fallback to nominal state on error
      if (_currentState != ThermalState.nominal) {
        _currentState = ThermalState.nominal;
      }
    }
  }
  
  /// Gets thermal state from Android platform (returns null if not available)
  Future<int?> _getThermalStateFromAndroid() async {
    try {
      // Try platform channel first (requires native implementation)
      final result = await _channel.invokeMethod<int>('getThermalState');
      return result;
    } catch (e) {
      // Platform channel not implemented, use fallback detection
      return await _getFallbackThermalState();
    }
  }
  
  /// Fallback thermal detection using CPU usage and available memory
  Future<int?> _getFallbackThermalState() async {
    try {
      // Simple heuristic based on available system resources
      // This is a lightweight approximation when native thermal API is not available
      
      // Check if we can read /proc/stat for CPU usage (Android specific)
      if (Platform.isAndroid) {
        try {
          final cpuInfo = await Process.run('cat', ['/proc/loadavg']);
          if (cpuInfo.exitCode == 0) {
            final loadAvg = cpuInfo.stdout.toString().split(' ')[0];
            final load = double.tryParse(loadAvg) ?? 0.0;
            
            // Simple thermal estimation based on CPU load
            if (load > 4.0) return 3; // Severe
            if (load > 2.0) return 2; // Moderate  
            if (load > 1.0) return 1; // Light
            return 0; // Nominal
          }
        } catch (e) {
          // Ignore errors in fallback detection
        }
      }
      
      // Default to nominal if no detection method works
      return 0;
    } catch (e) {
      return null;
    }
  }
  
  /// Gets user-friendly thermal state description
  static String getThermalStateDescription(ThermalState state) {
    switch (state) {
      case ThermalState.nominal:
        return 'Normal temperature - full performance available';
      case ThermalState.light:
        return 'Slightly warm - minor performance reduction';
      case ThermalState.moderate:
        return 'Warm - moderate performance reduction';
      case ThermalState.severe:
        return 'Hot - significant performance reduction';
      case ThermalState.critical:
        return 'Very hot - critical performance reduction';
      case ThermalState.emergency:
        return 'Overheating - emergency throttling active';
      case ThermalState.shutdown:
        return 'Extreme overheating - shutdown imminent';
    }
  }
  
  /// Gets thermal state color for UI indication
  static int getThermalStateColor(ThermalState state) {
    switch (state) {
      case ThermalState.nominal:
        return 0xFF4CAF50; // Green
      case ThermalState.light:
        return 0xFF8BC34A; // Light Green
      case ThermalState.moderate:
        return 0xFFFF9800; // Orange
      case ThermalState.severe:
        return 0xFFFF5722; // Deep Orange
      case ThermalState.critical:
        return 0xFFF44336; // Red
      case ThermalState.emergency:
        return 0xFF9C27B0; // Purple
      case ThermalState.shutdown:
        return 0xFF000000; // Black
    }
  }
  
  /// Disposes resources
  void dispose() {
    stopMonitoring();
    _listeners.clear();
  }
}