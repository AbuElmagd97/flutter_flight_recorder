import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlightEvent', () {
    test('stores the fields it was constructed with', () {
      final timestamp = DateTime(2026, 1, 1, 12, 0);
      final event = FlightEvent(
        id: 'evt-1',
        timestamp: timestamp,
        category: EventCategory.action,
        name: 'save_profile_tapped',
        metadata: {'screen': 'edit_profile'},
        severity: EventSeverity.info,
      );

      expect(event.id, 'evt-1');
      expect(event.timestamp, timestamp);
      expect(event.category, EventCategory.action);
      expect(event.name, 'save_profile_tapped');
      expect(event.metadata, {'screen': 'edit_profile'});
      expect(event.severity, EventSeverity.info);
    });

    test('supports all required categories', () {
      expect(
        EventCategory.values,
        containsAll(<EventCategory>[
          EventCategory.navigation,
          EventCategory.network,
          EventCategory.action,
          EventCategory.log,
          EventCategory.error,
          EventCategory.lifecycle,
        ]),
      );
    });

    test('metadata is immutable', () {
      final event = FlightEvent(
        id: 'evt-1',
        timestamp: DateTime.now(),
        category: EventCategory.log,
        name: 'hello',
        metadata: {'a': 1},
      );

      expect(() => event.metadata['a'] = 2, throwsUnsupportedError);
    });

    test('severity is optional', () {
      final event = FlightEvent(
        id: 'evt-1',
        timestamp: DateTime.now(),
        category: EventCategory.navigation,
        name: 'ProfileScreen',
      );

      expect(event.severity, isNull);
      expect(event.toJson().containsKey('severity'), isFalse);
    });

    test('toJson produces a serializable map', () {
      final timestamp = DateTime.utc(2026, 1, 1, 12, 0);
      final event = FlightEvent(
        id: 'evt-1',
        timestamp: timestamp,
        category: EventCategory.error,
        name: 'DioException',
        metadata: {'status': 422},
        severity: EventSeverity.error,
      );

      expect(event.toJson(), {
        'id': 'evt-1',
        'timestamp': timestamp.toIso8601String(),
        'category': 'error',
        'name': 'DioException',
        'metadata': {'status': 422},
        'severity': 'error',
      });
    });

    test('correlationId is null by default and omitted from toJson', () {
      final event = FlightEvent(
        id: 'evt-1',
        timestamp: DateTime.now(),
        category: EventCategory.action,
        name: 'save_tapped',
      );

      expect(event.correlationId, isNull);
      expect(event.toJson().containsKey('correlation_id'), isFalse);
    });

    test('correlationId is stored and included in toJson when set', () {
      final event = FlightEvent(
        id: 'evt-1',
        timestamp: DateTime.now(),
        category: EventCategory.action,
        name: 'save_tapped',
        correlationId: 'COR-ABCDEF',
      );

      expect(event.correlationId, 'COR-ABCDEF');
      expect(event.toJson()['correlation_id'], 'COR-ABCDEF');
    });

    test(
      'correlationId is separate from metadata — never merged into it',
      () {
        final event = FlightEvent(
          id: 'evt-1',
          timestamp: DateTime.now(),
          category: EventCategory.action,
          name: 'save_tapped',
          metadata: const {'screen': 'edit_profile'},
          correlationId: 'COR-ABCDEF',
        );

        expect(event.metadata, {'screen': 'edit_profile'});
        expect(event.metadata.containsKey('correlationId'), isFalse);
        expect(event.metadata.containsKey('correlation_id'), isFalse);
      },
    );

    test(
        'an oversized correlationId is truncated, same as any other recorded string',
        () {
      final oversized = 'x' * 3000;
      final event = FlightEvent(
        id: 'evt-1',
        timestamp: DateTime.now(),
        category: EventCategory.action,
        name: 'save_tapped',
        correlationId: oversized,
      );

      expect(event.correlationId!.length, lessThan(oversized.length));
    });
  });
}
