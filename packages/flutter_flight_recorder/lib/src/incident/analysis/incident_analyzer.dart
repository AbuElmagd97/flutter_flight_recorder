import '../../events/flight_event.dart';
import '../incident.dart';
import 'incident_analysis.dart';
import 'incident_story.dart';
import 'incident_timeline.dart';
import 'reproduction_step.dart';
import 'timeline_entry.dart';

/// Turns an [Incident]'s raw, flat event list into a structured, evidence-
/// based analysis: a normalized [IncidentTimeline], an inferred
/// [ReproductionStep] sequence, and a short [IncidentStory].
///
/// This is deterministic and entirely local — the same [Incident] always
/// produces the same [IncidentAnalysis], with no network calls, randomness,
/// or AI involved. It reads only [Incident.timeline] and [FlightEvent]
/// fields already captured by [FlightRecorder]; it never invents an event,
/// a relationship, or a cause that wasn't recorded.
///
/// ### How correlation works
///
/// Two strategies, tried in this order for every event:
///
/// 1. **Explicit** — [FlightEvent.correlationId]. When an application
///    explicitly declared two or more events as the same interaction
///    (see `FlightRecorder.newCorrelationId` and the `correlationId`
///    parameter on `FlightRecorder.recordAction` and friends), those
///    events are grouped together directly, regardless of what happened
///    chronologically in between. This is what makes
///    `Tap Save -> PATCH /profile -> Tap Home -> GET /home -> PATCH
///    /profile (422) -> ProfileUpdateException` still correctly
///    attribute the failing `PATCH` to *Save*, not *Home* — something
///    the chronological strategy alone cannot do, because it only ever
///    knows about the single most-recently-opened chain.
/// 2. **Chronological fallback** — for every event with no
///    [FlightEvent.correlationId], or with one that isn't *usable* (see
///    below): every `action`/`navigation` event opens a chain; every
///    `network`/`error` event that follows joins whichever chain is
///    currently open, until the next `action`/`navigation` closes it. A
///    `network`/`error` event with no preceding trigger forms its own
///    single-event chain. This is unchanged from the analyzer's original
///    behavior — an event that was never given a `correlationId` is
///    correlated exactly as it always was.
///
/// A `correlationId` is *usable* only when **two or more** events in the
/// current [Incident.timeline] actually share it. An id that only one
/// surviving event carries — most commonly because its partner scrolled
/// out of `FlightRecorder`'s rolling buffer before the incident was
/// created — is treated exactly like having no `correlationId` at all,
/// falling through to the chronological strategy for that one event
/// rather than forming a misleading, evidence-free chain of one.
///
/// `log` and `lifecycle` category events carry no causal or user-journey
/// meaning and are excluded from every output here, the same way
/// `BugStoryGenerator` already excludes them from its narrative.
///
/// ### What this analyzer never says
///
/// Neither strategy is causation evidence, only *association* evidence:
/// every string this analyzer produces describes events "in sequence" or
/// "after" another event — an explicit `correlationId` states that two
/// events were declared part of the same interaction, not that one
/// caused the other. `Incident`'s event model has no field that would
/// justify a causation claim — if one is ever added, that's the one
/// place this class would need to change.
///
/// ### Pipeline
///
/// [analyze] runs a fixed sequence of independent, single-purpose stages
/// — deliberately not a pile of ad-hoc conditionals — so each stage can be
/// reasoned about (and evolved, e.g. a smarter [_correlate]) on its own:
///
/// ```text
/// Incident.timeline
///     -> _chronological   (normalize / order)
///     -> _correlate       (classify + group into causal-sequence chains)
///     -> _buildTimeline        \
///     -> _buildReproductionSteps  }  three independent views of the chains
///     -> _buildStory            /
/// ```
class IncidentAnalyzer {
  const IncidentAnalyzer._();

  /// Analyzes [incident]. Call this when an incident is created or
  /// reported — not on every recorded event; analysis is not cached on
  /// [Incident] itself, so callers that need the result more than once
  /// should hold on to the returned [IncidentAnalysis].
  static IncidentAnalysis analyze(Incident incident) {
    final events = _chronological(incident.timeline);
    final chains = _correlate(events);
    final chainIdByEventId = <String, String>{
      for (final chain in chains)
        for (final event in chain.events) event.id: chain.id,
    };

    return IncidentAnalysis(
      timeline: _buildTimeline(events, chainIdByEventId),
      reproductionSteps: _buildReproductionSteps(events),
      story: _buildStory(chains),
    );
  }

  /// Stable sort by timestamp: [Incident.timeline] is already chronological
  /// in normal use (it's built by appending to a rolling buffer), but this
  /// makes every other stage safe to assume ordering even if a caller
  /// constructs an [Incident] with events out of order — with equal
  /// timestamps broken by original position, so the result is always the
  /// same for the same input.
  static List<FlightEvent> _chronological(List<FlightEvent> events) {
    final indexed = events.indexed.toList()
      ..sort((a, b) {
        final byTime = a.$2.timestamp.compareTo(b.$2.timestamp);
        return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
      });
    return [for (final entry in indexed) entry.$2];
  }

  // ---------------------------------------------------------------------
  // Correlation — the sole extension point for how events get grouped.
  // The contract every other stage relies on is just: `_correlate` takes
  // chronological events and returns `List<_Chain>`, where each `_Chain`
  // has an `id`, an optional `trigger`, and its member `events`. Nothing
  // downstream (`_buildTimeline`, `_buildStory`) inspects *how* a chain
  // was formed — only that shape — so this stays the one place that
  // logic lives. (`_buildReproductionSteps` doesn't use chains at all —
  // it judges each event independently — so it isn't affected either
  // way.)
  //
  // Two strategies, tried in this order per event — see the class doc
  // for the full explanation and the interleaved-actions example this
  // is designed to fix:
  //
  //  1. Explicit: events sharing a *usable* `correlationId` (two or more
  //     surviving events with that id) are grouped together directly,
  //     regardless of anything chronologically in between them.
  //  2. Chronological fallback (unchanged from before `correlationId`
  //     existed): every `action`/`navigation` event opens a chain; every
  //     `network`/`error` event that follows joins whichever chain is
  //     currently open, until the next `action`/`navigation` closes it.
  //
  // A single `open` pointer serves both strategies — exactly the
  // original algorithm's variable, just now also settable by the
  // explicit branch: an action/navigation event whose own
  // `correlationId` is usable still becomes the chain new uncorrelated
  // followers attach to, so `Tap Save(explicit) -> unrelated ping ->
  // PATCH /profile(explicit, same id as Save)` puts the uncorrelated
  // ping in *Save's* chain, not a disconnected third one. A `network`/
  // `error` event with its own usable `correlationId` always joins its
  // explicit chain directly, regardless of what `open` currently is.
  // ---------------------------------------------------------------------

  static List<_Chain> _correlate(List<FlightEvent> events) {
    final usableCorrelationIds = _usableCorrelationIds(events);
    final chains = <_Chain>[];
    final explicitChains = <String, _Chain>{};
    _Chain? open;
    var counter = 0;

    for (final event in events) {
      final isTrigger = event.category == EventCategory.action ||
          event.category == EventCategory.navigation;
      final correlationId = event.correlationId;
      final usesExplicitCorrelation =
          correlationId != null && usableCorrelationIds.contains(correlationId);

      if (usesExplicitCorrelation) {
        final chain = explicitChains.putIfAbsent(correlationId, () {
          counter++;
          final created = _Chain(
            id: 'chain-$counter',
            trigger: isTrigger ? event : null,
          );
          chains.add(created);
          return created;
        });
        chain.events.add(event);
        if (isTrigger) open = chain;
        continue;
      }

      switch (event.category) {
        case EventCategory.action:
        case EventCategory.navigation:
          // A new trigger always closes whatever was open, exactly as
          // before — an unrelated action in between still prevents a
          // false chronological link.
          counter++;
          final chain = _Chain(id: 'chain-$counter', trigger: event)
            ..events.add(event);
          open = chain;
          chains.add(chain);
        case EventCategory.network:
        case EventCategory.error:
          if (open != null) {
            open.events.add(event);
          } else {
            counter++;
            chains.add(
              _Chain(id: 'chain-$counter', trigger: null)..events.add(event),
            );
          }
        case EventCategory.log:
        case EventCategory.lifecycle:
          break;
      }
    }
    return chains;
  }

  /// A `correlationId` is only trustworthy grouping evidence when at
  /// least two surviving events in [events] actually share it — a
  /// single surviving event (its partner likely evicted from the
  /// rolling buffer before the incident was created) carries no more
  /// evidence than an uncorrelated event, so it must not form a
  /// misleading chain of one.
  static Set<String> _usableCorrelationIds(List<FlightEvent> events) {
    final counts = <String, int>{};
    for (final event in events) {
      final id = event.correlationId;
      if (id == null) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return {
      for (final entry in counts.entries)
        if (entry.value > 1) entry.key,
    };
  }

  // ---------------------------------------------------------------------
  // Timeline
  // ---------------------------------------------------------------------

  static IncidentTimeline _buildTimeline(
    List<FlightEvent> events,
    Map<String, String> chainIdByEventId,
  ) {
    final entries = <TimelineEntry>[
      for (final event in events)
        if (_timelineSummary(event) case final summary?)
          TimelineEntry(
            event: event,
            summary: summary,
            chainId: chainIdByEventId[event.id],
          ),
    ];
    return IncidentTimeline(entries);
  }

  static String? _timelineSummary(FlightEvent event) {
    switch (event.category) {
      case EventCategory.action:
        return "Tapped '${_humanize(event.name)}'";
      case EventCategory.navigation:
        return _navigationSummary(event);
      case EventCategory.network:
        return _networkSummary(event);
      case EventCategory.error:
        return '${event.name} occurred';
      case EventCategory.log:
      case EventCategory.lifecycle:
        return null;
    }
  }

  static String _navigationSummary(FlightEvent event) {
    final screen = _describeRoute(event.name);
    return switch (event.metadata['action']) {
      'pop' => 'Navigated back from $screen',
      'push' => 'Opened $screen',
      _ => 'Navigated to $screen',
    };
  }

  static String _networkSummary(FlightEvent event) {
    final label = _networkLabel(event);
    final statusCode = event.metadata['statusCode'];
    final errorType = event.metadata['errorType'];
    if (statusCode is int) return '$label → HTTP $statusCode';
    if (errorType != null) return '$label failed ($errorType)';
    return label;
  }

  static String _networkLabel(FlightEvent event) {
    final method = event.metadata['method'];
    final url = event.metadata['url'] ?? event.name;
    return method != null ? '$method $url' : '$url';
  }

  // ---------------------------------------------------------------------
  // Reproduction steps
  // ---------------------------------------------------------------------

  static List<ReproductionStep> _buildReproductionSteps(
    List<FlightEvent> events,
  ) {
    final steps = <ReproductionStep>[];
    String? lastDescription;
    for (final event in events) {
      final description = _reproductionDescription(event);
      if (description == null || description == lastDescription) continue;
      steps.add(
        ReproductionStep(
          index: steps.length + 1,
          description: description,
          eventIds: [event.id],
        ),
      );
      lastDescription = description;
    }
    return steps;
  }

  /// `null` means "not meaningful reproduction evidence" — either noise
  /// (a `pop`, a log line, a lifecycle transition) or a network request
  /// that succeeded, which isn't part of *reproducing* the incident.
  static String? _reproductionDescription(FlightEvent event) {
    switch (event.category) {
      case EventCategory.action:
        return "Tap '${_humanize(event.name)}'";
      case EventCategory.navigation:
        if (event.metadata['action'] == 'pop') return null;
        return 'Open ${_describeRoute(event.name)}';
      case EventCategory.network:
        return _networkFailureDescription(event);
      case EventCategory.error:
        return '${event.name} occurred';
      case EventCategory.log:
      case EventCategory.lifecycle:
        return null;
    }
  }

  /// `null` when the request didn't fail — a successful request is
  /// implementation noise for reproduction purposes, not evidence.
  static String? _networkFailureDescription(FlightEvent event) {
    final outcome = _networkFailureClause(event);
    if (outcome == null) return null;
    return '${_networkLabel(event)} request $outcome';
  }

  /// Returns the failure clause (e.g. `'returned HTTP 422'`) or `null` if
  /// this network event does not represent a failure.
  static String? _networkFailureClause(FlightEvent event) {
    final statusCode = event.metadata['statusCode'];
    final errorType = event.metadata['errorType'];
    if (statusCode is int && statusCode >= 400) {
      return 'returned HTTP $statusCode';
    }
    if (errorType != null) return 'failed ($errorType)';
    return null;
  }

  // ---------------------------------------------------------------------
  // Story
  // ---------------------------------------------------------------------

  static IncidentStory _buildStory(List<_Chain> chains) {
    if (chains.isEmpty) {
      return const IncidentStory(
        'No events were recorded before this incident.',
      );
    }

    final failureChain = _lastChainWithFailure(chains);
    if (failureChain == null) {
      return const IncidentStory(
        'No error or failed network request was recorded before this '
        'incident was created.',
      );
    }

    FlightEvent? failedNetwork;
    FlightEvent? error;
    for (final event in failureChain.events) {
      if (event.category == EventCategory.network &&
          _networkFailureClause(event) != null) {
        failedNetwork = event;
      }
      if (event.category == EventCategory.error) error = event;
    }

    final clauses = <String>[];
    if (failedNetwork != null) {
      clauses.add(
        'the ${_networkLabel(failedNetwork)} request '
        '${_networkFailureClause(failedNetwork)}',
      );
    }
    if (error != null) {
      clauses.add(clauses.isEmpty
          ? '${error.name} occurred'
          : 'followed by ${error.name}');
    }

    final body = clauses.isEmpty ? 'an error was recorded' : clauses.join(', ');
    final trigger = failureChain.trigger != null
        ? _storyTrigger(failureChain.trigger!)
        : null;

    final sentence =
        trigger != null ? 'After $trigger, $body.' : '${_capitalize(body)}.';
    return IncidentStory(sentence);
  }

  /// The chain whose most recent failure evidence is the most recent
  /// overall — deliberately "most recent", not "first" or "all",
  /// matching `Incident.latestError`'s existing precedent elsewhere in
  /// this package: when there were multiple failures, the story is
  /// about the one closest to when the incident was actually created.
  ///
  /// Compares by the failure evidence's own timestamp, not by [chains]'
  /// list order: with explicit correlation, a chain can be re-opened by
  /// a later event long after it was first created (e.g. a `PATCH`
  /// that finally lands well after an unrelated action's chain has come
  /// and gone) — list order alone would then pick the wrong chain.
  static _Chain? _lastChainWithFailure(List<_Chain> chains) {
    _Chain? result;
    DateTime? resultTimestamp;
    for (final chain in chains) {
      DateTime? latestFailure;
      for (final event in chain.events) {
        final isFailure = event.category == EventCategory.error ||
            (event.category == EventCategory.network &&
                _networkFailureClause(event) != null);
        if (!isFailure) continue;
        if (latestFailure == null || event.timestamp.isAfter(latestFailure)) {
          latestFailure = event.timestamp;
        }
      }
      if (latestFailure == null) continue;
      if (resultTimestamp == null || latestFailure.isAfter(resultTimestamp)) {
        result = chain;
        resultTimestamp = latestFailure;
      }
    }
    return result;
  }

  static String _storyTrigger(FlightEvent event) {
    switch (event.category) {
      case EventCategory.action:
        return "tapping '${_humanize(event.name)}'";
      case EventCategory.navigation:
        final screen = _describeRoute(event.name);
        return switch (event.metadata['action']) {
          'pop' => 'navigating back from $screen',
          'push' => 'opening $screen',
          _ => 'navigating to $screen',
        };
      case EventCategory.network:
      case EventCategory.error:
      case EventCategory.log:
      case EventCategory.lifecycle:
        // A chain's trigger is only ever an action/navigation event — see
        // _buildChains.
        return _humanize(event.name);
    }
  }

  static String _humanize(String name) => name.replaceAll('_', ' ').trim();

  static String _describeRoute(String name) {
    if (name.isEmpty || name == '/' || name == '<unnamed>') return 'app';
    return name.replaceFirst(RegExp(r'^/'), '').replaceAll('_', ' ');
  }

  static String _capitalize(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}

class _Chain {
  _Chain({required this.id, required this.trigger});

  final String id;

  /// The `action`/`navigation` event that started this chain, or `null`
  /// for a `network`/`error` event with no preceding trigger in the
  /// timeline.
  final FlightEvent? trigger;

  final List<FlightEvent> events = [];
}
