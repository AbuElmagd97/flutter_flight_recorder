import 'package:example/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

/// sensors_plus's two channels, used because the example enables the
/// shake trigger (`ReportTrigger.both`). No platform implementation is
/// registered in a widget test — see the reporter package's own
/// reporter_widget_test.dart for the full explanation of why this is
/// needed and why an onError handler alone can't cover it.
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
    // The home screen's button list is taller than the default 800x600
    // test surface.
    TestWidgetsFlutterBinding.ensureInitialized();
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.physicalSize = const Size(800, 1600);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    addTearDown(binding.platformDispatcher.views.first.resetPhysicalSize);
    addTearDown(binding.platformDispatcher.views.first.resetDevicePixelRatio);
  });
  tearDown(FlightRecorder.resetForTest);

  testWidgets('home screen renders all demo actions', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    expect(find.text('Navigate'), findsOneWidget);
    expect(find.text('Record Action'), findsOneWidget);
    expect(find.text('Create Log'), findsOneWidget);
    expect(find.text('Successful Request'), findsOneWidget);
    expect(find.text('Failed Request'), findsOneWidget);
    expect(find.text('Trigger Test Error'), findsOneWidget);
    expect(find.text('🐛 Report a Bug'), findsOneWidget);
  });

  testWidgets('Report a Bug opens the reporter form', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    // The example leaves captureScreenshot at its default (true), and
    // RenderRepaintBoundary.toImage() does real async engine work that
    // fake-async pump() calls don't drive forward. The tap's onPressed
    // fires openReporter() without this test awaiting it directly (it's
    // a plain VoidCallback), so runAsync alone isn't enough — give the
    // detached Future real wall-clock time to finish inside the real
    // async zone before pumping (same underlying fix as the reporter
    // package's own screenshot tests, adapted since this test drives it
    // through the UI rather than calling the state method directly).
    await tester.runAsync(() async {
      await tester.tap(find.text('🐛 Report a Bug'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(find.text('🐛 Report a Problem'), findsOneWidget);
  });

  testWidgets('Record Action adds an event to the timeline', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    await tester.tap(find.text('Record Action'));
    await tester.pump();

    expect(FlightRecorder.debugEvents, isNotEmpty);
    expect(FlightRecorder.debugEvents.last.name, 'save_profile_tapped');
  });

  testWidgets('Navigate pushes the profile screen and records it', (
    tester,
  ) async {
    await tester.pumpWidget(const ExampleApp());

    await tester.tap(find.text('Navigate'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Profile'), findsOneWidget);
    expect(
      FlightRecorder.debugEvents.any(
        (e) => e.category == EventCategory.navigation && e.name == 'profile',
      ),
      isTrue,
    );
  });
}
