import 'dart:math';

import 'package:flutter/foundation.dart';

import '../config/flight_recorder_config.dart';
import '../context/app_context.dart';
import '../error/uncaught_error_capture.dart';
import '../events/flight_event.dart';
import '../incident/incident.dart';
import '../incident/qa_report_data.dart';
import '../privacy/sanitizer.dart';
import 'rolling_buffer.dart';

export '../config/flight_recorder_config.dart';
export '../events/flight_event.dart';
export '../incident/incident.dart';
export '../incident/qa_report_data.dart';
export '../lifecycle/flight_recorder_lifecycle_observer.dart';
export '../navigation/flight_recorder_navigator_observer.dart'
    hide unnamedRouteLabel;

/// Records a bounded, rolling timeline of application events.
///
/// Call [init] once during app startup, then use [recordAction], [log],
/// [recordError] and [setContext] anywhere in the app. Calling any of
/// those before [init] is a no-op (an [AssertionError] is raised in debug
/// mode to catch the mistake early; release builds never crash from it).
///
/// [init] also installs automatic uncaught-error capture (see [init]'s
/// own doc). `FlightRecorderNavigatorObserver` and
/// `FlightRecorderLifecycleObserver` record navigation and app lifecycle
/// transitions respectively — both are separate, explicitly-opted-into
/// hooks, not installed automatically by [init].
class FlightRecorder {
  FlightRecorder._();

  static _Session? _session;

  static final UncaughtErrorCapture _errorCapture = UncaughtErrorCapture(
    recordError: (error, {stackTrace, metadata}) =>
        recordError(error, stackTrace: stackTrace, metadata: metadata),
    shouldCapture: () => _session?.config.captureUncaughtErrors ?? false,
  );

  /// Whether [init] has been called.
  static bool get isInitialized => _session != null;

  /// Starts recording. Safe to call again — a second call resets the
  /// buffer and context and applies the new [config], logging a warning
  /// rather than throwing, since re-initialization commonly happens
  /// harmlessly during hot restart in development.
  ///
  /// When [FlightRecorderConfig.captureUncaughtErrors] is true (the
  /// default), this also installs handlers for uncaught Flutter framework
  /// errors and unhandled platform/async errors. Those handlers always
  /// chain to whatever was previously installed — including Flutter's own
  /// default error reporting — so this never silently replaces existing
  /// error handling.
  static void init([
    FlightRecorderConfig config = const FlightRecorderConfig(),
  ]) {
    if (_session != null) {
      debugPrint(
        'FlightRecorder.init() was called again. Previous recorder state '
        'has been discarded and replaced with the new configuration.',
      );
    }
    _session = _Session(config);
    _errorCapture.install();
  }

  /// Records a user action, e.g. `FlightRecorder.recordAction('save_profile_tapped')`.
  static void recordAction(String name, {Map<String, Object?>? metadata}) {
    _record(EventCategory.action, name, metadata: metadata);
  }

  /// Records a structured log line. Logs become timeline events; this does
  /// not replace or hook into an application's existing logging framework.
  static void log(
    String message, {
    EventSeverity level = EventSeverity.info,
    Map<String, Object?>? metadata,
  }) {
    _record(EventCategory.log, message, metadata: metadata, severity: level);
  }

  /// Manually records an error. See [init] and
  /// [FlightRecorderConfig.captureUncaughtErrors] for automatic capture of
  /// uncaught errors — that's installed by [init], not by this method.
  static void recordError(
    Object error, {
    StackTrace? stackTrace,
    Map<String, Object?>? metadata,
    EventSeverity severity = EventSeverity.error,
  }) {
    final combinedMetadata = <String, Object?>{
      'error': error.toString(),
      if (stackTrace != null) 'stackTrace': stackTrace.toString(),
      ...?metadata,
    };
    _record(
      EventCategory.error,
      error.runtimeType.toString(),
      metadata: combinedMetadata,
      severity: severity,
    );
  }

  /// Attaches custom, application-supplied context to every future
  /// incident, e.g. `FlightRecorder.setContext('environment', 'uat')`.
  static void setContext(String key, Object? value) {
    if (!_requireInitialized('setContext')) return;
    _session!.context.set(key, value);
  }

  /// Records a navigation transition. Normally called by
  /// `FlightRecorderNavigatorObserver`, not directly by application code.
  /// Only route names are ever recorded — never route arguments.
  static void recordNavigation(
    String routeName, {
    String? previousRouteName,
    required String action,
  }) {
    _record(
      EventCategory.navigation,
      routeName,
      metadata: {
        'action': action,
        if (previousRouteName != null) 'from': previousRouteName,
      },
    );
  }

  /// Records a network request. Normally called by
  /// `FlightRecorderDioInterceptor` (from the `flutter_flight_recorder_dio`
  /// package), not directly by application code. `metadata` is expected
  /// to carry the sanitized URL, status code, duration, and error type —
  /// the interceptor is responsible for that shape, not this method.
  static void recordNetwork(
    String name, {
    Map<String, Object?>? metadata,
    EventSeverity? severity,
  }) {
    _record(EventCategory.network, name,
        metadata: metadata, severity: severity);
  }

  /// Records an application lifecycle transition (e.g. `'resumed'`,
  /// `'paused'`). Normally called by `FlightRecorderLifecycleObserver`,
  /// not directly by application code.
  static void recordLifecycle(String state, {Map<String, Object?>? metadata}) {
    _record(EventCategory.lifecycle, state, metadata: metadata);
  }

  /// Creates an immutable [Incident] snapshotting the current timeline and
  /// context. Unlike the void recording methods, this cannot silently
  /// no-op when uninitialized — it must return a value — so it throws a
  /// [StateError] in every build mode rather than only asserting in
  /// debug.
  ///
  /// The returned incident's [Incident.context] will NOT include app
  /// version or build number unless you called [setContext] for them —
  /// see [Incident.context]'s doc.
  static Incident createIncident({
    required String title,
    String? description,
    QaReportData? qaReport,
    Object? trigger,
  }) {
    if (_session == null) {
      throw StateError(
        'FlightRecorder.createIncident() was called before '
        'FlightRecorder.init(). Call FlightRecorder.init() once during '
        'app startup.',
      );
    }
    final session = _session!;
    return Incident(
      id: _generateIncidentId(),
      timestamp: DateTime.now(),
      title: title,
      description: description,
      qaReport: qaReport,
      trigger: trigger,
      timeline: session.buffer.toList(),
      context: session.context.snapshot(),
    );
  }

  static final Random _incidentIdRandom = Random.secure();

  static String _generateIncidentId() {
    final bytes = List<int>.generate(3, (_) => _incidentIdRandom.nextInt(256));
    final hex = bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
    return 'INC-$hex';
  }

  /// Resets all recorder state, including restoring [FlutterError.onError]
  /// and [PlatformDispatcher.onError] to whatever they were before this
  /// package touched them. Not part of the stable public API — for use in
  /// this package's own tests and in consuming apps' test suites to
  /// isolate recorder state between tests.
  @visibleForTesting
  static void resetForTest() {
    _session = null;
    _errorCapture.reset();
  }

  /// Snapshot of the current rolling buffer. Not part of the stable public
  /// API — prefer [createIncident] for a real, immutable snapshot; this
  /// exists so recorder internals are testable without creating one.
  @visibleForTesting
  static List<FlightEvent> get debugEvents =>
      _session?.buffer.toList() ?? const [];

  /// Snapshot of the current context. See [debugEvents].
  @visibleForTesting
  static Map<String, Object?> get debugContext =>
      _session?.context.snapshot() ?? const {};

  static void _record(
    EventCategory category,
    String name, {
    Map<String, Object?>? metadata,
    EventSeverity? severity,
  }) {
    if (!_requireInitialized('record')) return;
    final session = _session!;
    if (!session.config.enabled) return;
    if (!session.config.isCategoryEnabled(category)) return;

    final timestamp = DateTime.now();
    final event = FlightEvent(
      id: session.nextEventId(timestamp),
      timestamp: timestamp,
      category: category,
      name: name,
      metadata: session.sanitizer.sanitizeMetadata(metadata ?? const {}),
      severity: severity,
    );
    session.buffer.add(event);
  }

  static bool _requireInitialized(String method) {
    if (_session == null) {
      assert(
        false,
        'FlightRecorder.$method() was called before FlightRecorder.init(). '
        'Call FlightRecorder.init() once during app startup.',
      );
      return false;
    }
    return true;
  }
}

class _Session {
  _Session(this.config)
      : buffer = RollingBuffer<FlightEvent>(config.maxEvents),
        context = AppContext(),
        sanitizer = Sanitizer(
          sensitiveKeys: config.privacy.sensitiveKeys,
          customSanitizer: config.privacy.customSanitizer,
        );

  final FlightRecorderConfig config;
  final RollingBuffer<FlightEvent> buffer;
  final AppContext context;
  final Sanitizer sanitizer;

  int _idCounter = 0;

  String nextEventId(DateTime timestamp) {
    final ts = timestamp.microsecondsSinceEpoch.toRadixString(36);
    final seq = (_idCounter++).toRadixString(36);
    return '$ts-$seq';
  }
}
