import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:share_plus/share_plus.dart';

import 'config/floating_button_config.dart';
import 'config/report_trigger.dart';
import 'config/shake_config.dart';
import 'reporter_flow.dart';
import 'screenshot/screenshot_capture.dart';
import 'triggers/floating_trigger_button.dart';
import 'triggers/shake_detector.dart';

/// Wraps an app to enable QA bug reporting.
///
/// ```dart
/// void main() {
///   FlightRecorder.init();
///   runApp(
///     FlutterFlightRecorderReporter(
///       child: const MyApp(),
///     ),
///   );
/// }
/// ```
///
/// Shows a full-screen bug report flow (built with an internal, isolated
/// `MaterialApp` — see the package README's "Architecture" section for
/// why) via a plain `Stack`, never `Navigator.push` or
/// `showModalBottomSheet`. This means a `FlightRecorderNavigatorObserver`
/// attached to the wrapped app's own `MaterialApp` never sees any
/// navigation events from the reporter's own UI — there's nothing to
/// exclude, by construction, not by filtering.
class FlutterFlightRecorderReporter extends StatefulWidget {
  const FlutterFlightRecorderReporter({
    super.key,
    required this.child,
    this.trigger = ReportTrigger.both,
    this.floatingButton = const FloatingButtonConfig(),
    this.shake = const ShakeConfig(),
    this.captureScreenshot = true,
    this.textDirection,
  });

  final Widget child;
  final ReportTrigger trigger;
  final FloatingButtonConfig floatingButton;
  final ShakeConfig shake;

  /// Whether to capture a screenshot when the reporter opens. Screenshot
  /// capture always happens before the reporter's own UI is shown, and
  /// the two are structurally separate layers (see the class doc), so
  /// the reporter never captures itself either way.
  final bool captureScreenshot;

  /// This widget wraps the whole app, including its `MaterialApp` — so
  /// there's no ambient `Directionality` available to inherit for the
  /// reporter's own UI (its ancestor is whatever called `runApp`, not the
  /// app's own widget tree). Defaults to LTR; pass `TextDirection.rtl`
  /// explicitly for a right-to-left app.
  final TextDirection? textDirection;

  /// Opens the reporter manually. Available regardless of [trigger].
  static void open(BuildContext context) {
    final state = context
        .findAncestorStateOfType<FlutterFlightRecorderReporterState>();
    assert(
      state != null,
      'FlutterFlightRecorderReporter.open() was called without a '
      'FlutterFlightRecorderReporter ancestor in the widget tree.',
    );
    state?.openReporter(trigger: 'manual');
  }

  @override
  State<FlutterFlightRecorderReporter> createState() =>
      FlutterFlightRecorderReporterState();
}

class _OpenReporterState {
  const _OpenReporterState({
    required this.trigger,
    required this.screenshot,
    required this.screenshotCaptureFailed,
  });

  final String trigger;
  final Uint8List? screenshot;
  final bool screenshotCaptureFailed;
}

/// Not part of the stable public API on its own — exposed (via
/// [FlutterFlightRecorderReporter.createState]'s return type) so widget
/// tests can drive [openReporter] / [closeReporter] / [isOpen] directly
/// without needing a real shake or a real tap.
@visibleForTesting
class FlutterFlightRecorderReporterState
    extends State<FlutterFlightRecorderReporter> {
  final GlobalKey _screenshotBoundaryKey = GlobalKey(
    debugLabel: 'flutter_flight_recorder_reporter_screenshot_boundary',
  );
  final ValueNotifier<_OpenReporterState?> _openState = ValueNotifier(null);

  /// The key on the [RepaintBoundary] wrapping the app's own content —
  /// the screenshot capture scope. Exposed so tests can assert the
  /// reporter's own UI (form, preview) is never a descendant of this
  /// boundary, i.e. that the reporter structurally can't capture itself.
  @visibleForTesting
  GlobalKey get screenshotBoundaryKey => _screenshotBoundaryKey;

  StreamSubscription<AccelerometerEvent>? _shakeSubscription;
  ShakeDetector? _shakeDetector;

  /// Overridable for tests only.
  @visibleForTesting
  SharePlus? sharePlusOverride;

  bool get isOpen => _openState.value != null;

  bool get _shakeActive =>
      (widget.trigger == ReportTrigger.shake ||
          widget.trigger == ReportTrigger.both) &&
      widget.shake.enabled;

  bool get _buttonActive =>
      (widget.trigger == ReportTrigger.button ||
          widget.trigger == ReportTrigger.both) &&
      widget.floatingButton.enabled;

  @override
  void initState() {
    super.initState();
    _maybeStartShake();
  }

  @override
  void didUpdateWidget(covariant FlutterFlightRecorderReporter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger ||
        oldWidget.shake != widget.shake) {
      _stopShake();
      _maybeStartShake();
    }
  }

  @override
  void dispose() {
    _stopShake();
    _openState.dispose();
    super.dispose();
  }

  void _maybeStartShake() {
    if (!_shakeActive) return;
    _shakeDetector = ShakeDetector(
      config: widget.shake,
      onShake: () => openReporter(trigger: 'shake'),
    );
    // Handles a stream-level error once listening has already started
    // (e.g. a PlatformException decoding a later event). It does NOT
    // cover a failed initial `invokeMethod('listen', ...)` — sensors_plus
    // reports that straight to FlutterError.reportError rather than
    // through this stream's error channel (see EventChannel's own
    // source), so it's covered by FlightRecorder's automatic error
    // capture instead, same as any other uncaught framework error. Either
    // way, losing shake should degrade quietly — it's one trigger among
    // several (button, manual) — not crash or leave a dangling listener.
    _shakeSubscription = accelerometerEventStream().listen(
      (event) {
        _shakeDetector?.addSample(event.x, event.y, event.z, event.timestamp);
      },
      onError: (Object error, StackTrace stackTrace) {
        _stopShake();
      },
      cancelOnError: true,
    );
  }

  void _stopShake() {
    _shakeSubscription?.cancel();
    _shakeSubscription = null;
    _shakeDetector = null;
  }

  /// Opens the reporter. A no-op if it's already open — a shake, a
  /// button tap, or another `.open()` call while the reporter is showing
  /// never spawns a second overlapping instance.
  @visibleForTesting
  Future<void> openReporter({required String trigger}) async {
    if (isOpen) return;

    Uint8List? screenshot;
    var screenshotCaptureFailed = false;
    if (widget.captureScreenshot) {
      screenshot = await ScreenshotCapture.capture(_screenshotBoundaryKey);
      screenshotCaptureFailed = screenshot == null;
    }

    if (!mounted) return;
    _openState.value = _OpenReporterState(
      trigger: trigger,
      screenshot: screenshot,
      screenshotCaptureFailed: screenshotCaptureFailed,
    );
  }

  @visibleForTesting
  void closeReporter() {
    _openState.value = null;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.textDirection ?? TextDirection.ltr,
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              key: _screenshotBoundaryKey,
              child: widget.child,
            ),
          ),
          if (_buttonActive)
            Positioned.fill(
              // The button sits outside the wrapped app's own MaterialApp
              // (it's a sibling Stack layer, not a descendant of
              // widget.child), so there's no ambient MediaQuery to read
              // real notch/status-bar/gesture-nav padding from otherwise.
              // MediaQuery.fromView reads it directly from the platform
              // view, and SafeArea keeps the button's Align+Padding
              // positioning inside that safe region by default.
              child: MediaQuery.fromView(
                view: View.of(context),
                child: SafeArea(
                  child: ValueListenableBuilder<_OpenReporterState?>(
                    valueListenable: _openState,
                    builder: (context, state, _) => state == null
                        ? FloatingTriggerButton(
                            config: widget.floatingButton,
                            onPressed: () => openReporter(trigger: 'button'),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: ValueListenableBuilder<_OpenReporterState?>(
              valueListenable: _openState,
              builder: (context, state, _) => state == null
                  ? const SizedBox.shrink()
                  : MaterialApp(
                      debugShowCheckedModeBanner: false,
                      home: ReporterFlow(
                        trigger: state.trigger,
                        screenshot: state.screenshot,
                        screenshotCaptureFailed: state.screenshotCaptureFailed,
                        onClose: closeReporter,
                        sharePlus: sharePlusOverride,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
