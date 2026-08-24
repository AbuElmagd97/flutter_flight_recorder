/// Which mechanisms can open the bug reporter.
///
/// The manual trigger (`FlutterFlightRecorderReporter.open(context)`) is
/// always available regardless of this setting — [manual] just means
/// "only the manual trigger," not "no trigger at all."
enum ReportTrigger {
  /// Shake to open; no floating button.
  shake,

  /// Floating button to open; no shake detection.
  button,

  /// Both shake and the floating button are active.
  both,

  /// Neither shake nor the floating button; only the manual `.open()` call.
  manual,
}
