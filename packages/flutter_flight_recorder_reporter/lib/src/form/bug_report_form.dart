import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';

import 'attachments_checklist.dart';
import 'severity_selector.dart';

const Key whatHappenedFieldKey = Key(
  'flutter_flight_recorder_reporter_what_happened_field',
);
const Key expectedFieldKey = Key(
  'flutter_flight_recorder_reporter_expected_field',
);
const Key actualFieldKey = Key('flutter_flight_recorder_reporter_actual_field');
const Key includeScreenshotCheckboxKey = Key(
  'flutter_flight_recorder_reporter_include_screenshot',
);
const Key createReportButtonKey = Key(
  'flutter_flight_recorder_reporter_create_report_button',
);
const Key cancelButtonKey = Key(
  'flutter_flight_recorder_reporter_cancel_button',
);
const Key formValidationErrorKey = Key(
  'flutter_flight_recorder_reporter_form_validation_error',
);

typedef BugReportSubmit =
    void Function({
      required String whatHappened,
      String? expected,
      String? actual,
      required IncidentSeverity severity,
    });

/// The QA bug report form: what happened, expected/actual, severity, and
/// the automatic-attachments checklist. Deliberately has no other fields
/// — this form should not grow beyond what QA actually needs to report a bug.
class BugReportForm extends StatefulWidget {
  const BugReportForm({
    super.key,
    required this.screenshot,
    required this.screenshotCaptureFailed,
    required this.onIncludeScreenshotChanged,
    required this.onCancel,
    required this.onSubmit,
  });

  final Uint8List? screenshot;
  final bool screenshotCaptureFailed;
  final ValueChanged<bool> onIncludeScreenshotChanged;
  final VoidCallback onCancel;
  final BugReportSubmit onSubmit;

  @override
  State<BugReportForm> createState() => _BugReportFormState();
}

class _BugReportFormState extends State<BugReportForm> {
  final _whatHappenedController = TextEditingController();
  final _expectedController = TextEditingController();
  final _actualController = TextEditingController();
  IncidentSeverity? _severity;
  bool _includeScreenshot = true;
  String? _validationError;

  @override
  void dispose() {
    _whatHappenedController.dispose();
    _expectedController.dispose();
    _actualController.dispose();
    super.dispose();
  }

  void _handleCreate() {
    final whatHappened = _whatHappenedController.text.trim();
    if (whatHappened.isEmpty) {
      setState(() => _validationError = 'Please describe what happened.');
      return;
    }
    if (_severity == null) {
      setState(() => _validationError = 'Please select a severity.');
      return;
    }
    setState(() => _validationError = null);
    widget.onSubmit(
      whatHappened: whatHappened,
      expected: _emptyToNull(_expectedController.text),
      actual: _emptyToNull(_actualController.text),
      severity: _severity!,
    );
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final hasScreenshot = widget.screenshot != null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '🐛 Report a Problem',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              key: cancelButtonKey,
              icon: const Icon(Icons.close),
              tooltip: 'Cancel',
              onPressed: widget.onCancel,
            ),
          ],
        ),
        if (hasScreenshot) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Semantics(
              label: 'Screenshot preview',
              image: true,
              child: Image.memory(
                widget.screenshot!,
                height: 160,
                fit: BoxFit.contain,
              ),
            ),
          ),
          CheckboxListTile(
            key: includeScreenshotCheckboxKey,
            contentPadding: EdgeInsets.zero,
            title: const Text('Include screenshot'),
            value: _includeScreenshot,
            onChanged: (value) {
              final included = value ?? true;
              setState(() => _includeScreenshot = included);
              widget.onIncludeScreenshotChanged(included);
            },
          ),
        ] else if (widget.screenshotCaptureFailed) ...[
          const SizedBox(height: 16),
          const Text(
            'Screenshot unavailable',
            style: TextStyle(color: Colors.orange),
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          'What happened?',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        TextField(
          key: whatHappenedFieldKey,
          controller: _whatHappenedController,
          maxLines: 3,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        const Text('Expected', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          key: expectedFieldKey,
          controller: _expectedController,
          maxLines: 2,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        const Text('Actual', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          key: actualFieldKey,
          controller: _actualController,
          maxLines: 2,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        const Text('Severity', style: TextStyle(fontWeight: FontWeight.w600)),
        SeveritySelector(
          value: _severity,
          onChanged: (value) => setState(() => _severity = value),
        ),
        const SizedBox(height: 16),
        const Text(
          'Automatically attached',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        AttachmentsChecklist(
          includeScreenshot: hasScreenshot && _includeScreenshot,
        ),
        if (_validationError != null) ...[
          const SizedBox(height: 12),
          Text(
            _validationError!,
            key: formValidationErrorKey,
            style: const TextStyle(color: Colors.red),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                key: createReportButtonKey,
                onPressed: _handleCreate,
                child: const Text('Create Report'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
