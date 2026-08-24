import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';
import 'package:share_plus/share_plus.dart';

import '../export/incident_html_report.dart';

/// Shares an incident through the platform share sheet, in either of two
/// formats.
///
/// Files are shared entirely in-memory via `XFile.fromData` — no temp
/// file is written to disk, so this package doesn't need `path_provider`
/// as a dependency just to get a directory to write into.
///
/// `XFile.fromData`'s own `name:` parameter is silently ignored on every
/// platform except web (`cross_file`'s `dart:io` implementation derives
/// `.name` from a `path` instead) — found while testing this class in an
/// earlier phase. The filenames actually used are set via
/// `ShareParams.fileNameOverrides` instead, which is `share_plus`'s
/// documented way to name in-memory files correctly on every platform.
///
/// Failures (the share sheet erroring, the platform not supporting
/// sharing, etc.) are not caught here — they propagate to the caller,
/// which is responsible for surfacing them to the user rather than
/// letting them fail silently. See `ReportPreviewScreen`.
class ReportShare {
  const ReportShare._();

  /// Shares a single, self-contained HTML report — this is the primary,
  /// default share format (see the package README's "Report formats"
  /// section for why). If [screenshot] is provided it's embedded inline
  /// as a base64 image inside the HTML, not attached as a separate file,
  /// so this is always exactly one shared file.
  static Future<ShareResult> shareHtml(
    Incident incident, {
    Uint8List? screenshot,
    SharePlus? sharePlus,
  }) async {
    final htmlBytes = Uint8List.fromList(
      utf8.encode(IncidentHtmlReport.render(incident, screenshot: screenshot)),
    );

    return (sharePlus ?? SharePlus.instance).share(
      ShareParams(
        files: [XFile.fromData(htmlBytes, mimeType: 'text/html')],
        fileNameOverrides: ['${incident.id}.html'],
        subject: incident.title,
      ),
    );
  }

  /// Shares the incident's machine-readable JSON export — the explicit,
  /// secondary format for developers/backends/tooling that need to parse
  /// it programmatically. See [Incident.toJson].
  static Future<ShareResult> shareJson(
    Incident incident, {
    SharePlus? sharePlus,
  }) async {
    final jsonBytes = Uint8List.fromList(
      utf8.encode(
        const JsonEncoder.withIndent('  ').convert(incident.toJson()),
      ),
    );

    return (sharePlus ?? SharePlus.instance).share(
      ShareParams(
        files: [XFile.fromData(jsonBytes, mimeType: 'application/json')],
        fileNameOverrides: ['${incident.id}.json'],
        subject: incident.title,
      ),
    );
  }
}
