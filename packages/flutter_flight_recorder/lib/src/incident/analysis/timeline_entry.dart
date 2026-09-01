import 'package:flutter/foundation.dart';

import '../../events/flight_event.dart';

/// One human-readable line in an [IncidentTimeline].
///
/// Wraps a single recorded [event] — this never merges or drops data from
/// the underlying event, it only adds a plain-English [summary] and, when
/// [IncidentAnalyzer] found evidence connecting it to nearby events, a
/// [chainId] shared with the other entries in that same sequence (e.g. the
/// action that triggered a request, the request itself, and the error that
/// followed it).
@immutable
class TimelineEntry {
  const TimelineEntry({
    required this.event,
    required this.summary,
    this.chainId,
  });

  /// The underlying recorded event this entry describes. Already
  /// privacy-sanitized — see `FlightEvent.metadata`.
  final FlightEvent event;

  /// A short, plain-English description of [event], e.g. `"Opened Profile"`
  /// or `"PATCH /profile returned HTTP 422"`. Built entirely from fields
  /// already present on [event] — never inferred or fabricated.
  final String summary;

  /// Shared by every [TimelineEntry] that [IncidentAnalyzer] grouped into
  /// the same interaction — either because the underlying events shared
  /// an explicit `FlightEvent.correlationId`, or, absent that, because
  /// they were chronologically adjacent (a user action and the request/
  /// error that followed it, with no other action in between). `null`
  /// when this event could not be correlated with anything else. This
  /// is association evidence, not causation — see `IncidentAnalyzer`'s
  /// class doc for exactly how each strategy works.
  final String? chainId;

  Map<String, Object?> toJson() => {
        'event': event.toJson(),
        'summary': summary,
        if (chainId != null) 'chain_id': chainId,
      };

  @override
  String toString() => 'TimelineEntry($summary)';
}
