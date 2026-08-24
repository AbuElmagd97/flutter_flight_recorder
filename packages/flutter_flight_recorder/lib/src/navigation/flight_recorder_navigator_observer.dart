import 'package:flutter/widgets.dart';

import '../recorder/flight_recorder.dart';

const String unnamedRouteLabel = '<unnamed>';

/// Records navigation transitions using Navigator 1.x's observer
/// mechanism.
///
/// ```dart
/// MaterialApp(
///   navigatorObservers: [FlightRecorderNavigatorObserver()],
///   ...
/// )
/// ```
///
/// Only route names are recorded (falling back to [unnamedRouteLabel]
/// when a route has no name) — route arguments are never captured, even
/// if present on `route.settings.arguments`.
///
/// Navigation can happen before [FlightRecorder.init] has run (routes
/// can be pushed while the widget tree is first built, ahead of
/// wherever an app calls `init`). Unlike the recording methods meant to
/// be called directly by application code, this observer treats that as
/// expected rather than a mistake: it silently does nothing until
/// [FlightRecorder.isInitialized], instead of raising a debug assertion.
///
/// This class has no route-filtering hook today. A later phase (the QA
/// reporter) will need its own internal navigation — for showing a
/// screenshot preview, the bug report form, etc. — excluded from a real
/// user's navigation history. If that turns out to require filtering
/// here rather than being handled by, e.g., an [Overlay] instead of
/// [Navigator] routes, the natural extension point is an optional
/// `bool Function(Route<dynamic> route)? ignoreRoute` constructor
/// parameter, checked at the top of [_record].
class FlightRecorderNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _record('push', route, previousRoute);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _record('pop', route, previousRoute);
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _record('replace', newRoute, oldRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _record('remove', route, previousRoute);
    super.didRemove(route, previousRoute);
  }

  void _record(
    String action,
    Route<dynamic>? route,
    Route<dynamic>? previousRoute,
  ) {
    if (!FlightRecorder.isInitialized) return;
    FlightRecorder.recordNavigation(
      _routeName(route),
      previousRouteName:
          previousRoute == null ? null : _routeName(previousRoute),
      action: action,
    );
  }

  String _routeName(Route<dynamic>? route) =>
      route?.settings.name ?? unnamedRouteLabel;
}
