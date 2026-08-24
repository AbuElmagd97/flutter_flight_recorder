import 'package:flutter/widgets.dart';
import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(FlightRecorder.resetForTest);

  test('records a lifecycle state change after init()', () {
    FlightRecorder.init();
    final observer = FlightRecorderLifecycleObserver();

    observer.didChangeAppLifecycleState(AppLifecycleState.paused);

    final events = FlightRecorder.debugEvents.where(
      (e) => e.category == EventCategory.lifecycle,
    );
    expect(events, hasLength(1));
    expect(events.single.name, 'paused');
  });

  test('records each distinct lifecycle state by name', () {
    FlightRecorder.init();
    final observer = FlightRecorderLifecycleObserver();

    for (final state in AppLifecycleState.values) {
      observer.didChangeAppLifecycleState(state);
    }

    final names = FlightRecorder.debugEvents
        .where((e) => e.category == EventCategory.lifecycle)
        .map((e) => e.name)
        .toSet();
    expect(names, AppLifecycleState.values.map((s) => s.name).toSet());
  });

  test('does nothing before FlightRecorder.init() is called', () {
    final observer = FlightRecorderLifecycleObserver();

    expect(
      () => observer.didChangeAppLifecycleState(AppLifecycleState.resumed),
      returnsNormally,
    );
    expect(FlightRecorder.isInitialized, isFalse);
  });
}
