import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';
import 'package:flutter_flight_recorder_reporter/src/export/incident_html_report.dart';
import 'package:flutter_flight_recorder_reporter/src/severity_colors.dart';
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

Incident _incident({
  IncidentSeverity? severity,
  List<FlightEvent> timeline = const [],
  String? expected,
  String? actual,
  Map<String, Object?> context = const {},
}) {
  return Incident(
    id: 'INC-ABCDEF',
    timestamp: DateTime.utc(2026, 1, 1, 12),
    title: 'Profile update failed',
    qaReport: (severity == null && expected == null && actual == null)
        ? null
        : QaReportData(severity: severity, expected: expected, actual: actual),
    timeline: timeline,
    context: context,
  );
}

void main() {
  group('IncidentHtmlReport', () {
    test('is a complete, self-contained HTML document', () {
      final html = IncidentHtmlReport.render(_incident());
      expect(html, startsWith('<!DOCTYPE html>'));
      expect(html, contains('<style>'));
      expect(html, isNot(contains('<link ')));
      expect(html, isNot(contains('<script src')));
      expect(html, contains('</html>'));
    });

    test('contains the incident id and title', () {
      final html = IncidentHtmlReport.render(_incident());
      expect(html, contains('INC-ABCDEF'));
      expect(html, contains('Profile update failed'));
    });

    for (final severity in IncidentSeverity.values) {
      test('uses the correct header color for $severity', () {
        final html = IncidentHtmlReport.render(_incident(severity: severity));
        expect(html, contains(severityColorHex[severity]!));
      });
    }

    test('renders expected/actual QA report fields when present', () {
      final html = IncidentHtmlReport.render(
        _incident(expected: 'Profile should save.', actual: 'Error appears.'),
      );
      expect(html, contains('Profile should save.'));
      expect(html, contains('Error appears.'));
    });

    test('omits the QA report card when there is nothing to show', () {
      final html = IncidentHtmlReport.render(_incident());
      expect(html, isNot(contains('QA Report')));
    });

    test('includes a Latest Error callout when an error is present', () {
      final html = IncidentHtmlReport.render(
        _incident(timeline: [_event(EventCategory.error, 'DioException')]),
      );
      expect(html, contains('Latest Error'));
      expect(html, contains('DioException'));
    });

    test('omits the Latest Error callout when there is no error', () {
      final html = IncidentHtmlReport.render(
        _incident(timeline: [_event(EventCategory.action, 'tapped')]),
      );
      expect(html, isNot(contains('Latest Error')));
    });

    test('the error still appears again inside the full timeline too', () {
      // Intentional, not a duplicate to remove — matches the existing
      // derived-view design (Incident.latestError is a view over the
      // same timeline, not separate storage).
      final html = IncidentHtmlReport.render(
        _incident(timeline: [_event(EventCategory.error, 'DioException')]),
      );
      expect('DioException'.allMatches(html).length, greaterThanOrEqualTo(2));
    });

    test('embeds the screenshot as a base64 img tag when present', () {
      final screenshot = Uint8List.fromList([1, 2, 3, 4]);
      final html = IncidentHtmlReport.render(
        _incident(),
        screenshot: screenshot,
      );
      final expectedBase64 = base64Encode(screenshot);
      expect(html, contains('data:image/png;base64,$expectedBase64'));
    });

    test('omits the screenshot section entirely when absent', () {
      final html = IncidentHtmlReport.render(_incident());
      expect(html, isNot(contains('data:image/png;base64,')));
      expect(html, isNot(contains('<img')));
    });

    test('renders one timeline row per event with a category label', () {
      final html = IncidentHtmlReport.render(
        _incident(
          timeline: [
            _event(EventCategory.navigation, 'edit_profile'),
            _event(EventCategory.action, 'save_profile_tapped'),
            _event(
              EventCategory.network,
              'PATCH /profile',
              metadata: {
                'method': 'PATCH',
                'url': '/profile',
                'statusCode': 422,
              },
            ),
          ],
        ),
      );
      expect(html, contains('edit_profile'));
      expect(html, contains('save_profile_tapped'));
      expect(html, contains('PATCH /profile'));
      expect(html, contains('HTTP 422'));
    });

    test('an action event with metadata renders a non-empty metadata line', () {
      final html = IncidentHtmlReport.render(
        _incident(
          timeline: [
            _event(
              EventCategory.action,
              'save_profile_tapped',
              metadata: {'screen': 'home'},
            ),
          ],
        ),
      );
      expect(html, contains('<div class="timeline-meta">screen: home</div>'));
    });

    test('a log event with metadata renders a non-empty metadata line', () {
      final html = IncidentHtmlReport.render(
        _incident(
          timeline: [
            _event(
              EventCategory.log,
              'Profile update started',
              metadata: {'userId': 42},
            ),
          ],
        ),
      );
      expect(html, contains('<div class="timeline-meta">userId: 42</div>'));
    });

    test(
      'an action event with no metadata omits the metadata line entirely, no stray separator',
      () {
        final html = IncidentHtmlReport.render(
          _incident(
            timeline: [_event(EventCategory.action, 'save_profile_tapped')],
          ),
        );
        // Checking for the actual rendered element, not just the
        // substring "timeline-meta" — that also appears in the <style>
        // block's CSS rule regardless of whether any row uses it.
        expect(html, isNot(contains('<div class="timeline-meta">')));
        expect(html, isNot(contains(' · ')));
        expect(html, isNot(contains('·')));
      },
    );

    test('includes schema_version and context in the footer', () {
      final html = IncidentHtmlReport.render(
        _incident(context: {'platform': 'android', 'environment': 'uat'}),
      );
      expect(html, contains('schema_version $incidentSchemaVersion'));
      expect(html, contains('platform: android'));
      expect(html, contains('environment: uat'));
    });

    test(
      'renders only what the core Sanitizer already masked, never a raw value',
      () {
        // Proves this renderer has no separate data path of its own: it
        // goes through the real FlightRecorder end to end (which
        // sanitizes metadata before an event ever enters the buffer,
        // same mechanism as core's own privacy tests), then renders
        // whatever Incident it gets. The masked marker must appear, and
        // the raw secret must never appear, because the renderer never
        // had access to it in the first place.
        FlightRecorder.resetForTest();
        FlightRecorder.init();
        addTearDown(FlightRecorder.resetForTest);

        FlightRecorder.recordNetwork(
          'POST /login',
          metadata: {'method': 'POST', 'url': '/login', 'password': 'hunter2'},
        );
        final incident = FlightRecorder.createIncident(title: 'Login failed');

        // Confirms core's Sanitizer actually masked it before this test
        // even gets to the renderer — the interesting claim below is
        // about the renderer, not a re-test of core's own privacy suite.
        expect(incident.timeline.single.metadata['password'], '***');

        final html = IncidentHtmlReport.render(incident);

        expect(html, isNot(contains('hunter2')));
      },
    );

    test('HTML-escapes user-supplied text so it cannot break the markup', () {
      final html = IncidentHtmlReport.render(
        _incident(
          expected: '<script>alert(1)</script>',
          actual: 'A & B "quoted"',
        ),
      );
      expect(html, isNot(contains('<script>alert(1)</script>')));
      expect(html, contains('&lt;script&gt;'));
      expect(html, contains('&amp;'));
      expect(html, contains('&quot;quoted&quot;'));
    });

    test('handles an empty timeline honestly', () {
      final html = IncidentHtmlReport.render(_incident());
      expect(html, contains('No events were recorded.'));
    });

    test('includes a "What Happened?" card built from the recorded evidence', () {
      final html = IncidentHtmlReport.render(
        _incident(
          timeline: [
            _event(EventCategory.action, 'save_tapped'),
            _event(
              EventCategory.network,
              'PATCH /profile',
              metadata: const {
                'method': 'PATCH',
                'url': '/profile',
                'statusCode': 422,
              },
            ),
          ],
        ),
      );

      expect(html, contains('What Happened?'));
      expect(
        html,
        contains(
          'After tapping &#39;save tapped&#39;, the PATCH /profile request returned HTTP 422.',
        ),
      );
    });

    test(
      'includes numbered Reproduction Steps when there is evidence for them',
      () {
        final html = IncidentHtmlReport.render(
          _incident(
            timeline: [
              _event(
                EventCategory.navigation,
                '/profile',
                metadata: const {'action': 'push'},
              ),
              _event(EventCategory.action, 'save_tapped'),
            ],
          ),
        );

        expect(html, contains('Reproduction Steps'));
        expect(html, contains('<li>Open profile</li>'));
        expect(html, contains('<li>Tap &#39;save tapped&#39;</li>'));
      },
    );

    test(
      'omits the Reproduction Steps card when there is no evidence for any step',
      () {
        final html = IncidentHtmlReport.render(_incident());
        expect(html, isNot(contains('Reproduction Steps')));
      },
    );
  });
}
