import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';
import 'package:flutter_flight_recorder_reporter/src/share/report_share.dart';
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

Incident _incident() {
  return Incident(
    id: 'INC-ABCDEF',
    timestamp: DateTime.utc(2026, 1, 1),
    title: 'Profile update failed',
    timeline: const [],
    context: const {},
  );
}

void main() {
  group('ReportShare.shareHtml', () {
    test(
      'shares a single HTML file with the right name and mime type',
      () async {
        final platform = _FakeSharePlatform.succeeds();
        await ReportShare.shareHtml(
          _incident(),
          sharePlus: SharePlus.custom(platform),
        );

        final params = platform.lastParams!;
        expect(params.files, hasLength(1));
        expect(params.fileNameOverrides, ['INC-ABCDEF.html']);
        expect(params.files!.single.mimeType, 'text/html');
        expect(params.subject, 'Profile update failed');
      },
    );

    test('the shared bytes are the rendered HTML report', () async {
      final platform = _FakeSharePlatform.succeeds();
      final incident = _incident();
      await ReportShare.shareHtml(
        incident,
        sharePlus: SharePlus.custom(platform),
      );

      final bytes = await platform.lastParams!.files!.single.readAsBytes();
      final html = utf8.decode(bytes);
      expect(html, contains('<!DOCTYPE html>'));
      expect(html, contains('INC-ABCDEF'));
    });

    test(
      'embeds the screenshot inline rather than as a separate file',
      () async {
        final platform = _FakeSharePlatform.succeeds();
        final screenshot = Uint8List.fromList([1, 2, 3, 4]);
        await ReportShare.shareHtml(
          _incident(),
          screenshot: screenshot,
          sharePlus: SharePlus.custom(platform),
        );

        final params = platform.lastParams!;
        // Still exactly one file — the screenshot is embedded as base64
        // inside the HTML, not attached separately.
        expect(params.files, hasLength(1));
        final html = utf8.decode(await params.files!.single.readAsBytes());
        expect(html, contains('data:image/png;base64,'));
      },
    );

    test('propagates a share failure rather than swallowing it', () async {
      final platform = _FakeSharePlatform.fails(Exception('unavailable'));

      await expectLater(
        ReportShare.shareHtml(
          _incident(),
          sharePlus: SharePlus.custom(platform),
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('ReportShare.shareJson', () {
    test(
      'shares the incident JSON as a named file with the right mime type',
      () async {
        final platform = _FakeSharePlatform.succeeds();
        await ReportShare.shareJson(
          _incident(),
          sharePlus: SharePlus.custom(platform),
        );

        final params = platform.lastParams!;
        expect(params.files, hasLength(1));
        expect(params.fileNameOverrides, ['INC-ABCDEF.json']);
        expect(params.files!.single.mimeType, 'application/json');
        expect(params.subject, 'Profile update failed');
      },
    );

    test(
      'the shared JSON bytes decode back to the original, unchanged incident export',
      () async {
        final platform = _FakeSharePlatform.succeeds();
        final incident = _incident();
        await ReportShare.shareJson(
          incident,
          sharePlus: SharePlus.custom(platform),
        );

        final bytes = await platform.lastParams!.files!.single.readAsBytes();
        final decoded = jsonDecode(utf8.decode(bytes));
        expect(decoded['incident_id'], 'INC-ABCDEF');
        expect(decoded, incident.toJson());
      },
    );

    test('propagates a share failure rather than swallowing it', () async {
      final platform = _FakeSharePlatform.fails(Exception('unavailable'));

      await expectLater(
        ReportShare.shareJson(
          _incident(),
          sharePlus: SharePlus.custom(platform),
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
