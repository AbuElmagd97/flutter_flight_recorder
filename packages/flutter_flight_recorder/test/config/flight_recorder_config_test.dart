import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlightRecorderConfig', () {
    test('defaults to enabled with a 500-event buffer and all categories', () {
      const config = FlightRecorderConfig();

      expect(config.enabled, isTrue);
      expect(config.maxEvents, 500);
      expect(config.captureUncaughtErrors, isTrue);
      for (final category in EventCategory.values) {
        expect(config.isCategoryEnabled(category), isTrue);
      }
    });

    test('rejects a non-positive maxEvents', () {
      expect(
        () => FlightRecorderConfig(maxEvents: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('restricts recording to the given categories when provided', () {
      const config = FlightRecorderConfig(
        enabledCategories: {EventCategory.action, EventCategory.log},
      );

      expect(config.isCategoryEnabled(EventCategory.action), isTrue);
      expect(config.isCategoryEnabled(EventCategory.log), isTrue);
      expect(config.isCategoryEnabled(EventCategory.network), isFalse);
    });
  });

  group('PrivacyConfig', () {
    test('defaults to the built-in sensitive key set', () {
      const config = PrivacyConfig();
      expect(config.sensitiveKeys, contains('password'));
      expect(config.customSanitizer, isNull);
    });
  });
}
