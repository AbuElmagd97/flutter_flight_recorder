/// Metadata string values longer than this are truncated by
/// [normalizeForJson] and by [Sanitizer].
const int defaultMaxStringLength = 2000;

const String truncationSuffix = '…[truncated]';

String truncateIfNeeded(String value,
    [int maxLength = defaultMaxStringLength]) {
  if (value.length <= maxLength) return value;
  return '${value.substring(0, maxLength)}$truncationSuffix';
}

/// Converts an arbitrary value into a JSON-safe representation, recursing
/// into [Map]s and [Iterable]s. Unlike [Sanitizer], this does not mask
/// anything by key name — it only guarantees the result can always be
/// encoded, which is what values outside of event metadata (e.g. an
/// incident's `trigger`) need.
Object? normalizeForJson(
  Object? value, {
  int maxStringLength = defaultMaxStringLength,
}) {
  if (value == null || value is bool || value is num) return value;
  if (value is String) return truncateIfNeeded(value, maxStringLength);
  if (value is DateTime) return value.toIso8601String();
  if (value is Map) {
    final map = <String, Object?>{};
    value.forEach((key, v) {
      map[key.toString()] = normalizeForJson(
        v,
        maxStringLength: maxStringLength,
      );
    });
    return Map.unmodifiable(map);
  }
  if (value is Iterable) {
    return List.unmodifiable(
      value.map((v) => normalizeForJson(v, maxStringLength: maxStringLength)),
    );
  }
  return truncateIfNeeded(value.toString(), maxStringLength);
}
