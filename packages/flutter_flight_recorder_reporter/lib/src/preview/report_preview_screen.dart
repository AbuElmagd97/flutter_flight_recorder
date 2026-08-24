import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';
import 'package:share_plus/share_plus.dart';

import '../form/attachments_checklist.dart';
import '../share/report_share.dart';
import '../story/bug_story_generator.dart';
import 'severity_badge.dart';

const Key bugStoryTextKey = Key('flutter_flight_recorder_reporter_bug_story');
const Key copySummaryButtonKey = Key(
  'flutter_flight_recorder_reporter_copy_summary_button',
);
const Key shareButtonKey = Key('flutter_flight_recorder_reporter_share_button');
const Key exportJsonButtonKey = Key(
  'flutter_flight_recorder_reporter_export_json_button',
);
const Key closePreviewButtonKey = Key(
  'flutter_flight_recorder_reporter_close_preview_button',
);
const Key shareErrorTextKey = Key(
  'flutter_flight_recorder_reporter_share_error',
);
const Key entranceAnimationKey = Key(
  'flutter_flight_recorder_reporter_entrance_animation',
);

/// Shown after `FlightRecorder.createIncident` succeeds: the incident id,
/// a severity badge, the generated Bug Story, the attachments checklist,
/// and Copy Summary / Share Report (HTML) / Export JSON / Close actions.
///
/// Built entirely inside the reporter's own internal `MaterialApp` (see
/// `FlutterFlightRecorderReporter`'s class doc) — that architecture is
/// unchanged here, this widget just renders more richly within it.
class ReportPreviewScreen extends StatefulWidget {
  const ReportPreviewScreen({
    super.key,
    required this.incident,
    required this.screenshot,
    required this.onClose,
    this.sharePlus,
  });

  final Incident incident;
  final Uint8List? screenshot;
  final VoidCallback onClose;

  /// Overridable for tests only; production code should leave this null
  /// so `ReportShare` uses `SharePlus.instance`.
  final SharePlus? sharePlus;

  @override
  State<ReportPreviewScreen> createState() => _ReportPreviewScreenState();
}

class _ReportPreviewScreenState extends State<ReportPreviewScreen>
    with SingleTickerProviderStateMixin {
  String? _actionError;
  bool _busy = false;
  bool _animationStarted = false;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.04),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_animationStarted) return;
    _animationStarted = true;
    // Respect the platform's reduce-motion setting: jump straight to the
    // end state instead of animating.
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = BugStoryGenerator.generate(widget.incident);
    final severity = widget.incident.qaReport?.severity;

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          key: entranceAnimationKey,
          opacity: _opacity,
          child: SlideTransition(
            position: _slide,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ReportCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🐛 Bug Report Created',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.incident.id,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(widget.incident.title),
                      if (severity != null) ...[
                        const SizedBox(height: 12),
                        SeverityBadge(severity: severity),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _ReportCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _CardHeading('Bug Story'),
                      const SizedBox(height: 4),
                      Text(story, key: bugStoryTextKey),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _ReportCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _CardHeading('Attached'),
                      const SizedBox(height: 4),
                      AttachmentsChecklist(
                        includeScreenshot: widget.screenshot != null,
                      ),
                    ],
                  ),
                ),
                if (_actionError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _actionError!,
                    key: shareErrorTextKey,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 12),
                _ReportCard(
                  child: Column(
                    children: [
                      OutlinedButton(
                        key: copySummaryButtonKey,
                        onPressed: () => _copySummary(story),
                        child: const Text('Copy Summary'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        key: shareButtonKey,
                        onPressed: _busy ? null : _shareHtml,
                        child: Text(_busy ? 'Sharing…' : 'Share Report'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        key: exportJsonButtonKey,
                        onPressed: _busy ? null : _exportJson,
                        child: const Text('Export JSON'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        key: closePreviewButtonKey,
                        onPressed: widget.onClose,
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copySummary(String story) async {
    await Clipboard.setData(ClipboardData(text: story));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Summary copied')));
  }

  Future<void> _shareHtml() async {
    setState(() {
      _actionError = null;
      _busy = true;
    });
    try {
      await ReportShare.shareHtml(
        widget.incident,
        screenshot: widget.screenshot,
        sharePlus: widget.sharePlus,
      );
      if (!mounted) return;
      setState(() => _busy = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _actionError = 'Could not share the report: $e';
      });
    }
  }

  Future<void> _exportJson() async {
    setState(() {
      _actionError = null;
      _busy = true;
    });
    try {
      await ReportShare.shareJson(widget.incident, sharePlus: widget.sharePlus);
      if (!mounted) return;
      setState(() => _busy = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _actionError = 'Could not export JSON: $e';
      });
    }
  }
}

class _CardHeading extends StatelessWidget {
  const _CardHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.w600));
  }
}

/// A visually distinct card section: rounded corners, subtle border and
/// elevation — replacing the previous single continuous column of text.
class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
