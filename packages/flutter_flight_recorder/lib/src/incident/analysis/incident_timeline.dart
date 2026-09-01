import 'package:flutter/foundation.dart';

import 'timeline_entry.dart';

/// A normalized, human-readable timeline built from an [Incident]'s raw
/// event list by [IncidentAnalyzer].
///
/// Unlike `Incident.timeline` (every recorded event, verbatim), this
/// filters out entries that aren't part of the user-journey story — `log`
/// and `lifecycle` category events — the same noise `BugStoryGenerator`
/// already excludes from its narrative, for the same reason: they're
/// development-facing detail, not something a QA reporter needs to read.
/// Nothing is filtered based on content, only on event category, so this
/// can never silently drop evidence relevant to the incident.
@immutable
class IncidentTimeline {
  const IncidentTimeline(this.entries);

  /// Entries in chronological order.
  final List<TimelineEntry> entries;

  bool get isEmpty => entries.isEmpty;

  List<Object?> toJson() => entries.map((entry) => entry.toJson()).toList();

  @override
  String toString() => 'IncidentTimeline(${entries.length} entries)';
}
