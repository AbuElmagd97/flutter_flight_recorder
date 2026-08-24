## 0.0.1

Work in progress — not yet published to pub.dev.

* Event model: `FlightEvent`, `EventCategory`, `EventSeverity`.
* `FlightRecorder`: `init`, `recordAction`, `log`, `recordError`,
  `setContext`, `recordNavigation`, `recordLifecycle`, `recordNetwork`
  (used by `flutter_flight_recorder_dio`).
* Bounded rolling buffer (`FlightRecorderConfig.maxEvents`, default 500),
  backed by a `ListQueue` for O(1) add/evict.
* Privacy sanitization: default sensitive-key masking (nested), custom
  sanitizers, JSON-safety normalization of metadata. Full detail in
  [`docs/privacy.md`](../../docs/privacy.md).
* Application context capture (platform, locale) plus custom context via
  `setContext`.
* Incident system: `FlightRecorder.createIncident`, immutable `Incident`
  snapshots, `QaReportData`/`IncidentSeverity`, versioned `toJson` export
  (`schema_version: 1`).
* Automatic uncaught-error capture (`FlutterError.onError` +
  `PlatformDispatcher.onError`, always chained to any existing handler).
* `FlightRecorderNavigatorObserver`: Navigator 1.x push/pop/replace/remove
  recording, route names only.
* `FlightRecorderLifecycleObserver`: app lifecycle transition recording.
* Fix: `defaultSensitiveKeys` is now actually exported from the public
  barrel — it was documented (and used as a config default) but not
  reachable from `package:flutter_flight_recorder/flutter_flight_recorder.dart`
  before this. Found while building the Dio package, which needed it.
* Fix: `createIncident` is confirmed and tested to work (with an empty
  timeline) when called on a session started with `enabled: false` —
  corrected `FlightRecorderConfig.enabled`'s doc comment, which had
  described a scenario (an incident capturing events recorded before a
  *live* session was disabled) that the API doesn't actually support,
  since `enabled` is fixed per session and can only change via a fresh
  `init()` call, which resets the buffer. Found during a test-suite audit.
* Fix: `QaReportData`'s doc comment no longer describes the reporter UI
  as not yet built — it exists, in `flutter_flight_recorder_reporter`.

Not implemented, and not currently planned: Navigator 2.0 / `go_router` /
`auto_route` support, content-aware (as opposed to key-name) privacy
sanitization. Network recording, the QA reporter UI, and HTML/JSON
sharing live in the separate `flutter_flight_recorder_dio` and
`flutter_flight_recorder_reporter` packages, not here.
