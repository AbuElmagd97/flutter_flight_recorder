<!--
  Reminder: any version bump must also update the install-instruction
  version pins in this package's own README.md and in the repo-root
  WALKTHROUGH.md, not just pubspec.yaml — a pin left stale here has
  bitten us before.
-->

## 0.0.7

* Added `flightRecorderCorrelationIdKey`: set it on a request's
  `RequestOptions.extra` to explicitly correlate that request with
  other recorded events (e.g. the action that triggered it) — the
  interceptor reads it and threads it through to the core package's
  new `FlightEvent.correlationId`. Optional and purely additive; a
  request with no such key records exactly as it always has. Explicit,
  per-request only — no ambient/Zone-based propagation.
* Bumped the `flutter_flight_recorder` dependency constraint
  (`^0.0.7`) to track that package's new `IncidentAnalyzer` release.

## 0.0.6

Docs-only patch — no changes to `lib/` or `test/`. Fixed a stale
`^0.0.3` install-instruction version pin in this README and the
repo-root `WALKTHROUGH.md`, and bumped the `flutter_flight_recorder`
dependency constraint (`^0.0.6`) to track that package's own release.

## 0.0.5

Fix: the logo in the README used a relative path (`docs/images/...`),
which renders fine on GitHub but not on pub.dev, which serves the
README disconnected from the repo's file structure. Switched to
absolute `raw.githubusercontent.com` URLs.

## 0.0.4

Added package logo.

## 0.0.3

Docs-only patch — no changes to `lib/` or `test/`. Bumped the
`flutter_flight_recorder` dependency constraint (`^0.0.3`) to track that
package's own docs/example-only patch release.

## 0.0.2

Documentation updates only — no changes to `lib/` or `test/`. README
overhaul (pub.dev badges, published-package status, simplified
installation instructions) and a bumped `flutter_flight_recorder`
dependency constraint (`^0.0.2`) to track that package's own docs-only
patch release.

## 0.0.1

Work in progress — not yet published to pub.dev.

* `FlightRecorderDioInterceptor`: one network event per request (method,
  sanitized URL, duration, status code, error type), recorded when a
  request finishes — not a separate "started" event.
* Request/response body capture, disabled by default
  (`captureRequestBody` / `captureResponseBody`); captured bodies pass
  through the core package's metadata sanitization.
* Query-parameter sanitization for the recorded URL
  (`sensitiveQueryParams`, defaults to the core package's
  `defaultSensitiveKeys`).
* Pinned to `dio: ">=5.11.0 <6.0.0"` — latest stable 5.x at time of
  writing, verified via pub.dev's API.
