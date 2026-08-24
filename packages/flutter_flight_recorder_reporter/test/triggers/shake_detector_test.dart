import 'package:flutter_flight_recorder_reporter/src/config/shake_config.dart';
import 'package:flutter_flight_recorder_reporter/src/triggers/shake_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShakeDetector', () {
    test('does nothing while acceleration stays near gravity', () {
      var shakeCount = 0;
      final detector = ShakeDetector(
        config: const ShakeConfig(),
        onShake: () => shakeCount++,
      );

      // Roughly resting: gravity split across axes, magnitude ~9.8.
      detector.addSample(0, 0, gravityMagnitude, DateTime(2026));
      detector.addSample(0.1, 0.05, gravityMagnitude - 0.05, DateTime(2026));

      expect(shakeCount, 0);
    });

    test('fires when acceleration exceeds the threshold', () {
      var shakeCount = 0;
      final detector = ShakeDetector(
        config: const ShakeConfig(threshold: 15),
        onShake: () => shakeCount++,
      );

      // Magnitude far above gravity + threshold.
      detector.addSample(30, 0, 0, DateTime(2026));

      expect(shakeCount, 1);
    });

    test('does not fire for a deviation under the threshold', () {
      var shakeCount = 0;
      final detector = ShakeDetector(
        config: const ShakeConfig(threshold: 15),
        onShake: () => shakeCount++,
      );

      // Magnitude ~ gravity + 10, under the threshold of 15.
      detector.addSample(0, 0, gravityMagnitude + 10, DateTime(2026));

      expect(shakeCount, 0);
    });

    test('debounces repeated shakes within minTimeBetweenShakes', () {
      var shakeCount = 0;
      final detector = ShakeDetector(
        config: const ShakeConfig(minTimeBetweenShakes: Duration(seconds: 1)),
        onShake: () => shakeCount++,
      );

      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      detector.addSample(30, 0, 0, t0);
      detector.addSample(30, 0, 0, t0.add(const Duration(milliseconds: 500)));
      detector.addSample(30, 0, 0, t0.add(const Duration(milliseconds: 900)));

      expect(shakeCount, 1);
    });

    test('fires again once minTimeBetweenShakes has elapsed', () {
      var shakeCount = 0;
      final detector = ShakeDetector(
        config: const ShakeConfig(minTimeBetweenShakes: Duration(seconds: 1)),
        onShake: () => shakeCount++,
      );

      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      detector.addSample(30, 0, 0, t0);
      detector.addSample(30, 0, 0, t0.add(const Duration(seconds: 2)));

      expect(shakeCount, 2);
    });

    test('never fires when disabled', () {
      var shakeCount = 0;
      final detector = ShakeDetector(
        config: const ShakeConfig(enabled: false),
        onShake: () => shakeCount++,
      );

      detector.addSample(50, 50, 50, DateTime(2026));

      expect(shakeCount, 0);
    });

    test('a higher threshold requires a more vigorous shake', () {
      var shakeCount = 0;
      final detector = ShakeDetector(
        config: const ShakeConfig(threshold: 25),
        onShake: () => shakeCount++,
      );

      detector.addSample(20, 0, 0, DateTime(2026)); // deviation ~10, under 25
      expect(shakeCount, 0);

      detector.addSample(40, 0, 0, DateTime(2026)); // deviation ~30, over 25
      expect(shakeCount, 1);
    });
  });
}
