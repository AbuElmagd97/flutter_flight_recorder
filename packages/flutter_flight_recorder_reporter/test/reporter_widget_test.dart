import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';
import 'package:flutter_flight_recorder_reporter/flutter_flight_recorder_reporter.dart';
import 'package:flutter_flight_recorder_reporter/src/form/bug_report_form.dart';
import 'package:flutter_flight_recorder_reporter/src/form/severity_selector.dart';
import 'package:flutter_flight_recorder_reporter/src/preview/report_preview_screen.dart';
import 'package:flutter_flight_recorder_reporter/src/triggers/floating_trigger_button.dart';
import 'package:flutter_test/flutter_test.dart';

/// A distinctive marker in the wrapped app content, used to prove the
/// reporter's own UI is a structurally separate layer from it.
const Key appContentKey = Key('app_content_marker');

Widget _appWithReporter({
  ReportTrigger trigger = ReportTrigger.both,
  FloatingButtonConfig floatingButton = const FloatingButtonConfig(),
  ShakeConfig shake = const ShakeConfig(),
  bool captureScreenshot = false,
}) {
  return FlutterFlightRecorderReporter(
    trigger: trigger,
    floatingButton: floatingButton,
    shake: shake,
    captureScreenshot: captureScreenshot,
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          key: appContentKey,
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => FlutterFlightRecorderReporter.open(context),
              child: const Text('Report a bug'),
            ),
          ),
        ),
      ),
    ),
  );
}

FlutterFlightRecorderReporterState _stateOf(WidgetTester tester) {
  return tester.state<FlutterFlightRecorderReporterState>(
    find.byType(FlutterFlightRecorderReporter),
  );
}

/// sensors_plus's two channels used by `accelerometerEventStream()`. No
/// platform implementation is registered in a widget test, so without
/// mocking both, starting the stream (whenever a trigger including shake
/// is active) reports MissingPluginException straight to
/// `FlutterError.reportError` — not through the stream's own error
/// channel, so an `onError` handler on `.listen()` can't catch it (see
/// `EventChannel.receiveBroadcastStream`'s source). `flutter_test` then
/// fails the test. These mocks make both channels' method calls succeed
/// harmlessly instead — the stream just never emits real events, which
/// is fine, since nothing here tests the real sensor.
const MethodChannel _accelerometerEventChannel = MethodChannel(
  'dev.fluttercommunity.plus/sensors/accelerometer',
);
const MethodChannel _sensorsMethodChannel = MethodChannel(
  'dev.fluttercommunity.plus/sensors/method',
);

void main() {
  setUp(() {
    FlightRecorder.init();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [_accelerometerEventChannel, _sensorsMethodChannel]) {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    }
    // The bug report form is taller than the default 800x600 test
    // surface; give tests room to show it all without needing to scroll.
    TestWidgetsFlutterBinding.ensureInitialized();
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.physicalSize = const Size(800, 2000);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    addTearDown(binding.platformDispatcher.views.first.resetPhysicalSize);
    addTearDown(binding.platformDispatcher.views.first.resetDevicePixelRatio);
  });
  tearDown(FlightRecorder.resetForTest);

  group('manual trigger', () {
    testWidgets('.open() opens the bug report form', (tester) async {
      await tester.pumpWidget(_appWithReporter(trigger: ReportTrigger.manual));

      await tester.tap(find.text('Report a bug'));
      await tester.pumpAndSettle();

      expect(find.byType(BugReportForm), findsOneWidget);
    });

    testWidgets('is available even when trigger is manual-only', (
      tester,
    ) async {
      await tester.pumpWidget(_appWithReporter(trigger: ReportTrigger.manual));

      expect(find.byType(FloatingTriggerButton), findsNothing);

      await tester.tap(find.text('Report a bug'));
      await tester.pumpAndSettle();

      expect(find.byType(BugReportForm), findsOneWidget);
    });
  });

  group('floating button trigger', () {
    testWidgets('is shown when trigger is button', (tester) async {
      await tester.pumpWidget(_appWithReporter(trigger: ReportTrigger.button));
      expect(find.byType(FloatingTriggerButton), findsOneWidget);
    });

    testWidgets('is shown when trigger is both', (tester) async {
      await tester.pumpWidget(_appWithReporter(trigger: ReportTrigger.both));
      expect(find.byType(FloatingTriggerButton), findsOneWidget);
    });

    testWidgets('is not shown when trigger is shake-only', (tester) async {
      await tester.pumpWidget(_appWithReporter(trigger: ReportTrigger.shake));
      expect(find.byType(FloatingTriggerButton), findsNothing);
    });

    testWidgets(
      'is not shown when floatingButton.enabled is false, even with trigger both',
      (tester) async {
        await tester.pumpWidget(
          _appWithReporter(
            trigger: ReportTrigger.both,
            floatingButton: const FloatingButtonConfig(enabled: false),
          ),
        );
        expect(find.byType(FloatingTriggerButton), findsNothing);
      },
    );

    testWidgets('tapping it opens the bug report form', (tester) async {
      await tester.pumpWidget(_appWithReporter(trigger: ReportTrigger.button));

      await tester.tap(find.byKey(floatingTriggerButtonKey));
      await tester.pumpAndSettle();

      expect(find.byType(BugReportForm), findsOneWidget);
    });

    testWidgets('is hidden while the reporter is open', (tester) async {
      await tester.pumpWidget(_appWithReporter(trigger: ReportTrigger.button));

      await tester.tap(find.byKey(floatingTriggerButtonKey));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingTriggerButton), findsNothing);
    });

    testWidgets('sits inside a SafeArea, not positioned over system UI', (
      tester,
    ) async {
      await tester.pumpWidget(_appWithReporter(trigger: ReportTrigger.button));

      expect(
        find.ancestor(
          of: find.byKey(floatingTriggerButtonKey),
          matching: find.byType(SafeArea),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'is pushed below a simulated notch/status-bar inset instead of overlapping it',
      (tester) async {
        final binding = TestWidgetsFlutterBinding.instance;
        const topInset = 60.0; // simulated notch/status bar height
        binding.platformDispatcher.views.first.padding = const FakeViewPadding(
          top: topInset,
        );
        addTearDown(binding.platformDispatcher.views.first.resetPadding);

        await tester.pumpWidget(
          _appWithReporter(
            trigger: ReportTrigger.button,
            floatingButton: const FloatingButtonConfig(
              alignment: Alignment.topRight,
              padding: EdgeInsets.zero,
            ),
          ),
        );

        final buttonTop = tester
            .getTopLeft(find.byKey(floatingTriggerButtonKey))
            .dy;

        expect(buttonTop, greaterThanOrEqualTo(topInset));
      },
    );
  });

  group('shake stream setup', () {
    testWidgets(
      'starting the accelerometer stream with a real async round trip '
      'does not throw or fail the test',
      (tester) async {
        // Regression test: found while building the example app.
        // sensors_plus's accelerometer EventChannel reports a failed
        // `invokeMethod('listen', ...)` (no platform implementation
        // registered, e.g. an unsupported platform, or — as happened
        // here — a widget test with nothing mocking the channel)
        // straight to `FlutterError.reportError`, not through the
        // stream's own error channel — so an `onError` handler on
        // `.listen()` alone can't catch it (see
        // `EventChannel.receiveBroadcastStream`'s source). This only
        // ever surfaced under `tester.runAsync` with real elapsed time;
        // plain `pump()`/`pumpAndSettle()` never let the platform-channel
        // Future resolve at all, so it stayed silently dangling.
        //
        // The actual fix is `setUp`'s mock of the accelerometer channel
        // above — this test exists to catch a regression if that mock
        // is ever removed or the channel name changes.
        await tester.pumpWidget(_appWithReporter(trigger: ReportTrigger.both));

        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(FlutterFlightRecorderReporter), findsOneWidget);
      },
    );

    testWidgets('an unsupported platform (accelerometer listen() failing) is '
        'captured by FlightRecorder automatically, not left uncaught', (
      tester,
    ) async {
      // Spec §26 edge case: "Unsupported platform capability." setUp's
      // mock above makes listen() succeed; this test overrides it to
      // fail instead, simulating a platform sensors_plus has no
      // implementation for. Per the doc comment on _maybeStartShake in
      // reporter_widget.dart, a failed initial listen() call is
      // reported by EventChannel straight to FlutterError.reportError,
      // not through the stream's own error channel — the expected,
      // already-decided behavior (Phase 10) is that this gets picked
      // up by FlightRecorder's own automatic error capture, the same
      // as any other uncaught framework error, rather than crashing
      // the app or leaving shake in a broken state that takes the rest
      // of the reporter down with it.
      //
      // flutter_test's own default FlutterError.onError treats any
      // FlutterError.reportError call as a test failure, so — exactly
      // like uncaught_error_capture_test.dart in the core package —
      // this test resets and re-installs a harmless handler before
      // FlightRecorder.init() runs, so FlightRecorder's chain lands on
      // that instead of on flutter_test's failure detector.
      FlightRecorder.resetForTest();
      final savedHandler = FlutterError.onError;
      FlutterError.onError = (details) {};
      addTearDown(() => FlutterError.onError = savedHandler);

      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(_accelerometerEventChannel, (
        call,
      ) async {
        if (call.method == 'listen') {
          throw PlatformException(
            code: 'unavailable',
            message: 'no implementation found',
          );
        }
        return null;
      });

      FlightRecorder.init();
      await tester.pumpWidget(_appWithReporter(trigger: ReportTrigger.both));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();

      // The app keeps working normally — no crash, the floating
      // button (a trigger independent of shake) still opens the
      // reporter.
      expect(find.byType(FloatingTriggerButton), findsOneWidget);
      await tester.tap(find.byKey(floatingTriggerButtonKey));
      await tester.pumpAndSettle();
      expect(find.byType(BugReportForm), findsOneWidget);

      // And the failure itself was captured, not silently lost.
      expect(
        FlightRecorder.debugEvents.any(
          (event) => event.category == EventCategory.error,
        ),
        isTrue,
      );
    });
  });

  group('open/close lifecycle', () {
    testWidgets('closing the form returns to the closed state', (tester) async {
      await tester.pumpWidget(_appWithReporter(trigger: ReportTrigger.manual));

      await tester.tap(find.text('Report a bug'));
      await tester.pumpAndSettle();
      expect(_stateOf(tester).isOpen, isTrue);

      await tester.tap(find.byKey(cancelButtonKey));
      await tester.pumpAndSettle();

      expect(_stateOf(tester).isOpen, isFalse);
      expect(find.byType(BugReportForm), findsNothing);
    });

    testWidgets(
      'opening again while already open never spawns a second instance '
      '(the carried-forward "shake while open" requirement, exercised '
      'directly at the state level since real shakes cannot be simulated)',
      (tester) async {
        await tester.pumpWidget(
          _appWithReporter(trigger: ReportTrigger.manual),
        );
        final state = _stateOf(tester);

        // Two "shakes" in quick succession, exactly what the shake
        // detector's onShake callback would trigger.
        final first = state.openReporter(trigger: 'shake');
        final second = state.openReporter(trigger: 'shake');
        await Future.wait([first, second]);
        await tester.pumpAndSettle();

        expect(find.byType(BugReportForm), findsOneWidget);
        // Exactly one form, not two overlapping instances.
        expect(
          find.byType(MaterialApp),
          findsNWidgets(2),
        ); // app's own + reporter's own
      },
    );

    testWidgets('manual .open() is also a no-op while already open', (
      tester,
    ) async {
      await tester.pumpWidget(_appWithReporter(trigger: ReportTrigger.manual));
      final state = _stateOf(tester);

      await state.openReporter(trigger: 'manual');
      await tester.pumpAndSettle();
      expect(state.isOpen, isTrue);

      // A second manual open while already open must not throw or
      // duplicate the flow.
      await state.openReporter(trigger: 'manual');
      await tester.pumpAndSettle();

      expect(find.byType(BugReportForm), findsOneWidget);
    });
  });

  group('screenshot self-capture ordering', () {
    testWidgets("the reporter's own UI is never a descendant of the screenshot "
        'boundary — proving it structurally cannot capture itself, '
        'regardless of timing', (tester) async {
      await tester.pumpWidget(
        _appWithReporter(
          trigger: ReportTrigger.manual,
          captureScreenshot: true,
        ),
      );
      final state = _stateOf(tester);

      await tester.runAsync(() => state.openReporter(trigger: 'manual'));
      await tester.pumpAndSettle();

      expect(find.byType(BugReportForm), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(state.screenshotBoundaryKey),
          matching: find.byType(BugReportForm),
        ),
        findsNothing,
      );
      // The app's own marker content, in contrast, IS inside the
      // boundary — confirming the boundary scopes real app content.
      expect(
        find.descendant(
          of: find.byKey(state.screenshotBoundaryKey),
          matching: find.byKey(appContentKey),
        ),
        findsOneWidget,
      );
    });

    testWidgets('capture completes before the form is shown, not after', (
      tester,
    ) async {
      await tester.pumpWidget(
        _appWithReporter(
          trigger: ReportTrigger.manual,
          captureScreenshot: true,
        ),
      );
      final state = _stateOf(tester);

      // Start opening but do not let the pending screenshot future or
      // subsequent frames settle yet.
      final future = tester.runAsync(
        () => state.openReporter(trigger: 'manual'),
      );

      expect(state.isOpen, isFalse);
      expect(find.byType(BugReportForm), findsNothing);

      await future;
      await tester.pumpAndSettle();

      expect(state.isOpen, isTrue);
      expect(find.byType(BugReportForm), findsOneWidget);
    });
  });

  group('end-to-end flow', () {
    testWidgets(
      'open -> fill form -> submit -> preview creates a real incident',
      (tester) async {
        FlightRecorder.recordAction('save_profile_tapped');

        await tester.pumpWidget(
          _appWithReporter(trigger: ReportTrigger.manual),
        );

        await tester.tap(find.text('Report a bug'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(whatHappenedFieldKey),
          'Profile update failed',
        );
        await tester.tap(find.byKey(severityOptionKey(IncidentSeverity.high)));
        await tester.pump();
        await tester.tap(find.byKey(createReportButtonKey));
        await tester.pumpAndSettle();

        expect(find.byKey(bugStoryTextKey), findsOneWidget);
        expect(find.textContaining('INC-'), findsOneWidget);
      },
    );
  });
}
