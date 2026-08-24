import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QaReportData', () {
    test('toJson includes only the fields that were set', () {
      const report = QaReportData(
        expected: 'Profile should be saved successfully.',
        actual: 'Validation error appears.',
        severity: IncidentSeverity.high,
      );

      expect(report.toJson(), {
        'expected': 'Profile should be saved successfully.',
        'actual': 'Validation error appears.',
        'severity': 'high',
      });
    });

    test('toJson is empty when nothing was set', () {
      const report = QaReportData();
      expect(report.toJson(), isEmpty);
    });

    test('supports all required severities', () {
      expect(
          IncidentSeverity.values,
          containsAll(<IncidentSeverity>[
            IncidentSeverity.low,
            IncidentSeverity.medium,
            IncidentSeverity.high,
            IncidentSeverity.critical,
          ]));
    });
  });
}
