import 'package:flutter/material.dart';

const Key attachmentsChecklistKey = Key(
  'flutter_flight_recorder_reporter_attachments_checklist',
);

/// The "Automatically attached" list shown on both the bug report form
/// and the report preview screen — what will be (or was) attached to the
/// incident, so QA never has to guess.
///
/// Each item has its own distinct leading icon (rather than a uniform
/// checkmark) so the list reads at a glance instead of as a wall of
/// identical rows; a small trailing checkmark still confirms it's
/// actually attached.
class AttachmentsChecklist extends StatelessWidget {
  const AttachmentsChecklist({super.key, required this.includeScreenshot});

  final bool includeScreenshot;

  static const List<(String, IconData)> _alwaysAttached = [
    ('Current screen', Icons.smartphone),
    ('User journey', Icons.timeline),
    ('Navigation history', Icons.route),
    ('Recent network activity', Icons.wifi),
    ('Application logs', Icons.article),
    ('App information', Icons.info_outline),
  ];

  @override
  Widget build(BuildContext context) {
    final items = [
      if (includeScreenshot) ('Screenshot', Icons.camera_alt),
      ..._alwaysAttached,
    ];
    return Column(
      key: attachmentsChecklistKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(item.$2, size: 18, color: Colors.grey.shade700),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item.$1)),
                  const Icon(Icons.check, size: 16, color: Colors.green),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
