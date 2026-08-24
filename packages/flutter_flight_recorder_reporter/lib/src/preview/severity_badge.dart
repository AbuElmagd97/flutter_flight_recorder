import 'package:flutter/material.dart';
import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';

import '../severity_colors.dart';

const Key severityBadgeKey = Key(
  'flutter_flight_recorder_reporter_severity_badge',
);

/// A colored severity badge — green/amber/orange/red for
/// low/medium/high/critical — replacing the plain "Severity: X" text
/// line on the report preview screen.
class SeverityBadge extends StatelessWidget {
  const SeverityBadge({super.key, required this.severity});

  final IncidentSeverity severity;

  @override
  Widget build(BuildContext context) {
    final color = severityColor(severity);
    return Container(
      key: severityBadgeKey,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        severityLabel(severity).toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
