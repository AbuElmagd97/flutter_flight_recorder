import 'package:flutter/material.dart';
import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';

import '../severity_colors.dart';

Key severityOptionKey(IncidentSeverity severity) =>
    Key('flutter_flight_recorder_reporter_severity_${severity.name}');

class SeveritySelector extends StatelessWidget {
  const SeveritySelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final IncidentSeverity? value;
  final ValueChanged<IncidentSeverity?> onChanged;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<IncidentSeverity>(
      groupValue: value,
      onChanged: onChanged,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: IncidentSeverity.values
            .map(
              (severity) => RadioListTile<IncidentSeverity>(
                key: severityOptionKey(severity),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(severityLabel(severity)),
                value: severity,
              ),
            )
            .toList(),
      ),
    );
  }
}
