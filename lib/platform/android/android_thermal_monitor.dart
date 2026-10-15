import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Thermal severity reported by [AndroidThermalMonitor].
enum ThermalStatus {
  none,
  light,
  moderate,
  severe,
  critical,
}

/// Polls Android's PowerManager thermal headroom every 5 seconds and exposes
/// the result as both a synchronous getter and a broadcast [Stream].
///
/// On non-Android platforms [isSupported] returns false and the stream emits
/// [ThermalStatus.none] only when explicitly polled.
class AndroidThermalMonitor {
  static const MethodChannel _channel = MethodChannel('thermal_protection');

  AndroidThermalMonitor() {
    if (isSupported) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
      _poll(); // initial check
    }
  }

  final StreamController<ThermalStatus> _controller =
      StreamController<ThermalStatus>.broadcast();

  ThermalStatus _current = ThermalStatus.none;
  Timer? _timer;

  /// True on Android only.
  bool get isSupported => Platform.isAndroid;

  /// Most recently polled thermal status.
  ThermalStatus get currentStatus => _current;

  /// Broadcast stream that emits a new [ThermalStatus] whenever the value
  /// changes.
  Stream<ThermalStatus> get statusStream => _controller.stream;

  Future<void> _poll() async {
    try {
      final headroom =
          await _channel.invokeMethod<double>('getThermalHeadroom') ?? 1.0;
      _update(_headroomToStatus(headroom));
    } on MissingPluginException {
      // Channel not wired up in this environment — safe fallback.
      _update(ThermalStatus.none);
    } catch (_) {
      // API level < 29 or any other error — treat as no throttling.
      _update(ThermalStatus.none);
    }
  }

  void _update(ThermalStatus status) {
    _current = status;
    if (!_controller.isClosed) {
      _controller.add(status);
    }
  }

  static ThermalStatus _headroomToStatus(double headroom) {
    if (headroom < 0.15) return ThermalStatus.severe;
    if (headroom < 0.30) return ThermalStatus.moderate;
    if (headroom < 0.50) return ThermalStatus.light;
    return ThermalStatus.none;
  }

  /// Releases resources.  The monitor cannot be used after calling [dispose].
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _controller.close();
  }
}
