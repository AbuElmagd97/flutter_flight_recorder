<!--
  Reminder: any version bump must also update the install-instruction
  version pins in this package's own README.md and in the repo-root
  WALKTHROUGH.md, not just pubspec.yaml — a pin left stale here has
  bitten us before.
-->

## 0.0.7

* `ReportPreviewScreen` now shows a "What Happened?" card and, when
  there's evidence for one, a numbered "Reproduction Steps" card —
  both built from the core package's new `IncidentAnalyzer`. The
  existing Bug Story narrative is still shown, now under "Technical
  Narrative".
* `IncidentHtmlReport` (the shared HTML export) renders the same "What
  Happened?" and "Reproduction Steps" sections, so the exported report
  matches what's shown in the app.
* Bumped the `flutter_flight_recorder` dependency constraint
  (`^0.0.7`) to track that package's new `IncidentAnalyzer` release.
* Added an "Export Markdown" action to the report preview screen and
  `ReportShare.shareMarkdown` — shares the core package's new
  `IncidentMarkdownExporter` output as a `.md` file, alongside the
  existing HTML/JSON exports.

## 0.0.6

Docs-only patch — no changes to `lib/` or `test/`.

* Added the shake-to-report-demo GIF to this README.
* Fixed a stale `^0.0.3` install-instruction version pin in this
  README and the repo-root `WALKTHROUGH.md`, and bumped the
  `flutter_flight_recorder` dependency constraint (`^0.0.6`) to track
  that package's own release.

## 0.0.5

Fix: the logo and two in-page screenshots (bug report form, HTML
report) in the README used relative paths (`docs/images/...` /
`../../docs/images/...`), which render fine on GitHub but not on
pub.dev, which serves the README disconnected from the repo's file
structure. Switched all three to absolute `raw.githubusercontent.com`
URLs.

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

* `FlutterFlightRecorderReporter`: wraps an app, manual `.open()` trigger,
  shake trigger (`ShakeDetector` + `sensors_plus`), floating button
  trigger, `ReportTrigger` (shake/button/both/manual).
* Bug report form: what happened, expected, actual, severity, and the
  automatic-attachments checklist. Validated before submission.
* Screenshot capture via `RepaintBoundary`, structurally isolated from
  the reporter's own UI (see README "Architecture").
* `BugStoryGenerator`: deterministic, human-readable narrative from an
  incident's timeline.
* Report preview screen: incident id/title, a severity-colored badge,
  Bug Story, an icon-per-item Attached checklist, all in distinct card
  sections with a brief fade + slide entrance (respects
  `MediaQuery.disableAnimations`), plus Copy Summary / Share Report /
  Export JSON / Close.
* `IncidentHtmlReport`: a single, self-contained HTML export — pure Dart
  string templating, no new dependency. Severity-colored header, QA
  report fields, a "Latest Error" callout, a styled per-category
  timeline, the screenshot embedded inline as base64 (no separate file),
  and a footer with `schema_version`/context. This is now the default,
  primary shareable format (`Share Report`); JSON remains available as
  an explicit secondary format (`Export JSON`) — see the README's
  "Report formats" section.
* Sharing via `share_plus`, in-memory (`XFile.fromData` +
  `ShareParams.fileNameOverrides`), no `path_provider`. The internal
  helper behind this (not exported — see README "Exporting JSON and
  sharing") replaced an earlier version that shared JSON + a separate
  screenshot file; the screenshot is now embedded inline in the HTML
  instead.
* Fix: the floating button is now wrapped in `MediaQuery.fromView` +
  `SafeArea`, so it no longer overlaps notches/status bars/gesture
  navigation by default. It previously had no MediaQuery ancestor at all
  (it sits outside the wrapped app's own `MaterialApp`).
* Fix: the shake trigger's accelerometer stream now has an `onError`
  handler, so a stream-level failure after listening has started stops
  shake cleanly instead of leaving a dangling, unhandled subscription. A
  failed *initial* platform-channel registration (e.g. an unsupported
  platform) is a separate path handled by `FlightRecorder`'s own
  automatic error capture, not this — see the doc comment on
  `_maybeStartShake` for why those are two different cases. Now also
  covered by a test that simulates that exact failure.
* Fix: `IncidentHtmlReport`'s timeline rows for `action` and `log`
  category events now render their metadata (as `key: value` pairs,
  same as `navigation`/`network` rows) — they previously rendered name
  and timestamp only, silently dropping any metadata those two
  categories actually carried.
