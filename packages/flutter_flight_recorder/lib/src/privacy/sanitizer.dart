import '../json_safety.dart';
import 'default_sensitive_keys.dart';

/// Called for each top-level metadata entry before default masking is
/// applied. Return the value to store (or mask it yourself and return
/// anything non-sensitive-looking) — whatever is returned is still subject
/// to the default sensitive-key check afterward.
typedef CustomSanitizer = Object? Function(String key, Object? value);

/// Applies privacy masking and JSON-safety normalization to event metadata.
///
/// This is the single point where sanitization happens, and it runs
/// synchronously at record time — before a value ever enters the rolling
/// buffer. Two independent things happen in the same recursive walk:
///
/// * **Masking**: any key matching [sensitiveKeys] (case-insensitive, at
///   any nesting depth) has its value replaced with [maskValue].
/// * **Normalization**: values that aren't already JSON-safe (custom
///   objects, [DateTime], etc.) are converted to a safe representation
///   (usually `toString()`), and long strings are truncated, so metadata
///   can never fail to serialize later and can't grow unbounded.
///
/// Masking is key-name based, not content based: sensitive data stored
/// under a non-standard key (e.g. `'pwd'` instead of `'password'`) is not
/// detected automatically. Use [customSanitizer] or a non-default
/// [sensitiveKeys] set to cover application-specific key names.
class Sanitizer {
  Sanitizer({this.sensitiveKeys = defaultSensitiveKeys, this.customSanitizer});

  final Set<String> sensitiveKeys;
  final CustomSanitizer? customSanitizer;

  static const String maskValue = '***';

  /// Metadata string values longer than this are truncated. This bounds
  /// the cost of a single oversized value; it does not cap the number of
  /// keys in a metadata map.
  static const int maxStringLength = defaultMaxStringLength;

  Map<String, Object?> sanitizeMetadata(Map<String, Object?> metadata) {
    final result = <String, Object?>{};
    metadata.forEach((key, value) {
      final effectiveValue =
          customSanitizer != null ? customSanitizer!(key, value) : value;
      result[key] =
          _isSensitiveKey(key) ? maskValue : _normalize(effectiveValue);
    });
    return Map.unmodifiable(result);
  }

  bool _isSensitiveKey(String key) => sensitiveKeys.contains(key.toLowerCase());

  Object? _normalize(Object? value) {
    if (value == null || value is bool || value is num) return value;
    if (value is String) return truncateIfNeeded(value, maxStringLength);
    if (value is DateTime) return value.toIso8601String();
    if (value is Map) return _normalizeMap(value);
    if (value is Iterable) return List.unmodifiable(value.map(_normalize));
    return truncateIfNeeded(value.toString(), maxStringLength);
  }

  Map<String, Object?> _normalizeMap(Map<Object?, Object?> value) {
    final map = <String, Object?>{};
    value.forEach((rawKey, v) {
      final key = rawKey.toString();
      map[key] = _isSensitiveKey(key) ? maskValue : _normalize(v);
    });
    return Map.unmodifiable(map);
  }
}
