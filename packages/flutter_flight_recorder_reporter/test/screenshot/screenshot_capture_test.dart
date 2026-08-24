import 'package:flutter/material.dart';
import 'package:flutter_flight_recorder_reporter/src/screenshot/screenshot_capture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('captures PNG bytes from a RepaintBoundary', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: Container(color: Colors.blue, width: 100, height: 100),
        ),
      ),
    );

    // toImage() does real async engine work that fake-async pump() calls
    // don't drive forward — runAsync opts this call out of that.
    final bytes = await tester.runAsync(() => ScreenshotCapture.capture(key));

    expect(bytes, isNotNull);
    expect(bytes, isNotEmpty);
    // PNG signature.
    expect(bytes!.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
  });

  testWidgets('returns null when the key has no attached render object', (
    tester,
  ) async {
    final key = GlobalKey(); // never used in a widget tree

    final bytes = await ScreenshotCapture.capture(key);

    expect(bytes, isNull);
  });

  testWidgets(
    'returns null when the key is attached to something other than a RepaintBoundary',
    (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(home: Container(key: key)));

      final bytes = await ScreenshotCapture.capture(key);

      expect(bytes, isNull);
    },
  );
}
