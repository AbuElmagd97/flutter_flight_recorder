import 'dart:convert';

import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

FlightEvent _event(
  EventCategory category,
  String name, {
  Map<String, Object?> metadata = const {},
}) {
  return FlightEvent(
    id: name,
    timestamp: DateTime.utc(2026, 1, 1, 12),
    category: category,
    name: name,
    metadata: metadata,
  );
}

void main() {
  group('Incident', () {
    test('carries the fields it was constructed with', () {
      final timestamp = DateTime.utc(2026, 1, 1);
      final incident = Incident(
        id: 'INC-ABCDEF',
        timestamp: timestamp,
        title: 'Profile update failed',
        description: 'Unable to save profile changes.',
        qaReport: const QaReportData(severity: IncidentSeverity.high),
        trigger: 'manual',
        timeline: const [],
        context: const {'platform': 'android'},
      );

      expect(incident.id, 'INC-ABCDEF');
      expect(incident.timestamp, timestamp);
      expect(incident.title, 'Profile update failed');
      expect(incident.description, 'Unable to save profile changes.');
      expect(incident.qaReport?.severity, IncidentSeverity.high);
      expect(incident.trigger, 'manual');
      expect(incident.context, {'platform': 'android'});
    });

    test('description, qaReport and trigger are optional', () {
      final incident = Incident(
        id: 'INC-ABCDEF',
        timestamp: DateTime.utc(2026, 1, 1),
        title: 'Something broke',
        timeline: const [],
        context: const {},
      );

      expect(incident.description, isNull);
      expect(incident.qaReport, isNull);
      expect(incident.trigger, isNull);
    });

    test('timeline is immutable', () {
      final incident = Incident(
        id: 'INC-ABCDEF',
        timestamp: DateTime.utc(2026, 1, 1),
        title: 'x',
        timeline: [_event(EventCategory.action, 'tapped')],
        context: const {},
      );

      expect(() => incident.timeline.add(_event(EventCategory.log, 'y')),
          throwsUnsupportedError);
    });

    test('context is immutable', () {
      final incident = Incident(
        id: 'INC-ABCDEF',
        timestamp: DateTime.utc(2026, 1, 1),
        title: 'x',
        timeline: const [],
        context: const {'platform': 'android'},
      );

      expect(
          () => incident.context['platform'] = 'ios', throwsUnsupportedError);
    });

    test('is unaffected by later mutation of the lists it was built from', () {
      final sourceTimeline = [_event(EventCategory.action, 'first')];
      final sourceContext = {'platform': 'android'};

      final incident = Incident(
        id: 'INC-ABCDEF',
        timestamp: DateTime.utc(2026, 1, 1),
        title: 'x',
        timeline: sourceTimeline,
        context: sourceContext,
      );

      sourceTimeline.add(_event(EventCategory.action, 'second'));
      sourceContext['platform'] = 'ios';

      expect(incident.timeline, hasLength(1));
      expect(incident.context['platform'], 'android');
    });

    test('latestError returns the most recently recorded error event', () {
      final incident = Incident(
        id: 'INC-ABCDEF',
        timestamp: DateTime.utc(2026, 1, 1),
        title: 'x',
        timeline: [
          _event(EventCategory.error, 'first_error'),
          _event(EventCategory.action, 'tapped'),
          _event(EventCategory.error, 'second_error'),
        ],
        context: const {},
      );

      expect(incident.latestError?.name, 'second_error');
    });

    test('latestError is null when there are no error events', () {
      final incident = Incident(
        id: 'INC-ABCDEF',
        timestamp: DateTime.utc(2026, 1, 1),
        title: 'x',
        timeline: [_event(EventCategory.action, 'tapped')],
        context: const {},
      );

      expect(incident.latestError, isNull);
    });

    test('navigationHistory, networkEvents and logs filter by category', () {
      final incident = Incident(
        id: 'INC-ABCDEF',
        timestamp: DateTime.utc(2026, 1, 1),
        title: 'x',
        timeline: [
          _event(EventCategory.navigation, 'ProfileScreen'),
          _event(EventCategory.network, 'PATCH /profile'),
          _event(EventCategory.log, 'Profile update started'),
          _event(EventCategory.action, 'save_profile_tapped'),
        ],
        context: const {},
      );

      expect(incident.navigationHistory.single.name, 'ProfileScreen');
      expect(incident.networkEvents.single.name, 'PATCH /profile');
      expect(incident.logs.single.name, 'Profile update started');
    });

    test('normalizes a non-JSON-safe trigger instead of storing it raw', () {
      final incident = Incident(
        id: 'INC-ABCDEF',
        timestamp: DateTime.utc(2026, 1, 1),
        title: 'x',
        trigger: _NotSerializable(),
        timeline: const [],
        context: const {},
      );

      expect(incident.trigger, isA<String>());
      expect(incident.trigger, contains('NotSerializable'));
    });

    group('toJson', () {
      test('includes the minimum required fields', () {
        final timestamp = DateTime.utc(2026, 1, 1, 12);
        final incident = Incident(
          id: 'INC-ABCDEF',
          timestamp: timestamp,
          title: 'Profile update failed',
          timeline: const [],
          context: const {'platform': 'android'},
        );

        final json = incident.toJson();
        expect(json['schema_version'], incidentSchemaVersion);
        expect(json['incident_id'], 'INC-ABCDEF');
        expect(json['timestamp'], timestamp.toIso8601String());
        expect(json['title'], 'Profile update failed');
        expect(json['timeline'], isEmpty);
        expect(json['context'], {'platform': 'android'});
      });

      test('omits optional fields that were never set', () {
        final incident = Incident(
          id: 'INC-ABCDEF',
          timestamp: DateTime.utc(2026, 1, 1),
          title: 'x',
          timeline: const [],
          context: const {},
        );

        final json = incident.toJson();
        expect(json.containsKey('description'), isFalse);
        expect(json.containsKey('qa_report'), isFalse);
        expect(json.containsKey('trigger'), isFalse);
        expect(json.containsKey('error'), isFalse);
      });

      test('includes qa_report, trigger and error when present', () {
        final incident = Incident(
          id: 'INC-ABCDEF',
          timestamp: DateTime.utc(2026, 1, 1),
          title: 'x',
          qaReport: const QaReportData(severity: IncidentSeverity.high),
          trigger: 'manual',
          timeline: [_event(EventCategory.error, 'DioException')],
          context: const {},
        );

        final json = incident.toJson();
        expect(json['qa_report'], {'severity': 'high'});
        expect(json['trigger'], 'manual');
        expect((json['error'] as Map)['name'], 'DioException');
      });

      test('the whole map is encodable by dart:convert', () {
        final incident = Incident(
          id: 'INC-ABCDEF',
          timestamp: DateTime.utc(2026, 1, 1),
          title: 'x',
          qaReport: const QaReportData(expected: 'a', actual: 'b'),
          trigger: 'manual',
          timeline: [
            _event(EventCategory.error, 'DioException',
                metadata: {'status': 422}),
          ],
          context: const {'platform': 'android'},
        );

        expect(() => jsonEncode(incident.toJson()), returnsNormally);
      });
    });
  });
}

class _NotSerializable {
  @override
  String toString() => 'NotSerializable instance';
}
