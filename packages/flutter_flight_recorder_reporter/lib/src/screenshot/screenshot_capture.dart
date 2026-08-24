import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Captures the current UI as PNG bytes via a [RepaintBoundary], with no
/// screenshot package dependency — `RenderRepaintBoundary.toImage()` is
/// all this needs, and it's already part of the Flutter SDK.
///
/// Returns `null` on any failure (no boundary attached yet, capture
/// throws, etc.) rather than throwing — screenshot capture is explicitly
/// optional, and a failure here must not crash the
/// reporter flow. Callers are expected to surface `null` to the user as
/// "screenshot unavailable" rather than pretending it succeeded.
class ScreenshotCapture {
  static Future<Uint8List?> capture(
    GlobalKey boundaryKey, {
    double pixelRatio = 1.0,
  }) async {
    try {
      final renderObject = boundaryKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) return null;

      final image = await renderObject.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}
