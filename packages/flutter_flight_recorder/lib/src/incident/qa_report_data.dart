import 'package:flutter/foundation.dart';

/// Bug severity as chosen by a QA reporter. Distinct from [EventSeverity]:
/// this is a human-facing bug-triage classification, not a log/error
/// severity, and the two vocabularies are intentionally not shared.
enum IncidentSeverity { low, medium, high, critical }

/// The QA-specific part of an [Incident]: what QA expected to happen
/// versus what actually happened, and how severe they judged it.
///
/// Filled in from the bug report form in the separate
/// `flutter_flight_recorder_reporter` package; this type lives in core
/// so [FlightRecorder.createIncident] has a stable shape to accept
/// without core depending on that package.
@immutable
class QaReportData {
  const QaReportData({this.expected, this.actual, this.severity});

  final String? expected;
  final String? actual;
  final IncidentSeverity? severity;

  Map<String, Object?> toJson() => {
        if (expected != null) 'expected': expected,
        if (actual != null) 'actual': actual,
        if (severity != null) 'severity': severity!.name,
      };
}
