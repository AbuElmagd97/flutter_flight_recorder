import '../events/flight_event.dart';
import 'analysis/incident_analysis.dart';
import 'incident.dart';

/// Renders an [Incident] and its [IncidentAnalysis] as a single Markdown
/// bug report — meant to be pasted directly into Jira, Linear, GitHub
/// Issues, Slack, email, or any other Markdown-friendly tracker.
///
/// This is a pure formatter, nothing more: it never analyzes events,
/// performs correlation, infers reproduction steps, or generates the
/// incident story — all of that is [analysis]'s job, computed once by
/// [IncidentAnalyzer.analyze] and passed in here. [export] only decides
/// how to lay out already-computed values as Markdown, the same
/// separation `IncidentHtmlReport` (in the `flutter_flight_recorder_reporter`
/// package) keeps for HTML.
///
/// Sections appear in scan-order — the questions a developer actually
/// asks first, before any metadata:
///
/// 1. What happened? (`analysis.story`)
/// 2. QA report, if one was filed (`incident.qaReport`)
/// 3. Reproduction steps, if any were inferred (`analysis.reproductionSteps`)
/// 4. Technical evidence: the normalized timeline (`analysis.timeline`)
/// 5. Network activity, if any (extracted from the same timeline)
/// 6. Errors, if any (extracted from the same timeline)
/// 7. Environment (`incident.context`), if any was set
/// 8. Incident metadata (id, timestamp, trigger) — last, deliberately,
///    since it's the least useful line for a developer scanning the
///    report, not the first.
///
/// A section is omitted entirely when there's nothing to show for it —
/// this never renders a `## Errors\n\nNone` placeholder.
///
/// Every value written into Markdown already passed through
/// `FlightRecorder`'s own privacy sanitization before it ever entered
/// [Incident.timeline] (see `Sanitizer`) — this exporter has no separate
/// data path and performs no masking of its own; it only escapes
/// characters that would otherwise break Markdown syntax (`|`, `` ` ``,
/// backslash, embedded newlines), never redacts content for privacy.
///
/// Deterministic: the same [Incident]/[IncidentAnalysis] pair always
/// produces byte-identical Markdown.
class IncidentMarkdownExporter {
  const IncidentMarkdownExporter._();

  /// Renders [incident] and its precomputed [analysis] as a Markdown
  /// document. Callers that already ran `IncidentAnalyzer.analyze(incident)`
  /// (e.g. to show a preview screen) should reuse that same result here
  /// rather than analyzing twice.
  static String export(Incident incident, IncidentAnalysis analysis) {
    final sections = <String>[
      '# ${incident.title}',
      _whatHappened(analysis),
      if (_qaReport(incident) case final section?) section,
      if (_reproductionSteps(analysis) case final section?) section,
      if (_technicalEvidence(analysis) case final section?) section,
      if (_network(analysis) case final section?) section,
      if (_errors(analysis) case final section?) section,
      if (_environment(incident) case final section?) section,
      _incidentMetadata(incident),
    ];
    return sections.join('\n\n');
  }

  static String _whatHappened(IncidentAnalysis analysis) =>
      '## What happened?\n\n${_escapeInline(analysis.story.summary)}';

  static String? _qaReport(Incident incident) {
    final qa = incident.qaReport;
    if (qa == null || (qa.expected == null && qa.actual == null)) return null;

    final lines = <String>[
      if (qa.expected != null) '- **Expected:** ${_escapeInline(qa.expected!)}',
      if (qa.actual != null) '- **Actual:** ${_escapeInline(qa.actual!)}',
      if (qa.severity != null) '- **Severity:** ${qa.severity!.name}',
    ];
    return '## QA report\n\n${lines.join('\n')}';
  }

  static String? _reproductionSteps(IncidentAnalysis analysis) {
    if (analysis.reproductionSteps.isEmpty) return null;
    final lines = analysis.reproductionSteps
        .map((step) => '${step.index}. ${_escapeInline(step.description)}')
        .join('\n');
    return '## Reproduction steps\n\n$lines';
  }

  static String? _technicalEvidence(IncidentAnalysis analysis) {
    if (analysis.timeline.isEmpty) return null;
    final rows = analysis.timeline.entries
        .map(
          (entry) =>
              '| ${_formatTime(entry.event.timestamp)} | ${_escapeCell(entry.summary)} |',
        )
        .join('\n');
    return '## Technical evidence\n\n'
        '| Time | Event |\n'
        '|---|---|\n'
        '$rows';
  }

  static String? _network(IncidentAnalysis analysis) {
    final networkEntries = analysis.timeline.entries
        .where((entry) => entry.event.category == EventCategory.network)
        .toList(growable: false);
    if (networkEntries.isEmpty) return null;

    final blocks = networkEntries.map((entry) {
      final event = entry.event;
      final method = event.metadata['method'];
      final url = event.metadata['url'] ?? event.name;
      final statusCode = event.metadata['statusCode'];
      final durationMs = event.metadata['durationMs'];
      final errorType = event.metadata['errorType'];
      final label = method != null ? '$method $url' : '$url';

      final lines = <String>[
        '- ${_escapeInline(label.toString())}',
        if (statusCode != null) '  - Status: $statusCode',
        if (durationMs != null) '  - Duration: ${durationMs}ms',
        if (errorType != null)
          '  - Error: ${_escapeInline(errorType.toString())}',
      ];
      return lines.join('\n');
    }).join('\n');

    return '## Network\n\n$blocks';
  }

  static String? _errors(IncidentAnalysis analysis) {
    final errorEntries = analysis.timeline.entries
        .where((entry) => entry.event.category == EventCategory.error)
        .toList(growable: false);
    if (errorEntries.isEmpty) return null;

    final lines = errorEntries
        .map((entry) => '- ${_escapeInline(entry.event.name)}')
        .join('\n');
    return '## Errors\n\n$lines';
  }

  static String? _environment(Incident incident) {
    if (incident.context.isEmpty) return null;
    final lines = incident.context.entries
        .map((entry) => '- ${entry.key}: ${_escapeInline('${entry.value}')}')
        .join('\n');
    return '## Environment\n\n$lines';
  }

  static String _incidentMetadata(Incident incident) {
    final lines = <String>[
      '- Incident ID: ${incident.id}',
      '- Reported: ${incident.timestamp.toIso8601String()}',
      if (incident.trigger != null) '- Trigger: ${incident.trigger}',
    ];
    return '## Incident\n\n${lines.join('\n')}';
  }

  static String _formatTime(DateTime timestamp) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(timestamp.hour)}:${two(timestamp.minute)}:${two(timestamp.second)}';
  }

  /// Safe for a single inline Markdown line: collapses embedded newlines
  /// to spaces (a raw newline would otherwise end the line, or the list
  /// item / table row it's part of) and escapes characters that would
  /// otherwise be parsed as Markdown syntax.
  ///
  /// Deliberately does not escape `_`: CommonMark (and GitHub's renderer)
  /// only treats `_` as emphasis at a word boundary, not mid-identifier —
  /// so `save_tapped` or `/user_profile` already render as plain text.
  /// Escaping it anyway would turn every snake_case action name and
  /// underscore-containing URL into visual noise (`save\_tapped`) for no
  /// actual safety benefit.
  static String _escapeInline(String value) {
    final singleLine = value
        .replaceAll('\r\n', ' ')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ');
    return singleLine
        .replaceAll('\\', r'\\')
        .replaceAll('`', r'\`')
        .replaceAll('*', r'\*');
  }

  /// [_escapeInline] plus escaping `|`, which is only special inside a
  /// table cell — escaping it in a plain list item would be unnecessary
  /// noise.
  static String _escapeCell(String value) =>
      _escapeInline(value).replaceAll('|', r'\|');
}
