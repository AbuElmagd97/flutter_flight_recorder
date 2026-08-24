import 'package:flutter/foundation.dart';

/// Configuration for shake-to-report. Only consulted when [ReportTrigger]
/// is `shake` or `both`.
@immutable
class ShakeConfig {
  const ShakeConfig({
    this.enabled = true,
    this.threshold = 15.0,
    this.minTimeBetweenShakes = const Duration(seconds: 1),
  }) : assert(threshold > 0, 'threshold must be greater than 0');

  /// Set false to suppress shake detection even when the active
  /// [ReportTrigger] would otherwise enable it.
  final bool enabled;

  /// How far accelerometer magnitude must deviate from Earth's gravity
  /// (~9.8 m/s²) before a sample counts as part of a shake. Higher values
  /// require a more vigorous shake and reduce accidental triggers; lower
  /// values are more sensitive.
  final double threshold;

  /// Minimum time between two detected shakes. A shake detected before
  /// this elapses is ignored — this is the "avoid accidental triggers"
  /// debounce, not the "reporter already open" guard (that's handled
  /// separately and unconditionally, regardless of this value).
  final Duration minTimeBetweenShakes;
}
