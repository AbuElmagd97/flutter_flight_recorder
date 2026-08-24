import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';
import 'package:share_plus/share_plus.dart';

import 'form/bug_report_form.dart';
import 'preview/report_preview_screen.dart';

enum ReporterStep { form, preview }

/// Owns the form → preview transition for one open/close cycle of the
/// reporter. A fresh instance is created each time the reporter opens
/// (see `FlutterFlightRecorderReporterState`), so there's no state to
/// reset between uses.
class ReporterFlow extends StatefulWidget {
  const ReporterFlow({
    super.key,
    required this.trigger,
    required this.screenshot,
    required this.screenshotCaptureFailed,
    required this.onClose,
    this.sharePlus,
  });

  final String trigger;
  final Uint8List? screenshot;
  final bool screenshotCaptureFailed;
  final VoidCallback onClose;
  final SharePlus? sharePlus;

  @override
  State<ReporterFlow> createState() => ReporterFlowState();
}

@visibleForTesting
class ReporterFlowState extends State<ReporterFlow> {
  ReporterStep _step = ReporterStep.form;
  bool _includeScreenshot = true;
  Incident? _incident;

  @visibleForTesting
  ReporterStep get step => _step;

  void _handleSubmit({
    required String whatHappened,
    String? expected,
    String? actual,
    required IncidentSeverity severity,
  }) {
    final incident = FlightRecorder.createIncident(
      title: whatHappened,
      qaReport: QaReportData(
        expected: expected,
        actual: actual,
        severity: severity,
      ),
      trigger: widget.trigger,
    );
    setState(() {
      _incident = incident;
      _step = ReporterStep.preview;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: switch (_step) {
          ReporterStep.form => BugReportForm(
            screenshot: _includeScreenshot ? widget.screenshot : null,
            screenshotCaptureFailed: widget.screenshotCaptureFailed,
            onIncludeScreenshotChanged: (value) =>
                setState(() => _includeScreenshot = value),
            onCancel: widget.onClose,
            onSubmit: _handleSubmit,
          ),
          ReporterStep.preview => ReportPreviewScreen(
            incident: _incident!,
            screenshot: _includeScreenshot ? widget.screenshot : null,
            onClose: widget.onClose,
            sharePlus: widget.sharePlus,
          ),
        },
      ),
    );
  }
}
