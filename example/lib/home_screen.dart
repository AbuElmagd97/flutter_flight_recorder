import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';
import 'package:flutter_flight_recorder_reporter/flutter_flight_recorder_reporter.dart';

import 'main.dart' show dio;
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _lastAction;

  void _report(String message) {
    if (!mounted) return;
    setState(() => _lastAction = message);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _navigate() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'profile'),
        builder: (_) => const ProfileScreen(),
      ),
    );
  }

  void _recordAction() {
    FlightRecorder.recordAction(
      'save_profile_tapped',
      metadata: {'screen': 'home'},
    );
    _report('Action recorded: save_profile_tapped');
  }

  void _createLog() {
    FlightRecorder.log('Profile update started');
    _report('Log recorded: Profile update started');
  }

  Future<void> _successfulRequest() async {
    try {
      final response = await dio.get('https://httpbin.org/get');
      _report('Request succeeded: HTTP ${response.statusCode}');
    } on DioException catch (e) {
      _report('Request failed: ${e.type.name}');
    }
  }

  Future<void> _failedRequest() async {
    try {
      await dio.get('https://httpbin.org/status/500');
    } on DioException catch (e) {
      _report(
        'Request failed as expected: HTTP ${e.response?.statusCode ?? '?'}',
      );
    }
  }

  void _triggerTestError() {
    // Deliberately uncaught and asynchronous, so it's captured by
    // FlightRecorder's automatic PlatformDispatcher.onError hook (see
    // the core package's README "Automatic error capture") rather than
    // by a manual FlightRecorder.recordError call — the latter is
    // already exercised indirectly by the reporter's own error handling
    // paths, so this button demonstrates the other capture path.
    Future<void>.delayed(Duration.zero, () {
      throw StateError('Test error triggered from example app');
    });
    _report('Uncaught test error thrown (captured automatically)');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('flutter_flight_recorder example')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_lastAction != null) ...[
              Text(
                'Last action: $_lastAction',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
            ],
            ElevatedButton(onPressed: _navigate, child: const Text('Navigate')),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _recordAction,
              child: const Text('Record Action'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _createLog,
              child: const Text('Create Log'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _successfulRequest,
              child: const Text('Successful Request'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _failedRequest,
              child: const Text('Failed Request'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _triggerTestError,
              child: const Text('Trigger Test Error'),
            ),
            const SizedBox(height: 24),
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => FlutterFlightRecorderReporter.open(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
                child: const Text('🐛 Report a Bug'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Or shake the device, or tap the floating button near the '
              'top-right (notch/status bar area) to open the same reporter.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
