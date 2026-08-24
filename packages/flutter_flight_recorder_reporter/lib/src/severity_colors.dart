import 'package:flutter/material.dart';
import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';

/// Single source of truth for severity → color, shared by the in-app
/// preview screen ([SeverityBadge]) and the HTML export
/// (`IncidentHtmlReport`), so the two never drift apart. Hex strings are
/// the canonical form; [severityColor] just parses one into a Flutter
/// [Color] for widget use.
const Map<IncidentSeverity, String> severityColorHex = {
  IncidentSeverity.low: '#2E7D32', // green
  IncidentSeverity.medium: '#FF8F00', // amber
  IncidentSeverity.high: '#EF6C00', // orange
  IncidentSeverity.critical: '#C62828', // red
};

Color severityColor(IncidentSeverity severity) {
  final hex = severityColorHex[severity]!.substring(1);
  return Color(int.parse(hex, radix: 16) + 0xFF000000);
}

String severityLabel(IncidentSeverity severity) => switch (severity) {
  IncidentSeverity.low => 'Low',
  IncidentSeverity.medium => 'Medium',
  IncidentSeverity.high => 'High',
  IncidentSeverity.critical => 'Critical',
};
