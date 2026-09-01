<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/AbuElmagd97/flutter_flight_recorder/main/docs/images/logo.png">
  <img alt="flutter_flight_recorder logo" src="https://raw.githubusercontent.com/AbuElmagd97/flutter_flight_recorder/main/docs/images/logo-light.png" width="200">
</picture>

[![StandWithPalestine](https://raw.githubusercontent.com/TheBSD/StandWithPalestine/main/badges/StandWithPalestine.svg)](https://github.com/TheBSD/StandWithPalestine/blob/main/docs/README.md)

# flutter_flight_recorder

> Everything that happened before the bug.

A monorepo of three independent, separately publishable Flutter
packages that together solve one problem: when a QA engineer or user
finds a bug, developers should get the complete story of what happened
before it — with as little manual effort as possible.

<!-- Capture: a short screen recording of the full end-to-end flow —
     shake the device, the reporter opens, fill in the bug report form,
     tap submit, and the report preview screen appears. Convert to a
     GIF and save as docs/images/shake-to-report-demo.gif. Keep it
     short (a few seconds) and trimmed tightly to just that flow. -->
![Shake-to-report flow: shake the device, fill in the bug report form, and view the generated report preview](docs/images/shake-to-report-demo.gif)

New to this package? Start with [WALKTHROUGH.md](WALKTHROUGH.md) — from zero to your first bug report in under 5 minutes.

**Status:** All three packages are published on pub.dev.

## Incident Intelligence

Your QA team reports:

> "Profile save is broken."

`flutter_flight_recorder` can show:

**What happened:**
Profile update failed after the user edited their phone number and
tapped Save.

**Reproduction:**
1. Open Profile
2. Open Edit Profile
3. Change phone number
4. Tap Save
5. `PATCH /profile` request returned HTTP 422

**Evidence:**
`PATCH /profile → HTTP 422`, followed by `ProfileUpdateException`.

That's the recorder's `IncidentAnalyzer` — a small, deterministic,
offline analysis pipeline (no AI, no network calls) that turns an
incident's raw recorded events into a normalized timeline, an inferred
reproduction sequence, and a short evidence-based story:

```dart
final incident = FlightRecorder.createIncident(title: 'Profile save broken');
final analysis = IncidentAnalyzer.analyze(incident);

analysis.story;             // IncidentStory — 1–2 sentences, evidence only
analysis.reproductionSteps; // List<ReproductionStep> — numbered, deterministic
analysis.timeline;          // IncidentTimeline — normalized, noise filtered out
```

**What it infers:** the sequence of user actions, navigation, and
network/error events leading to the incident, and which of them are
plausibly related (same causal chain) based on chronological adjacency.

**What it intentionally never infers:** *why* something failed. It will
say a request "returned HTTP 422" — never guess that "the backend
rejected an invalid phone number" unless that's actually in the
recorded evidence. See `IncidentAnalyzer`'s class doc in the core
package for exactly how correlation works and its documented limits
(no request/correlation IDs yet — it's a chronological-adjacency
heuristic, not a proof of causation).

Full details, including every edge case the analyzer is tested
against, live in
[`flutter_flight_recorder`'s own README](packages/flutter_flight_recorder#incident-intelligence).

Turn that same evidence into a bug report your team can actually paste
somewhere — Jira, Linear, GitHub Issues, Slack, email:

```dart
final markdown = IncidentMarkdownExporter.export(incident, analysis);
```

A pure Markdown formatter over `incident` + `analysis` — no new
analysis, no invented conclusions, deterministic. See
[`flutter_flight_recorder`'s "Exporting
Markdown"](packages/flutter_flight_recorder#exporting-markdown) for a
full example report and what it deliberately leaves out.

## Which package do you need?

| I want to...                                  | Install this |
|------------------------------------------------|--------------|
| Record errors, navigation, and actions          | `flutter_flight_recorder` |
| ...and also auto-record my Dio HTTP requests    | + `flutter_flight_recorder_dio` |
| ...and let QA report bugs with one tap          | + `flutter_flight_recorder_reporter` |

Most apps start with just the first package.

## Quick start

Full setup, all three packages together:

```yaml
dependencies:
  flutter_flight_recorder: ^0.0.7
  flutter_flight_recorder_dio: ^0.0.7
  flutter_flight_recorder_reporter: ^0.0.7
```

```dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';
import 'package:flutter_flight_recorder_dio/flutter_flight_recorder_dio.dart';
import 'package:flutter_flight_recorder_reporter/flutter_flight_recorder_reporter.dart';

void main() {
  FlightRecorder.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FlutterFlightRecorderReporter(
      child: MaterialApp(
        navigatorObservers: [FlightRecorderNavigatorObserver()],
        home: const HomeScreen(),
      ),
    );
  }
}

final dio = Dio()..interceptors.add(FlightRecorderDioInterceptor());
```

Only using the core recorder? Skip the Dio and reporter lines above —
see the table above for what you actually need.

See each package's own README for its full API and configuration
options: [`flutter_flight_recorder`](packages/flutter_flight_recorder),
[`flutter_flight_recorder_dio`](packages/flutter_flight_recorder_dio),
[`flutter_flight_recorder_reporter`](packages/flutter_flight_recorder_reporter).

## Packages

* [`flutter_flight_recorder`](packages/flutter_flight_recorder) — the
  core event recorder: a bounded rolling timeline, error/navigation/
  lifecycle recording, privacy sanitization, and immutable, versioned
  incident snapshots. Zero pub package dependencies.
* [`flutter_flight_recorder_dio`](packages/flutter_flight_recorder_dio)
  — an optional Dio interceptor that records HTTP requests into the same
  timeline.
* [`flutter_flight_recorder_reporter`](packages/flutter_flight_recorder_reporter)
  — an optional QA bug-reporting UI: shake/button/manual trigger,
  screenshot capture, a bug report form, a deterministic human-readable
  Bug Story, and HTML/JSON report export.

Each package's own README covers its full quick start, API, and
limitations. Two things are documented once, centrally, and linked from
every package rather than duplicated:

* [`docs/privacy.md`](docs/privacy.md) — what's captured, what's never
  captured, when and how sanitization happens, and its one honest
  limitation (key-name matching, not content inspection).
* [`docs/platform_support.md`](docs/platform_support.md) — an explicit,
  honest platform support matrix that separates "no platform-specific
  code" from "actually verified."

## Example

[`example/`](example) is a real, runnable Flutter app demonstrating all
three packages together — see its own README for what it exercises and
a manual verification checklist for the things that can only be
confirmed on a real device.

## License

MIT — see [`LICENSE`](LICENSE). Each package also carries its own
identical MIT license.
