import 'dart:math' as math;

import '../config/shake_config.dart';

/// Standard gravity, in m/s², used as the baseline a resting device's
/// accelerometer reading is expected to hover around.
const double gravityMagnitude = 9.80665;

/// Pure shake-detection logic: threshold + debounce over a stream of
/// accelerometer samples. Deliberately has no dependency on `sensors_plus`
/// or any real sensor — [addSample] takes plain numbers, so this is fully
/// unit-testable with synthetic data. The actual sensor wiring
/// (subscribing to `accelerometerEventStream()` and calling [addSample]
/// for each event) lives in the widget that uses this, not here.
class ShakeDetector {
  ShakeDetector({required this.config, required this.onShake});

  final ShakeConfig config;
  final void Function() onShake;

  DateTime? _lastShakeAt;

  /// Feeds one accelerometer sample. Calls [onShake] at most once per
  /// [ShakeConfig.minTimeBetweenShakes] window, and never when
  /// [ShakeConfig.enabled] is false.
  void addSample(double x, double y, double z, DateTime timestamp) {
    if (!config.enabled) return;

    final magnitude = math.sqrt(x * x + y * y + z * z);
    final deviation = (magnitude - gravityMagnitude).abs();
    if (deviation < config.threshold) return;

    if (_lastShakeAt != null &&
        timestamp.difference(_lastShakeAt!) < config.minTimeBetweenShakes) {
      return;
    }

    _lastShakeAt = timestamp;
    onShake();
  }
}
