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
