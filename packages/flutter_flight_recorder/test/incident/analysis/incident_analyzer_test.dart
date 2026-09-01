import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

FlightEvent _event({
  required String id,
  required EventCategory category,
  required String name,
  required DateTime timestamp,
  Map<String, Object?> metadata = const {},
  EventSeverity? severity,
  String? correlationId,
}) {
  return FlightEvent(
    id: id,
    timestamp: timestamp,
    category: category,
    name: name,
    metadata: metadata,
    severity: severity,
    correlationId: correlationId,
  );
}

Incident _incident(List<FlightEvent> timeline) {
  return Incident(
    id: 'INC-TEST',
    timestamp: DateTime.utc(2026, 1, 1, 12),
    title: 'Test incident',
    timeline: timeline,
    context: const {},
  );
}

final _t0 = DateTime.utc(2026, 1, 1, 14, 32, 10);
DateTime _at(int seconds) => _t0.add(Duration(seconds: seconds));

void main() {
  group('IncidentAnalyzer.analyze — timeline', () {
    test(
        'empty incident produces an empty timeline, no steps, and a plain story',
        () {
      final analysis = IncidentAnalyzer.analyze(_incident(const []));

      expect(analysis.timeline.isEmpty, isTrue);
      expect(analysis.reproductionSteps, isEmpty);
      expect(analysis.story.summary,
          'No events were recorded before this incident.');
    });

    test(
        'orders entries chronologically even if the incident timeline is not sorted',
        () {
      final earlier = _event(
        id: 'e1',
        category: EventCategory.action,
        name: 'first_tapped',
        timestamp: _at(5),
      );
      final later = _event(
        id: 'e2',
        category: EventCategory.action,
        name: 'second_tapped',
        timestamp: _at(1),
      );
      // Constructed out of order on purpose.
      final analysis = IncidentAnalyzer.analyze(_incident([earlier, later]));

      expect(analysis.timeline.entries.map((e) => e.event.id), ['e2', 'e1']);
    });

    test('equal timestamps are broken by original position, deterministically',
        () {
      final a = _event(
        id: 'a',
        category: EventCategory.action,
        name: 'a_tapped',
        timestamp: _t0,
      );
      final b = _event(
        id: 'b',
        category: EventCategory.action,
        name: 'b_tapped',
        timestamp: _t0,
      );
      final analysis1 = IncidentAnalyzer.analyze(_incident([a, b]));
      final analysis2 = IncidentAnalyzer.analyze(_incident([a, b]));

      expect(analysis1.timeline.entries.map((e) => e.event.id), ['a', 'b']);
      expect(analysis2.timeline.entries.map((e) => e.event.id), ['a', 'b']);
    });

    test('excludes log and lifecycle events from the normalized timeline', () {
      final events = [
        _event(
          id: 'log1',
          category: EventCategory.log,
          name: 'debug line',
          timestamp: _at(0),
          severity: EventSeverity.debug,
        ),
        _event(
          id: 'life1',
          category: EventCategory.lifecycle,
          name: 'resumed',
          timestamp: _at(1),
        ),
        _event(
          id: 'act1',
          category: EventCategory.action,
          name: 'save_tapped',
          timestamp: _at(2),
        ),
      ];
      final analysis = IncidentAnalyzer.analyze(_incident(events));

      expect(analysis.timeline.entries, hasLength(1));
      expect(analysis.timeline.entries.single.event.id, 'act1');
    });

    test(
        'duplicate events (same id/content) each still produce their own entry',
        () {
      final duplicateA = _event(
        id: 'dup',
        category: EventCategory.action,
        name: 'retry_tapped',
        timestamp: _at(0),
      );
      final duplicateB = _event(
        id: 'dup',
        category: EventCategory.action,
        name: 'retry_tapped',
        timestamp: _at(1),
      );
      final analysis =
          IncidentAnalyzer.analyze(_incident([duplicateA, duplicateB]));

      expect(analysis.timeline.entries, hasLength(2));
    });

    test('network entry summarizes method, url and status', () {
      final network = _event(
        id: 'n1',
        category: EventCategory.network,
        name: 'PATCH /profile',
        timestamp: _at(0),
        metadata: const {
          'method': 'PATCH',
          'url': '/profile',
          'statusCode': 422,
        },
      );
      final analysis = IncidentAnalyzer.analyze(_incident([network]));

      expect(analysis.timeline.entries.single.summary,
          'PATCH /profile → HTTP 422');
    });
  });

  group('IncidentAnalyzer.analyze — correlation', () {
    test('action -> network -> error are grouped into one chain', () {
      final events = [
        _event(
          id: 'action',
          category: EventCategory.action,
          name: 'save_tapped',
          timestamp: _at(0),
        ),
        _event(
          id: 'network',
          category: EventCategory.network,
          name: 'PATCH /profile',
          timestamp: _at(1),
          metadata: const {
            'method': 'PATCH',
            'url': '/profile',
            'statusCode': 422
          },
        ),
        _event(
          id: 'error',
          category: EventCategory.error,
          name: 'ProfileUpdateException',
          timestamp: _at(2),
        ),
      ];
      final analysis = IncidentAnalyzer.analyze(_incident(events));
      final chainIds = analysis.timeline.entries.map((e) => e.chainId).toSet();

      expect(chainIds, hasLength(1));
      expect(chainIds.single, isNotNull);
    });

    test('action -> network (no error) are grouped into one chain', () {
      final events = [
        _event(
          id: 'action',
          category: EventCategory.action,
          name: 'refresh_tapped',
          timestamp: _at(0),
        ),
        _event(
          id: 'network',
          category: EventCategory.network,
          name: 'GET /profile',
          timestamp: _at(1),
          metadata: const {
            'method': 'GET',
            'url': '/profile',
            'statusCode': 200
          },
        ),
      ];
      final analysis = IncidentAnalyzer.analyze(_incident(events));
      final chainIds = analysis.timeline.entries.map((e) => e.chainId).toList();

      expect(chainIds[0], chainIds[1]);
    });

    test('action -> error (no network) are grouped into one chain', () {
      final events = [
        _event(
          id: 'action',
          category: EventCategory.action,
          name: 'save_tapped',
          timestamp: _at(0),
        ),
        _event(
          id: 'error',
          category: EventCategory.error,
          name: 'ValidationException',
          timestamp: _at(1),
        ),
      ];
      final analysis = IncidentAnalyzer.analyze(_incident(events));
      final chainIds = analysis.timeline.entries.map((e) => e.chainId).toList();

      expect(chainIds[0], chainIds[1]);
    });

    test(
      'a new action closes the previous chain — an unrelated request in '
      'between is never linked to an earlier action',
      () {
        final events = [
          _event(
            id: 'tapSave',
            category: EventCategory.action,
            name: 'save_tapped',
            timestamp: _at(0),
          ),
          _event(
            id: 'unrelated',
            category: EventCategory.network,
            name: 'GET /analytics/ping',
            timestamp: _at(1),
            metadata: const {
              'method': 'GET',
              'url': '/analytics/ping',
              'statusCode': 200
            },
          ),
          _event(
            id: 'tapCancel',
            category: EventCategory.action,
            name: 'cancel_tapped',
            timestamp: _at(2),
          ),
          _event(
            id: 'failing',
            category: EventCategory.network,
            name: 'PATCH /profile',
            timestamp: _at(3),
            metadata: const {
              'method': 'PATCH',
              'url': '/profile',
              'statusCode': 422
            },
          ),
        ];
        final analysis = IncidentAnalyzer.analyze(_incident(events));
        final byId = {
          for (final entry in analysis.timeline.entries)
            entry.event.id: entry.chainId,
        };

        expect(byId['tapSave'], byId['unrelated'],
            reason:
                'the ping is only evidence for the chain open when it happened');
        expect(byId['failing'], byId['tapCancel'],
            reason:
                'the failing request must be linked to the action that immediately preceded it');
        expect(byId['tapSave'], isNot(byId['failing']),
            reason:
                'Save must NOT be falsely blamed for a failure after an unrelated action');
      },
    );

    test(
        'multiple consecutive network events after one action share that chain',
        () {
      final events = [
        _event(
          id: 'action',
          category: EventCategory.action,
          name: 'sync_tapped',
          timestamp: _at(0),
        ),
        _event(
          id: 'n1',
          category: EventCategory.network,
          name: 'GET /a',
          timestamp: _at(1),
          metadata: const {'method': 'GET', 'url': '/a', 'statusCode': 200},
        ),
        _event(
          id: 'n2',
          category: EventCategory.network,
          name: 'GET /b',
          timestamp: _at(2),
          metadata: const {'method': 'GET', 'url': '/b', 'statusCode': 200},
        ),
      ];
      final analysis = IncidentAnalyzer.analyze(_incident(events));
      final chainIds = analysis.timeline.entries.map((e) => e.chainId).toSet();

      expect(chainIds, hasLength(1));
    });

    test('a network/error event with no preceding action forms its own chain',
        () {
      final network = _event(
        id: 'n1',
        category: EventCategory.network,
        name: 'GET /startup-config',
        timestamp: _at(0),
        metadata: const {
          'method': 'GET',
          'url': '/startup-config',
          'statusCode': 500
        },
      );
      final analysis = IncidentAnalyzer.analyze(_incident([network]));

      expect(analysis.timeline.entries.single.chainId, isNotNull);
    });

    test('unrelated requests separated by actions each get distinct chains',
        () {
      final events = [
        _event(
          id: 'a1',
          category: EventCategory.action,
          name: 'open_tab_a',
          timestamp: _at(0),
        ),
        _event(
          id: 'n1',
          category: EventCategory.network,
          name: 'GET /a',
          timestamp: _at(1),
          metadata: const {'method': 'GET', 'url': '/a', 'statusCode': 200},
        ),
        _event(
          id: 'a2',
          category: EventCategory.action,
          name: 'open_tab_b',
          timestamp: _at(2),
        ),
        _event(
          id: 'n2',
          category: EventCategory.network,
          name: 'GET /b',
          timestamp: _at(3),
          metadata: const {'method': 'GET', 'url': '/b', 'statusCode': 200},
        ),
      ];
      final analysis = IncidentAnalyzer.analyze(_incident(events));
      final byId = {
        for (final entry in analysis.timeline.entries)
          entry.event.id: entry.chainId,
      };

      expect(byId['a1'], byId['n1']);
      expect(byId['a2'], byId['n2']);
      expect(byId['a1'], isNot(byId['a2']));
    });
  });

  group('IncidentAnalyzer.analyze — reproduction steps', () {
    test('happy path: meaningful actions and navigation only, in order', () {
      final events = [
        _event(
            id: '1',
            category: EventCategory.navigation,
            name: '/profile',
            timestamp: _at(0),
            metadata: const {'action': 'push'}),
        _event(
            id: '2',
            category: EventCategory.action,
            name: 'edit_profile_tapped',
            timestamp: _at(1)),
        _event(
            id: '3',
            category: EventCategory.action,
            name: 'save_tapped',
            timestamp: _at(2)),
        _event(
            id: '4',
            category: EventCategory.network,
            name: 'PATCH /profile',
            timestamp: _at(3),
            metadata: const {
              'method': 'PATCH',
              'url': '/profile',
              'statusCode': 200
            }),
      ];
      final steps =
          IncidentAnalyzer.analyze(_incident(events)).reproductionSteps;

      expect(steps.map((s) => s.description), [
        'Open profile',
        "Tap 'edit profile tapped'",
        "Tap 'save tapped'",
      ]);
    });

    test('failed network request produces a numbered failure step', () {
      final events = [
        _event(
            id: '1',
            category: EventCategory.action,
            name: 'save_tapped',
            timestamp: _at(0)),
        _event(
            id: '2',
            category: EventCategory.network,
            name: 'PATCH /profile',
            timestamp: _at(1),
            metadata: const {
              'method': 'PATCH',
              'url': '/profile',
              'statusCode': 422
            }),
      ];
      final steps =
          IncidentAnalyzer.analyze(_incident(events)).reproductionSteps;

      expect(
          steps.last.description, 'PATCH /profile request returned HTTP 422');
    });

    test('exception after request appears as its own final step', () {
      final events = [
        _event(
            id: '1',
            category: EventCategory.action,
            name: 'save_tapped',
            timestamp: _at(0)),
        _event(
            id: '2',
            category: EventCategory.network,
            name: 'PATCH /profile',
            timestamp: _at(1),
            metadata: const {
              'method': 'PATCH',
              'url': '/profile',
              'statusCode': 422
            }),
        _event(
            id: '3',
            category: EventCategory.error,
            name: 'ProfileUpdateException',
            timestamp: _at(2)),
      ];
      final steps =
          IncidentAnalyzer.analyze(_incident(events)).reproductionSteps;

      expect(steps.map((s) => s.description), [
        "Tap 'save tapped'",
        'PATCH /profile request returned HTTP 422',
        'ProfileUpdateException occurred',
      ]);
    });

    test('multiple navigation events are each preserved in order', () {
      final events = [
        _event(
            id: '1',
            category: EventCategory.navigation,
            name: '/home',
            timestamp: _at(0),
            metadata: const {'action': 'push'}),
        _event(
            id: '2',
            category: EventCategory.navigation,
            name: '/profile',
            timestamp: _at(1),
            metadata: const {'action': 'push'}),
        _event(
            id: '3',
            category: EventCategory.navigation,
            name: '/profile/edit',
            timestamp: _at(2),
            metadata: const {'action': 'push'}),
      ];
      final steps =
          IncidentAnalyzer.analyze(_incident(events)).reproductionSteps;

      expect(steps.map((s) => s.description),
          ['Open home', 'Open profile', 'Open profile/edit']);
    });

    test('noisy event stream: logs, lifecycle, and back-navigation are dropped',
        () {
      final events = [
        _event(
            id: '1',
            category: EventCategory.log,
            name: 'debug',
            timestamp: _at(0)),
        _event(
            id: '2',
            category: EventCategory.lifecycle,
            name: 'resumed',
            timestamp: _at(1)),
        _event(
            id: '3',
            category: EventCategory.action,
            name: 'save_tapped',
            timestamp: _at(2)),
        _event(
            id: '4',
            category: EventCategory.navigation,
            name: '/profile',
            timestamp: _at(3),
            metadata: const {'action': 'pop'}),
        _event(
            id: '5',
            category: EventCategory.network,
            name: 'GET /ok',
            timestamp: _at(4),
            metadata: const {'method': 'GET', 'url': '/ok', 'statusCode': 200}),
      ];
      final steps =
          IncidentAnalyzer.analyze(_incident(events)).reproductionSteps;

      expect(steps.map((s) => s.description), ["Tap 'save tapped'"]);
    });

    test('incomplete event stream (network with no action) still yields a step',
        () {
      final events = [
        _event(
            id: '1',
            category: EventCategory.network,
            name: 'GET /config',
            timestamp: _at(0),
            metadata: const {
              'method': 'GET',
              'url': '/config',
              'statusCode': 500
            }),
      ];
      final steps =
          IncidentAnalyzer.analyze(_incident(events)).reproductionSteps;

      expect(steps, hasLength(1));
      expect(steps.single.description, 'GET /config request returned HTTP 500');
    });

    test('repeated identical actions collapse to a single step', () {
      final events = [
        _event(
            id: '1',
            category: EventCategory.action,
            name: 'retry_tapped',
            timestamp: _at(0)),
        _event(
            id: '2',
            category: EventCategory.action,
            name: 'retry_tapped',
            timestamp: _at(1)),
        _event(
            id: '3',
            category: EventCategory.action,
            name: 'retry_tapped',
            timestamp: _at(2)),
      ];
      final steps =
          IncidentAnalyzer.analyze(_incident(events)).reproductionSteps;

      expect(steps, hasLength(1));
    });

    test('no user actions: steps built purely from network/error evidence', () {
      final events = [
        _event(
            id: '1',
            category: EventCategory.network,
            name: 'GET /config',
            timestamp: _at(0),
            metadata: const {
              'method': 'GET',
              'url': '/config',
              'statusCode': 500
            }),
        _event(
            id: '2',
            category: EventCategory.error,
            name: 'ConfigLoadException',
            timestamp: _at(1)),
      ];
      final steps =
          IncidentAnalyzer.analyze(_incident(events)).reproductionSteps;

      expect(steps.map((s) => s.description), [
        'GET /config request returned HTTP 500',
        'ConfigLoadException occurred'
      ]);
    });

    test('incident containing only an error yields exactly one step', () {
      final events = [
        _event(
            id: '1',
            category: EventCategory.error,
            name: 'UnknownException',
            timestamp: _at(0)),
      ];
      final steps =
          IncidentAnalyzer.analyze(_incident(events)).reproductionSteps;

      expect(steps.map((s) => s.description), ['UnknownException occurred']);
    });

    test('step indices are 1-based and sequential', () {
      final events = [
        _event(
            id: '1',
            category: EventCategory.action,
            name: 'a_tapped',
            timestamp: _at(0)),
        _event(
            id: '2',
            category: EventCategory.action,
            name: 'b_tapped',
            timestamp: _at(1)),
      ];
      final steps =
          IncidentAnalyzer.analyze(_incident(events)).reproductionSteps;

      expect(steps.map((s) => s.index), [1, 2]);
    });
  });

  group('IncidentAnalyzer.analyze — incident story', () {
    test('successful operation: no error, no failed request', () {
      final events = [
        _event(
            id: '1',
            category: EventCategory.action,
            name: 'save_tapped',
            timestamp: _at(0)),
        _event(
            id: '2',
            category: EventCategory.network,
            name: 'PATCH /profile',
            timestamp: _at(1),
            metadata: const {
              'method': 'PATCH',
              'url': '/profile',
              'statusCode': 200
            }),
      ];
      final story = IncidentAnalyzer.analyze(_incident(events)).story;

      expect(
        story.summary,
        'No error or failed network request was recorded before this incident was created.',
      );
    });

    test(
        'failed request: story states the observed HTTP outcome, not a guessed cause',
        () {
      final events = [
        _event(
            id: '1',
            category: EventCategory.action,
            name: 'save_tapped',
            timestamp: _at(0)),
        _event(
            id: '2',
            category: EventCategory.network,
            name: 'PATCH /profile',
            timestamp: _at(1),
            metadata: const {
              'method': 'PATCH',
              'url': '/profile',
              'statusCode': 422
            }),
      ];
      final story = IncidentAnalyzer.analyze(_incident(events)).story;

      expect(
        story.summary,
        "After tapping 'save tapped', the PATCH /profile request returned HTTP 422.",
      );
      expect(story.summary, isNot(contains('because')));
      expect(story.summary, isNot(contains('invalid')));
    });

    test(
        'exception: story sequences the request result and the exception without asserting causation',
        () {
      final events = [
        _event(
            id: '1',
            category: EventCategory.action,
            name: 'save_tapped',
            timestamp: _at(0)),
        _event(
            id: '2',
            category: EventCategory.network,
            name: 'PATCH /profile',
            timestamp: _at(1),
            metadata: const {
              'method': 'PATCH',
              'url': '/profile',
              'statusCode': 422
            }),
        _event(
            id: '3',
            category: EventCategory.error,
            name: 'ProfileUpdateException',
            timestamp: _at(2)),
      ];
      final story = IncidentAnalyzer.analyze(_incident(events)).story;

      expect(
        story.summary,
        "After tapping 'save tapped', the PATCH /profile request returned HTTP 422, "
        'followed by ProfileUpdateException.',
      );
      expect(story.summary, isNot(contains('caused')));
    });

    test(
        'missing information: no preceding action, so no "after" claim is made',
        () {
      final events = [
        _event(
            id: '1',
            category: EventCategory.network,
            name: 'GET /profile',
            timestamp: _at(0),
            metadata: const {
              'method': 'GET',
              'url': '/profile',
              'statusCode': 500
            }),
      ];
      final story = IncidentAnalyzer.analyze(_incident(events)).story;

      expect(story.summary, 'The GET /profile request returned HTTP 500.');
      expect(story.summary, isNot(startsWith('After')));
    });

    test(
        'multiple failures: story is about the most recent failure, deterministically',
        () {
      final events = [
        _event(
            id: '1',
            category: EventCategory.action,
            name: 'retry_tapped',
            timestamp: _at(0)),
        _event(
            id: '2',
            category: EventCategory.network,
            name: 'GET /a',
            timestamp: _at(1),
            metadata: const {'method': 'GET', 'url': '/a', 'statusCode': 500}),
        _event(
            id: '3',
            category: EventCategory.action,
            name: 'retry_again_tapped',
            timestamp: _at(2)),
        _event(
            id: '4',
            category: EventCategory.network,
            name: 'GET /a',
            timestamp: _at(3),
            metadata: const {'method': 'GET', 'url': '/a', 'statusCode': 503}),
      ];
      final story = IncidentAnalyzer.analyze(_incident(events)).story;

      expect(story.summary, contains('HTTP 503'));
      expect(story.summary, isNot(contains('HTTP 500')));
    });

    test('no supported conclusion: empty timeline', () {
      final story = IncidentAnalyzer.analyze(_incident(const [])).story;

      expect(story.summary, 'No events were recorded before this incident.');
    });

    test(
        'errorType without a status code is described as a failure, not a success',
        () {
      final events = [
        _event(
            id: '1',
            category: EventCategory.action,
            name: 'save_tapped',
            timestamp: _at(0)),
        _event(
            id: '2',
            category: EventCategory.network,
            name: 'PATCH /profile',
            timestamp: _at(1),
            metadata: const {
              'method': 'PATCH',
              'url': '/profile',
              'errorType': 'connectionTimeout'
            }),
      ];
      final story = IncidentAnalyzer.analyze(_incident(events)).story;

      expect(story.summary, contains('failed (connectionTimeout)'));
    });
  });

  group('IncidentAnalyzer.analyze — determinism', () {
    test('the same event sequence always produces the same analysis', () {
      final events = [
        _event(
            id: '1',
            category: EventCategory.navigation,
            name: '/profile',
            timestamp: _at(0),
            metadata: const {'action': 'push'}),
        _event(
            id: '2',
            category: EventCategory.action,
            name: 'edit_profile_tapped',
            timestamp: _at(1)),
        _event(
            id: '3',
            category: EventCategory.action,
            name: 'phone_changed',
            timestamp: _at(2)),
        _event(
            id: '4',
            category: EventCategory.action,
            name: 'save_tapped',
            timestamp: _at(3)),
        _event(
            id: '5',
            category: EventCategory.network,
            name: 'PATCH /profile',
            timestamp: _at(4),
            metadata: const {
              'method': 'PATCH',
              'url': '/profile',
              'statusCode': 422
            }),
        _event(
            id: '6',
            category: EventCategory.error,
            name: 'ProfileUpdateException',
            timestamp: _at(5)),
      ];

      final first = IncidentAnalyzer.analyze(_incident(events));
      final second = IncidentAnalyzer.analyze(_incident(events));

      expect(first.story.summary, second.story.summary);
      expect(
        first.reproductionSteps.map((s) => s.description),
        second.reproductionSteps.map((s) => s.description),
      );
      expect(
        first.timeline.entries.map((e) => e.summary),
        second.timeline.entries.map((e) => e.summary),
      );
      expect(
        first.timeline.entries.map((e) => e.chainId),
        second.timeline.entries.map((e) => e.chainId),
      );
    });
  });

  group('IncidentAnalyzer.analyze — privacy', () {
    test(
      'the analyzer never introduces sensitive data — it only reads already-sanitized metadata',
      () {
        // FlightRecorder.recordAction/.recordNetwork/etc. sanitize metadata
        // before it reaches an event (see Sanitizer); this test documents
        // that IncidentAnalyzer does not add a second path around that —
        // it only ever reads FlightEvent.metadata as given.
        final events = [
          _event(
            id: '1',
            category: EventCategory.network,
            name: 'POST /login',
            timestamp: _at(0),
            metadata: const {
              'method': 'POST',
              'url': '/login',
              'statusCode': 401,
              // Already masked by Sanitizer by the time it would reach a
              // real FlightEvent — simulated here directly.
              'password': '***',
            },
          ),
        ];
        final analysis = IncidentAnalyzer.analyze(_incident(events));

        // The analyzer only pulls well-known fields (method/url/status/
        // errorType) into summaries/story — it never dumps arbitrary
        // metadata, so an already-masked field never resurfaces unmasked.
        expect(analysis.story.summary, isNot(contains('password')));
        expect(analysis.timeline.entries.single.summary,
            isNot(contains('password')));
        expect(analysis.reproductionSteps.map((s) => s.description).join(),
            isNot(contains('password')));
      },
    );
  });

  group('IncidentAnalyzer.analyze — explicit correlation', () {
    test('action -> network -> error sharing one correlationId are grouped',
        () {
      final events = [
        _event(
          id: 'action',
          category: EventCategory.action,
          name: 'save_tapped',
          timestamp: _at(0),
          correlationId: 'COR-A',
        ),
        _event(
          id: 'network',
          category: EventCategory.network,
          name: 'PATCH /profile',
          timestamp: _at(1),
          metadata: const {
            'method': 'PATCH',
            'url': '/profile',
            'statusCode': 422
          },
          correlationId: 'COR-A',
        ),
        _event(
          id: 'error',
          category: EventCategory.error,
          name: 'ProfileUpdateException',
          timestamp: _at(2),
          correlationId: 'COR-A',
        ),
      ];
      final analysis = IncidentAnalyzer.analyze(_incident(events));
      final chainIds = analysis.timeline.entries.map((e) => e.chainId).toSet();

      expect(chainIds, hasLength(1));
      expect(chainIds.single, isNotNull);
    });

    test('multiple network events sharing one correlationId all join it', () {
      final events = [
        _event(
          id: 'action',
          category: EventCategory.action,
          name: 'sync_tapped',
          timestamp: _at(0),
          correlationId: 'COR-A',
        ),
        _event(
          id: 'n1',
          category: EventCategory.network,
          name: 'GET /a',
          timestamp: _at(1),
          metadata: const {'method': 'GET', 'url': '/a', 'statusCode': 200},
          correlationId: 'COR-A',
        ),
        _event(
          id: 'n2',
          category: EventCategory.network,
          name: 'GET /b',
          timestamp: _at(2),
          metadata: const {'method': 'GET', 'url': '/b', 'statusCode': 200},
          correlationId: 'COR-A',
        ),
      ];
      final analysis = IncidentAnalyzer.analyze(_incident(events));
      final chainIds = analysis.timeline.entries.map((e) => e.chainId).toSet();

      expect(chainIds, hasLength(1));
    });

    test('two different correlationIds remain isolated from each other', () {
      final events = [
        _event(
          id: 'a1',
          category: EventCategory.action,
          name: 'save_tapped',
          timestamp: _at(0),
          correlationId: 'COR-A',
        ),
        _event(
          id: 'n1',
          category: EventCategory.network,
          name: 'PATCH /profile',
          timestamp: _at(1),
          metadata: const {
            'method': 'PATCH',
            'url': '/profile',
            'statusCode': 200
          },
          correlationId: 'COR-A',
        ),
        _event(
          id: 'a2',
          category: EventCategory.action,
          name: 'refresh_tapped',
          timestamp: _at(2),
          correlationId: 'COR-B',
        ),
        _event(
          id: 'n2',
          category: EventCategory.network,
          name: 'GET /profile',
          timestamp: _at(3),
          metadata: const {
            'method': 'GET',
            'url': '/profile',
            'statusCode': 200
          },
          correlationId: 'COR-B',
        ),
      ];
      final analysis = IncidentAnalyzer.analyze(_incident(events));
      final byId = {
        for (final entry in analysis.timeline.entries)
          entry.event.id: entry.chainId,
      };

      expect(byId['a1'], byId['n1']);
      expect(byId['a2'], byId['n2']);
      expect(byId['a1'], isNot(byId['a2']));
    });

    test(
      'interleaved A/B events never cross-correlate, even though B starts '
      'before A finishes',
      () {
        final events = [
          _event(
            id: 'save',
            category: EventCategory.action,
            name: 'save_tapped',
            timestamp: _at(0),
            correlationId: 'COR-A',
          ),
          _event(
            id: 'home',
            category: EventCategory.action,
            name: 'home_tapped',
            timestamp: _at(1),
            correlationId: 'COR-B',
          ),
          _event(
            id: 'getHome',
            category: EventCategory.network,
            name: 'GET /home',
            timestamp: _at(2),
            metadata: const {
              'method': 'GET',
              'url': '/home',
              'statusCode': 200
            },
            correlationId: 'COR-B',
          ),
          _event(
            id: 'patchProfile',
            category: EventCategory.network,
            name: 'PATCH /profile',
            timestamp: _at(3),
            metadata: const {
              'method': 'PATCH',
              'url': '/profile',
              'statusCode': 422
            },
            correlationId: 'COR-A',
          ),
          _event(
            id: 'profileError',
            category: EventCategory.error,
            name: 'ProfileUpdateException',
            timestamp: _at(4),
            correlationId: 'COR-A',
          ),
        ];
        final analysis = IncidentAnalyzer.analyze(_incident(events));
        final byId = {
          for (final entry in analysis.timeline.entries)
            entry.event.id: entry.chainId,
        };

        expect(byId['save'], byId['patchProfile']);
        expect(byId['save'], byId['profileError']);
        expect(byId['home'], byId['getHome']);
        expect(byId['save'], isNot(byId['home']));
      },
    );

    test(
      'explicit correlation and uncorrelated events coexist without '
      'corrupting each other',
      () {
        final events = [
          _event(
            id: 'save',
            category: EventCategory.action,
            name: 'save_tapped',
            timestamp: _at(0),
            correlationId: 'COR-A',
          ),
          _event(
            id: 'ping',
            category: EventCategory.network,
            name: 'GET /analytics/ping',
            timestamp: _at(1),
            metadata: const {
              'method': 'GET',
              'url': '/analytics/ping',
              'statusCode': 200
            },
            // no correlationId — should still fall back to chronological
            // attachment to the most recent action, exactly as before.
          ),
          _event(
            id: 'patchProfile',
            category: EventCategory.network,
            name: 'PATCH /profile',
            timestamp: _at(2),
            metadata: const {
              'method': 'PATCH',
              'url': '/profile',
              'statusCode': 422
            },
            correlationId: 'COR-A',
          ),
        ];
        final analysis = IncidentAnalyzer.analyze(_incident(events));
        final byId = {
          for (final entry in analysis.timeline.entries)
            entry.event.id: entry.chainId,
        };

        expect(byId['save'], byId['patchProfile']);
        expect(byId['save'], byId['ping'],
            reason: 'the uncorrelated ping still falls back to the most '
                'recent action, unchanged from V1 behavior');
      },
    );

    test(
      'a correlationId with no surviving partner in the timeline falls back '
      'to chronological correlation instead of forming a chain of one',
      () {
        // Simulates the partner having been evicted from the rolling
        // buffer before the incident was created: only one event in
        // this timeline carries COR-A.
        final events = [
          _event(
            id: 'action',
            category: EventCategory.action,
            name: 'save_tapped',
            timestamp: _at(0),
          ),
          _event(
            id: 'network',
            category: EventCategory.network,
            name: 'PATCH /profile',
            timestamp: _at(1),
            metadata: const {
              'method': 'PATCH',
              'url': '/profile',
              'statusCode': 422
            },
            correlationId: 'COR-ORPHANED',
          ),
        ];
        final analysis = IncidentAnalyzer.analyze(_incident(events));
        final byId = {
          for (final entry in analysis.timeline.entries)
            entry.event.id: entry.chainId,
        };

        // Falls back to the same chronological attachment a completely
        // uncorrelated network event would get — not a broken singleton
        // chain of its own.
        expect(byId['action'], byId['network']);
      },
    );

    test('a null correlationId preserves the existing chronological fallback',
        () {
      final events = [
        _event(
          id: 'action',
          category: EventCategory.action,
          name: 'save_tapped',
          timestamp: _at(0),
        ),
        _event(
          id: 'network',
          category: EventCategory.network,
          name: 'PATCH /profile',
          timestamp: _at(1),
          metadata: const {
            'method': 'PATCH',
            'url': '/profile',
            'statusCode': 422
          },
        ),
      ];
      final analysis = IncidentAnalyzer.analyze(_incident(events));
      final byId = {
        for (final entry in analysis.timeline.entries)
          entry.event.id: entry.chainId,
      };

      expect(byId['action'], byId['network']);
    });

    test(
      'REGRESSION: the interleaving scenario that motivated explicit '
      'correlation — the story attributes the failure to Save, not Home',
      () {
        final events = [
          _event(
            id: 'save',
            category: EventCategory.action,
            name: 'save_tapped',
            timestamp: _at(0),
            correlationId: 'COR-A',
          ),
          _event(
            id: 'patch1',
            category: EventCategory.network,
            name: 'PATCH /profile',
            timestamp: _at(1),
            metadata: const {
              'method': 'PATCH',
              'url': '/profile',
              'statusCode': 200
            },
            correlationId: 'COR-A',
          ),
          _event(
            id: 'home',
            category: EventCategory.action,
            name: 'home_tapped',
            timestamp: _at(2),
            correlationId: 'COR-B',
          ),
          _event(
            id: 'getHome',
            category: EventCategory.network,
            name: 'GET /home',
            timestamp: _at(3),
            metadata: const {
              'method': 'GET',
              'url': '/home',
              'statusCode': 200
            },
            correlationId: 'COR-B',
          ),
          _event(
            id: 'patch2',
            category: EventCategory.network,
            name: 'PATCH /profile',
            timestamp: _at(4),
            metadata: const {
              'method': 'PATCH',
              'url': '/profile',
              'statusCode': 422
            },
            correlationId: 'COR-A',
          ),
          _event(
            id: 'profileError',
            category: EventCategory.error,
            name: 'ProfileUpdateException',
            timestamp: _at(5),
            correlationId: 'COR-A',
          ),
        ];
        final story = IncidentAnalyzer.analyze(_incident(events)).story;

        expect(story.summary, contains("tapping 'save tapped'"));
        expect(story.summary, isNot(contains("tapping 'home tapped'")));
        expect(story.summary, contains('HTTP 422'));
        expect(story.summary, contains('ProfileUpdateException'));
      },
    );

    test(
      'the same interleaving WITHOUT correlation ids reproduces the old, '
      'documented V1 limitation unchanged — proving fallback behavior was '
      'not altered by adding explicit correlation',
      () {
        final events = [
          _event(
            id: 'save',
            category: EventCategory.action,
            name: 'save_tapped',
            timestamp: _at(0),
          ),
          _event(
            id: 'patch1',
            category: EventCategory.network,
            name: 'PATCH /profile',
            timestamp: _at(1),
            metadata: const {
              'method': 'PATCH',
              'url': '/profile',
              'statusCode': 200
            },
          ),
          _event(
            id: 'home',
            category: EventCategory.action,
            name: 'home_tapped',
            timestamp: _at(2),
          ),
          _event(
            id: 'getHome',
            category: EventCategory.network,
            name: 'GET /home',
            timestamp: _at(3),
            metadata: const {
              'method': 'GET',
              'url': '/home',
              'statusCode': 200
            },
          ),
          _event(
            id: 'patch2',
            category: EventCategory.network,
            name: 'PATCH /profile',
            timestamp: _at(4),
            metadata: const {
              'method': 'PATCH',
              'url': '/profile',
              'statusCode': 422
            },
          ),
          _event(
            id: 'profileError',
            category: EventCategory.error,
            name: 'ProfileUpdateException',
            timestamp: _at(5),
          ),
        ];
        final story = IncidentAnalyzer.analyze(_incident(events)).story;

        // The documented V1 limitation: without explicit correlation, the
        // failure is (mis)attributed to whichever action most recently
        // opened a chain — Home — not Save. This is unchanged, proving
        // the fallback path was not altered by this feature.
        expect(story.summary, contains("tapping 'home tapped'"));
      },
    );
  });
}
