import 'package:flutter/foundation.dart';

/// A short, evidence-based summary of what happened before an incident,
/// produced by [IncidentAnalyzer].
///
/// [summary] states only what the recorded evidence directly shows —
/// observed facts (an action happened, a request returned a status code,
/// an error was recorded) and their chronological sequence. It never
/// states a *cause* that wasn't captured (e.g. it will say a request
/// "returned HTTP 422", never guess *why* the server rejected it), and
/// when there isn't enough evidence to connect an error to a preceding
/// action, it says so rather than assuming one.
@immutable
class IncidentStory {
  const IncidentStory(this.summary);

  /// One or two plain-English sentences. Never empty — when there's
  /// nothing to report, this explicitly says so (e.g. `"No error or
  /// failed network request was recorded before this incident was
  /// created."`) rather than being blank.
  final String summary;

  @override
  String toString() => summary;
}
