import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';
import 'package:flutter_flight_recorder_reporter/src/form/attachments_checklist.dart';
import 'package:flutter_flight_recorder_reporter/src/form/bug_report_form.dart';
import 'package:flutter_flight_recorder_reporter/src/form/severity_selector.dart';
import 'package:flutter_test/flutter_test.dart';

class _SubmitCall {
  _SubmitCall(this.whatHappened, this.expected, this.actual, this.severity);
  final String whatHappened;
  final String? expected;
  final String? actual;
  final IncidentSeverity severity;
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// A real, valid 1x1 transparent PNG — arbitrary bytes fail to decode via
/// `Image.memory` and throw during image resolution.
final Uint8List _validPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

void main() {
  // The form is taller than the default 800x600 test surface. Rather than
  // scrolling mid-test to reveal fields below the fold, give tests a
  // surface tall enough to show the whole form at once.
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.physicalSize = const Size(800, 2000);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    addTearDown(binding.platformDispatcher.views.first.resetPhysicalSize);
    addTearDown(binding.platformDispatcher.views.first.resetDevicePixelRatio);
  });

  group('BugReportForm', () {
    testWidgets('renders all required fields and the attachments checklist', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BugReportForm(
            screenshot: null,
            screenshotCaptureFailed: false,
            onIncludeScreenshotChanged: (_) {},
            onCancel: () {},
            onSubmit:
                ({
                  required whatHappened,
                  expected,
                  actual,
                  required severity,
                }) {},
          ),
        ),
      );

      expect(find.byKey(whatHappenedFieldKey), findsOneWidget);
      expect(find.byKey(expectedFieldKey), findsOneWidget);
      expect(find.byKey(actualFieldKey), findsOneWidget);
      expect(find.byType(SeveritySelector), findsOneWidget);
      expect(find.byType(AttachmentsChecklist), findsOneWidget);
      expect(find.byKey(createReportButtonKey), findsOneWidget);
    });

    testWidgets('does not show the screenshot toggle without a screenshot', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BugReportForm(
            screenshot: null,
            screenshotCaptureFailed: false,
            onIncludeScreenshotChanged: (_) {},
            onCancel: () {},
            onSubmit:
                ({
                  required whatHappened,
                  expected,
                  actual,
                  required severity,
                }) {},
          ),
        ),
      );

      expect(find.byKey(includeScreenshotCheckboxKey), findsNothing);
    });

    testWidgets(
      'shows a screenshot preview and toggle when a screenshot is present',
      (tester) async {
        final screenshot = _validPngBytes;
        await tester.pumpWidget(
          _wrap(
            BugReportForm(
              screenshot: screenshot,
              screenshotCaptureFailed: false,
              onIncludeScreenshotChanged: (_) {},
              onCancel: () {},
              onSubmit:
                  ({
                    required whatHappened,
                    expected,
                    actual,
                    required severity,
                  }) {},
            ),
          ),
        );

        expect(find.byKey(includeScreenshotCheckboxKey), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);
      },
    );

    testWidgets('shows an unavailable notice when capture failed', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BugReportForm(
            screenshot: null,
            screenshotCaptureFailed: true,
            onIncludeScreenshotChanged: (_) {},
            onCancel: () {},
            onSubmit:
                ({
                  required whatHappened,
                  expected,
                  actual,
                  required severity,
                }) {},
          ),
        ),
      );

      expect(find.text('Screenshot unavailable'), findsOneWidget);
    });

    testWidgets(
      'blocks submission and shows a validation error when description is empty',
      (tester) async {
        var submitted = false;
        await tester.pumpWidget(
          _wrap(
            BugReportForm(
              screenshot: null,
              screenshotCaptureFailed: false,
              onIncludeScreenshotChanged: (_) {},
              onCancel: () {},
              onSubmit:
                  ({
                    required whatHappened,
                    expected,
                    actual,
                    required severity,
                  }) => submitted = true,
            ),
          ),
        );

        await tester.tap(find.byKey(createReportButtonKey));
        await tester.pump();

        expect(submitted, isFalse);
        expect(find.byKey(formValidationErrorKey), findsOneWidget);
        expect(find.text('Please describe what happened.'), findsOneWidget);
      },
    );

    testWidgets('blocks submission when severity is not selected', (
      tester,
    ) async {
      var submitted = false;
      await tester.pumpWidget(
        _wrap(
          BugReportForm(
            screenshot: null,
            screenshotCaptureFailed: false,
            onIncludeScreenshotChanged: (_) {},
            onCancel: () {},
            onSubmit:
                ({
                  required whatHappened,
                  expected,
                  actual,
                  required severity,
                }) => submitted = true,
          ),
        ),
      );

      await tester.enterText(
        find.byKey(whatHappenedFieldKey),
        'Profile update failed',
      );
      await tester.tap(find.byKey(createReportButtonKey));
      await tester.pump();

      expect(submitted, isFalse);
      expect(find.text('Please select a severity.'), findsOneWidget);
    });

    testWidgets('submits with trimmed values once validation passes', (
      tester,
    ) async {
      _SubmitCall? call;
      await tester.pumpWidget(
        _wrap(
          BugReportForm(
            screenshot: null,
            screenshotCaptureFailed: false,
            onIncludeScreenshotChanged: (_) {},
            onCancel: () {},
            onSubmit:
                ({
                  required whatHappened,
                  expected,
                  actual,
                  required severity,
                }) => call = _SubmitCall(
                  whatHappened,
                  expected,
                  actual,
                  severity,
                ),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(whatHappenedFieldKey),
        '  Profile update failed  ',
      );
      await tester.enterText(
        find.byKey(expectedFieldKey),
        'Profile should be saved successfully.',
      );
      await tester.tap(find.byKey(severityOptionKey(IncidentSeverity.high)));
      await tester.pump();
      await tester.tap(find.byKey(createReportButtonKey));
      await tester.pump();

      expect(call, isNotNull);
      expect(call!.whatHappened, 'Profile update failed');
      expect(call!.expected, 'Profile should be saved successfully.');
      expect(call!.actual, isNull);
      expect(call!.severity, IncidentSeverity.high);
    });

    testWidgets(
      'an empty expected/actual field submits as null, not an empty string',
      (tester) async {
        _SubmitCall? call;
        await tester.pumpWidget(
          _wrap(
            BugReportForm(
              screenshot: null,
              screenshotCaptureFailed: false,
              onIncludeScreenshotChanged: (_) {},
              onCancel: () {},
              onSubmit:
                  ({
                    required whatHappened,
                    expected,
                    actual,
                    required severity,
                  }) => call = _SubmitCall(
                    whatHappened,
                    expected,
                    actual,
                    severity,
                  ),
            ),
          ),
        );

        await tester.enterText(
          find.byKey(whatHappenedFieldKey),
          'Something broke',
        );
        await tester.tap(find.byKey(severityOptionKey(IncidentSeverity.low)));
        await tester.pump();
        await tester.tap(find.byKey(createReportButtonKey));
        await tester.pump();

        expect(call!.expected, isNull);
        expect(call!.actual, isNull);
      },
    );

    testWidgets('cancel button invokes onCancel', (tester) async {
      var cancelled = false;
      await tester.pumpWidget(
        _wrap(
          BugReportForm(
            screenshot: null,
            screenshotCaptureFailed: false,
            onIncludeScreenshotChanged: (_) {},
            onCancel: () => cancelled = true,
            onSubmit:
                ({
                  required whatHappened,
                  expected,
                  actual,
                  required severity,
                }) {},
          ),
        ),
      );

      await tester.tap(find.byKey(cancelButtonKey));
      await tester.pump();

      expect(cancelled, isTrue);
    });

    testWidgets('toggling include-screenshot notifies the callback', (
      tester,
    ) async {
      bool? included;
      final screenshot = _validPngBytes;
      await tester.pumpWidget(
        _wrap(
          BugReportForm(
            screenshot: screenshot,
            screenshotCaptureFailed: false,
            onIncludeScreenshotChanged: (value) => included = value,
            onCancel: () {},
            onSubmit:
                ({
                  required whatHappened,
                  expected,
                  actual,
                  required severity,
                }) {},
          ),
        ),
      );

      await tester.tap(find.byKey(includeScreenshotCheckboxKey));
      await tester.pump();

      expect(included, isFalse);
    });
  });
}
