<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../../docs/images/logo.png">
  <img alt="flutter_flight_recorder logo" src="../../docs/images/logo-light.png" width="200">
</picture>

# flutter_flight_recorder

[![pub package](https://img.shields.io/pub/v/flutter_flight_recorder.svg)](https://pub.dev/packages/flutter_flight_recorder)
[![pub points](https://img.shields.io/pub/points/flutter_flight_recorder)](https://pub.dev/packages/flutter_flight_recorder/score)
[![likes](https://img.shields.io/pub/likes/flutter_flight_recorder)](https://pub.dev/packages/flutter_flight_recorder/score)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> Everything that happened before the bug.

**Status: published on pub.dev.** This README documents only what's
implemented — the core event recorder and incident system. Every code
example below has been checked against the real, current source;
nothing here is aspirational.

Network request recording lives in the separate, optional
[`flutter_flight_recorder_dio`](../flutter_flight_recorder_dio) package,
and the QA bug-reporting UI lives in the separate, optional
[`flutter_flight_recorder_reporter`](../flutter_flight_recorder_reporter)
package — this core package depends on neither and stays dependency-free.

## What problem does this solve?

When a QA engineer or user finds a bug, a developer needs the complete
story of what happened before it — what screen they were on, what they
tapped, what network calls were in flight, what was logged, what error
was thrown — with as little manual effort from anyone as possible. This
package is a bounded, always-on recorder for exactly that story: it
keeps a rolling timeline of app events in memory, and turns it into an
immutable, structured **incident** the moment something goes wrong.

## Why not just use a logger?

A logger gives you a stream of text you have to go looking through,
after the fact, hoping the right lines are still in the buffer and that
you can reconstruct a timeline by eye. This package is different in
three ways a logger isn't:

* **It's structured, not text.** Every entry is a typed `FlightEvent`
  with a category, not a log line you have to parse.
* **It correlates categories on purpose.** Navigation, actions, network
  activity, and errors all land in the *same* timeline, in order, so you
  can see what led to what — not five separate logs you have to
  cross-reference by timestamp.
* **It produces a snapshot, not a stream.** `FlightRecorder.createIncident()`
  freezes the current timeline into an immutable object. A logger keeps
  scrolling; an incident stops the clock at the moment it matters.

It does not replace your existing logging framework — `FlightRecorder.log()`
is additive, not a requirement to rip out `package:logging` or anything
else you already use.

## Features

* A normalized, typed, immutable event model (`FlightEvent`) covering
  navigation, network, action, log, error, and lifecycle categories.
* A bounded rolling buffer — configurable capacity, oldest-evicted-first,
  O(1) add/evict.
* Manual and automatic error capture, chained to (never replacing) any
  existing error handling.
* A `NavigatorObserver` for Navigator 1.x, and a `WidgetsBindingObserver`
  for app lifecycle transitions.
* Privacy sanitization applied synchronously at record time, before an
  event ever enters the buffer — see [`docs/privacy.md`](../../docs/privacy.md).
* Immutable, versioned incident snapshots with a stable JSON export.
* Zero pub package dependencies.

## Installation

```yaml
dependencies:
  flutter_flight_recorder: ^0.0.3
```

## Quick start

```dart
import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';

void main() {
  FlightRecorder.init();
  runApp(const MyApp());
}
```

```dart
FlightRecorder.recordAction(
  'save_profile_tapped',
  metadata: {'screen': 'edit_profile'},
);

FlightRecorder.log('Profile update started');

FlightRecorder.recordError(error, stackTrace: stackTrace);

FlightRecorder.setContext('environment', 'uat');
```

That's the whole quick start — one call in `main()`, then whichever of
the four recording methods above you need, wherever you need them.

### Configuration

```dart
FlightRecorder.init(
  const FlightRecorderConfig(
    maxEvents: 500,               // oldest event evicted once exceeded
    enabledCategories: null,      // null = all categories
    captureUncaughtErrors: true,  // installs FlutterError.onError + PlatformDispatcher.onError hooks
    privacy: PrivacyConfig(
      sensitiveKeys: defaultSensitiveKeys, // password, token, authorization, ...
      customSanitizer: null,
    ),
  ),
);
```

`enabled: false` (default `true`) makes every recording method a no-op
for the lifetime of that config — see "Core Recorder" below for what
that does and doesn't affect.

## Core Recorder

`FlightRecorder` is a static facade over a single recording session,
started by `init()`. Calling `init()` again is safe and expected —
common during hot restart — but it fully resets the buffer and context
and applies the new config; it does not merge with the previous session.

Calling a recording method before `init()` is a no-op: an
`AssertionError` is raised in debug/test builds (to catch the mistake
during development), and silently does nothing in release builds (so it
can never crash a real user's app over ordering).

```dart
FlightRecorder.isInitialized; // bool
```

## Error Recording

```dart
FlightRecorder.recordError(
  error,
  stackTrace: stackTrace,
  metadata: {'screen': 'edit_profile'}, // optional
  severity: EventSeverity.error,          // optional, this is the default
);
```

This is the manual path — call it wherever you catch an error you want
attached to the timeline. Separately, when
`FlightRecorderConfig.captureUncaughtErrors` is `true` (the default),
`init()` also installs handlers for uncaught Flutter framework errors
and unhandled platform/async errors. Both **always chain to whatever
handler was already installed** — including Flutter's own default error
reporting — so this never silently replaces existing application error
handling. You don't need to call `recordError` yourself for errors that
reach these; they're captured automatically.

## Navigation Tracking

```dart
MaterialApp(
  navigatorObservers: [FlightRecorderNavigatorObserver()],
  // ...
)
```

Supports Navigator 1.x (`push`/`pop`/`replace`/`remove`). Only route
**names** are recorded — route arguments are never captured, by design
(spec §4). Unnamed routes are recorded as `'<unnamed>'`. Navigating
before `FlightRecorder.init()` has run is silently ignored rather than
raising a debug assertion, since routes can be pushed while the widget
tree first builds, potentially before your app has called `init()` —
this is deliberately different from the direct recording methods above,
where a debug assertion is the right nudge because a developer chose to
call them.

Navigator 2.0, `go_router`, and `auto_route` are not supported yet — see
"Limitations."

### App lifecycle

```dart
WidgetsBinding.instance.addObserver(FlightRecorderLifecycleObserver());
```

Records `resumed`/`inactive`/`paused`/`detached`/`hidden` transitions.
Same before-`init()` behavior as the navigation observer, for the same
reason — lifecycle transitions are framework-triggered, not something
application code chooses to call.

## Actions

```dart
FlightRecorder.recordAction('save_profile_tapped');

FlightRecorder.recordAction(
  'save_profile_tapped',
  metadata: {'screen': 'edit_profile'},
);
```

There is no automatic gesture tracking in this package (spec §5) — every
action is one you explicitly record. This is a deliberate scope
boundary, not a missing feature.

## Logs

```dart
FlightRecorder.log('Profile update started');

FlightRecorder.log(
  'Profile update started',
  level: EventSeverity.warning, // debug / info (default) / warning / error
  metadata: {'userId': 42},
);
```

Logs become timeline events, alongside everything else — this does not
replace or hook into an application's existing logging framework; it's
additive.

## Dio Integration

Network request recording is not in this package — see
[`flutter_flight_recorder_dio`](../flutter_flight_recorder_dio), a
separate, optional package that depends on this one. Core stays
dependency-free; it has no knowledge of Dio at all.

## QA Reporter

The shake/button/manual bug-reporting UI, screenshot capture, the Bug
Story generator, and HTML/JSON export are not in this package either —
see [`flutter_flight_recorder_reporter`](../flutter_flight_recorder_reporter),
also separate and optional.

## Privacy and Sanitization

Full detail lives in [`docs/privacy.md`](../../docs/privacy.md). The
short version: sanitization runs synchronously at record time, before an
event ever enters the buffer, masking any metadata key that matches the
sensitive-key list (`password`, `token`, `authorization`, `access_token`,
`refresh_token`, `cookie`, `session` by default) at any nesting depth,
and normalizing anything that isn't already JSON-safe so an event can
never fail to serialize later.

This is **key-name matching, not content inspection** — sensitive data
stored under a non-standard key (e.g. `'pwd'` instead of `'password'`)
will not be masked automatically. Extend `sensitiveKeys` or supply a
`customSanitizer` to cover application-specific key names.

### Application context — app version/build number are NOT captured automatically

**Read this if you're only using `flutter_flight_recorder` without the
reporter package.** `FlightRecorder` auto-captures exactly two fields:
`platform` and `locale`, both available directly from the Flutter SDK.
**It does not, and by design never will, automatically capture app
version or build number.** Every incident you create will simply be
missing that information unless you supply it yourself — this is not a
"not implemented yet" gap that will get filled in later; it's a permanent
architectural decision, so don't assume it'll show up once the reporter
package is added.

Why: the only package that provides app version/build number
(`package_info_plus`) would raise this package's minimum supported
Flutter version to match its own floor (`>=3.38.1`), which would defeat
the point of keeping core dependency-free and maximally portable. If you
need app version/build number in your incidents, supply them yourself:

```dart
final info = await PackageInfo.fromPlatform(); // package_info_plus, in your app
FlightRecorder.setContext('app_version', info.version);
FlightRecorder.setContext('build_number', info.buildNumber);
```

## Incident Structure

An incident is an immutable snapshot of the current timeline and
context, taken the moment `createIncident` is called. Later recording
never changes it — this is enforced structurally, not just by
convention: `timeline` and `context` are deep-copied into unmodifiable
collections at construction time.

```dart
final incident = FlightRecorder.createIncident(
  title: 'Profile update failed',
  description: 'Unable to save profile changes.',
  qaReport: const QaReportData(
    expected: 'Profile should be saved successfully.',
    actual: 'Validation error appears.',
    severity: IncidentSeverity.high,
  ),
  trigger: 'manual', // e.g. 'manual', 'shake', 'button'; free-form
);

incident.id;                 // 'INC-7F8A2D'
incident.timestamp;           // DateTime
incident.title;                 // String
incident.description;           // String?
incident.qaReport;               // QaReportData?
incident.trigger;                 // Object?, normalized to JSON-safe
incident.timeline;                 // List<FlightEvent>, the full timeline
incident.context;                   // Map<String, Object?>
incident.latestError;                // FlightEvent?, most recent error event
incident.navigationHistory;           // List<FlightEvent>, filtered
incident.networkEvents;                // List<FlightEvent>, filtered
incident.logs;                          // List<FlightEvent>, filtered
```

`createIncident` throws a `StateError` if called before `init()` —
deliberately different from the void recording methods above: it can't
safely no-op, since it has to return a value, so it fails loudly in
every build mode rather than only asserting in debug.

## Exporting JSON

```dart
final json = incident.toJson();
```

`Incident.toJson()` is versioned via `schema_version` (currently `1`).
The shape:

```json
{
  "schema_version": 1,
  "incident_id": "INC-7F8A2D",
  "timestamp": "...",
  "title": "...",
  "description": "...",
  "qa_report": {"expected": "...", "actual": "...", "severity": "high"},
  "trigger": "manual",
  "error": {"id": "...", "timestamp": "...", "category": "error", "name": "...", "metadata": {}},
  "timeline": [],
  "context": {}
}
```

`description`, `qa_report`, `trigger` and `error` are omitted entirely
when not set/available, rather than included as `null`.

**Recorded decision: the export keeps a single flat, chronological
`timeline` array — there are no separate `navigation_history` /
`network_events` / `logs` arrays in the JSON**, even though
`incident.navigationHistory` / `.networkEvents` / `.logs` exist as
filtered *Dart-side* getters. This was a deliberate choice, not
an oversight: it keeps the export shape simple and avoids
two representations of the same events drifting out of sync. If this
ever needs to change — e.g. splitting `timeline` into per-category arrays
in the wire format — that is a breaking change to the export shape and
**must** bump `schema_version`, not be done in place.

## Platform Support

See [`docs/platform_support.md`](../../docs/platform_support.md) for the
full matrix and an explicit distinction between "no platform-specific
code" and "actually verified." Short version: this package has no
platform channel or native plugin anywhere — every feature is pure Dart
or a Flutter SDK API — but only a macOS build of the example app has
actually been run; Android/iOS/Web/Windows/Linux have not been built in
this repository.

## Performance

* The rolling buffer is a `dart:collection` `ListQueue` — O(1) add and
  O(1) evict-oldest, not an O(n) list shift.
* Sanitization runs once, on the metadata passed at record time — it is
  never re-run on read or export.
* No JSON serialization happens during recording — only when you
  actually call `createIncident()`/`toJson()`.
* `enabled: false` and per-category disabling (`enabledCategories`) are
  cheap boolean checks at each public API entry point.
* App version/build number are deliberately not auto-captured (see
  Privacy) specifically to avoid pulling in a plugin dependency that
  would raise this package's minimum Flutter version.

## Security and Privacy

Covered fully in [`docs/privacy.md`](../../docs/privacy.md) — what's
captured, what's never captured, when sanitization happens, and the
explicit limitation that masking is key-name-based, not content-based.

## Limitations

* Sanitization is key-name matching, not content inspection — see
  Privacy.
* App version/build number are never auto-captured — see Privacy.
* Navigator 2.0 / `go_router` / `auto_route` are not supported; only
  Navigator 1.x via `NavigatorObserver`.
* No automatic gesture tracking — actions are only recorded when you
  explicitly call `recordAction`.
* The JSON export's `timeline` is a single flat array by design (see
  "Exporting JSON") — splitting it would be a breaking, versioned change,
  not a small addition.
* Only a macOS build has actually been run — see "Platform Support."

## Roadmap

Everything currently planned is either already built in a sibling
package (Dio integration, the QA reporter, HTML/JSON export) or is one
of the limitations above. There is no committed roadmap beyond what's
listed there; if Navigator 2.0 support or content-aware sanitization
become real priorities, they'd be deliberate, versioned additions — not
silent behavior changes.

## Contributing

This is a young, actively maintained project without a formal external
contribution process yet. If you're working in this repository,
match the conventions already established across the three packages:
minimal dependencies (justify every one against pub.dev's own
popularity/maintenance/platform-support signals), no fake or
aspirational README content, and `dart format` / `flutter analyze` /
`flutter test` clean before anything is considered done.

## License

MIT
