import 'package:flutter/foundation.dart';

import 'incident_story.dart';
import 'incident_timeline.dart';
import 'reproduction_step.dart';

/// The result of running [IncidentAnalyzer] over an [Incident]: a
/// normalized [timeline], an inferred [reproductionSteps] sequence, and a
/// short [story] — everything derived deterministically and entirely from
/// the incident's own recorded evidence.
@immutable
class IncidentAnalysis {
  const IncidentAnalysis({
    required this.timeline,
    required this.reproductionSteps,
    required this.story,
  });

  final IncidentTimeline timeline;
  final List<ReproductionStep> reproductionSteps;
  final IncidentStory story;

  Map<String, Object?> toJson() => {
        'story': story.summary,
        'reproduction_steps':
            reproductionSteps.map((step) => step.toJson()).toList(),
        'timeline': timeline.toJson(),
      };
}
