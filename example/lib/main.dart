import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';
import 'package:flutter_flight_recorder_dio/flutter_flight_recorder_dio.dart';
import 'package:flutter_flight_recorder_reporter/flutter_flight_recorder_reporter.dart';

import 'home_screen.dart';

/// Shared Dio instance with the flight recorder interceptor attached.
/// httpbin.org is a well-known, widely-used HTTP testing service —
/// appropriate for demonstrating a real success/failure request without
/// standing up a backend for this example.
final Dio dio = Dio()..interceptors.add(FlightRecorderDioInterceptor());

void main() {
  FlightRecorder.init();
  // App version/build number aren't auto-captured by the core package
  // (see its README) — this is the documented way to add them yourself.
  FlightRecorder.setContext('environment', 'example');
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FlutterFlightRecorderReporter(
      // Shake AND the floating button are both active; the manual
      // .open() call ("Report a Bug" on the home screen) always works
      // regardless of this setting.
      trigger: ReportTrigger.both,
      floatingButton: const FloatingButtonConfig(
        // Deliberately placed where a notch / Dynamic Island / status
        // bar commonly sits, so the SafeArea fix is easy to confirm on a
        // real device: the button should sit clearly below system UI,
        // never overlapping it.
        alignment: Alignment.topRight,
      ),
      child: MaterialApp(
        title: 'flutter_flight_recorder example',
        navigatorObservers: [FlightRecorderNavigatorObserver()],
        home: const HomeScreen(),
      ),
    );
  }
}
