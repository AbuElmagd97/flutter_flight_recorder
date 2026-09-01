import 'package:flutter/foundation.dart';

import '../json_safety.dart';

/// The kind of activity a [FlightEvent] represents.
enum EventCategory { navigation, network, action, log, error, lifecycle }

/// Severity of a [FlightEvent]. Reused for both structured log levels
/// (see [FlightRecorder.log]) and error severity (see
/// [FlightRecorder.recordError]) rather than defining two identical enums.
enum EventSeverity { debug, info, warning, error }

/// A single, immutable entry in the flight recorder's rolling timeline.
///
/// Instances are normally created by [FlightRecorder], which is responsible
/// for assigning [id], applying privacy sanitization to [metadata], and
/// enforcing the rolling buffer capacity. Constructing a [FlightEvent]
/// directly bypasses that sanitization, so application code should prefer
/// `FlightRecorder.recordAction` / `.log` / `.recordError` instead.
@immutable
class FlightEvent {
  /// Creates a single timeline entry.
  ///
  /// [metadata] is copied into an unmodifiable map, so later mutation of
  /// the map passed in has no effect on this event. Application code
  /// should prefer `FlightRecorder.recordAction` / `.log` /
  /// `.recordError` over constructing a [FlightEvent] directly — see the
  /// class doc comment for why.
  FlightEvent({
    required this.id,
    required this.timestamp,
    required this.category,
    required this.name,
    Map<String, Object?> metadata = const {},
    this.severity,
    String? correlationId,
  })  : metadata = Map.unmodifiable(metadata),
        correlationId =
            correlationId == null ? null : truncateIfNeeded(correlationId);

  /// Unique within a recording session. Not a global UUID.
  final String id;

  /// When this event was recorded.
  final DateTime timestamp;

  /// Which kind of activity this event represents.
  final EventCategory category;

  /// Short human-meaningful label, e.g. `'save_profile_tapped'` or a route
  /// name. Not free-form prose.
  final String name;

  /// Already sanitized and JSON-safe by the time an event reaches the
  /// buffer. Unmodifiable.
  final Map<String, Object?> metadata;

  /// Set for `log` and `error` category events; `null` for the others,
  /// which have no notion of severity.
  final EventSeverity? severity;

  /// An opaque token declaring that this event belongs to the same
  /// application-defined interaction as every other event sharing the
  /// same value — see `FlightRecorder.newCorrelationId` and the
  /// `correlationId` parameter on `FlightRecorder.recordAction` and
  /// friends.
  ///
  /// This states **association**, not causation: a shared
  /// [correlationId] means these events were explicitly declared as
  /// part of the same interaction, never that one caused another. See
  /// `IncidentAnalyzer`'s class doc for how this is used.
  ///
  /// `null` when the application never supplied one — [IncidentAnalyzer]
  /// falls back to its chronological heuristic for such events, exactly
  /// as it did before this field existed.
  ///
  /// Deliberately separate from [metadata]: unlike metadata, this is
  /// never subject to `Sanitizer`'s key-name masking, so it must be an
  /// opaque token (see `FlightRecorder.newCorrelationId`) — never an
  /// email, phone number, user ID, access token, URL, or other
  /// sensitive/business value. Still passed through the same
  /// length-truncation every other recorded string gets (see
  /// [truncateIfNeeded]), so an oversized value can't grow the timeline
  /// unbounded, but that is not a privacy guarantee.
  final String? correlationId;

  /// JSON-safe representation of this event, e.g. for embedding in an
  /// incident's `timeline` array.
  Map<String, Object?> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'category': category.name,
        'name': name,
        'metadata': metadata,
        if (severity != null) 'severity': severity!.name,
        if (correlationId != null) 'correlation_id': correlationId,
      };

  @override
  String toString() =>
      'FlightEvent(id: $id, category: ${category.name}, name: $name)';
}
