import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';

/// Generates a deterministic, human-readable narrative from an incident's
/// recorded timeline.
///
/// This is event-based summarization, not AI, and not causation analysis
/// — it describes what was recorded, in order, and nothing it wasn't
/// recorded. If information is unavailable (e.g. a network event has no
/// duration), the corresponding clause is omitted rather than invented.
///
/// `log` and `lifecycle` category events are deliberately left out of the
/// narrative — they're development-facing detail (log lines, app
/// backgrounding/foregrounding), not the user-journey story this is
/// meant to read as. They remain in `incident.timeline` and
/// `incident.logs` for anyone who wants them; this function just doesn't
/// narrate them.
class BugStoryGenerator {
  const BugStoryGenerator._();

  static String generate(Incident incident) {
    if (incident.timeline.isEmpty) {
      return 'No events were recorded before this incident.';
    }

    final sentences = <String>[];
    for (final event in incident.timeline) {
      switch (event.category) {
        case EventCategory.navigation:
          sentences.addAll(_describeNavigation(event));
        case EventCategory.action:
          sentences.add(_describeAction(event));
        case EventCategory.network:
          sentences.addAll(_describeNetwork(event));
        case EventCategory.error:
          sentences.add(_describeError(event));
        case EventCategory.log:
        case EventCategory.lifecycle:
          break;
      }
    }

    if (sentences.isEmpty) {
      return 'No user-facing events were recorded before this incident.';
    }

    if (incident.latestError != null) {
      sentences.add('The error was recorded and attached to this incident.');
    }

    return sentences.join(' ');
  }

  static List<String> _describeNavigation(FlightEvent event) {
    final screen = _describeRoute(event.name);
    final action = event.metadata['action'];
    return switch (action) {
      'push' => ['The user opened the $screen screen.'],
      'pop' => ['The user navigated back from the $screen screen.'],
      _ => ['The user navigated to the $screen screen.'],
    };
  }

  static String _describeAction(FlightEvent event) {
    final action = event.name.replaceAll('_', ' ').trim();
    return "The user tapped '$action'.";
  }

  static List<String> _describeNetwork(FlightEvent event) {
    final method = event.metadata['method'] ?? '';
    final url = event.metadata['url'] ?? event.name;
    final statusCode = event.metadata['statusCode'];
    final durationMs = event.metadata['durationMs'];
    final errorType = event.metadata['errorType'];

    final sentences = <String>[
      'The application sent a $method request to $url.',
    ];

    final durationClause = durationMs is int
        ? ' after ${(durationMs / 1000).toStringAsFixed(1)} seconds'
        : '';

    if (errorType != null && statusCode == null) {
      sentences.add('The request failed ($errorType)$durationClause.');
    } else if (statusCode is int && statusCode >= 400) {
      sentences.add('The request failed with HTTP $statusCode$durationClause.');
    } else if (statusCode is int) {
      sentences.add(
        'The request completed with HTTP $statusCode$durationClause.',
      );
    }

    return sentences;
  }

  static String _describeError(FlightEvent event) {
    return 'An error was recorded: ${event.name}.';
  }

  static String _describeRoute(String name) {
    if (name.isEmpty || name == '/' || name == '<unnamed>') return 'app';
    return name.replaceFirst(RegExp(r'^/'), '').replaceAll('_', ' ');
  }
}
