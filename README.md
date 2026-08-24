# flutter_flight_recorder

> Everything that happened before the bug.

A monorepo of three independent, separately publishable Flutter
packages that together solve one problem: when a QA engineer or user
finds a bug, developers should get the complete story of what happened
before it — with as little manual effort as possible.

**Status: work in progress**, not yet published to pub.dev.

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
