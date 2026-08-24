import 'package:flutter/foundation.dart';

import '../events/flight_event.dart';
import '../privacy/default_sensitive_keys.dart';
import '../privacy/sanitizer.dart';

export '../privacy/default_sensitive_keys.dart';
export '../privacy/sanitizer.dart' show CustomSanitizer;

/// Controls how [Sanitizer] masks and normalizes event metadata.
@immutable
class PrivacyConfig {
  const PrivacyConfig({
    this.sensitiveKeys = defaultSensitiveKeys,
    this.customSanitizer,
  });

  final Set<String> sensitiveKeys;
  final CustomSanitizer? customSanitizer;
}

/// Configuration for [FlightRecorder.init].
@immutable
class FlightRecorderConfig {
  const FlightRecorderConfig({
    this.enabled = true,
    this.maxEvents = 500,
    this.enabledCategories,
    this.captureUncaughtErrors = true,
    this.privacy = const PrivacyConfig(),
  }) : assert(maxEvents > 0, 'maxEvents must be greater than 0');

  /// When `false`, every recording method becomes a no-op for the
  /// lifetime of this config. [FlightRecorder.createIncident] itself is
  /// never blocked by this — it always succeeds — but since `enabled` is
  /// fixed for the whole session (there's no way to flip it without
  /// calling [FlightRecorder.init] again, which resets the buffer), a
  /// session that starts disabled has nothing to snapshot: its incidents
  /// will simply have an empty timeline, not an error.
  final bool enabled;

  /// Maximum number of events kept in the rolling buffer. Oldest events are
  /// evicted first once this is exceeded.
  final int maxEvents;

  /// Categories that may be recorded. `null` means all categories are
  /// enabled.
  final Set<EventCategory>? enabledCategories;

  /// Whether [FlightRecorder.init] installs handlers for uncaught Flutter
  /// framework errors and unhandled async errors. Installed handlers always
  /// chain to any previously-registered handler rather than replacing it.
  final bool captureUncaughtErrors;

  final PrivacyConfig privacy;

  bool isCategoryEnabled(EventCategory category) =>
      enabledCategories == null || enabledCategories!.contains(category);
}
