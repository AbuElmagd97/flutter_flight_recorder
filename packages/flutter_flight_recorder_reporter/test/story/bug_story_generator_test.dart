import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';
import 'package:flutter_flight_recorder_reporter/src/story/bug_story_generator.dart';
import 'package:flutter_test/flutter_test.dart';

FlightEvent _event(
  EventCategory category,
  String name, {
  Map<String, Object?> metadata = const {},
}) {
  return FlightEvent(
    id: name,
    timestamp: DateTime.utc(2026, 1, 1),
    category: category,
    name: name,
    metadata: metadata,
  );
}

Incident _incidentWith(List<FlightEvent> timeline) {
  return Incident(
    id: 'INC-000000',
    timestamp: DateTime.utc(2026, 1, 1),
    title: 'x',
    timeline: timeline,
    context: const {},
  );
}

void main() {
  group('BugStoryGenerator', () {
    test('is honest when there are no events', () {
      final story = BugStoryGenerator.generate(_incidentWith(const []));
      expect(story, 'No events were recorded before this incident.');
    });

    test('describes a navigation push using the route name', () {
      final story = BugStoryGenerator.generate(
        _incidentWith([
          _event(
            EventCategory.navigation,
            'edit_profile',
            metadata: {'action': 'push'},
          ),
        ]),
      );
      expect(story, contains('The user opened the edit profile screen.'));
    });

    test('falls back to "app" for the root/unnamed route', () {
      final story = BugStoryGenerator.generate(
        _incidentWith([
          _event(EventCategory.navigation, '/', metadata: {'action': 'push'}),
        ]),
      );
      expect(story, contains('The user opened the app screen.'));
    });

    test('describes a navigation pop', () {
      final story = BugStoryGenerator.generate(
        _incidentWith([
          _event(
            EventCategory.navigation,
            'profile',
            metadata: {'action': 'pop'},
          ),
        ]),
      );
      expect(
        story,
        contains('The user navigated back from the profile screen.'),
      );
    });

    test('describes an action with underscores replaced by spaces', () {
      final story = BugStoryGenerator.generate(
        _incidentWith([_event(EventCategory.action, 'save_profile_tapped')]),
      );
      expect(story, contains("The user tapped 'save profile tapped'."));
    });

    test('describes a successful network request with duration', () {
      final story = BugStoryGenerator.generate(
        _incidentWith([
          _event(
            EventCategory.network,
            'PATCH /profile',
            metadata: {
              'method': 'PATCH',
              'url': '/profile',
              'statusCode': 200,
              'durationMs': 500,
            },
          ),
        ]),
      );
      expect(
        story,
        contains('The application sent a PATCH request to /profile.'),
      );
      expect(
        story,
        contains('The request completed with HTTP 200 after 0.5 seconds.'),
      );
    });

    test('describes a failed network request', () {
      final story = BugStoryGenerator.generate(
        _incidentWith([
          _event(
            EventCategory.network,
            'PATCH /profile',
            metadata: {
              'method': 'PATCH',
              'url': '/profile',
              'statusCode': 422,
              'durationMs': 1200,
            },
          ),
        ]),
      );
      expect(
        story,
        contains('The application sent a PATCH request to /profile.'),
      );
      expect(
        story,
        contains('The request failed with HTTP 422 after 1.2 seconds.'),
      );
    });

    test('omits the duration clause when duration is unavailable', () {
      final story = BugStoryGenerator.generate(
        _incidentWith([
          _event(
            EventCategory.network,
            'GET /profile',
            metadata: {'method': 'GET', 'url': '/profile', 'statusCode': 200},
          ),
        ]),
      );
      expect(story, contains('The request completed with HTTP 200.'));
      expect(story, isNot(contains('after')));
    });

    test('describes a network failure with no status code via errorType', () {
      final story = BugStoryGenerator.generate(
        _incidentWith([
          _event(
            EventCategory.network,
            'GET /profile',
            metadata: {
              'method': 'GET',
              'url': '/profile',
              'errorType': 'connectionError',
            },
          ),
        ]),
      );
      expect(story, contains('The request failed (connectionError).'));
    });

    test('describes an error event and appends the closing sentence', () {
      final story = BugStoryGenerator.generate(
        _incidentWith([_event(EventCategory.error, 'DioException')]),
      );
      expect(story, contains('An error was recorded: DioException.'));
      expect(
        story,
        contains('The error was recorded and attached to this incident.'),
      );
    });

    test('does not append the closing sentence when there is no error', () {
      final story = BugStoryGenerator.generate(
        _incidentWith([_event(EventCategory.action, 'tapped')]),
      );
      expect(story, isNot(contains('The error was recorded')));
    });

    test('omits log and lifecycle events from the narrative', () {
      final story = BugStoryGenerator.generate(
        _incidentWith([
          _event(EventCategory.log, 'debug details'),
          _event(EventCategory.lifecycle, 'resumed'),
          _event(EventCategory.action, 'tapped'),
        ]),
      );
      expect(story, isNot(contains('debug details')));
      expect(story, isNot(contains('resumed')));
      expect(story, contains("The user tapped 'tapped'."));
    });

    test('is honest when only non-narrated categories were recorded', () {
      final story = BugStoryGenerator.generate(
        _incidentWith([_event(EventCategory.log, 'debug details')]),
      );
      expect(
        story,
        'No user-facing events were recorded before this incident.',
      );
    });

    test('matches the full spec example end to end', () {
      final story = BugStoryGenerator.generate(
        _incidentWith([
          _event(
            EventCategory.navigation,
            'edit_profile',
            metadata: {'action': 'push'},
          ),
          _event(EventCategory.action, 'save_profile_tapped'),
          _event(
            EventCategory.network,
            'PATCH /profile',
            metadata: {
              'method': 'PATCH',
              'url': '/profile',
              'statusCode': 422,
              'durationMs': 1200,
            },
          ),
          _event(EventCategory.error, 'DioException'),
        ]),
      );

      expect(story, contains('The user opened the edit profile screen.'));
      expect(story, contains("The user tapped 'save profile tapped'."));
      expect(
        story,
        contains('The application sent a PATCH request to /profile.'),
      );
      expect(
        story,
        contains('The request failed with HTTP 422 after 1.2 seconds.'),
      );
      expect(story, contains('An error was recorded: DioException.'));
      expect(
        story,
        contains('The error was recorded and attached to this incident.'),
      );
    });
  });
}
