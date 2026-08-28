# flutter_flight_recorder_dio

[![pub package](https://img.shields.io/pub/v/flutter_flight_recorder_dio.svg)](https://pub.dev/packages/flutter_flight_recorder_dio)
[![pub points](https://img.shields.io/pub/points/flutter_flight_recorder_dio)](https://pub.dev/packages/flutter_flight_recorder_dio/score)
[![likes](https://img.shields.io/pub/likes/flutter_flight_recorder_dio)](https://pub.dev/packages/flutter_flight_recorder_dio/score)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Dio interceptor for [`flutter_flight_recorder`](../flutter_flight_recorder): records HTTP requests (method, sanitized URL, duration, status, errors) into the flight recorder timeline.

**Status: published on pub.dev.** Every code example below has been
checked against the real, current source; nothing here is aspirational.

## What problem does this solve? Why not just use a logger?

See the [core package's README](../flutter_flight_recorder#what-problem-does-this-solve)
for the full answer — this package exists purely to get network activity
into that same shared timeline automatically, instead of you writing
`FlightRecorder.recordAction(...)` calls around every `dio.get`/`dio.post`
call by hand.

## Features

* One network event per completed request — method, sanitized URL,
  duration, status code, and error type together.
* Request/response body capture, off by default, opt-in per interceptor
  instance.
* URL query-parameter sanitization, independent of and complementary to
  the core package's own metadata sanitizer.
* Zero dependencies beyond `dio` itself and the core package.

## Installation

```yaml
dependencies:
  flutter_flight_recorder_dio: ^0.0.2
```

## Quick start

```dart
import 'package:dio/dio.dart';
import 'package:flutter_flight_recorder_dio/flutter_flight_recorder_dio.dart';

final dio = Dio();
dio.interceptors.add(FlightRecorderDioInterceptor());
```

`FlightRecorder.init()` must have been called first (from the core
package) for anything to be recorded — if it hasn't, this interceptor
silently does nothing rather than raising a debug assertion, the same
behavior as the core package's navigation and lifecycle observers, and
for the same reason: a `Dio` instance and its interceptors are commonly
constructed before an app has necessarily called `FlightRecorder.init()`.

## Dio Integration — what gets recorded

One network event per request, recorded when it finishes — not a
separate "started" event:

* HTTP method
* a sanitized URL
* timestamp (when the request finished)
* duration in milliseconds
* status code (when there is a response)
* error type (`DioExceptionType.name`, when the request failed)

```dart
event.category;               // EventCategory.network
event.name;                     // 'PATCH /profile'
event.metadata['method'];        // 'PATCH'
event.metadata['url'];            // 'https://api.example.com/profile'
event.metadata['statusCode'];      // 422
event.metadata['durationMs'];       // 1200
event.metadata['errorType'];         // 'badResponse', only present on failure
```

### Request/response bodies — disabled by default

```dart
FlightRecorderDioInterceptor(
  captureRequestBody: false,  // default
  captureResponseBody: false, // default
);
```

Enable explicitly if you need them. When enabled, a captured body still
passes through the core package's own metadata sanitization — the same
default sensitive-key masking used everywhere else (`password`, `token`,
`authorization`, ...), applied recursively, so a nested `password` field
in a JSON body is still masked even with capture turned on.

### URL sanitization

Query parameters whose key matches `sensitiveQueryParams` (case
insensitive; defaults to `defaultSensitiveKeys` from the core package)
are masked in the recorded URL:

```dart
FlightRecorderDioInterceptor(
  sensitiveQueryParams: {'token', 'access_token', 'session_id'}, // your own set
);
```

This is handled separately from the core package's generic metadata
sanitizer, because a URL is a single string to that sanitizer — it
doesn't parse query strings looking for sensitive-looking keys. Nothing
else about the recorded data is sanitized by this package directly; the
method/status/duration/errorType fields aren't the kind of data that
needs masking. Full detail on sanitization in general lives in
[`docs/privacy.md`](../../docs/privacy.md).

## Platform Support

See [`docs/platform_support.md`](../../docs/platform_support.md) for the
full matrix. Short version: this package has no platform channel of its
own — everything is Dart-level `dio` object manipulation — so its
platform reach is exactly `dio`'s own (all six platforms declared), but
only a macOS build of the example app has actually been run.

## Performance

* No additional serialization beyond what the core package already does
  at `FlightRecorder.recordNetwork` time — this package's own work per
  request is: read a few fields off `RequestOptions`/`Response`/`DioException`,
  mask the URL's query string, and hand a metadata map to core.
* Bodies are never captured (and therefore never sanitized) unless you
  explicitly opt in — the default cost of this interceptor per request
  is a handful of field reads, not a JSON traversal.

## Limitations

* One event per request, not two (no separate "request started" event)
  — matches what the request/response cycle naturally produces once it's
  finished, and avoids recording half a request if nothing ever calls
  `onResponse`/`onError` for it (e.g. it's still in flight when the app
  closes).
* Only Dio is supported — no `http`/`chopper`/other HTTP client
  integrations exist in this repository.
* `Uri.queryParameters` (used internally for URL sanitization) collapses
  repeated query keys (e.g. `?a=1&a=2`) to the last value — a Dart API
  limitation, not something this package works around.

## Roadmap

No committed roadmap beyond the limitations above and whatever the core
package's own roadmap covers.

## Contributing

Same as the [core package](../flutter_flight_recorder#contributing) —
this is a young, actively maintained project without a formal, separate
contribution process for this package yet.

## License

MIT
