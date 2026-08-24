import 'package:flutter/foundation.dart';
import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(FlightRecorder.resetForTest);

  group('automatic uncaught error capture', () {
    test(
        'records a FlutterError.onError call and chains to the previous handler',
        () {
      var previousCalled = false;
      FlutterErrorDetails? previousDetails;
      final savedHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        previousCalled = true;
        previousDetails = details;
      };

      FlightRecorder.init();

      final details = FlutterErrorDetails(
        exception: StateError('boom'),
        stack: StackTrace.current,
        library: 'my_lib',
      );
      FlutterError.onError!(details);

      expect(previousCalled, isTrue);
      expect(previousDetails, details);
      expect(FlightRecorder.debugEvents, hasLength(1));
      final event = FlightRecorder.debugEvents.single;
      expect(event.category, EventCategory.error);
      expect(event.metadata['library'], 'my_lib');

      FlutterError.onError = savedHandler;
    });

    test(
        'records a PlatformDispatcher.onError call and chains to the previous handler',
        () {
      var previousCalled = false;
      final savedHandler = PlatformDispatcher.instance.onError;
      PlatformDispatcher.instance.onError = (error, stack) {
        previousCalled = true;
        return true;
      };

      FlightRecorder.init();

      final handled = PlatformDispatcher.instance.onError!(
        StateError('boom'),
        StackTrace.current,
      );

      expect(previousCalled, isTrue);
      expect(handled, isTrue);
      expect(FlightRecorder.debugEvents, hasLength(1));
      expect(FlightRecorder.debugEvents.single.category, EventCategory.error);

      PlatformDispatcher.instance.onError = savedHandler;
    });

    test('does not record when captureUncaughtErrors is false', () {
      final savedHandler = FlutterError.onError;
      FlightRecorder.init(
        const FlightRecorderConfig(captureUncaughtErrors: false),
      );

      FlutterError.onError!(
        FlutterErrorDetails(exception: StateError('boom')),
      );

      expect(FlightRecorder.debugEvents, isEmpty);
      FlutterError.onError = savedHandler;
    });

    test(
      'reinitializing does not duplicate recording across repeated installs',
      () {
        final savedFlutterHandler = FlutterError.onError;
        var previousCallCount = 0;
        FlutterError.onError = (details) => previousCallCount++;

        FlightRecorder.init();
        FlightRecorder.init(); // simulate hot-restart style re-init

        FlutterError
            .onError!(FlutterErrorDetails(exception: StateError('boom')));

        // Exactly one recorded event and exactly one call through to the
        // real previous handler — not one per install() call.
        expect(FlightRecorder.debugEvents, hasLength(1));
        expect(previousCallCount, 1);

        FlutterError.onError = savedFlutterHandler;
      },
    );

    test('resetForTest restores the handlers that were present before init()',
        () {
      final savedHandler = FlutterError.onError;
      void marker(FlutterErrorDetails details) {}
      FlutterError.onError = marker;

      FlightRecorder.init();
      expect(FlutterError.onError, isNot(same(marker)));

      FlightRecorder.resetForTest();
      expect(FlutterError.onError, same(marker));

      FlutterError.onError = savedHandler;
    });
  });
}
