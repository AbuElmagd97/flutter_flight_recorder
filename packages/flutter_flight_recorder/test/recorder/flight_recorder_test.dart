import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(FlightRecorder.resetForTest);
  tearDown(FlightRecorder.resetForTest);

  group('initialization', () {
    test('is not initialized until init() is called', () {
      expect(FlightRecorder.isInitialized, isFalse);
      FlightRecorder.init();
      expect(FlightRecorder.isInitialized, isTrue);
    });

    test('recording before init() fails loudly in debug/test mode', () {
      expect(() => FlightRecorder.recordAction('tapped'), throwsAssertionError);
    });

    test('setContext before init() fails loudly in debug/test mode', () {
      expect(() => FlightRecorder.setContext('k', 'v'), throwsAssertionError);
    });

    test(
      'calling init() twice resets prior state and applies the new config',
      () {
        FlightRecorder.init();
        FlightRecorder.recordAction('first_session_action');
        expect(FlightRecorder.debugEvents, hasLength(1));

        FlightRecorder.init(const FlightRecorderConfig(maxEvents: 2));
        expect(FlightRecorder.debugEvents, isEmpty);

        FlightRecorder.recordAction('a');
        FlightRecorder.recordAction('b');
        FlightRecorder.recordAction('c');
        expect(FlightRecorder.debugEvents, hasLength(2));
      },
    );
  });

  group('enabled / disabled', () {
    test('recording is a no-op when disabled', () {
      FlightRecorder.init(const FlightRecorderConfig(enabled: false));
      FlightRecorder.recordAction('tapped');
      FlightRecorder.log('hello');
      FlightRecorder.recordError('boom');

      expect(FlightRecorder.debugEvents, isEmpty);
    });

    test('createIncident is not blocked by enabled: false, unlike record*', () {
      // enabled only gates the void recording methods (see the test
      // above) — createIncident() itself still works, unlike calling it
      // before init() at all (that throws; see the createIncident group
      // below). With nothing recorded, the resulting timeline is simply
      // empty, not an error.
      FlightRecorder.init(const FlightRecorderConfig(enabled: false));

      final incident = FlightRecorder.createIncident(title: 'x');

      expect(incident.timeline, isEmpty);
    });
  });

  group('recordNavigation', () {
    test('records the action and from route in metadata', () {
      FlightRecorder.init();
      FlightRecorder.recordNavigation(
        '/profile',
        previousRouteName: '/',
        action: 'push',
      );

      final event = FlightRecorder.debugEvents.single;
      expect(event.category, EventCategory.navigation);
      expect(event.name, '/profile');
      expect(event.metadata['action'], 'push');
      expect(event.metadata['from'], '/');
    });

    test('omits from when there is no previous route', () {
      FlightRecorder.init();
      FlightRecorder.recordNavigation('/', action: 'push');

      expect(
        FlightRecorder.debugEvents.single.metadata.containsKey('from'),
        isFalse,
      );
    });
  });

  group('recordNetwork', () {
    test('records a network event with metadata and severity', () {
      FlightRecorder.init();
      FlightRecorder.recordNetwork(
        'PATCH /profile',
        metadata: {'statusCode': 422, 'durationMs': 1200},
        severity: EventSeverity.warning,
      );

      final event = FlightRecorder.debugEvents.single;
      expect(event.category, EventCategory.network);
      expect(event.name, 'PATCH /profile');
      expect(event.metadata['statusCode'], 422);
      expect(event.severity, EventSeverity.warning);
    });
  });

  group('recordLifecycle', () {
    test('records a lifecycle event', () {
      FlightRecorder.init();
      FlightRecorder.recordLifecycle('paused');

      final event = FlightRecorder.debugEvents.single;
      expect(event.category, EventCategory.lifecycle);
      expect(event.name, 'paused');
    });
  });

  group('category filtering', () {
    test('only enabled categories are recorded', () {
      FlightRecorder.init(
        const FlightRecorderConfig(enabledCategories: {EventCategory.action}),
      );

      FlightRecorder.recordAction('tapped');
      FlightRecorder.log('ignored');

      expect(FlightRecorder.debugEvents, hasLength(1));
      expect(FlightRecorder.debugEvents.single.category, EventCategory.action);
    });
  });

  group('rolling buffer integration', () {
    test('evicts the oldest event once maxEvents is exceeded', () {
      FlightRecorder.init(const FlightRecorderConfig(maxEvents: 3));

      for (var i = 0; i < 5; i++) {
        FlightRecorder.recordAction('action_$i');
      }

      final names = FlightRecorder.debugEvents.map((e) => e.name).toList();
      expect(names, ['action_2', 'action_3', 'action_4']);
    });

    test('handles rapid recording without dropping the newest events', () {
      FlightRecorder.init(const FlightRecorderConfig(maxEvents: 50));

      for (var i = 0; i < 500; i++) {
        FlightRecorder.recordAction('action_$i');
      }

      expect(FlightRecorder.debugEvents, hasLength(50));
      expect(FlightRecorder.debugEvents.last.name, 'action_499');
    });
  });

  group('recordAction', () {
    test('records an action event with metadata', () {
      FlightRecorder.init();
      FlightRecorder.recordAction(
        'save_profile_tapped',
        metadata: {'screen': 'edit_profile'},
      );

      final event = FlightRecorder.debugEvents.single;
      expect(event.category, EventCategory.action);
      expect(event.name, 'save_profile_tapped');
      expect(event.metadata, {'screen': 'edit_profile'});
    });
  });

  group('log', () {
    test('records a log event at the given severity', () {
      FlightRecorder.init();
      FlightRecorder.log(
        'Profile update started',
        level: EventSeverity.warning,
      );

      final event = FlightRecorder.debugEvents.single;
      expect(event.category, EventCategory.log);
      expect(event.name, 'Profile update started');
      expect(event.severity, EventSeverity.warning);
    });

    test('defaults to info severity', () {
      FlightRecorder.init();
      FlightRecorder.log('hello');

      expect(FlightRecorder.debugEvents.single.severity, EventSeverity.info);
    });
  });

  group('recordError', () {
    test('records the error and stack trace as metadata', () {
      FlightRecorder.init();
      final stackTrace = StackTrace.current;
      FlightRecorder.recordError(
        StateError('bad state'),
        stackTrace: stackTrace,
        metadata: {'screen': 'edit_profile'},
      );

      final event = FlightRecorder.debugEvents.single;
      expect(event.category, EventCategory.error);
      expect(event.name, 'StateError');
      expect(event.severity, EventSeverity.error);
      expect(event.metadata['error'], contains('bad state'));
      expect(event.metadata['stackTrace'], stackTrace.toString());
      expect(event.metadata['screen'], 'edit_profile');
    });

    test('handles a null stack trace', () {
      FlightRecorder.init();
      FlightRecorder.recordError('boom');

      final event = FlightRecorder.debugEvents.single;
      expect(event.metadata.containsKey('stackTrace'), isFalse);
    });
  });

  group('setContext', () {
    test('merges custom context with the captured fixed context', () {
      FlightRecorder.init();
      FlightRecorder.setContext('environment', 'uat');

      final context = FlightRecorder.debugContext;
      expect(context['environment'], 'uat');
      expect(context.containsKey('platform'), isTrue);
      expect(context.containsKey('locale'), isTrue);
    });

    test('overwriting a key replaces the previous value', () {
      FlightRecorder.init();
      FlightRecorder.setContext('environment', 'uat');
      FlightRecorder.setContext('environment', 'production');

      expect(FlightRecorder.debugContext['environment'], 'production');
    });
  });

  group('privacy integration', () {
    test('sanitizes metadata before it enters the buffer', () {
      FlightRecorder.init();
      FlightRecorder.recordAction('login', metadata: {'password': 'hunter2'});

      expect(FlightRecorder.debugEvents.single.metadata['password'], '***');
    });

    test('honors a custom PrivacyConfig', () {
      FlightRecorder.init(
        FlightRecorderConfig(privacy: PrivacyConfig(sensitiveKeys: {'pwd'})),
      );
      FlightRecorder.recordAction(
        'login',
        metadata: {'pwd': 'hunter2', 'password': 'kept'},
      );

      final metadata = FlightRecorder.debugEvents.single.metadata;
      expect(metadata['pwd'], '***');
      expect(metadata['password'], 'kept');
    });
  });

  group('event ids', () {
    test('are unique even for events recorded in the same microsecond', () {
      FlightRecorder.init(const FlightRecorderConfig(maxEvents: 100));

      for (var i = 0; i < 20; i++) {
        FlightRecorder.recordAction('action_$i');
      }

      final ids = FlightRecorder.debugEvents.map((e) => e.id).toSet();
      expect(ids, hasLength(20));
    });
  });

  group('createIncident', () {
    test('throws StateError when called before init(), in every build mode',
        () {
      expect(
        () => FlightRecorder.createIncident(title: 'x'),
        throwsA(isA<StateError>()),
      );
    });

    test('snapshots the current timeline and context', () {
      FlightRecorder.init();
      FlightRecorder.recordAction('save_profile_tapped');
      FlightRecorder.setContext('environment', 'uat');

      final incident =
          FlightRecorder.createIncident(title: 'Profile update failed');

      expect(incident.timeline, hasLength(1));
      expect(incident.timeline.single.name, 'save_profile_tapped');
      expect(incident.context['environment'], 'uat');
    });

    test('remains unchanged as recording continues afterward', () {
      FlightRecorder.init();
      FlightRecorder.recordAction('before');

      final incident = FlightRecorder.createIncident(title: 'x');
      FlightRecorder.recordAction('after');

      expect(incident.timeline, hasLength(1));
      expect(incident.timeline.single.name, 'before');
    });

    test('generates an INC-XXXXXX style id', () {
      FlightRecorder.init();
      final incident = FlightRecorder.createIncident(title: 'x');

      expect(incident.id, matches(RegExp(r'^INC-[0-9A-F]{6}$')));
    });

    test('generates a different id for each incident', () {
      FlightRecorder.init();
      final first = FlightRecorder.createIncident(title: 'x');
      final second = FlightRecorder.createIncident(title: 'x');

      expect(first.id, isNot(second.id));
    });

    test('passes title, description, qaReport and trigger through', () {
      FlightRecorder.init();
      final incident = FlightRecorder.createIncident(
        title: 'Profile update failed',
        description: 'Unable to save profile changes.',
        qaReport: const QaReportData(severity: IncidentSeverity.high),
        trigger: 'manual',
      );

      expect(incident.title, 'Profile update failed');
      expect(incident.description, 'Unable to save profile changes.');
      expect(incident.qaReport?.severity, IncidentSeverity.high);
      expect(incident.trigger, 'manual');
    });
  });

  group('newCorrelationId', () {
    test('generates a COR-XXXXXXXXXXXX style id', () {
      expect(
        FlightRecorder.newCorrelationId(),
        matches(RegExp(r'^COR-[0-9A-F]{12}$')),
      );
    });

    test('generates a different id on each call', () {
      final ids = List.generate(20, (_) => FlightRecorder.newCorrelationId());
      expect(ids.toSet(), hasLength(20));
    });

    test('is opaque — carries no recognizable structure from app data', () {
      // Not a formal proof of randomness, just a sanity check that the
      // id isn't, say, derived from the current time or a counter that
      // would make it predictable/guessable.
      final first = FlightRecorder.newCorrelationId();
      final second = FlightRecorder.newCorrelationId();
      expect(first, isNot(second));
      expect(first, isNot(contains(DateTime.now().year.toString())));
    });
  });

  group('correlationId — optional param on record* methods', () {
    setUp(FlightRecorder.init);

    test(
        'existing call sites with no correlationId compile and behave unchanged',
        () {
      FlightRecorder.recordAction('save_tapped');
      FlightRecorder.log('hello');
      FlightRecorder.recordError('boom');
      FlightRecorder.recordNavigation('/profile', action: 'push');
      FlightRecorder.recordNetwork('GET /profile');
      FlightRecorder.recordLifecycle('resumed');

      expect(FlightRecorder.debugEvents, hasLength(6));
      expect(
        FlightRecorder.debugEvents.every((e) => e.correlationId == null),
        isTrue,
      );
    });

    test('recordAction threads correlationId onto the recorded event', () {
      FlightRecorder.recordAction('save_tapped', correlationId: 'COR-A');
      expect(FlightRecorder.debugEvents.single.correlationId, 'COR-A');
    });

    test('recordNetwork threads correlationId onto the recorded event', () {
      FlightRecorder.recordNetwork(
        'PATCH /profile',
        correlationId: 'COR-A',
      );
      expect(FlightRecorder.debugEvents.single.correlationId, 'COR-A');
    });

    test('recordError threads correlationId onto the recorded event', () {
      FlightRecorder.recordError('boom', correlationId: 'COR-A');
      expect(FlightRecorder.debugEvents.single.correlationId, 'COR-A');
    });

    test('recordNavigation threads correlationId onto the recorded event', () {
      FlightRecorder.recordNavigation(
        '/profile',
        action: 'push',
        correlationId: 'COR-A',
      );
      expect(FlightRecorder.debugEvents.single.correlationId, 'COR-A');
    });

    test('log threads correlationId onto the recorded event', () {
      FlightRecorder.log('hello', correlationId: 'COR-A');
      expect(FlightRecorder.debugEvents.single.correlationId, 'COR-A');
    });

    test('recordLifecycle threads correlationId onto the recorded event', () {
      FlightRecorder.recordLifecycle('resumed', correlationId: 'COR-A');
      expect(FlightRecorder.debugEvents.single.correlationId, 'COR-A');
    });

    test(
      'no global correlation state leaks between unrelated calls — each '
      'event only carries the id explicitly passed to it',
      () {
        FlightRecorder.recordAction('save_tapped', correlationId: 'COR-A');
        FlightRecorder.recordAction('cancel_tapped');
        FlightRecorder.recordAction('retry_tapped', correlationId: 'COR-B');

        final events = FlightRecorder.debugEvents;
        expect(events[0].correlationId, 'COR-A');
        expect(events[1].correlationId, isNull);
        expect(events[2].correlationId, 'COR-B');
      },
    );
  });
}
