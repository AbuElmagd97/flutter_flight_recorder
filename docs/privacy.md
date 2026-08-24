# Privacy and data sanitization

This is the single authoritative privacy document for the whole
`flutter_flight_recorder` project. Each package's README links here
rather than repeating this content — if anything below ever seems to
disagree with a package README, this document wins.

## What is captured by default

* **Event metadata** you explicitly pass to `recordAction`, `log`,
  `recordError`, or that the Dio interceptor derives from a request
  (method, URL, status code, duration, error type).
* **Route names** from `FlightRecorderNavigatorObserver` — never route
  arguments.
* **App lifecycle state names** (`resumed`, `paused`, etc.) from
  `FlightRecorderLifecycleObserver`.
* **Application context**: `platform` and `locale`, captured
  automatically from the Flutter SDK, plus anything you add yourself via
  `FlightRecorder.setContext`.
* **A screenshot**, only when the QA reporter opens and only if
  `captureScreenshot` is left enabled — never captured ambiently.

## What is never captured automatically

* Request or response **bodies** — disabled by default in the Dio
  interceptor (`captureRequestBody`/`captureResponseBody`), opt-in only.
* Route **arguments** — `FlightRecorderNavigatorObserver` only ever
  records a route's name.
* Raw **gesture/touch data** — there is no automatic gesture tracking in
  this project at all (spec §5); only the explicit `recordAction` call
  you write.
* **App version or build number** — the core package deliberately does
  not auto-capture these (see "App version/build number" below).
* Anything from a QA reporter's bug report form beyond what's typed into
  it — no telemetry beyond what a user or the app explicitly records.

## When sanitization happens

Synchronously, at record time — before an event ever enters the rolling
buffer. There is no "sanitize on export" step; by the time an event is
sitting in the buffer, it has already been through
[`Sanitizer.sanitizeMetadata`](../packages/flutter_flight_recorder/lib/src/privacy/sanitizer.dart).
Every downstream consumer — `Incident.toJson()`, the Bug Story generator,
the HTML report — only ever reads already-sanitized data. None of them
re-sanitize, and none of them have a separate path to raw data.

## What is sanitized, and how

Two independent things happen in the same recursive walk over a metadata
map, at any nesting depth (objects, and objects inside lists):

1. **Masking.** Any key matching the sensitive-key list — by default
   `password`, `token`, `authorization`, `access_token`, `refresh_token`,
   `cookie`, `session` — has its value replaced with `'***'`. Matching is
   case-insensitive.
2. **Normalization.** Values that aren't already JSON-safe (a custom
   object, a `DateTime`, etc.) are converted to a safe representation
   (usually via `toString()`), and long string values are truncated —
   this guarantees an event can never fail to serialize later, and can't
   grow the buffer unboundedly from one oversized value.

```json
{
  "user": {
    "email": "user@example.com",
    "password": "secret"
  }
}
```

becomes

```json
{
  "user": {
    "email": "user@example.com",
    "password": "***"
  }
}
```

The Dio interceptor adds one more layer specific to itself: it also
masks matching keys in a request's **query string**, since a URL is a
single opaque string to the generic metadata sanitizer above — it
doesn't parse query parameters looking for sensitive-looking keys. See
`FlightRecorderDioInterceptor.sensitiveQueryParams`.

## The one honest limitation: this is key-name matching, not content inspection

Sensitive data stored under a **non-standard key** (e.g. `'pwd'` instead
of `'password'`) will **not** be masked automatically. There is no
scanning of values themselves for anything that looks like a secret
(a credit card number, an API key format, etc.) — only key names are
checked.

If your application uses non-standard key names for sensitive data, do
one of:

```dart
FlightRecorder.init(
  const FlightRecorderConfig(
    privacy: PrivacyConfig(
      sensitiveKeys: {...defaultSensitiveKeys, 'pwd', 'ssn'},
    ),
  ),
);
```

or supply a `customSanitizer` (`Object? Function(String key, Object? value)`),
which runs on every top-level metadata entry before the default masking
check. Note: `customSanitizer` only runs on **top-level** keys of the
metadata map you pass to a given call — nested keys still only go
through the default key-name check.

## App version/build number

The core package auto-captures exactly `platform` and `locale`. It does
not, and by design never will, automatically capture app version or
build number: the only package that provides them
(`package_info_plus`) would raise the core package's minimum supported
Flutter version to match its own floor, which would defeat the point of
keeping core dependency-free and maximally portable. Supply them
yourself if you need them:

```dart
final info = await PackageInfo.fromPlatform(); // package_info_plus, in your own app
FlightRecorder.setContext('app_version', info.version);
FlightRecorder.setContext('build_number', info.buildNumber);
```

## The HTML report and screenshots

`IncidentHtmlReport` (in `flutter_flight_recorder_reporter`) only ever
reads from the already-sanitized `Incident` object it's given — it has
no separate data path, and it never re-sanitizes or un-masks anything.
It does, however, embed the **screenshot** inline as base64 image data
if one was captured and the QA reporter user chose to include it. A
screenshot is a pixel capture of the current UI — it is not covered by
key-name masking, because it isn't structured metadata. If your app's
screen can show sensitive information on screen, treat the screenshot
step in the QA reporter the same way you'd treat any other screen
recording or screenshot capability: it's shown to the QA user before
submission specifically so they can exclude it.

## Summary table

| Data | Captured automatically? | Sanitized? |
|---|---|---|
| Action/log/error metadata you pass | Yes, if you pass it | Yes (key-name masking + normalization) |
| Route names | Yes (if observer attached) | N/A (names only, never arguments) |
| Route arguments | No, never | — |
| Lifecycle state names | Yes (if observer attached) | N/A |
| Dio request/response bodies | No (opt-in) | Yes, once captured |
| Dio URL query parameters | Yes | Yes (dedicated URL sanitizer) |
| App context (platform/locale) | Yes | N/A (not sensitive) |
| App version/build number | No, never | — (supply via `setContext` yourself) |
| Screenshot | Only when the reporter opens, opt-in per report | Not applicable — it's pixels, not structured data; QA can exclude it before sending |
