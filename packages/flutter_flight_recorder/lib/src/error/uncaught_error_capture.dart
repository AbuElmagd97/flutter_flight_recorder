import 'package:flutter/foundation.dart';

typedef ErrorRecorder = void Function(
  Object error, {
  StackTrace? stackTrace,
  Map<String, Object?>? metadata,
});

typedef ShouldCapture = bool Function();

/// Installs [FlutterError.onError] and [PlatformDispatcher.onError]
/// wrappers that record uncaught errors, then always chain to whatever
/// handler was present before this package ever touched them.
///
/// The previous handler is captured exactly once, on the first [install]
/// call — a second [install] call (e.g. from calling
/// `FlightRecorder.init` again) reinstalls a fresh wrapper that still
/// chains to that same original handler, rather than wrapping its own
/// previously-installed wrapper. This is what keeps repeated
/// initialization from recording the same error multiple times, and what
/// keeps this package from ever silently replacing an application's own
/// error handling — including Flutter's own default one.
class UncaughtErrorCapture {
  UncaughtErrorCapture({
    required ErrorRecorder recordError,
    required ShouldCapture shouldCapture,
  })  : _recordError = recordError,
        _shouldCapture = shouldCapture;

  final ErrorRecorder _recordError;
  final ShouldCapture _shouldCapture;

  FlutterExceptionHandler? _originalFlutterOnError;
  bool Function(Object error, StackTrace stack)? _originalDispatcherOnError;
  bool _captured = false;

  void install() {
    if (!_captured) {
      _originalFlutterOnError = FlutterError.onError;
      _originalDispatcherOnError = PlatformDispatcher.instance.onError;
      _captured = true;
    }

    FlutterError.onError = (FlutterErrorDetails details) {
      if (_shouldCapture()) {
        _recordError(
          details.exception,
          stackTrace: details.stack,
          metadata: {
            if (details.library != null) 'library': details.library,
            if (details.context != null) 'context': details.context.toString(),
          },
        );
      }
      _originalFlutterOnError?.call(details);
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      if (_shouldCapture()) {
        _recordError(error, stackTrace: stack);
      }
      return _originalDispatcherOnError?.call(error, stack) ?? true;
    };
  }

  /// Restores the handlers captured by [install] and forgets them. Called
  /// internally by `FlightRecorder.resetForTest`; not exposed as its own
  /// public API.
  void reset() {
    if (_captured) {
      FlutterError.onError = _originalFlutterOnError;
      PlatformDispatcher.instance.onError = _originalDispatcherOnError;
    }
    _captured = false;
    _originalFlutterOnError = null;
    _originalDispatcherOnError = null;
  }
}
