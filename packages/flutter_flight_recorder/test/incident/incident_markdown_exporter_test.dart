import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

FlightEvent _event({
  required String id,
  required EventCategory category,
  required String name,
  required DateTime timestamp,
  Map<String, Object?> metadata = const {},
}) {
  return FlightEvent(
    id: id,
    timestamp: timestamp,
    category: category,
    name: name,
    metadata: metadata,
  );
}

Incident _incident({
  String id = 'INC-ABCDEF',
  DateTime? timestamp,
  String title = 'Test incident',
  QaReportData? qaReport,
  Object? trigger,
  List<FlightEvent> timeline = const [],
  Map<String, Object?> context = const {},
}) {
  return Incident(
    id: id,
    timestamp: timestamp ?? DateTime.utc(2026, 1, 1, 12),
    title: title,
    qaReport: qaReport,
    trigger: trigger,
    timeline: timeline,
    context: context,
  );
}

final _t0 = DateTime.utc(2026, 1, 1, 14, 32, 10);
DateTime _at(int seconds) => _t0.add(Duration(seconds: seconds));

void main() {
  group('IncidentMarkdownExporter.export — basic', () {
    test('story only: a minimal incident still produces a valid report', () {
      final incident = _incident(timeline: const []);
      final analysis = IncidentAnalyzer.analyze(incident);
      final markdown = IncidentMarkdownExporter.export(incident, analysis);

      expect(markdown, startsWith('# Test incident'));
      expect(markdown, contains('## What happened?'));
      expect(
        markdown,
        contains('No events were recorded before this incident.'),
      );
      expect(markdown, contains('## Incident'));
      expect(markdown, contains('- Incident ID: INC-ABCDEF'));
    });

    test('reproduction steps only render when there is evidence for them', () {
      final incident = _incident(
        timeline: [
          _event(
            id: '1',
            category: EventCategory.action,
            name: 'save_tapped',
            timestamp: _at(0),
          ),
        ],
      );
      final analysis = IncidentAnalyzer.analyze(incident);
      final markdown = IncidentMarkdownExporter.export(incident, analysis);

      expect(markdown, contains('## Reproduction steps'));
      expect(markdown, contains("1. Tap 'save tapped'"));
    });

    test('timeline renders a Time | Event table', () {
      final incident = _incident(
        timeline: [
          _event(
            id: '1',
            category: EventCategory.navigation,
            name: '/profile',
            timestamp: _at(0),
            metadata: const {'action': 'push'},
          ),
        ],
      );
      final analysis = IncidentAnalyzer.analyze(incident);
      final markdown = IncidentMarkdownExporter.export(incident, analysis);

      expect(markdown, contains('## Technical evidence'));
      expect(markdown, contains('| Time | Event |'));
      expect(markdown, contains('|---|---|'));
      expect(markdown, contains('| 14:32:10 | Opened profile |'));
    });

    test(
        'complete incident: story, QA report, steps, evidence, network, '
        'errors, environment and metadata all present', () {
      final incident = _incident(
        title: 'Profile update failed',
        qaReport: const QaReportData(
          expected: 'Profile saves successfully.',
          actual: 'Validation error appears.',
          severity: IncidentSeverity.high,
        ),
        trigger: 'shake',
        context: const {'platform': 'ios', 'environment': 'uat'},
        timeline: [
          _event(
            id: '1',
            category: EventCategory.navigation,
            name: '/profile',
            timestamp: _at(0),
            metadata: const {'action': 'push'},
          ),
          _event(
            id: '2',
            category: EventCategory.action,
            name: 'save_tapped',
            timestamp: _at(1),
          ),
          _event(
            id: '3',
            category: EventCategory.network,
            name: 'PATCH /profile',
            timestamp: _at(1),
            metadata: const {
              'method': 'PATCH',
              'url': '/profile',
              'statusCode': 422,
              'durationMs': 842,
            },
          ),
          _event(
            id: '4',
            category: EventCategory.error,
            name: 'ProfileUpdateException',
            timestamp: _at(2),
          ),
        ],
      );
      final analysis = IncidentAnalyzer.analyze(incident);
      final markdown = IncidentMarkdownExporter.export(incident, analysis);

      for (final heading in [
        '## What happened?',
        '## QA report',
        '## Reproduction steps',
        '## Technical evidence',
        '## Network',
        '## Errors',
        '## Environment',
        '## Incident',
      ]) {
        expect(markdown, contains(heading), reason: 'missing $heading');
      }
      expect(markdown, contains('- **Expected:** Profile saves successfully.'));
      expect(markdown, contains('- **Actual:** Validation error appears.'));
      expect(markdown, contains('- **Severity:** high'));
      expect(markdown, contains('- PATCH /profile'));
      expect(markdown, contains('- Status: 422'));
      expect(markdown, contains('- Duration: 842ms'));
      expect(markdown, contains('- ProfileUpdateException'));
      expect(markdown, contains('- platform: ios'));
      expect(markdown, contains('- environment: uat'));
      expect(markdown, contains('- Trigger: shake'));
    });
  });

  group('IncidentMarkdownExporter.export — empty/incomplete', () {
    test('empty analysis: no reproduction steps or timeline sections', () {
      final incident = _incident();
      final analysis = IncidentAnalyzer.analyze(incident);
      final markdown = IncidentMarkdownExporter.export(incident, analysis);

      expect(markdown, isNot(contains('## Reproduction steps')));
      expect(markdown, isNot(contains('## Technical evidence')));
      expect(markdown, isNot(contains('## Network')));
      expect(markdown, isNot(contains('## Errors')));
    });

    test('no QA report: section omitted entirely', () {
      final incident = _incident(qaReport: null);
      final analysis = IncidentAnalyzer.analyze(incident);
      final markdown = IncidentMarkdownExporter.export(incident, analysis);

      expect(markdown, isNot(contains('## QA report')));
    });

    test(
      'a QA report with only a severity (no expected/actual) is also omitted',
      () {
        final incident = _incident(
          qaReport: const QaReportData(severity: IncidentSeverity.low),
        );
        final analysis = IncidentAnalyzer.analyze(incident);
        final markdown = IncidentMarkdownExporter.export(incident, analysis);

        expect(markdown, isNot(contains('## QA report')));
      },
    );

    test('reproduction steps present but no network activity at all', () {
      final incident = _incident(
        timeline: [
          _event(
            id: '1',
            category: EventCategory.action,
            name: 'save_tapped',
            timestamp: _at(0),
          ),
        ],
      );
      final analysis = IncidentAnalyzer.analyze(incident);
      final markdown = IncidentMarkdownExporter.export(incident, analysis);

      expect(markdown, contains('## Reproduction steps'));
      expect(markdown, isNot(contains('## Network')));
      expect(markdown, isNot(contains('## Errors')));
    });

    test('network failure with no preceding user action', () {
      final incident = _incident(
        timeline: [
          _event(
            id: '1',
            category: EventCategory.network,
            name: 'GET /config',
            timestamp: _at(0),
            metadata: const {
              'method': 'GET',
              'url': '/config',
              'statusCode': 500,
            },
          ),
        ],
      );
      final analysis = IncidentAnalyzer.analyze(incident);
      final markdown = IncidentMarkdownExporter.export(incident, analysis);

      expect(markdown, contains('## Network'));
      expect(markdown, contains('- GET /config'));
      expect(markdown, contains('- Status: 500'));
      expect(markdown, isNot(contains('## Reproduction steps ->')));
    });

    test('no environment metadata: section omitted', () {
      final incident = _incident(context: const {});
      final analysis = IncidentAnalyzer.analyze(incident);
      final markdown = IncidentMarkdownExporter.export(incident, analysis);

      expect(markdown, isNot(contains('## Environment')));
    });

    test(
      'empty timeline: the report still looks intentional, not broken',
      () {
        final incident = _incident(timeline: const []);
        final analysis = IncidentAnalyzer.analyze(incident);
        final markdown = IncidentMarkdownExporter.export(incident, analysis);

        expect(markdown, isNot(contains('## Technical evidence')));
        expect(markdown, isNot(contains('| Time | Event |')));
        // Still a complete, well-formed document: title, story, metadata.
        expect(markdown, startsWith('# '));
        expect(markdown, contains('## What happened?'));
        expect(markdown, contains('## Incident'));
      },
    );

    test('no trigger: the metadata section omits the Trigger line', () {
      final incident = _incident(trigger: null);
      final analysis = IncidentAnalyzer.analyze(incident);
      final markdown = IncidentMarkdownExporter.export(incident, analysis);

      expect(markdown, isNot(contains('- Trigger:')));
    });
  });

  group('IncidentMarkdownExporter.export — formatting safety', () {
    test('a pipe in event data does not break the table structure', () {
      final incident = _incident(
        timeline: [
          _event(
            id: '1',
            category: EventCategory.error,
            name: 'Error: a | b | c',
            timestamp: _at(0),
          ),
        ],
      );
      final analysis = IncidentAnalyzer.analyze(incident);
      final markdown = IncidentMarkdownExporter.export(incident, analysis);

      // The Technical evidence table row specifically — not the "What
      // happened?" story line, where a bare `|` is harmless prose (only
      // a table cell needs pipe-escaping).
      final tableLine = markdown
          .split('\n')
          .firstWhere((line) => line.startsWith('| 14:32:10'));
      expect(tableLine, contains(r'a \| b \| c'));
      // Every pipe inside the cell value is escaped — only the two
      // structural pipes (the row's own delimiters) remain unescaped.
      final unescapedPipes = RegExp(r'(?<!\\)\|').allMatches(tableLine);
      expect(unescapedPipes.length, 3); // leading | Time | Event |
    });

    test('backticks in event data are escaped, not left to break formatting',
        () {
      final incident = _incident(
        timeline: [
          _event(
            id: '1',
            category: EventCategory.error,
            name: '`rm -rf /`Exception',
            timestamp: _at(0),
          ),
        ],
      );
      final analysis = IncidentAnalyzer.analyze(incident);
      final markdown = IncidentMarkdownExporter.export(incident, analysis);

      expect(markdown, contains(r'\`rm -rf /\`Exception'));
    });

    test('a multiline value is collapsed to a single line', () {
      final incident = _incident(
        timeline: [
          _event(
            id: '1',
            category: EventCategory.error,
            name: 'Multi\nLine\nError',
            timestamp: _at(0),
          ),
        ],
      );
      final analysis = IncidentAnalyzer.analyze(incident);
      final markdown = IncidentMarkdownExporter.export(incident, analysis);

      // Collapsed to one line wherever it appears (story, reproduction
      // step, table row, and the Errors list all describe this one
      // event — appearing in several sections is expected and correct;
      // what matters is that none of them ever split across lines).
      expect(markdown, contains('Multi Line Error'));
      expect(markdown, isNot(contains('Multi\nLine')));
      expect(markdown, isNot(contains('Line\nError')));
    });

    test('a long value does not crash and remains a single table row', () {
      final longName = 'X' * 5000;
      final incident = _incident(
        timeline: [
          _event(
            id: '1',
            category: EventCategory.error,
            name: longName,
            timestamp: _at(0),
          ),
        ],
      );
      final analysis = IncidentAnalyzer.analyze(incident);
      final markdown = IncidentMarkdownExporter.export(incident, analysis);

      // Nothing is truncated or corrupted — the full value survives,
      // wherever it appears (see the multiline test above for why it's
      // legitimately expected in more than one section).
      expect(markdown, contains(longName));
    });

    test('unicode content is preserved as-is', () {
      final incident = _incident(
        timeline: [
          _event(
            id: '1',
            category: EventCategory.action,
            name: 'tapped_日本語_émoji_🚀',
            timestamp: _at(0),
          ),
        ],
      );
      final analysis = IncidentAnalyzer.analyze(incident);
      final markdown = IncidentMarkdownExporter.export(incident, analysis);

      expect(markdown, contains('日本語'));
      expect(markdown, contains('émoji'));
      expect(markdown, contains('🚀'));
    });

    test('an empty string value renders without crashing', () {
      final incident = _incident(
        timeline: [
          _event(
            id: '1',
            category: EventCategory.error,
            name: '',
            timestamp: _at(0),
          ),
        ],
      );
      final analysis = IncidentAnalyzer.analyze(incident);
      expect(
        () => IncidentMarkdownExporter.export(incident, analysis),
        returnsNormally,
      );
    });

    test(
        'a backslash in event data is escaped so it cannot introduce an unintended escape sequence',
        () {
      final incident = _incident(
        timeline: [
          _event(
            id: '1',
            category: EventCategory.error,
            name: r'C:\Users\test',
            timestamp: _at(0),
          ),
        ],
      );
      final analysis = IncidentAnalyzer.analyze(incident);
      final markdown = IncidentMarkdownExporter.export(incident, analysis);

      expect(markdown, contains(r'C:\\Users\\test'));
    });
  });

  group('IncidentMarkdownExporter.export — privacy', () {
    test(
      'sensitive metadata values cannot appear in the Markdown, only what the '
      'core Sanitizer already masked',
      () {
        // Simulates what a real FlightEvent looks like after Sanitizer has
        // already run — this exporter reads FlightEvent.metadata as given
        // and performs no separate data path or masking of its own.
        final incident = _incident(
          timeline: [
            _event(
              id: '1',
              category: EventCategory.action,
              name: 'login_tapped',
              timestamp: _at(0),
              metadata: const {'password': '***'},
            ),
            _event(
              id: '2',
              category: EventCategory.network,
              name: 'POST /login',
              timestamp: _at(1),
              metadata: const {
                'method': 'POST',
                'url': '/login',
                'statusCode': 401,
                'accessToken': '***',
                'refreshToken': '***',
                'authorization': '***',
              },
            ),
          ],
        );
        final analysis = IncidentAnalyzer.analyze(incident);
        final markdown = IncidentMarkdownExporter.export(incident, analysis);

        for (final secret in [
          'password',
          'accessToken',
          'refreshToken',
          'authorization',
          'Authorization',
        ]) {
          expect(
            markdown,
            isNot(contains(secret)),
            reason: '"$secret" (a metadata key, not a masked value) leaked',
          );
        }
      },
    );

    test(
      'an already-masked value (***) is not re-exposed or re-derived',
      () {
        final incident = _incident(
          timeline: [
            _event(
              id: '1',
              category: EventCategory.network,
              name: 'POST /login',
              timestamp: _at(0),
              metadata: const {
                'method': 'POST',
                'url': '/login?token=***',
                'statusCode': 401,
              },
            ),
          ],
        );
        final analysis = IncidentAnalyzer.analyze(incident);
        final markdown = IncidentMarkdownExporter.export(incident, analysis);

        // The masked marker survives, Markdown-escaped (`\*` so it can
        // never be misread as emphasis syntax) — it still reads as
        // "***" once rendered, and the real token is never derived or
        // re-exposed.
        expect(markdown, contains(r'\*\*\*'));
        expect(markdown, isNot(matches(RegExp(r'token=(?!\\\*\\\*\\\*)\S+'))));
      },
    );

    test(
        'QA-provided expected/actual text is passed through verbatim, unmasked '
        '— it is human-written report text, not recorder metadata', () {
      final incident = _incident(
        qaReport: const QaReportData(
          expected: 'Should not show a password field.',
          actual: 'Password field visible.',
        ),
      );
      final analysis = IncidentAnalyzer.analyze(incident);
      final markdown = IncidentMarkdownExporter.export(incident, analysis);

      expect(markdown, contains('Should not show a password field.'));
    });
  });

  group('IncidentMarkdownExporter.export — determinism', () {
    test(
        'the same Incident/IncidentAnalysis pair always produces identical Markdown',
        () {
      final incident = _incident(
        timeline: [
          _event(
            id: '1',
            category: EventCategory.action,
            name: 'save_tapped',
            timestamp: _at(0),
          ),
          _event(
            id: '2',
            category: EventCategory.network,
            name: 'PATCH /profile',
            timestamp: _at(1),
            metadata: const {
              'method': 'PATCH',
              'url': '/profile',
              'statusCode': 422,
            },
          ),
        ],
      );
      final analysis = IncidentAnalyzer.analyze(incident);

      final first = IncidentMarkdownExporter.export(incident, analysis);
      final second = IncidentMarkdownExporter.export(incident, analysis);
      final third = IncidentMarkdownExporter.export(
        incident,
        IncidentAnalyzer.analyze(incident),
      );

      expect(first, second);
      expect(first, third);
    });
  });

  group('IncidentMarkdownExporter.export — golden', () {
    test(
      'a complete incident produces the exact expected Markdown document '
      '(fails loudly on any accidental format change)',
      () {
        final incident = Incident(
          id: 'INC-7F8A2D',
          timestamp: DateTime.utc(2026, 1, 1, 14, 32, 24),
          title: 'Profile update failed',
          qaReport: const QaReportData(
            expected: 'Profile should be saved successfully.',
            actual: 'A validation error appears instead.',
            severity: IncidentSeverity.high,
          ),
          trigger: 'shake',
          context: const {'platform': 'iOS', 'environment': 'uat'},
          timeline: [
            _event(
              id: '1',
              category: EventCategory.navigation,
              name: '/profile',
              timestamp: _t0,
              metadata: const {'action': 'push'},
            ),
            _event(
              id: '2',
              category: EventCategory.navigation,
              name: '/profile/edit',
              timestamp: _at(3),
              metadata: const {'action': 'push'},
            ),
            _event(
              id: '3',
              category: EventCategory.action,
              name: 'save_tapped',
              timestamp: _at(11),
            ),
            _event(
              id: '4',
              category: EventCategory.network,
              name: 'PATCH /profile',
              timestamp: _at(11),
              metadata: const {
                'method': 'PATCH',
                'url': '/profile',
                'statusCode': 422,
                'durationMs': 842,
              },
            ),
            _event(
              id: '5',
              category: EventCategory.error,
              name: 'ProfileUpdateException',
              timestamp: _at(12),
            ),
          ],
        );
        final analysis = IncidentAnalyzer.analyze(incident);
        final markdown = IncidentMarkdownExporter.export(incident, analysis);

        expect(markdown, '''
# Profile update failed

## What happened?

After tapping 'save tapped', the PATCH /profile request returned HTTP 422, followed by ProfileUpdateException.

## QA report

- **Expected:** Profile should be saved successfully.
- **Actual:** A validation error appears instead.
- **Severity:** high

## Reproduction steps

1. Open profile
2. Open profile/edit
3. Tap 'save tapped'
4. PATCH /profile request returned HTTP 422
5. ProfileUpdateException occurred

## Technical evidence

| Time | Event |
|---|---|
| 14:32:10 | Opened profile |
| 14:32:13 | Opened profile/edit |
| 14:32:21 | Tapped 'save tapped' |
| 14:32:21 | PATCH /profile → HTTP 422 |
| 14:32:22 | ProfileUpdateException occurred |

## Network

- PATCH /profile
  - Status: 422
  - Duration: 842ms

## Errors

- ProfileUpdateException

## Environment

- platform: iOS
- environment: uat

## Incident

- Incident ID: INC-7F8A2D
- Reported: 2026-01-01T14:32:24.000Z
- Trigger: shake''');
      },
    );
  });
}
