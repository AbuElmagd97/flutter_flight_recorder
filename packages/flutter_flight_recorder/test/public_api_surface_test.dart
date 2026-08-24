import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards against symbols the README/other packages document or depend on
/// silently falling out of the public barrel export (as happened with
/// `defaultSensitiveKeys`, found while building the Dio interceptor — it
/// was used as a documented default value but not actually exported).
void main() {
  test('defaultSensitiveKeys is part of the public API', () {
    expect(defaultSensitiveKeys, contains('password'));
  });
}
