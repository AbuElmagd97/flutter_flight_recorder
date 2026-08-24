import 'package:flutter/foundation.dart';

import '../events/flight_event.dart';
import '../json_safety.dart';
import 'qa_report_data.dart';

/// Current [Incident.toJson] schema version. Bump this and document the
/// change whenever the JSON shape changes in a way existing consumers
/// would need to account for.
const int incidentSchemaVersion = 1;

/// An immutable snapshot of everything known about a bug at the moment it
/// was reported.
///
/// Created via [FlightRecorder.createIncident], never directly by
/// application code in normal use. Once created, an incident never
/// changes — later recording does not retroactively affect it, since
/// [timeline] and [context] are frozen copies taken at construction time,
/// not live views into the recorder.
@immutable
class Incident {
  Incident({
    required this.id,
    required this.timestamp,
    required this.title,
    this.description,
    this.qaReport,
    Object? trigger,
    required List<FlightEvent> timeline,
    required Map<String, Object?> context,
  })  : trigger = trigger == null ? null : normalizeForJson(trigger),
        timeline = List.unmodifiable(timeline),
        context = Map.unmodifiable(context);

  final String id;
  final DateTime timestamp;
  final String title;
  final String? description;
  final QaReportData? qaReport;

  /// What caused this incident to be created, e.g. `'manual'`, `'shake'`,
  /// `'button'`, or any application-supplied value. Free-form and
  /// optional. Normalized to a JSON-safe value at construction time so
  /// [toJson] can never fail because of it.
  final Object? trigger;

  /// Full event timeline at the moment this incident was created.
  final List<FlightEvent> timeline;

  /// Application context at the moment this incident was created.
  ///
  /// Auto-captured fields are limited to `platform` and `locale`. App
  /// version and build number are **not** in here unless the app called
  /// `FlightRecorder.setContext` for them — see the package README's
  /// "Application context" section for why that's permanent, not
  /// temporary.
  final Map<String, Object?> context;

  /// The most recently recorded error event in [timeline], if any.
  FlightEvent? get latestError {
    for (final event in timeline.reversed) {
      if (event.category == EventCategory.error) return event;
    }
    return null;
  }

  List<FlightEvent> get navigationHistory =>
      _byCategory(EventCategory.navigation);

  List<FlightEvent> get networkEvents => _byCategory(EventCategory.network);

  List<FlightEvent> get logs => _byCategory(EventCategory.log);

  List<FlightEvent> _byCategory(EventCategory category) => timeline
      .where((event) => event.category == category)
      .toList(growable: false);

  /// Stable, versioned JSON export. See [incidentSchemaVersion].
  ///
  /// `timeline` is a single flat array — there are no separate
  /// navigation/network/logs arrays in the export (a deliberate decision;
  /// see the package README's "JSON export" section for why, and why
  /// changing that would need a schema version bump).
  Map<String, Object?> toJson() {
    final error = latestError;
    return {
      'schema_version': incidentSchemaVersion,
      'incident_id': id,
      'timestamp': timestamp.toIso8601String(),
      'title': title,
      if (description != null) 'description': description,
      if (qaReport != null) 'qa_report': qaReport!.toJson(),
      if (trigger != null) 'trigger': trigger,
      if (error != null) 'error': error.toJson(),
      'timeline': timeline.map((event) => event.toJson()).toList(),
      'context': context,
    };
  }
}
