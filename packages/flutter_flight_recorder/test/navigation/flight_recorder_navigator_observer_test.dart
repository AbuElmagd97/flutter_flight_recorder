import 'package:flutter/material.dart';
import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _appWithRoutes() {
  return MaterialApp(
    navigatorObservers: [FlightRecorderNavigatorObserver()],
    initialRoute: '/',
    routes: {
      '/': (_) => const Scaffold(body: Text('Home')),
      '/profile': (_) => const Scaffold(body: Text('Profile')),
    },
  );
}

void main() {
  setUp(() => FlightRecorder.init());
  tearDown(FlightRecorder.resetForTest);

  testWidgets('records the initial route push', (tester) async {
    await tester.pumpWidget(_appWithRoutes());

    final events = FlightRecorder.debugEvents.where(
      (e) => e.category == EventCategory.navigation,
    );
    expect(events, isNotEmpty);
    expect(events.first.name, '/');
    expect(events.first.metadata['action'], 'push');
  });

  testWidgets('records a push to a named route with the previous route', (
    tester,
  ) async {
    await tester.pumpWidget(_appWithRoutes());
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed('/profile');
    await tester.pumpAndSettle();

    final pushEvents = FlightRecorder.debugEvents.where(
      (e) =>
          e.category == EventCategory.navigation &&
          e.metadata['action'] == 'push',
    );
    final profilePush = pushEvents.last;
    expect(profilePush.name, '/profile');
    expect(profilePush.metadata['from'], '/');
  });

  testWidgets('records a pop', (tester) async {
    await tester.pumpWidget(_appWithRoutes());
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed('/profile');
    await tester.pumpAndSettle();

    navigator.pop();
    await tester.pumpAndSettle();

    final popEvents = FlightRecorder.debugEvents.where(
      (e) =>
          e.category == EventCategory.navigation &&
          e.metadata['action'] == 'pop',
    );
    expect(popEvents, isNotEmpty);
    expect(popEvents.last.name, '/profile');
  });

  testWidgets('falls back to the unnamed route label for unnamed routes', (
    tester,
  ) async {
    await tester.pumpWidget(_appWithRoutes());
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Unnamed'))),
    );
    await tester.pumpAndSettle();

    final pushEvents = FlightRecorder.debugEvents.where(
      (e) =>
          e.category == EventCategory.navigation &&
          e.metadata['action'] == 'push',
    );
    expect(pushEvents.last.name, '<unnamed>');
  });

  testWidgets('does not capture route arguments', (tester) async {
    await tester.pumpWidget(_appWithRoutes());
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed('/profile', arguments: {'password': 'hunter2'});
    await tester.pumpAndSettle();

    final json =
        FlightRecorder.debugEvents.map((e) => e.toJson().toString()).join();
    expect(json, isNot(contains('hunter2')));
  });

  testWidgets('records nothing before FlightRecorder.init() is called', (
    tester,
  ) async {
    FlightRecorder.resetForTest(); // undo setUp's init() for this one test
    await tester.pumpWidget(_appWithRoutes());

    expect(FlightRecorder.isInitialized, isFalse);
    // No assertion error thrown by pumping — that's the behavior under test.
  });

  testWidgets('rapid navigation is all recorded', (tester) async {
    await tester.pumpWidget(_appWithRoutes());
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));

    for (var i = 0; i < 10; i++) {
      navigator.pushNamed('/profile');
    }
    await tester.pumpAndSettle();

    final pushEvents = FlightRecorder.debugEvents.where(
      (e) =>
          e.category == EventCategory.navigation &&
          e.metadata['action'] == 'push',
    );
    expect(pushEvents.length, greaterThanOrEqualTo(10));
  });
}
