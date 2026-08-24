import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';

import '../severity_colors.dart';

const Map<EventCategory, String> _categoryColorHex = {
  EventCategory.navigation: '#1565C0',
  EventCategory.network: '#6A1B9A',
  EventCategory.action: '#00838F',
  EventCategory.log: '#616161',
  EventCategory.error: '#C62828',
  EventCategory.lifecycle: '#8D6E63',
};

const Map<EventCategory, String> _categoryEmoji = {
  EventCategory.navigation: '🧭',
  EventCategory.network: '📶',
  EventCategory.action: '👆',
  EventCategory.log: '📝',
  EventCategory.error: '⚠️',
  EventCategory.lifecycle: '🔄',
};

/// Renders an [Incident] as a single, self-contained HTML document —
/// pure Dart string templating with inline `<style>` CSS. No external
/// stylesheet/script/network call, no new package dependency.
///
/// Everything rendered here is read directly from the already-sanitized
/// [Incident] object — event metadata was masked by the core package's
/// `Sanitizer` before it ever entered the buffer (see
/// `FlightRecorder`/`Sanitizer` in the core package). This renderer
/// never sees raw unsanitized data and never re-sanitizes anything; it
/// only HTML-escapes values for safe rendering.
class IncidentHtmlReport {
  const IncidentHtmlReport._();

  static String render(Incident incident, {Uint8List? screenshot}) {
    final severity = incident.qaReport?.severity;
    final error = incident.latestError;

    final buffer = StringBuffer()
      ..writeln('<!DOCTYPE html>')
      ..writeln('<html lang="en">')
      ..writeln('<head>')
      ..writeln('<meta charset="UTF-8">')
      ..writeln(
        '<meta name="viewport" content="width=device-width, initial-scale=1">',
      )
      ..writeln(
        '<title>${_escape(incident.id)} — ${_escape(incident.title)}</title>',
      )
      ..writeln('<style>$_css</style>')
      ..writeln('</head>')
      ..writeln('<body>')
      ..writeln('<div class="container">')
      ..writeln(_renderHeader(incident, severity))
      ..writeln(_renderQaReport(incident))
      ..writeln(_renderErrorCallout(error))
      ..writeln(_renderScreenshot(screenshot))
      ..writeln(_renderTimeline(incident))
      ..writeln(_renderFooter(incident))
      ..writeln('</div>')
      ..writeln('</body>')
      ..writeln('</html>');

    return buffer.toString();
  }

  static String _renderHeader(Incident incident, IncidentSeverity? severity) {
    final backgroundColor = severity != null
        ? severityColorHex[severity]!
        : '#455A64';
    return '''
<div class="header" style="background:$backgroundColor;">
  <div class="incident-id">${_escape(incident.id)}</div>
  <h1>${_escape(incident.title)}</h1>
  <div class="meta">${_escape(incident.timestamp.toIso8601String())}</div>
  ${severity != null ? '<span class="badge">${_escape(severityLabel(severity).toUpperCase())}</span>' : ''}
</div>''';
  }

  static String _renderQaReport(Incident incident) {
    final qa = incident.qaReport;
    if (qa == null || (qa.expected == null && qa.actual == null)) return '';

    final fields = StringBuffer();
    if (qa.expected != null) {
      fields.write(_field('Expected', qa.expected!));
    }
    if (qa.actual != null) {
      fields.write(_field('Actual', qa.actual!));
    }
    return '<div class="card"><h2>QA Report</h2>$fields</div>';
  }

  static String _renderErrorCallout(FlightEvent? error) {
    if (error == null) return '';
    return '''
<div class="error-callout">
  <h2>⚠️ Latest Error</h2>
  ${_field('Type', error.name)}
  ${_field('Time', error.timestamp.toIso8601String())}
</div>''';
  }

  static String _renderScreenshot(Uint8List? screenshot) {
    if (screenshot == null) return '';
    final base64Data = base64Encode(screenshot);
    return '''
<div class="card">
  <h2>Screenshot</h2>
  <img class="screenshot" src="data:image/png;base64,$base64Data" alt="Screenshot">
</div>''';
  }

  static String _renderTimeline(Incident incident) {
    if (incident.timeline.isEmpty) {
      return '<div class="card"><h2>Timeline</h2>'
          '<div class="value">No events were recorded.</div></div>';
    }
    final rows = incident.timeline.map(_renderTimelineRow).join();
    return '<div class="card"><h2>Timeline</h2>$rows</div>';
  }

  static String _renderTimelineRow(FlightEvent event) {
    final color = _categoryColorHex[event.category]!;
    final emoji = _categoryEmoji[event.category]!;
    final summary = _eventSummary(event);
    return '''
<div class="timeline-row">
  <div class="timeline-icon" style="background:$color;">$emoji</div>
  <div class="timeline-body">
    <div class="timeline-name">${_escape(event.name)}</div>
    <div class="timeline-time">${_escape(event.timestamp.toIso8601String())}</div>
    ${summary != null && summary.isNotEmpty ? '<div class="timeline-meta">${_escape(summary)}</div>' : ''}
  </div>
</div>''';
  }

  static String? _eventSummary(FlightEvent event) {
    switch (event.category) {
      case EventCategory.navigation:
        final action = event.metadata['action'];
        final from = event.metadata['from'];
        return [
          if (action != null) 'action: $action',
          if (from != null) 'from: $from',
        ].join(' · ');
      case EventCategory.network:
        final method = event.metadata['method'];
        final url = event.metadata['url'];
        final statusCode = event.metadata['statusCode'];
        final durationMs = event.metadata['durationMs'];
        final errorType = event.metadata['errorType'];
        return [
          if (method != null && url != null) '$method $url',
          if (statusCode != null) 'HTTP $statusCode',
          if (durationMs != null) '${durationMs}ms',
          if (errorType != null) '$errorType',
        ].join(' · ');
      case EventCategory.error:
        return event.metadata['error']?.toString();
      case EventCategory.action:
      case EventCategory.log:
        // No fixed set of well-known fields for these two categories
        // (unlike navigation/network/error) — render whatever metadata
        // was actually recorded, generically, in the same "key: value"
        // style. Omit the line entirely when there's nothing to show,
        // rather than an empty/placeholder separator.
        return _genericMetadataSummary(event);
      case EventCategory.lifecycle:
        return null;
    }
  }

  static String? _genericMetadataSummary(FlightEvent event) {
    if (event.metadata.isEmpty) return null;
    return event.metadata.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(' · ');
  }

  static String _renderFooter(Incident incident) {
    final contextSummary = incident.context.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(' · ');
    return '<div class="footer">schema_version $incidentSchemaVersion'
        '${contextSummary.isNotEmpty ? ' · ${_escape(contextSummary)}' : ''}'
        '</div>';
  }

  static String _field(String label, String value) =>
      '<div class="field"><div class="label">${_escape(label)}</div>'
      '<div class="value">${_escape(value)}</div></div>';

  static String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');

  static const String _css = '''
:root { color-scheme: light; }
* { box-sizing: border-box; }
body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  margin: 0; padding: 0; background: #f4f5f7; color: #1a1a1a;
}
.container { max-width: 720px; margin: 0 auto; padding: 24px 16px 48px; }
.header { border-radius: 12px; padding: 24px; color: #fff; margin-bottom: 16px; }
.header .incident-id { font-family: "SFMono-Regular", Consolas, monospace; font-size: 13px; opacity: 0.85; }
.header h1 { margin: 8px 0 4px; font-size: 22px; }
.header .meta { font-size: 12px; opacity: 0.85; margin-bottom: 10px; }
.badge {
  display: inline-block; padding: 4px 10px; border-radius: 999px;
  background: rgba(255,255,255,0.22); font-size: 11px; font-weight: 700;
  text-transform: uppercase; letter-spacing: 0.05em;
}
.card {
  background: #fff; border-radius: 12px; padding: 20px; margin-bottom: 16px;
  box-shadow: 0 1px 3px rgba(0,0,0,0.08);
}
.card h2 {
  margin: 0 0 12px; font-size: 13px; text-transform: uppercase;
  letter-spacing: 0.05em; color: #666;
}
.field { margin-bottom: 12px; }
.field:last-child { margin-bottom: 0; }
.field .label { font-size: 11px; color: #888; text-transform: uppercase; letter-spacing: 0.04em; margin-bottom: 2px; }
.field .value { font-size: 14px; white-space: pre-wrap; word-break: break-word; }
.error-callout {
  border-left: 4px solid #C62828; background: #FDEDEC; border-radius: 8px;
  padding: 16px; margin-bottom: 16px;
}
.error-callout h2 { color: #C62828; margin: 0 0 10px; font-size: 13px; text-transform: uppercase; letter-spacing: 0.05em; }
.timeline-row { display: flex; gap: 12px; padding: 10px 0; border-bottom: 1px solid #eee; }
.timeline-row:last-child { border-bottom: none; }
.timeline-icon {
  width: 28px; height: 28px; min-width: 28px; border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  font-size: 13px; color: #fff;
}
.timeline-body { flex: 1; min-width: 0; }
.timeline-name { font-weight: 600; font-size: 13px; }
.timeline-time { font-size: 11px; color: #999; }
.timeline-meta { font-size: 12px; color: #555; margin-top: 2px; word-break: break-word; }
.screenshot { max-width: 100%; border-radius: 8px; border: 1px solid #eee; display: block; }
.footer { text-align: center; font-size: 11px; color: #999; margin-top: 8px; }
''';
}
