import 'package:flutter/foundation.dart';

/// One numbered step in an [IncidentAnalysis.reproductionSteps] sequence.
///
/// Each step is backed by one or more recorded events — [eventIds]
/// references `FlightEvent.id` — so a consumer can always trace a
/// reproduction step back to the exact evidence it came from.
@immutable
class ReproductionStep {
  const ReproductionStep({
    required this.index,
    required this.description,
    required this.eventIds,
  });

  /// 1-based position in the sequence.
  final int index;

  /// Short, imperative description, e.g. `"Open Profile"` or `"Tap Save"`.
  final String description;

  /// `FlightEvent.id` of the event(s) this step is evidence for.
  final List<String> eventIds;

  Map<String, Object?> toJson() => {
        'step': index,
        'description': description,
        'event_ids': eventIds,
      };

  @override
  String toString() => '$index. $description';
}
