import 'package:flutter/foundation.dart';

/// Non-sensitive application context attached to every incident.
///
/// Only captures what's obtainable without a plugin dependency: platform
/// and locale, both available directly from the Flutter SDK. Values that
/// need a plugin (app version, build number, device model, ...) are
/// deliberately not auto-captured — core stays dependency-free. Supply
/// them yourself via [set], typically sourced from a package like
/// `package_info_plus` in your own app.
class AppContext {
  AppContext() : _fixed = Map.unmodifiable(_captureFixedContext());

  final Map<String, Object?> _fixed;
  final Map<String, Object?> _custom = <String, Object?>{};

  void set(String key, Object? value) {
    _custom[key] = value;
  }

  Map<String, Object?> snapshot() => Map.unmodifiable({..._fixed, ..._custom});

  static Map<String, Object?> _captureFixedContext() => {
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'locale': PlatformDispatcher.instance.locale.toString(),
      };
}
