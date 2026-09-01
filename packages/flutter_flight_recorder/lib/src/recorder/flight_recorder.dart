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
export '../incident/analysis/incident_analysis.dart';
export '../incident/analysis/incident_analyzer.dart';
export '../incident/analysis/incident_story.dart';
export '../incident/analysis/incident_timeline.dart';
export '../incident/analysis/reproduction_step.dart';
export '../incident/analysis/timeline_entry.dart';
export '../incident/incident.dart';
export '../incident/incident_markdown_exporter.dart';
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
  ///
  /// [correlationId] optionally declares that this event belongs to the
  /// same application-defined interaction as every other recorded event
  /// passed the same id — see [newCorrelationId] and
  /// `FlightEvent.correlationId` for what that does and does not mean.
  /// Omit it (the default) to keep today's behavior exactly: an
  /// uncorrelated event, grouped by `IncidentAnalyzer`'s chronological
  /// fallback like every event recorded before this parameter existed.
  static void recordAction(
    String name, {
    Map<String, Object?>? metadata,
    String? correlationId,
  }) {
    _record(EventCategory.action, name,
        metadata: metadata, correlationId: correlationId);
  }

  /// Records a structured log line. Logs become timeline events; this does
  /// not replace or hook into an application's existing logging framework.
  ///
  /// See [recordAction] for what [correlationId] does.
  static void log(
    String message, {
    EventSeverity level = EventSeverity.info,
    Map<String, Object?>? metadata,
    String? correlationId,
  }) {
    _record(EventCategory.log, message,
        metadata: metadata, severity: level, correlationId: correlationId);
  }

  /// Manually records an error. See [init] and
  /// [FlightRecorderConfig.captureUncaughtErrors] for automatic capture of
  /// uncaught errors — that's installed by [init], not by this method.
  ///
  /// See [recordAction] for what [correlationId] does.
  static void recordError(
    Object error, {
    StackTrace? stackTrace,
    Map<String, Object?>? metadata,
    EventSeverity severity = EventSeverity.error,
    String? correlationId,
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
      correlationId: correlationId,
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
  ///
  /// See [recordAction] for what [correlationId] does.
  static void recordNavigation(
    String routeName, {
    String? previousRouteName,
    required String action,
    String? correlationId,
  }) {
    _record(
      EventCategory.navigation,
      routeName,
      metadata: {
        'action': action,
        if (previousRouteName != null) 'from': previousRouteName,
      },
      correlationId: correlationId,
    );
  }

  /// Records a network request. Normally called by
  /// `FlightRecorderDioInterceptor` (from the `flutter_flight_recorder_dio`
  /// package), not directly by application code. `metadata` is expected
  /// to carry the sanitized URL, status code, duration, and error type —
  /// the interceptor is responsible for that shape, not this method.
  ///
  /// See [recordAction] for what [correlationId] does — the interceptor
  /// passes one through here when the request carried an explicit one
  /// (see that package's own docs for how).
  static void recordNetwork(
    String name, {
    Map<String, Object?>? metadata,
    EventSeverity? severity,
    String? correlationId,
  }) {
    _record(EventCategory.network, name,
        metadata: metadata, severity: severity, correlationId: correlationId);
  }

  /// Records an application lifecycle transition (e.g. `'resumed'`,
  /// `'paused'`). Normally called by `FlightRecorderLifecycleObserver`,
  /// not directly by application code.
  static void recordLifecycle(
    String state, {
    Map<String, Object?>? metadata,
    String? correlationId,
  }) {
    _record(EventCategory.lifecycle, state,
        metadata: metadata, correlationId: correlationId);
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

  /// Generates a fresh, opaque correlation id for use with the
  /// `correlationId` parameter on [recordAction] and the other `record*`
  /// methods — e.g. one call per user interaction you want explicitly
  /// correlated, passed to every event recorded as part of it:
  ///
  /// ```dart
  /// final id = FlightRecorder.newCorrelationId();
  /// FlightRecorder.recordAction('save_tapped', correlationId: id);
  /// // ... pass `id` through to whatever records the resulting request.
  /// ```
  ///
  /// Random and unrelated to any application data — treat it as an
  /// opaque token. Unlike `metadata`, `correlationId` is never subject
  /// to `Sanitizer`'s masking (see `FlightEvent.correlationId`'s doc),
  /// so never pass an email, phone number, user id, token, URL, or any
  /// other sensitive/business value here — only ids from this method,
  /// or values you already know are equally opaque.
  static String newCorrelationId() => 'COR-${_randomHex(6)}';

  static final Random _idRandom = Random.secure();

  static String _generateIncidentId() => 'INC-${_randomHex(3)}';

  static String _randomHex(int byteLength) {
    final bytes = List<int>.generate(byteLength, (_) => _idRandom.nextInt(256));
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
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
    String? correlationId,
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
      correlationId: correlationId,
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
