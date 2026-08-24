import 'package:flutter/widgets.dart';

import '../recorder/flight_recorder.dart';

/// Records application lifecycle transitions (resumed, inactive, paused,
/// detached, hidden).
///
/// ```dart
/// WidgetsBinding.instance.addObserver(FlightRecorderLifecycleObserver());
/// ```
///
/// Like the navigator observer, this silently does nothing before
/// [FlightRecorder.init] has run rather than raising a debug assertion —
/// lifecycle transitions are framework-triggered, not something
/// application code chooses to call.
class FlightRecorderLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (FlightRecorder.isInitialized) {
      FlightRecorder.recordLifecycle(state.name);
    }
    super.didChangeAppLifecycleState(state);
  }
}
