import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';

void main() {
  FlightRecorder.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [FlightRecorderNavigatorObserver()],
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _simulateActivity() {
    FlightRecorder.recordAction('button_tapped', metadata: {'screen': 'home'});
    FlightRecorder.log('User tapped the demo button');

    final incident = FlightRecorder.createIncident(title: 'Demo incident');
    // jsonEncode just makes the output readable in your terminal.
    debugPrint(jsonEncode(incident.toJson()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('flutter_flight_recorder example')),
      body: Center(
        child: ElevatedButton(
          onPressed: _simulateActivity,
          child: const Text('Record activity and create an incident'),
        ),
      ),
    );
  }
}
