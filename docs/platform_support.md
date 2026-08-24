# Platform support

This is the single authoritative platform support document for the whole
project. Each package's README links here rather than repeating this
content.

Two different claims are made below, and they are kept **deliberately
separate** rather than blurred into one "supported" checkmark:

* **"No platform-specific code"** means the feature is built entirely
  from cross-platform Flutter SDK APIs (or, for the Dio package, from
  `dio` itself) with no platform channel, no native plugin — so there is
  no code path that *could* behave differently per platform. This is a
  fact about the implementation, verifiable by reading the source.
* **"Verified"** means someone actually built and ran the code on that
  platform and confirmed it worked. As of this writing, that's narrower:
  **only a macOS debug build of the example app** (`flutter build macos
  --debug`, launched and confirmed to stay running) has actually been
  built and run outside of `flutter test`'s host-machine execution.
  Android, iOS, Web, Windows, and Linux builds have **not** been
  attempted. `flutter analyze` and `flutter test` passing on every
  package is not the same as a real platform build succeeding, and isn't
  claimed to be.

Per the product spec's own instruction: **never claim support that
wasn't verified.** Where a table below says "No" in the Verified column,
that means exactly that — not verified — regardless of what the
adjacent "no platform-specific code" or "platforms declared" columns
say. A "Yes" in either of those other columns is not a soft way of
saying "supported."

## `flutter_flight_recorder` (core)

No platform channel, no native plugin, anywhere in this package — every
feature is either pure Dart or a Flutter SDK API
(`FlutterError`, `PlatformDispatcher`, `NavigatorObserver`,
`WidgetsBindingObserver`).

| Platform | No platform-specific code | Verified |
|---|---|---|
| Android | Yes | No |
| iOS | Yes | No |
| Web | Yes | No |
| macOS | Yes | Yes — example app built and launched (Phase 10) |
| Windows | Yes | No |
| Linux | Yes | No |

## `flutter_flight_recorder_dio`

No platform channel of its own — everything is Dart-level `dio` object
manipulation. Platform reach is bounded by `dio`'s own support, which
declares all six platforms.

| Platform | No platform-specific code | Verified |
|---|---|---|
| Android | Yes | No |
| iOS | Yes | No |
| Web | Yes | No |
| macOS | Yes | Yes — example app built and launched (Phase 10) |
| Windows | Yes | No |
| Linux | Yes | No |

## `flutter_flight_recorder_reporter`

This package is not uniform — some features have no platform-specific
code (the form, the preview screen, screenshot capture — all pure
Flutter SDK), and two depend on plugins (`sensors_plus` for shake,
`share_plus` for sharing) whose own platform reach varies.

| Feature | Mechanism | Platforms the dependency declares | Verified |
|---|---|---|---|
| Bug report form / preview screen | Pure Flutter widgets | All 6 | macOS only (Phase 10) |
| Screenshot capture | `RepaintBoundary` (Flutter SDK) | All 6 | macOS only (Phase 10) |
| Shake trigger | `sensors_plus` | Android, iOS, Windows, Linux, macOS, Web | **No** — every shake test in this repo feeds synthetic accelerometer samples directly into the detection logic; the real `sensors_plus` stream has never been exercised on any platform |
| Sharing (HTML/JSON export) | `share_plus` | Android, iOS, Windows, Linux, macOS, Web | **No** — every share test uses an injected fake `SharePlatform`; the real platform share sheet has never been exercised |

**A note on the shake trigger specifically, beyond the table above**:
`sensors_plus` *declaring* support for desktop and web platforms is not
the same as those platforms having a real accelerometer. In practice,
shake-to-report is only meaningful on a physical Android or iOS device.
On a desktop or in a browser, the accelerometer stream will most likely
simply never emit events (harmless — the trigger silently does nothing)
rather than error, but this has not been confirmed on any of those
platforms.

**Web Share API note**: `share_plus`'s web support depends on the
browser actually implementing the Web Share API, which is inconsistent
across browsers. This project has not tested that inconsistency directly
— if you're targeting web and sharing matters, verify it in your actual
target browsers rather than assuming it from this table.

## What this means for you, concretely

* If you're building for **Android or iOS**, everything in this project
  should work as designed — but "should," not "confirmed," for anything
  beyond the core package's pure-Dart logic (which is exercised
  thoroughly by `flutter test`, just not by an actual mobile build in
  this repo yet).
* If you're building for **macOS**, the example app is confirmed to
  build and launch. Shake and sharing were still not exercised for real
  even there (macOS has no accelerometer to shake).
* If you're building for **Web, Windows, or Linux**, nothing in this
  project has been run on those platforms at all. The core and Dio
  packages have no platform-specific code, so there's no *structural*
  reason they wouldn't work — but that's an inference, not a
  verification, and is reported as exactly that.
