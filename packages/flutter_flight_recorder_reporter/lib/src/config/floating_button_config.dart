import 'package:flutter/widgets.dart';

/// Configuration for the floating report-trigger button. Only consulted
/// when [ReportTrigger] is `button` or `both`.
@immutable
class FloatingButtonConfig {
  const FloatingButtonConfig({
    this.enabled = true,
    this.alignment = Alignment.bottomRight,
    this.padding = const EdgeInsets.all(16),
  });

  /// Set false to suppress the floating button even when the active
  /// [ReportTrigger] would otherwise show it — a finer-grained switch than
  /// changing the trigger mode itself.
  final bool enabled;

  final Alignment alignment;
  final EdgeInsets padding;
}
