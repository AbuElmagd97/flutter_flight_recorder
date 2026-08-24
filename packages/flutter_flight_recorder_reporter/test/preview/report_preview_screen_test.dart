import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';
import 'package:flutter_flight_recorder_reporter/src/preview/report_preview_screen.dart';
import 'package:flutter_flight_recorder_reporter/src/preview/severity_badge.dart';
import 'package:flutter_flight_recorder_reporter/src/severity_colors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

class _FakeSharePlatform extends SharePlatform {
  _FakeSharePlatform.succeeds() : _error = null;
  _FakeSharePlatform.fails(Object error) : _error = error;

  final Object? _error;
  ShareParams? lastParams;

  @override
  Future<ShareResult> share(ShareParams params) async {
    lastParams = params;
    if (_error != null) throw _error;
    return const ShareResult('shared', ShareResultStatus.success);
  }
}

Incident _incident({IncidentSeverity? severity = IncidentSeverity.high}) {
  return Incident(
    id: 'INC-ABCDEF',
    timestamp: DateTime.utc(2026, 1, 1),
    title: 'Profile update failed',
    qaReport: severity == null ? null : QaReportData(severity: severity),
    timeline: const [],
    context: const {},
  );
}

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  setUp(() {
    // The card layout is taller than the default 800x600 test surface.
    TestWidgetsFlutterBinding.ensureInitialized();
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.physicalSize = const Size(800, 1400);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    addTearDown(binding.platformDispatcher.views.first.resetPhysicalSize);
    addTearDown(binding.platformDispatcher.views.first.resetDevicePixelRatio);
  });

  group('ReportPreviewScreen', () {
    testWidgets('shows the incident id, title, severity badge and Bug Story', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ReportPreviewScreen(
            incident: _incident(),
            screenshot: null,
            onClose: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('INC-ABCDEF'), findsOneWidget);
      expect(find.text('Profile update failed'), findsOneWidget);
      expect(find.byType(SeverityBadge), findsOneWidget);
      expect(find.text('HIGH'), findsOneWidget);
      expect(find.byKey(bugStoryTextKey), findsOneWidget);
    });

    testWidgets('shows no severity badge when the incident has no qaReport', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ReportPreviewScreen(
            incident: _incident(severity: null),
            screenshot: null,
            onClose: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SeverityBadge), findsNothing);
    });

    for (final severity in IncidentSeverity.values) {
      testWidgets('severity badge uses the correct color for $severity', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(
            ReportPreviewScreen(
              incident: _incident(severity: severity),
              screenshot: null,
              onClose: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final container = tester.widget<Container>(
          find.byKey(severityBadgeKey),
        );
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, severityColor(severity));
      });
    }

    testWidgets('each attachment item renders with an icon, not just text', (
      tester,
    ) async {
      final screenshot = Uint8List.fromList([1, 2, 3, 4]);
      await tester.pumpWidget(
        _wrap(
          ReportPreviewScreen(
            incident: _incident(),
            screenshot: screenshot,
            onClose: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.camera_alt), findsOneWidget); // Screenshot
      expect(find.byIcon(Icons.smartphone), findsOneWidget); // Current screen
      expect(find.byIcon(Icons.timeline), findsOneWidget); // User journey
      expect(find.byIcon(Icons.route), findsOneWidget); // Navigation history
      expect(
        find.byIcon(Icons.wifi),
        findsOneWidget,
      ); // Recent network activity
      expect(find.byIcon(Icons.article), findsOneWidget); // Application logs
      expect(
        find.byIcon(Icons.info_outline),
        findsOneWidget,
      ); // App information
    });

    testWidgets('renders correctly with animations disabled', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _wrap(
            ReportPreviewScreen(
              incident: _incident(),
              screenshot: null,
              onClose: () {},
            ),
          ),
        ),
      );

      // With animations disabled the content should already be at full
      // opacity after the very first frame, with no need to wait out the
      // 350ms transition.
      await tester.pump();
      final fade = tester.widget<FadeTransition>(
        find.byKey(entranceAnimationKey),
      );
      expect(fade.opacity.value, 1.0);

      // pumpAndSettle must still complete (not hang on a repeating
      // animation) regardless.
      await tester.pumpAndSettle();
      expect(find.text('INC-ABCDEF'), findsOneWidget);
    });

    testWidgets('close button invokes onClose', (tester) async {
      var closed = false;
      await tester.pumpWidget(
        _wrap(
          ReportPreviewScreen(
            incident: _incident(),
            screenshot: null,
            onClose: () => closed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(closePreviewButtonKey));
      await tester.pump();

      expect(closed, isTrue);
    });

    testWidgets('copy summary puts the Bug Story on the clipboard', (
      tester,
    ) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await tester.pumpWidget(
        _wrap(
          ReportPreviewScreen(
            incident: _incident(),
            screenshot: null,
            onClose: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(copySummaryButtonKey));
      await tester.pump();

      final setDataCall = calls.singleWhere(
        (call) => call.method == 'Clipboard.setData',
      );
      expect(
        (setDataCall.arguments as Map)['text'],
        'No events were recorded before this incident.',
      );
    });

    testWidgets('Share Report shares a single HTML file', (tester) async {
      final platform = _FakeSharePlatform.succeeds();
      await tester.pumpWidget(
        _wrap(
          ReportPreviewScreen(
            incident: _incident(),
            screenshot: null,
            onClose: () {},
            sharePlus: SharePlus.custom(platform),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(shareButtonKey));
      await tester.pumpAndSettle();

      expect(platform.lastParams, isNotNull);
      expect(platform.lastParams!.files, hasLength(1));
      expect(platform.lastParams!.fileNameOverrides, ['INC-ABCDEF.html']);
      expect(platform.lastParams!.files!.single.mimeType, 'text/html');
      expect(find.byKey(shareErrorTextKey), findsNothing);
    });

    testWidgets(
      'Export JSON shares a single JSON file, separately from Share Report',
      (tester) async {
        final platform = _FakeSharePlatform.succeeds();
        await tester.pumpWidget(
          _wrap(
            ReportPreviewScreen(
              incident: _incident(),
              screenshot: null,
              onClose: () {},
              sharePlus: SharePlus.custom(platform),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(exportJsonButtonKey), findsOneWidget);
        await tester.tap(find.byKey(exportJsonButtonKey));
        await tester.pumpAndSettle();

        expect(platform.lastParams!.files, hasLength(1));
        expect(platform.lastParams!.fileNameOverrides, ['INC-ABCDEF.json']);
        expect(platform.lastParams!.files!.single.mimeType, 'application/json');
      },
    );

    testWidgets(
      'a share failure is caught and surfaced, not silently swallowed',
      (tester) async {
        final platform = _FakeSharePlatform.fails(
          Exception('share sheet unavailable'),
        );
        await tester.pumpWidget(
          _wrap(
            ReportPreviewScreen(
              incident: _incident(),
              screenshot: null,
              onClose: () {},
              sharePlus: SharePlus.custom(platform),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(shareButtonKey));
        await tester.pumpAndSettle();

        expect(find.byKey(shareErrorTextKey), findsOneWidget);
        expect(
          find.textContaining('Could not share the report'),
          findsOneWidget,
        );
      },
    );
  });
}
